// Sending and scheduling. Dependencies are passed in ({ db, messaging, queue, now })
// so tests run against the Firestore emulator with a fake FCM and task queue.
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { buildMessage } from './messages.js';
import {
  ENGAGEMENT_KINDS,
  KINDS,
  followingTask,
  focusOn,
  planOf,
  plannedTasks,
  reEngagementStreak,
  skipReason,
} from './schedule.js';

const DAY_MS = 24 * 60 * 60 * 1000;
const EARLY_MS = 5 * 60 * 1000;
/** Devices not seen for this long are dropped (FCM itself treats a month idle as stale). */
export const STALE_DEVICE_MS = 60 * DAY_MS;

/** FCM says this installation will never receive again. */
const GONE = new Set([
  'messaging/installation-id-not-registered',
  'messaging/registration-token-not-registered',
]);
/** Worth another try later (Cloud Tasks retries the whole run). */
const TRANSIENT = new Set([
  'messaging/internal-error',
  'messaging/server-unavailable',
  'messaging/unknown-error',
  'messaging/message-rate-exceeded',
]);

/** Queues [task]; a task with the same id is already queued (or ran recently), so that's fine. */
export async function enqueue(queue, task) {
  if (!task) return;
  try {
    await queue.enqueue(task.data, { id: task.id, scheduleTime: new Date(task.data.scheduledAt) });
  } catch (e) {
    if (!String(e.code ?? '').endsWith('task-already-exists')) throw e;
  }
}

/** Best effort: the dispatcher's version check also drops tasks we fail to delete. */
async function cancel(queue, id) {
  try {
    await queue.delete(id);
  } catch {
    // Already ran or never existed.
  }
}

/**
 * After the user's settings or activity changed: cancels tasks whose schedule
 * changed or was turned off, and queues the next one of each enabled kind.
 */
export async function syncSchedule({ queue, now }, uid, before, after) {
  const next = after ? plannedTasks(uid, after, now) : [];
  const keep = new Set(next.map((t) => t.id));
  for (const old of before ? plannedTasks(uid, before, now) : []) {
    if (!keep.has(old.id)) await cancel(queue, old.id);
  }
  for (const t of next) await enqueue(queue, t);
}

/** A reinstall or account switch can leave the same installation under another user: drop it there. */
export async function claimDevice({ db }, uid, deviceId, fid) {
  const same = await db.collectionGroup('devices').where('fid', '==', fid).get();
  await Promise.all(
    same.docs
      .filter((d) => d.ref.parent.parent.id !== uid || d.id !== deviceId)
      .map((d) => d.ref.delete()),
  );
}

/** Account deleted: cancel what's queued and remove everything stored for it. */
export async function deleteAccountData({ db, queue, now }, uid) {
  const ref = db.doc(`users/${uid}`);
  const snap = await ref.get();
  if (snap.exists) {
    for (const t of plannedTasks(uid, snap.data(), now)) await cancel(queue, t.id);
  }
  await db.recursiveDelete(ref);
}

function validTask(t) {
  return (
    t &&
    typeof t.uid === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(t.uid) &&
    KINDS.includes(t.kind) &&
    typeof t.dateKey === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(t.dateKey) &&
    typeof t.version === 'string' &&
    Number.isFinite(t.scheduledAt)
  );
}

/**
 * Handles one due task. Retry-safe: the log doc `notifications/{kind}_{dateKey}`
 * is claimed in a transaction, so a finished occurrence is never sent again.
 * A crash between FCM accepting and the log update can still resend once; the
 * device tag / collapse id then replaces the first copy instead of showing two.
 */
export async function dispatch({ db, messaging, queue, now }, task) {
  if (!validTask(task)) return { outcome: 'invalid' };
  const { uid, kind, dateKey, version, scheduledAt } = task;
  // Cloud Tasks never runs early, but a queue that does (the local emulator) or a
  // stray manual call must not send tomorrow's reminder today.
  if (now < scheduledAt - EARLY_MS) return { outcome: 'early' };
  const userRef = db.doc(`users/${uid}`);
  const userSnap = await userRef.get();
  if (!userSnap.exists) return { outcome: 'no-user' };
  const user = userSnap.data();

  // Turned off, or moved: a newer chain (if any) already exists.
  if (planOf(user, kind)?.version !== version) return { outcome: 'stale' };
  // Keep the chain going before anything can fail below.
  await enqueue(queue, followingTask(uid, user, kind, dateKey, now));

  const notificationId = `${kind}_${dateKey}`;
  const logRef = userRef.collection('notifications').doc(notificationId);
  const at = Timestamp.fromMillis(now);
  const claimed = await db.runTransaction(async (tx) => {
    const status = (await tx.get(logRef)).data()?.status;
    if (status === 'accepted' || status === 'skipped') return false;
    tx.set(logRef, {
      kind, dateKey, engagement: ENGAGEMENT_KINDS.has(kind),
      status: 'processing', runs: FieldValue.increment(1), updatedAt: at,
    }, { merge: true });
    return true;
  });
  if (!claimed) return { outcome: 'duplicate' };

  const [historySnap, stateSnap, devicesSnap] = await Promise.all([
    userRef.collection('notifications').where('sentAt', '>=', Timestamp.fromMillis(now - 14 * DAY_MS)).get(),
    userRef.collection('private').doc('engagement').get(),
    userRef.collection('devices').get(),
  ]);
  const state = stateSnap.data();
  const reason = skipReason({
    kind, dateKey, scheduledAt, user, now, state,
    history: historySnap.docs.map((d) => d.data()),
  });
  const skip = async (why) => {
    await logRef.set({ status: 'skipped', skipReason: why, updatedAt: at }, { merge: true });
    return { outcome: 'skipped', reason: why };
  };
  if (reason) return skip(reason);

  const stale = devicesSnap.docs.filter((d) => now - (d.data().updatedAt?.toMillis() ?? 0) > STALE_DEVICE_MS);
  await Promise.all(stale.map((d) => d.ref.delete()));
  const devices = devicesSnap.docs.filter((d) => !stale.includes(d));
  if (devices.length === 0) return skip('no-devices');

  const summary = kind === 'dailySummary' ? focusOn(user, dateKey, now) : undefined;
  const message = buildMessage({ kind, uid, notificationId, summary });
  await logRef.set({ status: 'sending', sendAttempts: FieldValue.increment(1), updatedAt: at }, { merge: true });
  const result = await messaging.sendEach(devices.map((d) => ({ ...message, fid: d.data().fid })));

  const codes = result.responses.map((r) => (r.success ? null : r.error?.code ?? 'unknown'));
  await Promise.all(devices.filter((_, i) => GONE.has(codes[i])).map((d) => d.ref.delete()));
  const accepted = result.responses.filter((r) => r.success).length;
  // "accepted" means FCM took the message for these devices, not that a device showed it.
  const log = {
    providerAccepted: accepted,
    providerRejected: codes.filter((c) => c && !TRANSIENT.has(c)).length,
    errorCodes: [...new Set(codes.filter(Boolean))],
    updatedAt: at,
  };
  if (accepted > 0) {
    await logRef.set({ ...log, status: 'accepted', sentAt: at }, { merge: true });
    if (kind === 'reEngagement') {
      await stateSnap.ref.set({
        reEngagementStreak: reEngagementStreak(user, state) + 1,
        lastReEngagementAt: at,
      }, { merge: true });
    }
    return { outcome: 'accepted', accepted };
  }
  if (codes.some((c) => TRANSIENT.has(c))) {
    await logRef.set({ ...log, status: 'retrying' }, { merge: true });
    throw new Error(`FCM unavailable for ${uid}/${notificationId}; Cloud Tasks will retry`);
  }
  await logRef.set({ ...log, status: 'failed' }, { merge: true });
  return { outcome: 'failed', codes: log.errorCodes };
}
