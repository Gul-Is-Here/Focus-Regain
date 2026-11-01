// When each notification is due and whether it may be sent. Pure functions:
// no Firestore, no clock (callers pass `now` in epoch ms), so they're unit-tested.
import { createHash } from 'node:crypto';
import { DateTime } from 'luxon';

export const KINDS = ['focusEncouragement', 'dailySummary', 'reEngagement'];

/** Optional nudges the user didn't schedule themselves; these share the caps below. */
export const ENGAGEMENT_KINDS = new Set(['focusEncouragement', 'reEngagement']);

export const INACTIVE_DAYS = 3;
export const REENGAGE_MINUTE = 18 * 60;
export const REENGAGE_COOLDOWN_DAYS = 7;
/** Check-ins in a row without the user coming back, before we stop until they do. */
export const MAX_REENGAGE_STREAK = 2;
export const MAX_ENGAGEMENT_PER_WEEK = 3;
/** This many unopened nudges in a row pause nudges for IGNORED_PAUSE_DAYS. */
export const IGNORED_IN_A_ROW = 3;
export const IGNORED_PAUSE_DAYS = 14;
/** A task delayed past this (retries, outage) is dropped instead of arriving at an odd time. */
export const MAX_LATE_MS = 2 * 60 * 60 * 1000;

const DAY_MS = 24 * 60 * 60 * 1000;

/** The user's IANA zone, or UTC if missing or unknown. */
export function zoneOf(user) {
  const zone = user?.timezone;
  return typeof zone === 'string' && DateTime.now().setZone(zone).isValid ? zone : 'UTC';
}

const local = (ms, zone) => DateTime.fromMillis(ms, { zone });
const minuteOfDay = (dt) => dt.hour * 60 + dt.minute;

/** Epoch ms of [minute] past local midnight on [dateKey] (yyyy-mm-dd). A time skipped by a DST change moves forward. */
export function atLocal(dateKey, minute, zone) {
  return DateTime.fromISO(dateKey, { zone })
    .set({ hour: Math.floor(minute / 60), minute: minute % 60 })
    .toMillis();
}

export const addDays = (dateKey, days) => DateTime.fromISO(dateKey).plus({ days }).toISODate();

/** Quiet hours may run past midnight (e.g. 22:00-07:00). */
export function inQuietHours(quiet, minute) {
  if (!quiet?.enabled || quiet.start === quiet.end) return false;
  return quiet.start < quiet.end
    ? minute >= quiet.start && minute < quiet.end
    : minute >= quiet.start || minute < quiet.end;
}

const hash = (parts) => createHash('sha256').update(JSON.stringify(parts)).digest('hex').slice(0, 12);

/**
 * The schedule of [kind] for [user], or null when it's off. [version] changes
 * whenever something that moves the send time changes, so tasks queued under
 * an old version know they are stale.
 */
export function planOf(user, kind) {
  const prefs = user?.notificationPrefs ?? {};
  if (!prefs[kind]?.enabled) return null;
  const zone = zoneOf(user);
  if (kind === 'reEngagement') {
    if (!user.lastActiveDay) return null;
    // Early evening, moved to the end of quiet hours if it falls inside them.
    const minute = inQuietHours(prefs.quietHours, REENGAGE_MINUTE)
      ? prefs.quietHours.end
      : REENGAGE_MINUTE;
    return { minute, version: hash([kind, zone, minute, user.lastActiveDay]) };
  }
  const minute = prefs[kind].minute;
  if (!Number.isInteger(minute) || minute < 0 || minute >= 24 * 60) return null;
  return { minute, version: hash([kind, zone, minute]) };
}

function task(uid, kind, dateKey, plan, zone) {
  return {
    id: `${uid}-${kind}-${dateKey}-${plan.version}`,
    data: { uid, kind, dateKey, version: plan.version, scheduledAt: atLocal(dateKey, plan.minute, zone) },
  };
}

/** The first day on or after [dateKey] whose send time is still ahead of [now]. */
function firstAhead(dateKey, plan, zone, now) {
  let day = dateKey;
  while (atLocal(day, plan.minute, zone) <= now) day = addDays(day, 1);
  return day;
}

/** The next task of [kind] after [now], or null if it's off. */
export function firstTask(uid, user, kind, now) {
  const plan = planOf(user, kind);
  if (!plan) return null;
  const zone = zoneOf(user);
  const start = kind === 'reEngagement'
    ? addDays(user.lastActiveDay, INACTIVE_DAYS)
    : local(now, zone).toISODate();
  return task(uid, kind, firstAhead(start, plan, zone, now), plan, zone);
}

/** The task after the one for [dateKey]: tomorrow, or a week later for check-ins. */
export function followingTask(uid, user, kind, dateKey, now) {
  const plan = planOf(user, kind);
  if (!plan) return null;
  const zone = zoneOf(user);
  const step = kind === 'reEngagement' ? REENGAGE_COOLDOWN_DAYS : 1;
  return task(uid, kind, firstAhead(addDays(dateKey, step), plan, zone, now), plan, zone);
}

/** All tasks that should be queued for [user] now. */
export function plannedTasks(uid, user, now) {
  return KINDS.map((kind) => firstTask(uid, user, kind, now)).filter(Boolean);
}

/** Changes when queued tasks must be redone; other writes (focus sync) leave it alone. */
export function scheduleKey(user) {
  if (!user) return null;
  return JSON.stringify([KINDS.map((k) => planOf(user, k)?.version ?? null), user.lastActiveDay ?? null]);
}

const sessionEnd = (s, now) => s.endedAt ?? Math.min(s.endsAt, now);

/** Synced sessions with sane numbers only (rules can't check list items). */
function sessionsOf(user) {
  const ok = (v) => Number.isFinite(v);
  return (Array.isArray(user?.focus?.sessions) ? user.focus.sessions : []).filter(
    (s) => s && ok(s.startedAt) && ok(s.endsAt) && s.endsAt >= s.startedAt &&
      (s.endedAt == null || (ok(s.endedAt) && s.endedAt >= s.startedAt)),
  );
}

/** A focus session is running right now (synced from the phone; never guessed). */
export function focusActive(user, now) {
  return sessionsOf(user).some(
    (s) => s.endedAt == null && s.startedAt <= now && now < s.endsAt,
  );
}

/** Real focus time on local day [dateKey], up to [now]. */
export function focusOn(user, dateKey, now) {
  const zone = zoneOf(user);
  const dayStart = atLocal(dateKey, 0, zone);
  const dayEnd = atLocal(addDays(dateKey, 1), 0, zone);
  let ms = 0;
  let sessions = 0;
  for (const s of sessionsOf(user)) {
    const overlap = Math.min(sessionEnd(s, now), dayEnd) - Math.max(s.startedAt, dayStart);
    if (overlap > 0) {
      ms += overlap;
      sessions += 1;
    }
  }
  return { minutes: Math.floor(ms / 60000), sessions };
}

const millis = (t) => (t == null ? null : typeof t === 'number' ? t : t.toMillis());

/**
 * Why optional nudges must wait, from what was really sent ([history]: notification
 * logs of the last two weeks), or null. Opens count: ignored nudges slow us down.
 */
export function engagementBlock(history, now, zone) {
  const sent = history
    .filter((n) => n.engagement && n.status === 'accepted' && n.sentAt != null)
    .map((n) => ({ sentAt: millis(n.sentAt), opened: n.openedAt != null }))
    .sort((a, b) => b.sentAt - a.sentAt);
  const today = local(now, zone).toISODate();
  if (sent.some((n) => local(n.sentAt, zone).toISODate() === today)) return 'daily-cap';
  if (sent.filter((n) => now - n.sentAt < 7 * DAY_MS).length >= MAX_ENGAGEMENT_PER_WEEK) return 'weekly-cap';
  const recent = sent.slice(0, IGNORED_IN_A_ROW);
  if (
    recent.length === IGNORED_IN_A_ROW &&
    recent.every((n) => !n.opened) &&
    now - recent[0].sentAt < IGNORED_PAUSE_DAYS * DAY_MS
  ) return 'ignored-cooldown';
  return null;
}

/** Check-ins sent since the user was last active. */
export function reEngagementStreak(user, state) {
  const lastSent = millis(state?.lastReEngagementAt);
  const lastActive = millis(user?.lastActiveAt);
  if (lastSent == null || (lastActive != null && lastActive > lastSent)) return 0;
  return state.reEngagementStreak ?? 0;
}

/** Why this occurrence must not be sent right now, or null. Checked right before sending. */
export function skipReason({ kind, dateKey, scheduledAt, user, history, state, now }) {
  const zone = zoneOf(user);
  if (now - scheduledAt > MAX_LATE_MS) return 'too-late';
  if (inQuietHours(user.notificationPrefs?.quietHours, minuteOfDay(local(now, zone)))) return 'quiet-hours';
  if (kind === 'focusEncouragement' && focusActive(user, now)) return 'focus-active';
  if (kind === 'dailySummary' && focusOn(user, dateKey, now).minutes === 0) return 'no-activity';
  if (kind === 'reEngagement') {
    const lastActive = millis(user.lastActiveAt);
    if (lastActive != null && now - lastActive < INACTIVE_DAYS * DAY_MS) return 'active';
    if (reEngagementStreak(user, state) >= MAX_REENGAGE_STREAK) return 'inactivity-cooldown';
  }
  if (ENGAGEMENT_KINDS.has(kind)) return engagementBlock(history, now, zone);
  return null;
}
