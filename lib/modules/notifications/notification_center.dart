import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../data/models/focus_session.dart';
import '../../data/models/notification_prefs.dart';
import '../../data/platform/screen_time_api.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/push_messaging.dart';
import '../../data/repositories/reminder_store.dart';
import '../../data/repositories/settings_repository.dart';
import '../shell/shell_view_model.dart';

/// Push reminders on this device: registration, what the server needs to
/// know, and what happens when a push arrives or is tapped.
///
/// Who sends what (never both for the same occurrence):
/// - Server (FCM, functions/): focus nudge, daily focus summary, check-ins.
/// - This phone (native, android/.../BlockerService, FocusStore, WeeklyRecap):
///   limit warnings, "focus session done", weekly screen-time recap, because
///   they need screen time, which never leaves the phone.
class NotificationCenter extends GetxService {
  NotificationCenter(
    this._push,
    this._store,
    this._auth,
    this._settings,
    this._screenTime, {
    Future<String> Function()? timezone,
  }) : _timezone = timezone ?? _deviceTimezone;

  final PushMessaging _push;
  final ReminderStore _store;
  final AuthRepository _auth;
  final SettingsRepository _settings;
  final ScreenTimeApi _screenTime;
  final Future<String> Function() _timezone;

  /// Network steps on sign-out must not keep the user waiting.
  static const _netTimeout = Duration(seconds: 5);

  static Future<String> _deviceTimezone() async =>
      (await FlutterTimezone.getLocalTimezone()).identifier;

  final permission = PushPermission.notDetermined.obs;

  /// Null until loaded (or if loading failed).
  final prefs = Rxn<NotificationPrefs>();
  final prefsFailed = false.obs;
  final timezone = RxnString();

  PushMessage? _waitingForSignIn;
  int? _pendingTab;
  final _openedNow = <String>{};
  final _bannered = <String>{};
  final _subs = <StreamSubscription<Object?>>[];
  AppLifecycleListener? _lifecycle;

  String? get _uid => _auth.currentUser?.id;

  @override
  void onInit() {
    super.onInit();
    _subs
      ..add(_push.registrations.listen(_saveDevice, onError: _log))
      ..add(_push.foreground.listen(_banner, onError: _log))
      ..add(_push.opened.listen(open, onError: _log));
    // Time zone and "last active" may change while the app is in the background.
    _lifecycle = AppLifecycleListener(onResume: _onResume);
    _push.initial().then((m) {
      if (m != null) open(m);
    }, onError: _log);
  }

  @override
  void onClose() {
    for (final s in _subs) {
      s.cancel();
    }
    _lifecycle?.dispose();
    super.onClose();
  }

  /// After sign-in, and at launch when already signed in.
  Future<void> onSignedIn() async {
    final waiting = _waitingForSignIn;
    _waitingForSignIn = null;
    if (waiting != null) await open(waiting);
    await refreshPermission();
    if (permission.value == PushPermission.granted) {
      await _guard(_push.register);
    }
    await Future.wait([syncActivity(), loadPrefs()]);
  }

  /// Before signing out, so this phone stops getting this account's pushes.
  /// If offline, the server still drops the device: FCM rejects an
  /// unregistered installation, and a reused one moves to its new account.
  Future<void> onSignedOut() async {
    final uid = _uid;
    if (uid == null) return;
    final deviceId = await _settings.deviceId();
    await _guard(() => _store.removeDevice(uid, deviceId).timeout(_netTimeout));
    await _guard(() => _push.unregister().timeout(_netTimeout));
    prefs.value = null;
    _pendingTab = null;
    _waitingForSignIn = null;
    _bannered.clear();
  }

  Future<void> refreshPermission() async {
    try {
      permission.value = await _push.permission();
    } on Exception {
      permission.value = PushPermission.unavailable;
    }
  }

  /// From the user's tap on "Turn on reminders" (never on its own).
  Future<void> requestPermission() async {
    try {
      permission.value = await _push.requestPermission();
    } on Exception {
      permission.value = PushPermission.unavailable;
    }
    if (permission.value == PushPermission.granted) {
      await _guard(_push.register);
    }
  }

  Future<void> loadPrefs() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      prefs.value = await _store.loadPrefs(uid);
      prefsFailed.value = false;
    } on Exception catch (e) {
      prefsFailed.value = true;
      _log(e);
    }
  }

  Future<void> updatePrefs(NotificationPrefs next) async {
    final uid = _uid;
    if (uid == null) return;
    final previous = prefs.value;
    prefs.value = next;
    try {
      await _store.savePrefs(uid, next);
    } on Exception {
      prefs.value = previous;
      Get.snackbar(
        'Not saved',
        "Couldn't update your reminders. Check your connection and try again.",
      );
    }
  }

  /// Time zone, "opened today" (once a day) and recent focus sessions.
  Future<void> syncActivity() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final zone = await _timezone();
      timezone.value = zone;
      final today = _dayKey(DateTime.now());
      final firstToday = _settings.activeSyncedDay != today;
      await _store.syncActivity(
        uid,
        timezone: zone,
        activeDay: firstToday ? today : null,
        sessions: await _recentSessions(),
      );
      if (firstToday) await _settings.setActiveSyncedDay(today);
    } on Exception catch (e) {
      _log(e);
    }
  }

  /// The tab a tapped push asked for, once the main screen opens.
  int? takePendingTab() {
    final tab = _pendingTab;
    _pendingTab = null;
    return tab;
  }

  /// A push was tapped (system notification or in-app banner).
  Future<void> open(PushMessage message) async {
    final id = message.id;
    if (id == null ||
        _openedNow.contains(id) ||
        _settings.openedPushes.contains(id)) {
      return;
    }
    final uid = _uid;
    if (uid == null) {
      // Opened from a cold start before signing in: handled after sign-in.
      _waitingForSignIn = message;
      return;
    }
    _openedNow.add(id);
    // Sent to another account that used this phone: don't open its content.
    if (message.uid != uid) return;
    _goTo(message.route == 'focus' ? 1 : 0);
    await _settings.addOpenedPush(id);
    await _guard(() => _store.markOpened(uid, id));
  }

  void _goTo(int tab) {
    if (Get.isRegistered<ShellViewModel>()) {
      // Close anything on top of the tabs (e.g. the schedule editor).
      if (Get.currentRoute != AppRoutes.shell) {
        Get.until((route) => route.settings.name == AppRoutes.shell);
      }
      Get.find<ShellViewModel>().changeTab(tab);
    } else {
      // Still on sign-in, onboarding or permissions: open it when the tabs show.
      _pendingTab = tab;
    }
  }

  void _banner(PushMessage message) {
    final id = message.id;
    if (id == null || message.uid != _uid || !_bannered.add(id)) return;
    Get.snackbar(
      message.title ?? 'Focus Regain',
      message.body ?? '',
      onTap: (_) => open(message),
      duration: const Duration(seconds: 6),
    );
  }

  Future<void> _saveDevice(String fid) async {
    final uid = _uid;
    if (uid == null) return;
    final deviceId = await _settings.deviceId();
    await _guard(
      () => _store.saveDevice(
        uid,
        deviceId: deviceId,
        fid: fid,
        platform: defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
      ),
    );
  }

  Future<void> _onResume() async {
    if (_uid == null) return;
    await refreshPermission();
    await syncActivity();
  }

  /// The last week of sessions, running one included (times only, no apps).
  Future<List<FocusSession>> _recentSessions() async {
    if (!_screenTime.isSupported) return const [];
    final since = DateTime.now().subtract(const Duration(days: 8));
    final history = await _screenTime.getFocusHistory();
    final active = await _screenTime.getActiveFocus();
    return [
      ?active,
      for (final s in history.reversed)
        if (s.startedAt.isAfter(since) && s.startedAt != active?.startedAt) s,
    ];
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _guard(Future<void> Function() step) async {
    try {
      await step();
    } on Exception catch (e) {
      _log(e);
    }
  }

  static void _log(Object e) => debugPrint('Notifications: $e');
}
