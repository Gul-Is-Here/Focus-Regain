import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:regain_app/data/models/blocking_rules.dart';

void main() {
  test('rules survive the JSON trip to Android and back', () {
    const rules = BlockingRules(
      alwaysBlocked: {'com.video'},
      dailyLimits: {'com.chat': 30},
      schedules: [
        BlockSchedule(
          id: '1',
          name: 'Bedtime',
          days: {7, 1},
          startMinute: 22 * 60,
          endMinute: 7 * 60,
          packages: {'com.video'},
        ),
      ],
      style: BlockStyle.pause,
    );

    final back = BlockingRules.fromJson(
      jsonDecode(jsonEncode(rules.toJson())) as Map<String, Object?>,
    );

    expect(back.alwaysBlocked, {'com.video'});
    expect(back.dailyLimits, {'com.chat': 30});
    expect(back.style, BlockStyle.pause);
    final s = back.schedules.single;
    // Sets aren't compared by value inside records, so check them on their own.
    expect(s.name, 'Bedtime');
    expect(s.days, {1, 7});
    expect((s.startMinute, s.endMinute, s.isOvernight), (1320, 420, true));
  });

  test('unreadable rules fall back to none', () {
    final rules = BlockingRules.fromJson({'alwaysBlocked': 'oops'});
    expect(rules.isEmpty, isTrue);
  });
}
