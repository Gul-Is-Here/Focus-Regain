// What each notification says. Only real numbers; no guilt; nothing personal on
// the lock screen (Android "private" visibility; iOS hides previews when locked by default).

export function formatMinutes(minutes) {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  if (h === 0) return `${m} min`;
  return m === 0 ? `${h} h` : `${h} h ${m} min`;
}

const TEXT = {
  focusEncouragement: () => ({
    title: 'Ready for a focus session?',
    body: "Even 15 minutes helps. Start one whenever you're ready.",
    route: 'focus',
  }),
  dailySummary: ({ minutes, sessions }) => ({
    title: 'Your focus today',
    body: `You focused for ${formatMinutes(minutes)} across ${sessions} ${sessions === 1 ? 'session' : 'sessions'}.`,
    route: 'focus',
  }),
  reEngagement: () => ({
    title: 'Focus Regain is here when you need it',
    body: 'Open the app to see how your days are going.',
    route: 'dashboard',
  }),
};

/**
 * The FCM message for one occurrence (without the target). [notificationId] is
 * also the on-device tag / collapse id, so a resent copy replaces the first.
 */
export function buildMessage({ kind, uid, notificationId, summary }) {
  const { title, body, route } = TEXT[kind](summary ?? {});
  return {
    notification: { title, body },
    data: { notificationId, uid, route, kind },
    android: {
      notification: { tag: notificationId, channelId: 'reminders', visibility: 'private' },
    },
    apns: {
      headers: { 'apns-collapse-id': notificationId },
      payload: { aps: { 'thread-id': kind } },
    },
  };
}
