import 'dart:typed_data';

import '../models/app_usage.dart';
import '../models/blocking_rules.dart';
import '../models/focus_session.dart';
import '../models/installed_app.dart';

/// Platform-neutral access to screen-time data and app blocking.
abstract interface class ScreenTimeApi {
  /// False where there is no native implementation yet (iOS until Phase 8).
  bool get isSupported;

  Future<bool> hasUsageAccess();

  Future<void> openUsageAccessSettings();

  /// Needed to show the block screen over other apps.
  Future<bool> hasOverlayPermission();

  Future<void> openOverlaySettings();

  /// False where the system never grants the overlay (Android Go), so
  /// blocking can't work on this phone at all.
  Future<bool> canRequestOverlay();

  /// True when Android 13+ locks usage access and the overlay switch until
  /// the user allows "restricted settings" in App info (installed from an
  /// APK file rather than a store).
  Future<bool> mayNeedRestrictedSettings();

  /// This app's App info page (where restricted settings are allowed).
  Future<void> openAppInfo();

  /// True when the system won't stop blocking to save battery.
  Future<bool> isIgnoringBatteryOptimizations();

  Future<void> openBatteryOptimizationSettings();

  /// Apps sorted by foreground time, most used first.
  Future<List<AppUsage>> getUsage(DateTime from, DateTime to);

  /// PNG bytes, or null if the app is gone.
  Future<Uint8List?> getAppIcon(String packageName);

  /// Apps the user may block, sorted by name. The phone app, Settings, the
  /// home screen and Focus Regain itself are never included.
  Future<List<InstalledApp>> getInstalledApps();

  Future<BlockingRules> getBlockingRules();

  /// Saves the rules and starts or stops the blocking service to match.
  Future<void> setBlockingRules(BlockingRules rules);

  /// Needed for limit warnings (Android 13+ asks for it; users can also turn it off).
  Future<bool> hasNotificationPermission();

  Future<void> openNotificationSettings();

  /// The running session, or null. Sessions are kept natively, so they keep
  /// going (and end on time) even when the app is closed.
  Future<FocusSession?> getActiveFocus();

  /// Starts a session, or returns the one already running.
  Future<FocusSession> startFocus({
    required int minutes,
    required Set<String> packages,
    required bool strict,
  });

  /// Ends the running session early. False if it is strict.
  Future<bool> stopFocus();

  /// Finished and stopped sessions, oldest first.
  Future<List<FocusSession>> getFocusHistory();

  /// Schedules (or cancels) the Monday-morning recap of last week, which
  /// compares each day against [targetMinutes].
  Future<void> configureWeeklyRecap({
    required bool enabled,
    required int targetMinutes,
  });

  /// How many times the block screen stopped an app today.
  Future<int> getInterceptionsToday();
}
