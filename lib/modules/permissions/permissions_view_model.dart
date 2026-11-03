import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../data/platform/screen_time_api.dart';

/// In the order the user is asked for them.
enum AppPermission { usageAccess, overlay, notifications, battery }

/// Walks through every permission, one step at a time. The app opens only
/// once all of them are allowed.
class PermissionsViewModel extends GetxController {
  PermissionsViewModel(this._screenTime);

  final ScreenTimeApi _screenTime;

  final granted = <AppPermission>{}.obs;
  final loading = true.obs;

  /// Installed from an APK file: Android locks two of the switches until
  /// "restricted settings" are allowed in App info.
  final restrictedSettings = false.obs;

  /// The step can be locked by restricted settings (usage access, overlay).
  bool get currentMayBeLocked =>
      restrictedSettings.value &&
      (current == AppPermission.usageAccess ||
          current == AppPermission.overlay);
  AppLifecycleListener? _lifecycle;

  /// The first one still missing, or null when all are allowed.
  AppPermission? get current =>
      AppPermission.values.where((p) => !granted.contains(p)).firstOrNull;

  bool get allGranted => !loading.value && current == null;

  /// Which permissions are allowed right now.
  static Future<Set<AppPermission>> check(ScreenTimeApi api) async => {
    if (await api.hasUsageAccess()) AppPermission.usageAccess,
    // Android Go never allows it; skip the step instead of locking the app.
    if (await api.hasOverlayPermission() || !await api.canRequestOverlay())
      AppPermission.overlay,
    if (await api.hasNotificationPermission()) AppPermission.notifications,
    if (await api.isIgnoringBatteryOptimizations()) AppPermission.battery,
  };

  @override
  void onInit() {
    super.onInit();
    // Nothing to ask for where blocking isn't supported yet (iOS).
    if (!_screenTime.isSupported) {
      _openApp();
      return;
    }
    // Each permission is turned on in Android Settings: re-check on return.
    _lifecycle = AppLifecycleListener(onResume: recheck);
    _firstCheck();
  }

  @override
  void onClose() {
    _lifecycle?.dispose();
    super.onClose();
  }

  Future<void> _firstCheck() async {
    try {
      restrictedSettings.value = await _screenTime.mayNeedRestrictedSettings();
    } on Exception {
      // Only decides whether to show the extra steps.
    }
    await recheck();
    // Already allowed earlier: straight through, no screen to tap past.
    if (current == null) _openApp();
  }

  Future<void> recheck() async {
    try {
      granted.assignAll(await check(_screenTime));
    } on Exception {
      // Keep what we had; the next resume checks again.
    } finally {
      loading.value = false;
    }
  }

  /// Opens the Android Settings page for the current step.
  Future<void> allow() async {
    final permission = current;
    if (permission == null) return;
    try {
      await switch (permission) {
        AppPermission.usageAccess => _screenTime.openUsageAccessSettings(),
        AppPermission.overlay => _screenTime.openOverlaySettings(),
        AppPermission.notifications => _screenTime.openNotificationSettings(),
        AppPermission.battery => _screenTime.openBatteryOptimizationSettings(),
      };
    } on Exception {
      Get.snackbar(
        "Couldn't open Settings",
        'Open Android Settings and find Regain Focus there.',
      );
    }
  }

  Future<void> openAppInfo() async {
    try {
      await _screenTime.openAppInfo();
    } on Exception {
      Get.snackbar(
        "Couldn't open App info",
        'Open Android Settings > Apps > Regain Focus.',
      );
    }
  }

  void finish() {
    if (allGranted) _openApp();
  }

  void _openApp() => Get.offAllNamed(AppRoutes.shell);
}
