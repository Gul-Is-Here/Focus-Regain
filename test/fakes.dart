import 'dart:async';

import 'package:flutter/services.dart';

import 'package:regain_app/data/models/app_category.dart';
import 'package:regain_app/data/models/app_usage.dart';
import 'package:regain_app/data/models/blocking_rules.dart';
import 'package:regain_app/data/models/focus_session.dart';
import 'package:regain_app/data/models/installed_app.dart';
import 'package:regain_app/data/models/notification_prefs.dart';
import 'package:regain_app/data/platform/screen_time_api.dart';
import 'package:regain_app/data/repositories/auth_repository.dart';
import 'package:regain_app/data/repositories/push_messaging.dart';
import 'package:regain_app/data/repositories/reminder_store.dart';

class FakeScreenTime implements ScreenTimeApi {
  bool access = true;

  /// When set, every call that checks access waits for it (loading states).
  Completer<void>? gate;

  /// Makes [getUsage] fail like a platform error.
  bool failUsage = false;
  bool overlay = true;

  /// False acts like Android Go, where the overlay can never be allowed.
  bool overlayRequestable = true;
  bool batteryUnrestricted = true;
  bool notifications = true;

  /// Returned for any day not in [usageByDay].
  List<AppUsage> usage = [];
  Map<DateTime, List<AppUsage>> usageByDay = {};
  final queriedDays = <DateTime>[];

  List<InstalledApp> installed = [];
  BlockingRules rules = const BlockingRules();
  final savedRules = <BlockingRules>[];

  FocusSession? activeFocus;
  List<FocusSession> focusHistory = [];

  ({bool enabled, int targetMinutes})? recap;

  int interceptions = 0;

  int settingsOpened = 0;
  int overlaySettingsOpened = 0;

  @override
  bool get isSupported => true;

  @override
  Future<bool> hasUsageAccess() async {
    await gate?.future;
    return access;
  }

  @override
  Future<void> openUsageAccessSettings() async => settingsOpened++;

  @override
  Future<bool> hasOverlayPermission() async => overlay;

  @override
  Future<void> openOverlaySettings() async => overlaySettingsOpened++;

  @override
  Future<bool> canRequestOverlay() async => overlayRequestable;

  /// Installed from an APK file on Android 13+ (restricted settings).
  bool restrictedSettings = false;
  int appInfoOpened = 0;

  @override
  Future<bool> mayNeedRestrictedSettings() async => restrictedSettings;

  @override
  Future<void> openAppInfo() async => appInfoOpened++;

  @override
  Future<bool> isIgnoringBatteryOptimizations() async => batteryUnrestricted;

  @override
  Future<void> openBatteryOptimizationSettings() async {}

  @override
  Future<List<AppUsage>> getUsage(DateTime from, DateTime to) async {
    if (failUsage) throw PlatformException(code: 'screen_time_failed');
    queriedDays.add(from);
    return usageByDay[from] ?? usage;
  }

  @override
  Future<Uint8List?> getAppIcon(String packageName) async => null;

  @override
  Future<List<InstalledApp>> getInstalledApps() async => installed;

  @override
  Future<BlockingRules> getBlockingRules() async => rules;

  @override
  Future<void> setBlockingRules(BlockingRules rules) async {
    this.rules = rules;
    savedRules.add(rules);
  }

  @override
  Future<bool> hasNotificationPermission() async => notifications;

  @override
  Future<void> openNotificationSettings() async {}

  @override
  Future<FocusSession?> getActiveFocus() async => activeFocus;

  @override
  Future<FocusSession> startFocus({
    required int minutes,
    required Set<String> packages,
    required bool strict,
  }) async {
    final now = DateTime.now();
    return activeFocus ??= FocusSession(
      startedAt: now,
      endsAt: now.add(Duration(minutes: minutes)),
      packages: packages,
      strict: strict,
    );
  }

  @override
  Future<bool> stopFocus() async {
    final s = activeFocus;
    if (s == null) return true;
    if (s.strict) return false;
    focusHistory.add(
      FocusSession(
        startedAt: s.startedAt,
        endsAt: s.endsAt,
        packages: s.packages,
        strict: s.strict,
        endedAt: DateTime.now(),
      ),
    );
    activeFocus = null;
    return true;
  }

  @override
  Future<List<FocusSession>> getFocusHistory() async => focusHistory;

  @override
  Future<void> configureWeeklyRecap({
    required bool enabled,
    required int targetMinutes,
  }) async => recap = (enabled: enabled, targetMinutes: targetMinutes);

  @override
  Future<int> getInterceptionsToday() async => interceptions;
}

AppUsage usageOf(
  String label,
  Duration time, [
  AppCategory category = AppCategory.other,
]) => AppUsage(
  packageName: 'com.$label',
  label: label,
  foreground: time,
  category: category,
);

InstalledApp appOf(String label, [AppCategory? category]) => InstalledApp(
  packageName: 'com.$label',
  label: label,
  category: category ?? AppCategory.other,
);

class FakeAuth implements AuthRepository {
  FakeAuth({this.user = (id: 'alex', name: 'Alex', email: 'alex@example.com')});

  AuthUser? user;

  /// When set, the next call throws it instead of succeeding.
  AuthFailure? failNext;

  /// What Google / Apple return: false = the user closed the sheet.
  bool providerResult = true;
  final calls = <String>[];

  @override
  AuthUser? get currentUser => user;

  Future<void> _call(String name, AuthUser? signedIn) async {
    calls.add(name);
    final failure = failNext;
    failNext = null;
    if (failure != null) throw failure;
    if (signedIn != null) user = signedIn;
  }

  @override
  Future<void> logIn({required String email, required String password}) =>
      _call('logIn $email', (id: 'alex', name: null, email: email));

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) => _call('signUp $name $email', (id: 'alex', name: name, email: email));

  @override
  Future<bool> signInWithGoogle() async {
    await _call('google', null);
    if (providerResult) user = (id: 'g', name: 'G', email: 'g@example.com');
    return providerResult;
  }

  @override
  Future<bool> signInWithApple() async {
    await _call('apple', null);
    if (providerResult) user = (id: 'a', name: 'A', email: 'a@example.com');
    return providerResult;
  }

  @override
  Future<void> sendPasswordReset(String email) => _call('reset $email', null);

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    user = null;
  }
}

/// FCM on a device: permission, registration (FID) and incoming pushes.
class FakePush implements PushMessaging {
  PushPermission status = PushPermission.granted;

  /// What the system prompt returns.
  PushPermission afterRequest = PushPermission.granted;
  String fid = 'fid-1';
  PushMessage? initialMessage;
  int requests = 0;
  int registers = 0;
  int unregisters = 0;
  final _registrations = StreamController<String>.broadcast();
  final _foreground = StreamController<PushMessage>.broadcast();
  final _opened = StreamController<PushMessage>.broadcast();

  /// FCM issued a new installation id (refresh).
  void refresh(String newFid) {
    fid = newFid;
    _registrations.add(newFid);
  }

  void arrive(PushMessage m) => _foreground.add(m);

  void tap(PushMessage m) => _opened.add(m);

  @override
  Future<PushPermission> permission() async => status;

  @override
  Future<PushPermission> requestPermission() async {
    requests++;
    return status = afterRequest;
  }

  @override
  Stream<String> get registrations => _registrations.stream;

  @override
  Future<void> register() async {
    registers++;
    _registrations.add(fid);
  }

  @override
  Future<void> unregister() async => unregisters++;

  @override
  Stream<PushMessage> get foreground => _foreground.stream;

  @override
  Stream<PushMessage> get opened => _opened.stream;

  @override
  Future<PushMessage?> initial() async => initialMessage;
}

PushMessage pushOf({
  String id = 'focusEncouragement_2026-11-01',
  String uid = 'alex',
  String route = 'focus',
}) => (
  id: id,
  uid: uid,
  route: route,
  title: 'Ready for a focus session?',
  body: "Even 15 minutes helps. Start one whenever you're ready.",
);

/// The Firestore side: users/{uid} with devices, settings and activity.
class FakeReminderStore implements ReminderStore {
  NotificationPrefs prefs = const NotificationPrefs();
  bool failLoad = false;
  bool failSave = false;

  /// When set, removing a device waits for it (an offline sign-out).
  Completer<void>? removeGate;

  /// deviceId -> (uid, fid, platform)
  final devices = <String, ({String uid, String fid, String platform})>{};
  final activity =
      <({String uid, String timezone, String? activeDay, int sessions})>[];
  final opened = <String>[];

  @override
  Future<NotificationPrefs> loadPrefs(String uid) async {
    if (failLoad) throw Exception('offline');
    return prefs;
  }

  @override
  Future<void> savePrefs(String uid, NotificationPrefs p) async {
    if (failSave) throw Exception('offline');
    prefs = p;
  }

  @override
  Future<void> saveDevice(
    String uid, {
    required String deviceId,
    required String fid,
    required String platform,
  }) async => devices[deviceId] = (uid: uid, fid: fid, platform: platform);

  @override
  Future<void> removeDevice(String uid, String deviceId) async {
    await removeGate?.future;
    devices.remove(deviceId);
  }

  @override
  Future<void> syncActivity(
    String uid, {
    required String timezone,
    String? activeDay,
    required List<FocusSession> sessions,
  }) async => activity.add((
    uid: uid,
    timezone: timezone,
    activeDay: activeDay,
    sessions: sessions.length,
  ));

  @override
  Future<void> markOpened(String uid, String notificationId) async =>
      opened.add('$uid/$notificationId');
}
