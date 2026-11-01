import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:get/get.dart';

import '../../app/utils/duration_format.dart';
import '../../app/utils/streak.dart';
import '../../data/models/focus_session.dart';
import '../../data/models/installed_app.dart';
import '../../data/platform/screen_time_api.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/usage_history_repository.dart';
import '../notifications/notification_center.dart';

enum FocusStatus {
  loading,
  unsupported,
  unavailable,
  needsSetup,
  idle,
  running,
  error,
}

class FocusViewModel extends GetxController {
  FocusViewModel(this._screenTime, this._settings, this._history);

  final ScreenTimeApi _screenTime;
  final SettingsRepository _settings;
  final UsageHistoryRepository _history;

  static const presets = [15, 25, 50, 90];
  static const minMinutes = 5;
  static const maxMinutes = 180;

  final status = FocusStatus.loading.obs;
  final minutes = 25.obs;
  final strict = false.obs;
  late final selected = _settings.focusPackages.obs;
  final apps = <InstalledApp>[].obs;
  final query = ''.obs;
  final active = Rxn<FocusSession>();
  final remaining = Duration.zero.obs;

  /// "Now" for every live counter (Focus tab and Dashboard). Ticks each second
  /// while a session runs, and at midnight, so only the widgets reading it
  /// rebuild. Counters are derived from saved timestamps, never incremented.
  final clock = DateTime.now().obs;
  final history = <FocusSession>[].obs;

  late final focusGoalMinutes = _settings.focusGoalMinutes.obs;

  /// Null until loaded (or if usage can't be read).
  final screenTimeToday = Rxn<Duration>();

  /// Average of the past 7 days that have data; null if none do.
  final dailyAverage = Rxn<Duration>();
  final interceptionsToday = 0.obs;

  Timer? _ticker;
  Timer? _midnight;
  AppLifecycleListener? _lifecycle;

  List<InstalledApp> get visibleApps {
    final q = query.value.trim().toLowerCase();
    if (q.isEmpty) return apps;
    return apps.where((a) => a.label.toLowerCase().contains(q)).toList();
  }

  /// 0..1 share of the running session that has passed.
  double get progress {
    final s = active.value;
    if (s == null) return 0;
    final total = s.planned.inMilliseconds;
    return total == 0 ? 1 : 1 - remaining.value.inMilliseconds / total;
  }

  List<FocusSession> _sessionsOn(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day + 1);
    return history
        .where((s) => !s.startedAt.isBefore(start) && s.startedAt.isBefore(end))
        .toList();
  }

  List<FocusSession> get todaySessions => _sessionsOn(clock.value);

  /// Focus time on today's local date: finished sessions plus the running
  /// one so far. Updates live with [clock].
  Duration get focusedToday =>
      focusedOn(clock.value, history, active.value, clock.value);

  Duration get focusedYesterday {
    final now = clock.value;
    return focusedOn(
      DateTime(now.year, now.month, now.day - 1),
      history,
      active.value,
      now,
    );
  }

  /// Time since the running session started, or zero when none is running.
  Duration get elapsed {
    final s = active.value;
    if (s == null) return Duration.zero;
    final end = clock.value.isBefore(s.endsAt) ? clock.value : s.endsAt;
    final d = end.difference(s.startedAt);
    return d.isNegative ? Duration.zero : d;
  }

  /// Focus time that falls on [day]'s local date. Only the part of a session
  /// inside that date counts, so one crossing midnight is split between the
  /// two days. [running] counts up to [now] (at most its planned end).
  static Duration focusedOn(
    DateTime day,
    Iterable<FocusSession> finished,
    FocusSession? running,
    DateTime now,
  ) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = DateTime(day.year, day.month, day.day + 1);
    Duration overlap(DateTime from, DateTime to) {
      final a = from.isAfter(dayStart) ? from : dayStart;
      final b = to.isBefore(dayEnd) ? to : dayEnd;
      return b.isAfter(a) ? b.difference(a) : Duration.zero;
    }

    var total = Duration.zero;
    for (final s in finished) {
      // While a session ends it can briefly be both running and in history.
      if (running != null && s.startedAt == running.startedAt) continue;
      total += overlap(s.startedAt, s.endedAt ?? s.endsAt);
    }
    if (running != null) {
      total += overlap(
        running.startedAt,
        now.isBefore(running.endsAt) ? now : running.endsAt,
      );
    }
    return total;
  }

  /// 0..1+ share of the daily focus goal reached today.
  double get goalProgress => focusedToday.inMinutes / focusGoalMinutes.value;

  int get streak => focusStreak(history, DateTime.now());

  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  /// "+45 min vs yesterday", "−20 min vs yesterday" or "Same as yesterday".
  String get trendText {
    final diff = focusedToday.inMinutes - focusedYesterday.inMinutes;
    if (diff == 0) return 'Same as yesterday';
    return '${diff > 0 ? '+' : '−'}${formatMinutes(diff.abs())} vs yesterday';
  }

  bool get trendUp => focusedToday >= focusedYesterday;

  /// The nudge card text, split so the first part can be highlighted.
  ({String highlight, String rest}) get nudge {
    final done = focusedToday.inMinutes;
    final goal = focusGoalMinutes.value;
    if (done >= goal) {
      return (
        highlight: 'Goal reached.',
        rest: ' ${formatMinutes(done)} of focus today. Nice work.',
      );
    }
    if (done > 0) {
      return (
        highlight: '${formatMinutes(goal - done)} left',
        rest: " to reach today's focus goal. Keep going.",
      );
    }
    return (
      highlight: 'No focus yet today.',
      rest: ' A ${formatMinutes(minutes.value)} session is a good start.',
    );
  }

  @override
  void onInit() {
    super.onInit();
    if (!_screenTime.isSupported) {
      status.value = FocusStatus.unsupported;
      return;
    }
    // The session may have ended, or permissions changed, while we were away.
    _lifecycle = AppLifecycleListener(onResume: refreshState);
    _armMidnight();
    refreshState();
  }

  @override
  void onClose() {
    _ticker?.cancel();
    _midnight?.cancel();
    _lifecycle?.dispose();
    super.onClose();
  }

  Future<void> refreshState() async {
    clock.value = DateTime.now();
    try {
      final ready =
          await _screenTime.hasUsageAccess() &&
          await _screenTime.hasOverlayPermission();
      history.assignAll(await _screenTime.getFocusHistory());
      focusGoalMinutes.value = _settings.focusGoalMinutes;
      if (!ready) {
        final unavailable =
            !await _screenTime.hasOverlayPermission() &&
            !await _screenTime.canRequestOverlay();
        _setActive(
          null,
          idleStatus: unavailable
              ? FocusStatus.unavailable
              : FocusStatus.needsSetup,
        );
        return;
      }
      if (apps.isEmpty) apps.assignAll(await _screenTime.getInstalledApps());
      _setActive(await _screenTime.getActiveFocus());
    } on Exception {
      _ticker?.cancel();
      status.value = FocusStatus.error;
      return;
    }
    await _loadStats();
  }

  // Stats are extras: if they fail, the tab still works without them.
  Future<void> _loadStats() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final apps = await _screenTime.getUsage(today, now);
      screenTimeToday.value = apps.fold<Duration>(
        Duration.zero,
        (sum, a) => sum + a.foreground,
      );
      final past = (await _history.pastDays(
        today,
        7,
      )).where((d) => d.minutes > 0).toList();
      dailyAverage.value = past.isEmpty
          ? null
          : Duration(
              minutes: past.fold(0, (sum, d) => sum + d.minutes) ~/ past.length,
            );
      interceptionsToday.value = await _screenTime.getInterceptionsToday();
    } on Exception {
      screenTimeToday.value = null;
    }
  }

  void toggleApp(String packageName) => selected.contains(packageName)
      ? selected.remove(packageName)
      : selected.add(packageName);

  /// True when every app in the current search results is picked.
  bool get allVisibleSelected =>
      visibleApps.isNotEmpty &&
      visibleApps.every((a) => selected.contains(a.packageName));

  /// Picks every app in the search results, or clears them if all are picked.
  /// Native code still skips protected apps (dialer, settings, launcher, us).
  void toggleAllVisible() {
    final packages = visibleApps.map((a) => a.packageName).toSet();
    if (allVisibleSelected) {
      selected.removeWhere(packages.contains);
    } else {
      selected.addAll(packages.where((p) => !selected.contains(p)));
    }
  }

  Future<void> start() async {
    // One session at a time (native also returns the running one).
    if (selected.isEmpty || active.value != null) return;
    try {
      final session = await _screenTime.startFocus(
        minutes: minutes.value,
        packages: selected.toSet(),
        strict: strict.value,
      );
      await _settings.setFocusPackages(selected.toSet());
      _setActive(session);
      _syncReminders();
    } on Exception {
      Get.snackbar(
        'Not started',
        "Couldn't start the focus session. Try again.",
      );
    }
  }

  Future<void> stop() async {
    try {
      if (!await _screenTime.stopFocus()) {
        Get.snackbar('Strict mode', "This session can't be stopped early.");
      }
    } on Exception {
      Get.snackbar('Not stopped', "Couldn't stop the session. Try again.");
    }
    await refreshState();
    _syncReminders();
  }

  /// The server skips focus nudges during a session and sums real focus time.
  void _syncReminders() {
    if (Get.isRegistered<NotificationCenter>()) {
      unawaited(Get.find<NotificationCenter>().syncActivity());
    }
  }

  void _setActive(
    FocusSession? session, {
    FocusStatus idleStatus = FocusStatus.idle,
  }) {
    _ticker?.cancel();
    active.value = session;
    if (session == null) {
      status.value = idleStatus;
      return;
    }
    status.value = FocusStatus.running;
    _tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// Moves [clock] to the new day at midnight, so today's total resets even
  /// with no session running. Re-armed each time; only one is ever pending.
  void _armMidnight() {
    _midnight?.cancel();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(next.difference(now), () {
      clock.value = DateTime.now();
      _armMidnight();
    });
  }

  void _tick() {
    final now = DateTime.now();
    clock.value = now;
    final left = active.value!.endsAt.difference(now);
    if (left > Duration.zero) {
      remaining.value = left;
      return;
    }
    // Over: the native side records it and sends the "done" notification.
    remaining.value = Duration.zero;
    _ticker?.cancel();
    refreshState();
  }
}
