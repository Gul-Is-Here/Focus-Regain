// Push notifications for Focus Regain. Only these trusted functions send messages
// (Admin SDK); the app only stores its settings, activity and devices.
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getFunctions } from 'firebase-admin/functions';
import { getMessaging } from 'firebase-admin/messaging';
import { logger } from 'firebase-functions';
import * as v1 from 'firebase-functions/v1';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { onTaskDispatched } from 'firebase-functions/v2/tasks';
import { claimDevice, deleteAccountData, dispatch, syncSchedule } from './src/dispatch.js';
import { scheduleKey } from './src/schedule.js';

initializeApp();

const QUEUE = 'sendScheduledNotification';
const deps = () => ({
  db: getFirestore(),
  messaging: getMessaging(),
  queue: getFunctions().taskQueue(QUEUE),
  now: Date.now(),
});

/** One due notification (queued per user and kind; never a scan of all users). */
export const sendScheduledNotification = onTaskDispatched(
  {
    retryConfig: { maxAttempts: 5, minBackoffSeconds: 60 },
    rateLimits: { maxConcurrentDispatches: 20 },
  },
  async (req) => {
    const result = await dispatch(deps(), req.data);
    logger.info('notification task', { ...req.data, ...result });
  },
);

/** Settings, time zone or activity changed: redo this user's queued tasks. */
export const onUserWritten = onDocumentWritten('users/{uid}', async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  if (scheduleKey(before) === scheduleKey(after)) return;
  await syncSchedule(deps(), event.params.uid, before, after);
});

/** A device registered: make sure no other account still targets it. */
export const onDeviceWritten = onDocumentWritten('users/{uid}/devices/{deviceId}', async (event) => {
  const fid = event.data?.after?.data()?.fid;
  if (typeof fid === 'string') await claimDevice(deps(), event.params.uid, event.params.deviceId, fid);
});

export const onAccountDeleted = v1.auth.user().onDelete((user) => deleteAccountData(deps(), user.uid));
