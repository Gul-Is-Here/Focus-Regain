// Firestore security rules, against the emulator (npm test).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { Timestamp, deleteDoc, doc, getDoc, serverTimestamp, setDoc, updateDoc } from 'firebase/firestore';

let env;
before(async () => {
  const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
  env = await initializeTestEnvironment({
    projectId: 'demo-regain-rules',
    firestore: { rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'), host, port: Number(port) },
  });
});
after(() => env.cleanup());
beforeEach(() => env.clearFirestore());

const prefs = {
  focusEncouragement: { enabled: true, minute: 1080 },
  dailySummary: { enabled: false, minute: 1260 },
  reEngagement: { enabled: true },
  quietHours: { enabled: true, start: 1320, end: 420 },
};
const as = (uid) => env.authenticatedContext(uid).firestore();

test('users read and write only their own settings', async () => {
  const alice = as('alice');
  await assertSucceeds(setDoc(doc(alice, 'users/alice'), {
    timezone: 'Asia/Karachi', lastActiveDay: '2026-11-01', lastActiveAt: serverTimestamp(),
    notificationPrefs: prefs, focus: { sessions: [{ startedAt: 1, endsAt: 2, endedAt: null }], updatedAt: 1 },
  }));
  await assertSucceeds(getDoc(doc(alice, 'users/alice')));
  await assertFails(getDoc(doc(as('bob'), 'users/alice')));
  await assertFails(setDoc(doc(as('bob'), 'users/alice'), { timezone: 'UTC' }, { merge: true }));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'users/alice')));
  await assertFails(deleteDoc(doc(as('bob'), 'users/alice')));
  await assertSucceeds(deleteDoc(doc(alice, 'users/alice'))); // Delete account
});

test('settings are validated', async () => {
  const alice = as('alice');
  await assertFails(setDoc(doc(alice, 'users/alice'), { notificationPrefs: { ...prefs, dailySummary: { enabled: true, minute: 2000 } } }));
  await assertFails(setDoc(doc(alice, 'users/alice'), { notificationPrefs: { ...prefs, extra: true } }));
  await assertFails(setDoc(doc(alice, 'users/alice'), { screenTime: 500 }));
  // "Last active" can only be the server's time.
  await assertFails(setDoc(doc(alice, 'users/alice'), { lastActiveAt: Timestamp.fromMillis(0) }));
  await assertSucceeds(setDoc(doc(alice, 'users/alice'), { lastActiveAt: serverTimestamp() }));
  await assertSucceeds(setDoc(doc(alice, 'users/alice'), { timezone: 'Europe/London' }, { merge: true }));
});

test('devices: own only, validated, server time', async () => {
  const alice = as('alice');
  await assertSucceeds(setDoc(doc(alice, 'users/alice/devices/d1'), { fid: 'fid', platform: 'android', updatedAt: serverTimestamp() }));
  await assertFails(setDoc(doc(alice, 'users/alice/devices/d2'), { fid: 'fid', platform: 'web', updatedAt: serverTimestamp() }));
  await assertFails(setDoc(doc(alice, 'users/alice/devices/d3'), { fid: 'fid', platform: 'ios', updatedAt: serverTimestamp(), uid: 'x' }));
  await assertFails(getDoc(doc(as('bob'), 'users/alice/devices/d1')));
  await assertFails(setDoc(doc(as('bob'), 'users/alice/devices/d9'), { fid: 'mine', platform: 'ios', updatedAt: serverTimestamp() }));
  await assertSucceeds(deleteDoc(doc(alice, 'users/alice/devices/d1')));
});

test('notification log: the app can only mark its own as opened, once', async () => {
  await env.withSecurityRulesDisabled((ctx) =>
    setDoc(doc(ctx.firestore(), 'users/alice/notifications/n1'), { status: 'accepted', kind: 'dailySummary' }));
  const alice = as('alice');
  await assertFails(setDoc(doc(alice, 'users/alice/notifications/n2'), { status: 'accepted' }));
  await assertFails(updateDoc(doc(alice, 'users/alice/notifications/n1'), { status: 'skipped' }));
  await assertFails(updateDoc(doc(as('bob'), 'users/alice/notifications/n1'), { openedAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(doc(alice, 'users/alice/notifications/n1'), { openedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(alice, 'users/alice/notifications/n1'), { openedAt: serverTimestamp() }));
  await assertFails(deleteDoc(doc(as('bob'), 'users/alice/notifications/n1')));
  await assertSucceeds(deleteDoc(doc(alice, 'users/alice/notifications/n1'))); // Delete account
});

test('server-only state is closed to every client', async () => {
  await assertFails(getDoc(doc(as('alice'), 'users/alice/private/engagement')));
  await assertFails(setDoc(doc(as('alice'), 'users/alice/private/engagement'), { reEngagementStreak: 0 }));
});
