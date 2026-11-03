import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../data/platform/screen_time_api.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../dashboard/dashboard_view_model.dart';
import '../focus/focus_view_model.dart';
import '../notifications/notification_center.dart';

class SettingsViewModel extends GetxController {
  SettingsViewModel(
    this._settings,
    this._screenTime,
    this._auth,
    this.reminders,
  );

  final SettingsRepository _settings;
  final ScreenTimeApi _screenTime;
  final AuthRepository _auth;
  final NotificationCenter reminders;

  static const minTargetMinutes = 60;
  static const maxTargetMinutes = 360;
  static const targetStepMinutes = 30;
  static const minFocusGoalMinutes = 15;
  static const maxFocusGoalMinutes = 480;
  static const focusGoalStepMinutes = 15;

  late final themeMode = _settings.themeMode.obs;
  late final dailyTargetMinutes = _settings.dailyTargetMinutes.obs;
  late final weeklyRecap = _settings.weeklyRecap.obs;
  late final focusGoalMinutes = _settings.focusGoalMinutes.obs;
  final notificationsAllowed = true.obs;

  bool get isSupported => _screenTime.isSupported;

  AuthUser? get account => _auth.currentUser;

  /// Back to Log in; on-device data and settings stay.
  Future<void> signOut() async {
    await reminders.onSignedOut();
    await _auth.signOut();
    Get.offAllNamed(AppRoutes.login);
  }

  /// Deletes the account and what's stored with it online. Screen time
  /// never left the phone, so it stays until the app is uninstalled.
  Future<void> deleteAccount() async {
    try {
      await reminders.deleteAccountData();
      await _auth.deleteAccount();
    } on AuthFailure catch (e) {
      // Usually "log in again first": the data is gone, signing in and
      // deleting again removes the account too.
      await _auth.signOut();
      Get.offAllNamed(AppRoutes.login);
      Get.snackbar('Account not deleted yet', e.message);
      return;
    } on Exception {
      Get.snackbar(
        'Not deleted',
        "Couldn't delete your account. Check your connection and try again.",
      );
      return;
    }
    Get.offAllNamed(AppRoutes.login);
    Get.snackbar('Account deleted', 'Your account and its data are gone.');
  }

  AppLifecycleListener? _lifecycle;

  @override
  void onInit() {
    super.onInit();
    if (!isSupported) return;
    // Notification permission is changed in Settings, so re-check on return.
    _lifecycle = AppLifecycleListener(onResume: refreshNotificationStatus);
    refreshNotificationStatus();
  }

  @override
  void onClose() {
    _lifecycle?.dispose();
    super.onClose();
  }

  Future<void> refreshNotificationStatus() async {
    try {
      notificationsAllowed.value = await _screenTime
          .hasNotificationPermission();
    } on Exception {
      // Leave the last known value; the tile only offers a shortcut.
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    Get.changeThemeMode(mode);
    await _settings.setThemeMode(mode);
  }

  Future<void> setDailyTarget(int minutes) async {
    dailyTargetMinutes.value = minutes;
    await _settings.setDailyTargetMinutes(minutes);
    await _configureRecap();
    // The ring, chart and streak all depend on the target.
    if (Get.isRegistered<DashboardViewModel>()) {
      await Get.find<DashboardViewModel>().refreshUsage();
    }
  }

  Future<void> setFocusGoal(int minutes) async {
    focusGoalMinutes.value = minutes;
    await _settings.setFocusGoalMinutes(minutes);
    if (Get.isRegistered<FocusViewModel>()) {
      Get.find<FocusViewModel>().focusGoalMinutes.value = minutes;
    }
  }

  Future<void> setWeeklyRecap(bool on) async {
    weeklyRecap.value = on;
    await _settings.setWeeklyRecap(on);
    await _configureRecap();
  }

  Future<void> openNotificationSettings() =>
      _screenTime.openNotificationSettings();

  Future<void> _configureRecap() async {
    if (!isSupported) return;
    try {
      await _screenTime.configureWeeklyRecap(
        enabled: weeklyRecap.value,
        targetMinutes: dailyTargetMinutes.value,
      );
    } on Exception {
      Get.snackbar('Not saved', "Couldn't update the weekly recap. Try again.");
    }
  }
}
