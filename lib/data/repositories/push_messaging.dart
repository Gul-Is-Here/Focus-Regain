import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Whether this device may show push notifications from us.
enum PushPermission { granted, denied, notDetermined, unavailable }

/// What the app needs from a push: [id] is the server's notification id
/// (kind_date), [uid] the account it was sent to, [route] where a tap leads.
typedef PushMessage = ({
  String? id,
  String? uid,
  String? route,
  String? title,
  String? body,
});

/// Firebase Cloud Messaging on this device. Tests replace it with a fake.
abstract class PushMessaging {
  Future<PushPermission> permission();

  /// Shows the system prompt where the OS still allows it.
  Future<PushPermission> requestPermission();

  /// This installation's id (FID) whenever it is registered or changes.
  Stream<String> get registrations;

  Future<void> register();

  /// Stops pushes to this installation (sign out).
  Future<void> unregister();

  /// Arrived while the app was on screen (the system shows no banner then).
  Stream<PushMessage> get foreground;

  /// Tapped while the app was in the background.
  Stream<PushMessage> get opened;

  /// Tapped while the app was closed: the push that started it.
  Future<PushMessage?> initial();
}

/// Uses Firebase Installation IDs (FIDs): FCM's registration-token APIs are
/// deprecated. FIDs are switched on in AndroidManifest.xml and Info.plist.
class FirebasePushMessaging implements PushMessaging {
  FirebasePushMessaging([FirebaseMessaging? messaging])
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  static PushMessage _from(RemoteMessage m) => (
    id: m.data['notificationId'] as String?,
    uid: m.data['uid'] as String?,
    route: m.data['route'] as String?,
    title: m.notification?.title,
    body: m.notification?.body,
  );

  static PushPermission _status(NotificationSettings s) =>
      switch (s.authorizationStatus) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional => PushPermission.granted,
        AuthorizationStatus.denied ||
        AuthorizationStatus.deniedPermanently => PushPermission.denied,
        AuthorizationStatus.notDetermined => PushPermission.notDetermined,
      };

  bool get _apple =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  /// Apple needs an APNs token before any FCM call; none means push can't
  /// work here (Simulator, missing capability or APNs key).
  Future<bool> _available() async {
    if (!await _messaging.isSupported()) return false;
    if (!_apple) return true;
    return await _messaging.getAPNSToken() != null;
  }

  @override
  Future<PushPermission> permission() async {
    final settings = await _messaging.getNotificationSettings();
    final status = _status(settings);
    if (status == PushPermission.granted && !await _available()) {
      return PushPermission.unavailable;
    }
    return status;
  }

  @override
  Future<PushPermission> requestPermission() async {
    final status = _status(await _messaging.requestPermission());
    if (status == PushPermission.granted && !await _available()) {
      return PushPermission.unavailable;
    }
    return status;
  }

  @override
  Stream<String> get registrations => _messaging.onRegistered;

  @override
  Future<void> register() async {
    if (!await _available()) return;
    // The app shows its own in-app banner instead of a second system one.
    await _messaging.setForegroundNotificationPresentationOptions();
    await _messaging.register();
  }

  @override
  Future<void> unregister() => _messaging.unregister();

  @override
  Stream<PushMessage> get foreground => FirebaseMessaging.onMessage.map(_from);

  @override
  Stream<PushMessage> get opened =>
      FirebaseMessaging.onMessageOpenedApp.map(_from);

  @override
  Future<PushMessage?> initial() async {
    final m = await _messaging.getInitialMessage();
    return m == null ? null : _from(m);
  }
}
