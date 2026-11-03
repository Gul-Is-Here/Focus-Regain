import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/focus_session.dart';
import '../models/notification_prefs.dart';

/// What the push server needs, stored per account in Firestore (users/{uid}).
/// Only settings, time zone, the day the app was last opened and focus
/// session times: never screen time or app names. Tests replace it with a fake.
abstract class ReminderStore {
  Future<NotificationPrefs> loadPrefs(String uid);

  Future<void> savePrefs(String uid, NotificationPrefs prefs);

  Future<void> saveDevice(
    String uid, {
    required String deviceId,
    required String fid,
    required String platform,
  });

  Future<void> removeDevice(String uid, String deviceId);

  /// [activeDay] (yyyy-mm-dd) is set once a day when the app is opened.
  Future<void> syncActivity(
    String uid, {
    required String timezone,
    String? activeDay,
    required List<FocusSession> sessions,
  });

  /// Records that a push was opened (the server only knows FCM accepted it).
  Future<void> markOpened(String uid, String notificationId);

  /// Everything above, for Delete account.
  Future<void> deleteAccountData(String uid);
}

class FirestoreReminderStore implements ReminderStore {
  FirestoreReminderStore([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, Object?>> _user(String uid) =>
      _db.collection('users').doc(uid);

  @override
  Future<NotificationPrefs> loadPrefs(String uid) async {
    final snap = await _user(uid).get();
    return NotificationPrefs.fromJson(snap.data()?['notificationPrefs']);
  }

  @override
  Future<void> savePrefs(String uid, NotificationPrefs prefs) =>
      _user(uid)
          .set({'notificationPrefs': prefs.toJson()}, SetOptions(merge: true));

  @override
  Future<void> saveDevice(
    String uid, {
    required String deviceId,
    required String fid,
    required String platform,
  }) => _user(uid).collection('devices').doc(deviceId).set({
    'fid': fid,
    'platform': platform,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  @override
  Future<void> removeDevice(String uid, String deviceId) =>
      _user(uid).collection('devices').doc(deviceId).delete();

  @override
  Future<void> syncActivity(
    String uid, {
    required String timezone,
    String? activeDay,
    required List<FocusSession> sessions,
  }) => _user(uid).set({
    'timezone': timezone,
    if (activeDay != null) ...{
      'lastActiveDay': activeDay,
      'lastActiveAt': FieldValue.serverTimestamp(),
    },
    'focus': {
      'sessions': [
        for (final s in sessions.take(60))
          {
            'startedAt': s.startedAt.millisecondsSinceEpoch,
            'endsAt': s.endsAt.millisecondsSinceEpoch,
            'endedAt': s.endedAt?.millisecondsSinceEpoch,
          },
      ],
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    },
  }, SetOptions(merge: true));

  @override
  Future<void> markOpened(String uid, String notificationId) =>
      _user(uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'openedAt': FieldValue.serverTimestamp()});

  @override
  Future<void> deleteAccountData(String uid) async {
    for (final name in ['devices', 'notifications']) {
      final docs = (await _user(uid).collection(name).get()).docs;
      // A batch takes at most 500 writes.
      for (var i = 0; i < docs.length; i += 500) {
        final batch = _db.batch();
        for (final d in docs.skip(i).take(500)) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    }
    await _user(uid).delete();
  }
}
