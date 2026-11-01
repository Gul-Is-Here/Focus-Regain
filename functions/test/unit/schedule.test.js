import assert from 'node:assert/strict';
import { test } from 'node:test';
import { buildMessage } from '../../src/messages.js';
import {
  atLocal, engagementBlock, firstTask, focusActive, focusOn, followingTask,
  inQuietHours, planOf, scheduleKey, skipReason,
} from '../../src/schedule.js';

const H = 60 * 60 * 1000;
const iso = (s) => Date.parse(s);
const user = (over = {}) => ({
  timezone: 'Asia/Karachi',
  lastActiveDay: '2026-11-01',
  notificationPrefs: {
    focusEncouragement: { enabled: true, minute: 18 * 60 },
    dailySummary: { enabled: true, minute: 21 * 60 },
    reEngagement: { enabled: true },
    quietHours: { enabled: true, start: 22 * 60, end: 7 * 60 },
  },
  ...over,
});

test('local times follow the time zone, including DST changes', () => {
  assert.equal(atLocal('2026-11-01', 18 * 60, 'Asia/Karachi'), iso('2026-11-01T13:00:00Z'));
  // New York: 18:00 is 23:00Z in winter and 22:00Z in summer.
  assert.equal(atLocal('2026-03-07', 18 * 60, 'America/New_York'), iso('2026-03-07T23:00:00Z'));
  assert.equal(atLocal('2026-03-09', 18 * 60, 'America/New_York'), iso('2026-03-09T22:00:00Z'));
  // 02:30 doesn't exist on 2026-03-08 there; it moves forward instead of failing.
  assert.equal(atLocal('2026-03-08', 150, 'America/New_York'), iso('2026-03-08T07:30:00Z'));
});

test('quiet hours, overnight and same-day', () => {
  const night = { enabled: true, start: 22 * 60, end: 7 * 60 };
  assert.equal(inQuietHours(night, 23 * 60), true);
  assert.equal(inQuietHours(night, 6 * 60 + 59), true);
  assert.equal(inQuietHours(night, 7 * 60), false);
  assert.equal(inQuietHours(night, 21 * 60 + 59), false);
  assert.equal(inQuietHours({ enabled: true, start: 13 * 60, end: 14 * 60 }, 13 * 60 + 30), true);
  assert.equal(inQuietHours({ ...night, enabled: false }, 23 * 60), false);
});

test('a kind that is off has no plan; changing time or zone changes the version', () => {
  const u = user();
  assert.equal(planOf(user({ notificationPrefs: {} }), 'dailySummary'), null);
  const base = planOf(u, 'focusEncouragement').version;
  const later = user({ notificationPrefs: { ...u.notificationPrefs, focusEncouragement: { enabled: true, minute: 19 * 60 } } });
  assert.notEqual(planOf(later, 'focusEncouragement').version, base);
  assert.notEqual(planOf(user({ timezone: 'Europe/London' }), 'focusEncouragement').version, base);
  // Quiet hours don't move a chosen time (it is skipped at send time instead).
  const quiet = user({ notificationPrefs: { ...u.notificationPrefs, quietHours: { enabled: true, start: 0, end: 60 } } });
  assert.equal(planOf(quiet, 'focusEncouragement').version, base);
});

test('check-ins move out of quiet hours', () => {
  const u = user();
  const evening = user({ notificationPrefs: { ...u.notificationPrefs, quietHours: { enabled: true, start: 17 * 60, end: 19 * 60 } } });
  assert.equal(planOf(evening, 'reEngagement').minute, 19 * 60);
  assert.equal(planOf(u, 'reEngagement').minute, 18 * 60);
});

test('first task is today if the time is ahead, else tomorrow; ids are deterministic', () => {
  const u = user();
  const morning = iso('2026-11-01T05:00:00Z'); // 10:00 in Karachi
  const t = firstTask('uid1', u, 'focusEncouragement', morning);
  assert.equal(t.data.dateKey, '2026-11-01');
  assert.equal(t.data.scheduledAt, iso('2026-11-01T13:00:00Z'));
  assert.equal(t.id, `uid1-focusEncouragement-2026-11-01-${t.data.version}`);
  assert.deepEqual(firstTask('uid1', u, 'focusEncouragement', morning), t);
  const night = iso('2026-11-01T16:00:00Z'); // 21:00
  assert.equal(firstTask('uid1', u, 'focusEncouragement', night).data.dateKey, '2026-11-02');
});

test('a time zone change moves the next send to the new local time', () => {
  const now = iso('2026-11-01T05:00:00Z');
  const before = firstTask('u', user(), 'focusEncouragement', now);
  const after = firstTask('u', user({ timezone: 'Europe/London' }), 'focusEncouragement', now);
  assert.equal(after.data.scheduledAt, iso('2026-11-01T18:00:00Z'));
  assert.notEqual(after.id, before.id);
});

test('check-in is 3 days after last activity, then a week later', () => {
  const now = iso('2026-11-01T10:00:00Z');
  const t = firstTask('u', user(), 'reEngagement', now);
  assert.equal(t.data.dateKey, '2026-11-04');
  assert.equal(followingTask('u', user(), 'reEngagement', '2026-11-04', now).data.dateKey, '2026-11-11');
  assert.equal(followingTask('u', user(), 'dailySummary', '2026-11-04', now).data.dateKey, '2026-11-05');
});

test('focus time counts only real sessions, split at local midnight', () => {
  const sessions = [
    // 23:30-00:30 Karachi time: 30 min on each day.
    { startedAt: iso('2026-11-01T18:30:00Z'), endsAt: iso('2026-11-01T19:30:00Z'), endedAt: iso('2026-11-01T19:30:00Z') },
    // Stopped early after 10 min.
    { startedAt: iso('2026-11-02T05:00:00Z'), endsAt: iso('2026-11-02T06:00:00Z'), endedAt: iso('2026-11-02T05:10:00Z') },
    { startedAt: 'bad', endsAt: 5 },
  ];
  const u = user({ focus: { sessions } });
  assert.deepEqual(focusOn(u, '2026-11-01', iso('2026-11-03T00:00:00Z')), { minutes: 30, sessions: 1 });
  assert.deepEqual(focusOn(u, '2026-11-02', iso('2026-11-03T00:00:00Z')), { minutes: 40, sessions: 2 });
  const running = user({ focus: { sessions: [{ startedAt: iso('2026-11-02T05:00:00Z'), endsAt: iso('2026-11-02T06:00:00Z'), endedAt: null }] } });
  assert.equal(focusActive(running, iso('2026-11-02T05:30:00Z')), true);
  assert.equal(focusActive(running, iso('2026-11-02T06:00:00Z')), false);
  assert.equal(focusOn(running, '2026-11-02', iso('2026-11-02T05:20:00Z')).minutes, 20);
});

test('optional nudges: one a day, three a week, pause after three ignored', () => {
  const now = iso('2026-11-10T12:00:00Z');
  const sent = (daysAgo, opened = false) => ({
    engagement: true, status: 'accepted', sentAt: now - daysAgo * 24 * H, openedAt: opened ? 1 : undefined,
  });
  assert.equal(engagementBlock([], now, 'UTC'), null);
  assert.equal(engagementBlock([sent(0.1)], now, 'UTC'), 'daily-cap');
  assert.equal(engagementBlock([sent(1, true), sent(2, true), sent(3, true)], now, 'UTC'), 'weekly-cap');
  assert.equal(engagementBlock([sent(8), sent(9), sent(10)], now, 'UTC'), 'ignored-cooldown');
  assert.equal(engagementBlock([sent(8, true), sent(9), sent(10)], now, 'UTC'), null);
  // Skipped and reminder sends don't count.
  assert.equal(engagementBlock([{ ...sent(0.1), status: 'skipped' }, { ...sent(0.1), engagement: false }], now, 'UTC'), null);
});

test('skip reasons are checked right before sending', () => {
  const at = iso('2026-11-01T13:00:00Z'); // 18:00 Karachi
  const base = { kind: 'focusEncouragement', dateKey: '2026-11-01', scheduledAt: at, history: [], state: undefined };
  assert.equal(skipReason({ ...base, user: user(), now: at }), null);
  assert.equal(skipReason({ ...base, user: user(), now: at + 3 * H }), 'too-late');
  assert.equal(skipReason({ ...base, scheduledAt: at + 5 * H, user: user(), now: at + 5 * H }), 'quiet-hours');
  const running = user({ focus: { sessions: [{ startedAt: at - 60000, endsAt: at + H, endedAt: null }] } });
  assert.equal(skipReason({ ...base, user: running, now: at }), 'focus-active');
  assert.equal(skipReason({ ...base, kind: 'dailySummary', user: user(), now: at }), 'no-activity');

  const re = { ...base, kind: 'reEngagement' };
  const recent = user({ lastActiveAt: at - 24 * H });
  assert.equal(skipReason({ ...re, user: recent, now: at }), 'active');
  const away = user({ lastActiveAt: at - 4 * 24 * H });
  assert.equal(skipReason({ ...re, user: away, now: at }), null);
  const twoSent = { reEngagementStreak: 2, lastReEngagementAt: at - 24 * H };
  assert.equal(skipReason({ ...re, user: away, state: twoSent, now: at }), 'inactivity-cooldown');
  // Coming back resets the streak.
  const back = user({ lastActiveAt: at - 3.5 * 24 * H });
  assert.equal(skipReason({ ...re, user: back, state: { reEngagementStreak: 2, lastReEngagementAt: at - 4 * 24 * H }, now: at }), null);
});

test('syncing focus sessions does not touch the schedule', () => {
  const u = user();
  assert.equal(scheduleKey(u), scheduleKey({ ...u, focus: { sessions: [] } }));
  assert.notEqual(scheduleKey(u), scheduleKey({ ...u, lastActiveDay: '2026-11-02' }));
});

test('messages carry no personal details and collapse duplicates on the device', () => {
  const m = buildMessage({ kind: 'dailySummary', uid: 'u', notificationId: 'dailySummary_2026-11-01', summary: { minutes: 65, sessions: 2 } });
  assert.equal(m.notification.body, 'You focused for 1 h 5 min across 2 sessions.');
  assert.equal(m.android.notification.tag, 'dailySummary_2026-11-01');
  assert.equal(m.android.notification.visibility, 'private');
  assert.equal(m.apns.headers['apns-collapse-id'], 'dailySummary_2026-11-01');
  assert.deepEqual(m.data, { notificationId: 'dailySummary_2026-11-01', uid: 'u', route: 'focus', kind: 'dailySummary' });
  for (const v of Object.values(m.data)) assert.equal(typeof v, 'string');
});
