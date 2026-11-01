import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/app_usage.dart';
import '../models/blocking_rules.dart';
import '../models/focus_session.dart';
import '../models/installed_app.dart';
import 'screen_time_api.dart';

/// Talks to ScreenTimeHandler.kt on Android.
class ScreenTimeChannel implements ScreenTimeApi {
  static const _channel = MethodChannel('com.focuseregain.app/screen_time');

  @override
  bool get isSupported => defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> hasUsageAccess() => _bool('hasUsageAccess');

  @override
  Future<void> openUsageAccessSettings() =>
      _channel.invokeMethod('openUsageAccessSettings');

  @override
  Future<bool> hasOverlayPermission() => _bool('hasOverlayPermission');

  @override
  Future<void> openOverlaySettings() =>
      _channel.invokeMethod('openOverlaySettings');

  @override
  Future<bool> canRequestOverlay() => _bool('canRequestOverlay');

  @override
  Future<bool> mayNeedRestrictedSettings() =>
      _bool('mayNeedRestrictedSettings');

  @override
  Future<void> openAppInfo() => _channel.invokeMethod('openAppInfo');

  @override
  Future<bool> isIgnoringBatteryOptimizations() =>
      _bool('isIgnoringBatteryOptimizations');

  @override
  Future<void> openBatteryOptimizationSettings() =>
      _channel.invokeMethod('openBatteryOptimizationSettings');

  @override
  Future<List<AppUsage>> getUsage(DateTime from, DateTime to) async {
    final rows = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'getUsage',
      {'from': from.millisecondsSinceEpoch, 'to': to.millisecondsSinceEpoch},
    );
    return [for (final row in rows ?? const []) AppUsage.fromMap(row)];
  }

  @override
  Future<Uint8List?> getAppIcon(String packageName) =>
      _channel.invokeMethod<Uint8List>('getAppIcon', packageName);

  @override
  Future<List<InstalledApp>> getInstalledApps() async {
    final rows = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'getInstalledApps',
    );
    return [for (final row in rows ?? const []) InstalledApp.fromMap(row)];
  }

  @override
  Future<BlockingRules> getBlockingRules() async {
    final json = await _channel.invokeMethod<String>('getBlockingRules');
    if (json == null) return const BlockingRules();
    try {
      return BlockingRules.fromJson(jsonDecode(json) as Map<String, Object?>);
    } on FormatException {
      return const BlockingRules();
    }
  }

  @override
  Future<void> setBlockingRules(BlockingRules rules) =>
      _channel.invokeMethod('setBlockingRules', jsonEncode(rules.toJson()));

  @override
  Future<bool> hasNotificationPermission() =>
      _bool('hasNotificationPermission');

  @override
  Future<void> openNotificationSettings() =>
      _channel.invokeMethod('openNotificationSettings');

  @override
  Future<FocusSession?> getActiveFocus() async {
    final json = await _channel.invokeMethod<String>('getActiveFocus');
    return json == null ? null : _session(json);
  }

  @override
  Future<FocusSession> startFocus({
    required int minutes,
    required Set<String> packages,
    required bool strict,
  }) async => _session(
    (await _channel.invokeMethod<String>('startFocus', {
      'minutes': minutes,
      'packages': packages.toList(),
      'strict': strict,
    }))!,
  );

  @override
  Future<bool> stopFocus() => _bool('stopFocus');

  @override
  Future<List<FocusSession>> getFocusHistory() async {
    final json = await _channel.invokeMethod<String>('getFocusHistory');
    final list = jsonDecode(json ?? '[]') as List;
    return [
      for (final s in list) FocusSession.fromJson(s as Map<String, Object?>),
    ];
  }

  @override
  Future<void> configureWeeklyRecap({
    required bool enabled,
    required int targetMinutes,
  }) => _channel.invokeMethod('configureWeeklyRecap', {
    'enabled': enabled,
    'targetMinutes': targetMinutes,
  });

  @override
  Future<int> getInterceptionsToday() async =>
      await _channel.invokeMethod<int>('getInterceptionsToday') ?? 0;

  FocusSession _session(String json) =>
      FocusSession.fromJson(jsonDecode(json) as Map<String, Object?>);

  Future<bool> _bool(String method) async =>
      await _channel.invokeMethod<bool>(method) ?? false;
}
