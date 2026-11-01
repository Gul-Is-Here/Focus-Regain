import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_usage.dart';
import '../platform/screen_time_api.dart';

/// Daily totals for past days. A finished day never changes, so it is read
/// from the OS once and cached; the cache also outlives Android's own event
/// history, which only goes back about a week.
class UsageHistoryRepository {
  UsageHistoryRepository(this._prefs, this._screenTime);

  final SharedPreferences _prefs;
  final ScreenTimeApi _screenTime;

  // v2: totals saved before the "stopped without a pause" fix were far too
  // high (Android 17), so they are dropped and read again.
  static const _cacheKey = 'daily_totals_v2';
  static const _oldCacheKeys = ['daily_totals'];
  static const keepDays = 60;

  /// The [count] days before [today], oldest first.
  Future<List<DailyUsage>> pastDays(DateTime today, int count) async {
    final cache = _readCache();
    var changed = false;
    final days = <DailyUsage>[];
    for (var i = count; i >= 1; i--) {
      final day = DateTime(today.year, today.month, today.day - i);
      final key = _dayKey(day);
      var minutes = cache[key];
      if (minutes == null) {
        final apps = await _screenTime.getUsage(
          day,
          DateTime(day.year, day.month, day.day + 1),
        );
        minutes = apps
            .fold(Duration.zero, (sum, app) => sum + app.foreground)
            .inMinutes;
        cache[key] = minutes;
        changed = true;
      }
      days.add(DailyUsage(day: day, minutes: minutes));
    }
    if (changed) await _writeCache(cache, today);
    return days;
  }

  Map<String, int> _readCache() {
    final raw = _prefs.getString(_cacheKey);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      );
    } catch (_) {
      return {}; // Corrupt cache: rebuild it from the OS.
    }
  }

  Future<void> _writeCache(Map<String, int> cache, DateTime today) {
    final cutoff = _dayKey(
      DateTime(today.year, today.month, today.day - keepDays),
    );
    // yyyy-mm-dd keys sort in date order.
    cache.removeWhere((key, _) => key.compareTo(cutoff) < 0);
    for (final key in _oldCacheKeys) {
      _prefs.remove(key);
    }
    return _prefs.setString(_cacheKey, jsonEncode(cache));
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
