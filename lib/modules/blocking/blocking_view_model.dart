import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:get/get.dart';

import '../../app/utils/duration_format.dart';
import '../../data/models/blocking_rules.dart';
import '../../data/models/installed_app.dart';
import '../../data/platform/screen_time_api.dart';

enum BlockingStatus { loading, unsupported, unavailable, setup, ready, error }

class BlockingViewModel extends GetxController {
  BlockingViewModel(this._screenTime);

  final ScreenTimeApi _screenTime;

  final status = BlockingStatus.loading.obs;
  final hasUsageAccess = false.obs;
  final hasOverlayPermission = false.obs;
  final batteryUnrestricted = true.obs;
  final notificationsAllowed = true.obs;
  final apps = <InstalledApp>[].obs;
  final rules = const BlockingRules().obs;
  final query = ''.obs;

  /// Hides the battery tip until the app restarts.
  final batteryTipDismissed = false.obs;

  AppLifecycleListener? _lifecycle;

  List<InstalledApp> get visibleApps {
    final q = query.value.trim().toLowerCase();
    if (q.isEmpty) return apps;
    return apps
        .where(
          (a) =>
              a.label.toLowerCase().contains(q) ||
              a.category.label.toLowerCase().contains(q),
        )
        .toList();
  }

  /// Installed apps that have at least one rule (blocked, limit or schedule).
  int get restrictedCount =>
      apps.where((a) => summaryFor(a.packageName) != null).length;

  /// One line describing the rules on an app, or null if it has none.
  String? summaryFor(String packageName) {
    final r = rules.value;
    final limit = r.dailyLimits[packageName];
    final inSchedules = r.schedules
        .where((s) => s.packages.contains(packageName))
        .length;
    final parts = [
      if (r.alwaysBlocked.contains(packageName)) 'Always blocked',
      if (limit != null) '${formatMinutes(limit)} a day',
      if (inSchedules == 1) 'In 1 schedule',
      if (inSchedules > 1) 'In $inSchedules schedules',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  void onInit() {
    super.onInit();
    if (!_screenTime.isSupported) {
      status.value = BlockingStatus.unsupported;
      return;
    }
    // Permissions are granted in Settings, so re-check when the user comes back.
    _lifecycle = AppLifecycleListener(onResume: refreshState);
    refreshState();
  }

  @override
  void onClose() {
    _lifecycle?.dispose();
    super.onClose();
  }

  Future<void> refreshState() async {
    try {
      hasUsageAccess.value = await _screenTime.hasUsageAccess();
      hasOverlayPermission.value = await _screenTime.hasOverlayPermission();
      batteryUnrestricted.value = await _screenTime
          .isIgnoringBatteryOptimizations();
      notificationsAllowed.value = await _screenTime
          .hasNotificationPermission();
      if (!hasOverlayPermission.value &&
          !await _screenTime.canRequestOverlay()) {
        status.value = BlockingStatus.unavailable;
        return;
      }
      if (!hasUsageAccess.value || !hasOverlayPermission.value) {
        status.value = BlockingStatus.setup;
        return;
      }
      apps.assignAll(await _screenTime.getInstalledApps());
      rules.value = await _screenTime.getBlockingRules();
      status.value = BlockingStatus.ready;
    } on Exception {
      status.value = BlockingStatus.error;
    }
  }

  Future<void> setAlwaysBlocked(String packageName, bool on) {
    final next = {...rules.value.alwaysBlocked};
    on ? next.add(packageName) : next.remove(packageName);
    return _save(rules.value.copyWith(alwaysBlocked: next));
  }

  /// [minutes] null removes the limit.
  Future<void> setDailyLimit(String packageName, int? minutes) {
    final next = {...rules.value.dailyLimits};
    minutes == null ? next.remove(packageName) : next[packageName] = minutes;
    return _save(rules.value.copyWith(dailyLimits: next));
  }

  Future<void> setStyle(BlockStyle style) =>
      _save(rules.value.copyWith(style: style));

  /// Adds [schedule], or replaces the one with the same id.
  Future<void> saveSchedule(BlockSchedule schedule) {
    final next = [
      for (final s in rules.value.schedules)
        if (s.id != schedule.id) s,
      schedule,
    ];
    return _save(rules.value.copyWith(schedules: next));
  }

  Future<void> deleteSchedule(String id) => _save(
    rules.value.copyWith(
      schedules: [
        for (final s in rules.value.schedules)
          if (s.id != id) s,
      ],
    ),
  );

  Future<void> _save(BlockingRules next) async {
    final previous = rules.value;
    rules.value = next;
    try {
      await _screenTime.setBlockingRules(next);
    } on Exception {
      // Undo so the screen matches what is really saved.
      rules.value = previous;
      Get.snackbar(
        'Not saved',
        "Couldn't update your blocking rules. Try again.",
      );
    }
  }

  Future<void> openUsageAccessSettings() =>
      _screenTime.openUsageAccessSettings();

  Future<void> openOverlaySettings() => _screenTime.openOverlaySettings();

  Future<void> openBatteryOptimizationSettings() =>
      _screenTime.openBatteryOptimizationSettings();

  Future<void> openNotificationSettings() =>
      _screenTime.openNotificationSettings();
}
