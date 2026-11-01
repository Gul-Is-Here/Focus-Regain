import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/focus_goal.dart';

/// Local, on-device settings and onboarding answers.
class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _onboardingDoneKey = 'onboarding_done';
  static const _goalsKey = 'goals';
  static const _dailyTargetKey = 'daily_target_minutes';
  static const _themeModeKey = 'theme_mode';
  static const _focusPackagesKey = 'focus_packages';
  static const _weeklyRecapKey = 'weekly_recap';
  static const _focusGoalKey = 'focus_goal_minutes';
  static const _rememberMeKey = 'remember_me';
  static const _deviceIdKey = 'device_id';
  static const _activeSyncedDayKey = 'active_synced_day';
  static const _openedPushesKey = 'opened_pushes';

  static const defaultDailyTargetMinutes = 180;
  static const defaultFocusGoalMinutes = 120;

  bool get onboardingDone => _prefs.getBool(_onboardingDoneKey) ?? false;

  List<FocusGoal> get goals {
    final names = _prefs.getStringList(_goalsKey) ?? const [];
    // Skip names from older app versions that no longer exist.
    return FocusGoal.values.where((g) => names.contains(g.name)).toList();
  }

  int get dailyTargetMinutes =>
      _prefs.getInt(_dailyTargetKey) ?? defaultDailyTargetMinutes;

  Future<void> setDailyTargetMinutes(int minutes) =>
      _prefs.setInt(_dailyTargetKey, minutes);

  /// How much focused time a day counts as a full ring on the Focus tab.
  int get focusGoalMinutes =>
      _prefs.getInt(_focusGoalKey) ?? defaultFocusGoalMinutes;

  Future<void> setFocusGoalMinutes(int minutes) =>
      _prefs.setInt(_focusGoalKey, minutes);

  /// Stay signed in between launches. Off: signed out at the next start.
  bool get rememberMe => _prefs.getBool(_rememberMeKey) ?? true;

  Future<void> setRememberMe(bool on) => _prefs.setBool(_rememberMeKey, on);

  /// Monday-morning summary of last week. On unless the user turns it off.
  bool get weeklyRecap => _prefs.getBool(_weeklyRecapKey) ?? true;

  Future<void> setWeeklyRecap(bool on) => _prefs.setBool(_weeklyRecapKey, on);

  Future<void> saveOnboarding({
    required Set<FocusGoal> goals,
    required int dailyTargetMinutes,
  }) async {
    await _prefs.setStringList(_goalsKey, [for (final g in goals) g.name]);
    await _prefs.setInt(_dailyTargetKey, dailyTargetMinutes);
    // Written last so a crash mid-save shows onboarding again instead of half-saved answers.
    await _prefs.setBool(_onboardingDoneKey, true);
  }

  ThemeMode get themeMode {
    final name = _prefs.getString(_themeModeKey);
    return ThemeMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(_themeModeKey, mode.name);

  /// Apps picked for the last focus session, offered again next time.
  Set<String> get focusPackages =>
      (_prefs.getStringList(_focusPackagesKey) ?? const []).toSet();

  Future<void> setFocusPackages(Set<String> packages) =>
      _prefs.setStringList(_focusPackagesKey, packages.toList());

  /// Random id for this installation (the doc id of its push registration).
  Future<String> deviceId() async {
    final existing = _prefs.getString(_deviceIdKey);
    if (existing != null) return existing;
    final random = Random.secure();
    final id = [
      for (var i = 0; i < 16; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    await _prefs.setString(_deviceIdKey, id);
    return id;
  }

  /// The last day (yyyy-mm-dd) "last active" was sent to the server.
  String? get activeSyncedDay => _prefs.getString(_activeSyncedDayKey);

  Future<void> setActiveSyncedDay(String day) =>
      _prefs.setString(_activeSyncedDayKey, day);

  /// Pushes already opened here, so a repeated tap event doesn't navigate twice.
  List<String> get openedPushes =>
      _prefs.getStringList(_openedPushesKey) ?? const [];

  Future<void> addOpenedPush(String id) => _prefs.setStringList(
    _openedPushesKey,
    // The last 50 are plenty: ids are per kind and day.
    [
      ...openedPushes.where((e) => e != id),
      id,
    ].reversed.take(50).toList().reversed.toList(),
  );
}
