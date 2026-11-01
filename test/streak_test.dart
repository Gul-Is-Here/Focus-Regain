import 'package:flutter_test/flutter_test.dart';
import 'package:regain_app/app/utils/streak.dart';
import 'package:regain_app/data/models/daily_usage.dart';
import 'package:regain_app/data/models/focus_session.dart';

void main() {
  List<DailyUsage> days(List<int> minutes) => [
    for (var i = 0; i < minutes.length; i++)
      DailyUsage(day: DateTime(2026, 10, 1 + i), minutes: minutes[i]),
  ];

  test('counts back from the most recent day while at or under target', () {
    expect(underTargetStreak(days([200, 100, 180, 150]), 180), 3);
  });

  test('a day over target ends the streak', () {
    expect(underTargetStreak(days([100, 100, 181]), 180), 0);
  });

  test('a day with no data ends the streak', () {
    expect(underTargetStreak(days([100, 0, 120, 90]), 180), 2);
    expect(underTargetStreak(days([]), 180), 0);
  });

  group('focusStreak', () {
    final now = DateTime(2026, 11, 5, 15);
    FocusSession session(int day, {bool completed = true}) {
      final start = DateTime(2026, 11, day, 9);
      final end = start.add(const Duration(minutes: 25));
      return FocusSession(
        startedAt: start,
        endsAt: end,
        packages: const {},
        strict: false,
        endedAt: completed ? end : start.add(const Duration(minutes: 5)),
      );
    }

    test('counts today and the days before it', () {
      expect(focusStreak([session(3), session(4), session(5)], now), 3);
    });

    test('still alive from yesterday when today has none yet', () {
      expect(focusStreak([session(3), session(4)], now), 2);
    });

    test('stopped sessions and gaps do not count', () {
      expect(focusStreak([session(3), session(5, completed: false)], now), 0);
      expect(focusStreak([session(2), session(4)], now), 1);
    });
  });
}
