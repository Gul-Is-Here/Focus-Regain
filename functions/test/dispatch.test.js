// Runs against the Firestore emulator (npm test). FCM and Cloud Tasks are fakes.
import assert from 'node:assert/strict';
import { beforeEach, test } from 'node:test';
import { initializeApp } from 'firebase-admin/app';
import { Timestamp, getFirestore } from 'firebase-admin/firestore';
import { claimDevice, deleteAccountData, dispatch, syncSchedule } from '../src/dispatch.js';
import { firstTask, plannedTasks } from '../src/schedule.js';

const PROJECT = 'demo-regain';
initializeApp({ projectId: PROJECT });
const db = getFirestore();
const H = 60 * 60 * 1000;
const DAY = 24 * H;
const AT = Date.parse('2026-11-01T13:00:00Z'); // 18:00 in Karachi

function fakeMessaging(codeFor = () => null) {
  const sent = [];
  return {
    sent,
    async sendEach(messages) {
      sent.push(...messages);
      return {
        responses: messages.map((m) => {
          const code = codeFor(m.fid);
          return code ? { success: false, error: { code } } : { success: true, messageId: `id-${m.fid}` };
        }),
      };
    },
  };
}

function fakeQueue() {
  const tasks = new Map();
  return {
    tasks,
    async enqueue(data, { id }) {
      if (tasks.has(id)) throw Object.assign(new Error('exists'), { code: 'functions/task-already-exists' });
      tasks.set(id, data);
    },
    async delete(id) {
      tasks.delete(id);
    },
  };
}

const prefs = {
  focusEncouragement: { enabled: true, minute: 18 * 60 },
  dailySummary: { enabled: true, minute: 21 * 60 },
  reEngagement: { enabled: true },
  quietHours: { enabled: true, start: 22 * 60, end: 7 * 60 },
};

async function seed(uid, { user = {}, devices = { phone: 'fid-phone', tablet: 'fid-tablet' } } = {}) {
  const data = {
    timezone: 'Asia/Karachi', lastActiveDay: '2026-11-01',
    lastActiveAt: Timestamp.fromMillis(AT - DAY), notificationPrefs: prefs, ...user,
  };
  await db.doc(`users/${uid}`).set(data);
  for (const [id, fid] of Object.entries(devices)) {
    await db.doc(`users/${uid}/devices/${id}`).set({ fid, platform: 'android', updatedAt: Timestamp.fromMillis(AT - H) });
  }
  return data;
}

const taskFor = (uid, data, kind, now = AT - H) => firstTask(uid, data, kind, now).data;
const log = async (uid, id) => (await db.doc(`users/${uid}/notifications/${id}`).get()).data();
const deviceIds = async (uid) => (await db.collection(`users/${uid}/devices`).get()).docs.map((d) => d.id).sort();

beforeEach(async () => {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  await fetch(`http://${host}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`, { method: 'DELETE' });
});

test('sends to every device once, logs FCM acceptance, and queues tomorrow', async () => {
  const data = await seed('alice');
  const messaging = fakeMessaging();
  const queue = fakeQueue();
  const task = taskFor('alice', data, 'focusEncouragement');
  const r = await dispatch({ db, messaging, queue, now: AT }, task);
  assert.deepEqual(r, { outcome: 'accepted', accepted: 2 });
  assert.deepEqual(messaging.sent.map((m) => m.fid).sort(), ['fid-phone', 'fid-tablet']);
  const entry = await log('alice', 'focusEncouragement_2026-11-01');
  assert.equal(entry.status, 'accepted');
  assert.equal(entry.providerAccepted, 2);
  assert.equal(entry.openedAt, undefined); // opens are recorded by the app, separately
  assert.ok([...queue.tasks.values()].some((t) => t.kind === 'focusEncouragement' && t.dateKey === '2026-11-02'));

  // Cloud Tasks retries the same task (or two copies run): no second send.
  const again = await dispatch({ db, messaging, queue, now: AT + 60000 }, task);
  assert.equal(again.outcome, 'duplicate');
  assert.equal(messaging.sent.length, 2);
});

test('removes uninstalled devices and still reaches the others', async () => {
  const data = await seed('bob');
  const messaging = fakeMessaging((fid) => (fid === 'fid-tablet' ? 'messaging/installation-id-not-registered' : null));
  const r = await dispatch({ db, messaging, queue: fakeQueue(), now: AT }, taskFor('bob', data, 'focusEncouragement'));
  assert.equal(r.accepted, 1);
  assert.deepEqual(await deviceIds('bob'), ['phone']);
});

test('FCM outage: throws so Cloud Tasks retries, then sends exactly once', async () => {
  const data = await seed('cara', { devices: { phone: 'fid-phone' } });
  const task = taskFor('cara', data, 'focusEncouragement');
  const queue = fakeQueue();
  await assert.rejects(dispatch({ db, messaging: fakeMessaging(() => 'messaging/server-unavailable'), queue, now: AT }, task));
  assert.equal((await log('cara', task.kind + '_' + task.dateKey)).status, 'retrying');
  const ok = fakeMessaging();
  assert.equal((await dispatch({ db, messaging: ok, queue, now: AT + 60000 }, task)).outcome, 'accepted');
  assert.equal((await dispatch({ db, messaging: ok, queue, now: AT + 120000 }, task)).outcome, 'duplicate');
  assert.equal(ok.sent.length, 1);
  const entry = await log('cara', 'focusEncouragement_2026-11-01');
  assert.equal(entry.sendAttempts, 2);
  assert.equal(entry.runs, 2); // the duplicate run never claims it
});

test('opt-out and time changes cancel queued tasks; old tasks are dropped as stale', async () => {
  const before = await seed('dan');
  const queue = fakeQueue();
  await syncSchedule({ queue, now: AT - H }, 'dan', null, before);
  const old = taskFor('dan', before, 'focusEncouragement');
  assert.equal(queue.tasks.size, 3);

  const off = { ...before, notificationPrefs: { ...prefs, focusEncouragement: { enabled: false, minute: 18 * 60 } } };
  await db.doc('users/dan').set(off);
  await syncSchedule({ queue, now: AT - H }, 'dan', before, off);
  assert.equal([...queue.tasks.values()].some((t) => t.kind === 'focusEncouragement'), false);
  const messaging = fakeMessaging();
  // Even if the delete had failed, the task finds it is stale and doesn't continue the chain.
  assert.equal((await dispatch({ db, messaging, queue, now: AT }, old)).outcome, 'stale');
  assert.equal(messaging.sent.length, 0);
  assert.equal([...queue.tasks.values()].some((t) => t.kind === 'focusEncouragement'), false);

  // Moving to another time zone re-plans every kind at the new local time.
  const moved = { ...before, timezone: 'Europe/London' };
  await syncSchedule({ queue, now: AT - H }, 'dan', off, moved);
  const fe = [...queue.tasks.values()].find((t) => t.kind === 'focusEncouragement');
  assert.equal(fe.scheduledAt, Date.parse('2026-11-01T18:00:00Z'));
});

test('quiet hours, an active focus session, and lateness all skip the send', async () => {
  const messaging = fakeMessaging();
  const late = await seed('eve');
  const lateTask = taskFor('eve', late, 'focusEncouragement');
  assert.deepEqual(await dispatch({ db, messaging, queue: fakeQueue(), now: AT + 3 * H }, lateTask), { outcome: 'skipped', reason: 'too-late' });

  const night = await seed('fay', { user: { notificationPrefs: { ...prefs, focusEncouragement: { enabled: true, minute: 23 * 60 } } } });
  const nightTask = taskFor('fay', night, 'focusEncouragement');
  const r = await dispatch({ db, messaging, queue: fakeQueue(), now: nightTask.scheduledAt }, nightTask);
  assert.equal(r.reason, 'quiet-hours');

  const busy = await seed('gus', { user: { focus: { sessions: [{ startedAt: AT - 10 * 60000, endsAt: AT + H, endedAt: null }] } } });
  const busyR = await dispatch({ db, messaging, queue: fakeQueue(), now: AT }, taskFor('gus', busy, 'focusEncouragement'));
  assert.equal(busyR.reason, 'focus-active');
  assert.equal(messaging.sent.length, 0);
  // A skipped occurrence is final for that day: a retry doesn't send it later.
  assert.equal((await log('gus', 'focusEncouragement_2026-11-01')).status, 'skipped');
});

test('daily summary reports real focus time, and nothing on a day without focus', async () => {
  const at = Date.parse('2026-11-01T16:00:00Z'); // 21:00 Karachi
  const sessions = [
    { startedAt: at - 3 * H, endsAt: at - 2 * H, endedAt: at - 2 * H },
    { startedAt: at - H, endsAt: at - 30 * 60000, endedAt: at - 50 * 60000 },
  ];
  const data = await seed('hal', { user: { focus: { sessions } } });
  const messaging = fakeMessaging();
  const task = taskFor('hal', data, 'dailySummary', at - H);
  await dispatch({ db, messaging, queue: fakeQueue(), now: at }, task);
  assert.equal(messaging.sent[0].notification.body, 'You focused for 1 h 10 min across 2 sessions.');

  const idle = await seed('ivy');
  const r = await dispatch({ db, messaging: fakeMessaging(), queue: fakeQueue(), now: at }, taskFor('ivy', idle, 'dailySummary', at - H));
  assert.equal(r.reason, 'no-activity');
});

test('check-ins: only after real inactivity, max two in a row, shared daily cap', async () => {
  const lastActive = Date.parse('2026-10-28T08:00:00Z');
  const data = await seed('jo', {
    user: { lastActiveDay: '2026-10-28', lastActiveAt: Timestamp.fromMillis(lastActive) },
    devices: { phone: 'fid-jo' },
  });
  const queue = fakeQueue();
  const first = firstTask('jo', data, 'reEngagement', lastActive).data;
  assert.equal(first.dateKey, '2026-10-31');
  const messaging = fakeMessaging();
  assert.equal((await dispatch({ db, messaging, queue, now: first.scheduledAt }, first)).outcome, 'accepted');
  assert.equal(messaging.sent[0].data.route, 'dashboard');
  const second = [...queue.tasks.values()].find((t) => t.kind === 'reEngagement');
  assert.equal(second.dateKey, '2026-11-07');
  assert.equal((await dispatch({ db, messaging, queue, now: second.scheduledAt }, second)).outcome, 'accepted');
  const third = [...queue.tasks.values()].find((t) => t.kind === 'reEngagement' && t.dateKey === '2026-11-14');
  assert.equal((await dispatch({ db, messaging, queue, now: third.scheduledAt }, third)).reason, 'inactivity-cooldown');
  assert.equal(messaging.sent.length, 2);

  // A focus nudge already went out today: the check-in waits (one optional message a day).
  const kim = await seed('kim', { user: { lastActiveDay: '2026-10-28', lastActiveAt: Timestamp.fromMillis(lastActive) } });
  const t = firstTask('kim', kim, 'reEngagement', lastActive).data;
  await db.doc('users/kim/notifications/focusEncouragement_2026-10-31').set({
    engagement: true, status: 'accepted', sentAt: Timestamp.fromMillis(t.scheduledAt - H),
  });
  assert.equal((await dispatch({ db, messaging, queue: fakeQueue(), now: t.scheduledAt }, t)).reason, 'daily-cap');
});

test('devices older than 60 days are dropped', async () => {
  const data = await seed('lu', { devices: {} });
  await db.doc('users/lu/devices/old').set({ fid: 'fid-old', platform: 'ios', updatedAt: Timestamp.fromMillis(AT - 61 * DAY) });
  const r = await dispatch({ db, messaging: fakeMessaging(), queue: fakeQueue(), now: AT }, taskFor('lu', data, 'focusEncouragement'));
  assert.equal(r.reason, 'no-devices');
  assert.deepEqual(await deviceIds('lu'), []);
});

test('an installation moved to another account is removed from the old one', async () => {
  await seed('mo', { devices: { phone: 'fid-shared' } });
  await seed('ned', { devices: { phone: 'fid-shared' } });
  await claimDevice({ db }, 'ned', 'phone', 'fid-shared');
  assert.deepEqual(await deviceIds('mo'), []);
  assert.deepEqual(await deviceIds('ned'), ['phone']);
});

test('deleting an account removes its data and cancels its tasks', async () => {
  const data = await seed('oz');
  await db.doc('users/oz/notifications/x').set({ status: 'accepted' });
  const queue = fakeQueue();
  for (const t of plannedTasks('oz', data, AT - H)) await queue.enqueue(t.data, { id: t.id });
  await deleteAccountData({ db, queue, now: AT - H }, 'oz');
  assert.equal(queue.tasks.size, 0);
  assert.equal((await db.doc('users/oz').get()).exists, false);
  assert.equal((await db.collection('users/oz/devices').get()).size, 0);
  assert.equal((await dispatch({ db, messaging: fakeMessaging(), queue, now: AT }, taskFor('oz', data, 'focusEncouragement'))).outcome, 'no-user');
});

test('a task run early (emulator, manual call) sends nothing', async () => {
  const data = await seed('pat');
  const messaging = fakeMessaging();
  const r = await dispatch({ db, messaging, queue: fakeQueue(), now: AT - 6 * 60000 }, taskFor('pat', data, 'focusEncouragement'));
  assert.equal(r.outcome, 'early');
  assert.equal(messaging.sent.length, 0);
  assert.equal(await log('pat', 'focusEncouragement_2026-11-01'), undefined);
});

test('malformed task payloads are ignored', async () => {
  assert.equal((await dispatch({ db, messaging: fakeMessaging(), queue: fakeQueue(), now: AT }, { uid: '../x', kind: 'focusEncouragement' })).outcome, 'invalid');
});
