import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:regain_app/data/repositories/usage_history_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

void main() {
  final today = DateTime(2026, 11, 1);

  Future<(UsageHistoryRepository, FakeScreenTime, SharedPreferences)>
  setUpRepo([Map<String, Object> prefs = const {}]) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues(prefs);
    final p = await SharedPreferences.getInstance();
    final fake = FakeScreenTime();
    return (UsageHistoryRepository(p, fake), fake, p);
  }

  test(
    'sums each past day, oldest first, and reads the OS only once',
    () async {
      final (repo, fake, _) = await setUpRepo();
      fake.usageByDay = {
        DateTime(2026, 10, 30): [
          usageOf('A', const Duration(minutes: 40)),
          usageOf('B', const Duration(minutes: 20)),
        ],
        DateTime(2026, 10, 31): [usageOf('A', const Duration(minutes: 90))],
      };

      final days = await repo.pastDays(today, 2);
      expect(
        [for (final d in days) d.day],
        [DateTime(2026, 10, 30), DateTime(2026, 10, 31)],
      );
      expect([for (final d in days) d.minutes], [60, 90]);

      fake.queriedDays.clear();
      final again = await repo.pastDays(today, 2);
      expect(fake.queriedDays, isEmpty);
      expect([for (final d in again) d.minutes], [60, 90]);
    },
  );

  test('drops days older than keepDays and survives a corrupt cache', () async {
    final (repo, _, prefs) = await setUpRepo({
      'daily_totals_v2': jsonEncode({'2020-01-01': 5}),
    });
    await repo.pastDays(today, 1);
    final cached = jsonDecode(prefs.getString('daily_totals_v2')!) as Map;
    expect(cached.keys, ['2026-10-31']);

    final (broken, _, _) = await setUpRepo({'daily_totals_v2': 'not json'});
    expect((await broken.pastDays(today, 1)).single.minutes, 0);
  });

  test('totals saved before the v2 fix are read again and removed', () async {
    final (repo, fake, prefs) = await setUpRepo({
      'daily_totals': jsonEncode({'2026-10-31': 1500}), // 25 h: the old bug
    });
    fake.usageByDay = {
      DateTime(2026, 10, 31): [usageOf('A', const Duration(minutes: 90))],
    };
    expect((await repo.pastDays(today, 1)).single.minutes, 90);
    expect(prefs.containsKey('daily_totals'), isFalse);
  });
}
