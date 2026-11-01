import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:get/get.dart';

import '../../app/utils/streak.dart';
import '../../data/models/app_category.dart';
import '../../data/models/app_usage.dart';
import '../../data/models/daily_usage.dart';
import '../../data/platform/screen_time_api.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/usage_history_repository.dart';

enum DashboardStatus { loading, unsupported, needsAccess, ready, error }

class DashboardViewModel extends GetxController {
  DashboardViewModel(this._screenTime, this._settings, this._history);

  final ScreenTimeApi _screenTime;
  final SettingsRepository _settings;
  final UsageHistoryRepository _history;

  final status = DashboardStatus.loading.obs;
  final apps = <AppUsage>[].obs;

  /// A refresh is running while numbers are already on screen.
  final refreshing = false.obs;

  /// The last refresh failed; the earlier numbers are still shown.
  final refreshFailed = false.obs;

  /// Last 7 days, oldest first; the last entry is today.
  final week = <DailyUsage>[].obs;
  late final targetMinutes = _settings.dailyTargetMinutes.obs;

  /// Finished days in a row at or under the target (today isn't over yet).
  final streak = 0.obs;

  static const streakLookbackDays = 30;

  /// How often today's numbers reload while the app is on screen.
  /// shortcut: polls Android's usage log; totals show whole minutes, so 30 s
  /// keeps them current. Move to a native push if a shorter interval is needed.
  static const livePeriod = Duration(seconds: 30);

  AppLifecycleListener? _lifecycle;
  Timer? _live;
  bool _loading = false;

  Duration get total =>
      apps.fold(Duration.zero, (sum, app) => sum + app.foreground);

  bool get overTarget => total.inMinutes > targetMinutes.value;

  /// 0..1+ share of the daily target used so far.
  double get targetProgress => total.inMinutes / targetMinutes.value;

  /// Minutes left before the target (negative once over it).
  int get minutesLeft => targetMinutes.value - total.inMinutes;

  /// Apps under a minute are counted in [total] but not listed.
  List<AppUsage> get listedApps =>
      apps.where((a) => a.foreground.inMinutes >= 1).toList();

  /// 0..1 share of today's total spent in [app].
  double shareOf(AppUsage app) => shareOfTime(app.foreground);

  /// The six finished days before today that have data.
  List<DailyUsage> get _pastWithData => week.isEmpty
      ? const []
      : week.take(week.length - 1).where((d) => d.minutes > 0).toList();

  /// Average of the past six days that have data; null if none do.
  int? get recentAverage {
    final days = _pastWithData;
    if (days.isEmpty) return null;
    return days.fold(0, (sum, d) => sum + d.minutes) ~/ days.length;
  }

  bool get hasHistory => _pastWithData.isNotEmpty;

  /// Today's time per app category, largest first. Categories are what each
  /// app declares to Android; apps that declare none count as "Other".
  List<({AppCategory category, Duration time})> get categories {
    final totals = <AppCategory, Duration>{};
    for (final app in apps) {
      totals[app.category] =
          (totals[app.category] ?? Duration.zero) + app.foreground;
    }
    return [
      for (final e in totals.entries)
        if (e.value.inMinutes >= 1) (category: e.key, time: e.value),
    ]..sort((a, b) => b.time.compareTo(a.time));
  }

  /// 0..1 share of today's total spent in [time].
  double shareOfTime(Duration time) => total.inMilliseconds == 0
      ? 0
      : time.inMilliseconds / total.inMilliseconds;

  @override
  void onInit() {
    super.onInit();
    if (!_screenTime.isSupported) {
      status.value = DashboardStatus.unsupported;
      return;
    }
    _lifecycle = AppLifecycleListener(
      // Picks up the permission when the user comes back from Settings.
      onResume: refreshUsage,
      // Live updates only while the app is visible.
      onShow: _startLive,
      onHide: _stopLive,
    );
    _startLive();
    refreshUsage();
  }

  @override
  void onClose() {
    _stopLive();
    _lifecycle?.dispose();
    super.onClose();
  }

  void _startLive() {
    _live?.cancel();
    _live = Timer.periodic(livePeriod, (_) {
      if (status.value == DashboardStatus.ready) refreshUsage(silent: true);
    });
  }

  void _stopLive() {
    _live?.cancel();
    _live = null;
  }

  /// Reloads today's numbers. Content already on screen stays there while
  /// this runs, and stays (with [refreshFailed] set) if it fails. [silent]
  /// is the background live update: no progress bar, no failure banner, and
  /// skipped while another reload is still running.
  Future<void> refreshUsage({bool silent = false}) async {
    if (silent && _loading) return;
    _loading = true;
    final hadContent = status.value == DashboardStatus.ready;
    if (hadContent && !silent) refreshing.value = true;
    try {
      if (!await _screenTime.hasUsageAccess()) {
        status.value = DashboardStatus.needsAccess;
        return;
      }
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayApps = await _screenTime.getUsage(today, now);
      final past = await _history.pastDays(today, streakLookbackDays);
      apps.assignAll(todayApps);
      targetMinutes.value = _settings.dailyTargetMinutes;
      week.assignAll([
        ...past.skip(past.length - 6),
        DailyUsage(day: today, minutes: total.inMinutes),
      ]);
      streak.value = underTargetStreak(past, targetMinutes.value);
      refreshFailed.value = false;
      status.value = DashboardStatus.ready;
    } on Exception {
      if (silent) return; // the next tick or a manual refresh tries again
      if (hadContent) {
        refreshFailed.value = true;
      } else {
        status.value = DashboardStatus.error;
      }
    } finally {
      _loading = false;
      if (!silent) refreshing.value = false;
    }
  }

  Future<void> openUsageAccessSettings() =>
      _screenTime.openUsageAccessSettings();
}
