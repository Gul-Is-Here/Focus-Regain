import 'package:flutter_test/flutter_test.dart';
import 'package:regain_app/app/utils/duration_format.dart';
import 'package:regain_app/data/models/focus_session.dart';
import 'package:regain_app/modules/focus/focus_view_model.dart';

FocusSession session(DateTime start, Duration planned, {Duration? ran}) =>
    FocusSession(
      startedAt: start,
      endsAt: start.add(planned),
      packages: const {'com.Chat'},
      strict: false,
      endedAt: ran == null ? null : start.add(ran),
    );

void main() {
  final today = DateTime(2026, 3, 10);

  test('sums finished sessions on the day', () {
    final done = [
      session(
        today.add(const Duration(hours: 9)),
        const Duration(minutes: 25),
        ran: const Duration(minutes: 25),
      ),
      session(
        today.add(const Duration(hours: 14)),
        const Duration(minutes: 50),
        ran: const Duration(minutes: 20),
      ), // stopped early
      session(
        today.subtract(const Duration(hours: 3)), // yesterday
        const Duration(minutes: 30),
        ran: const Duration(minutes: 30),
      ),
    ];
    final now = today.add(const Duration(hours: 18));
    expect(
      FocusViewModel.focusedOn(today, done, null, now),
      const Duration(minutes: 45),
    );
  });

  test('adds the running session up to now', () {
    final start = today.add(const Duration(hours: 10));
    final running = session(start, const Duration(minutes: 50));
    final now = start.add(const Duration(minutes: 12, seconds: 7));
    expect(
      FocusViewModel.focusedOn(today, const [], running, now),
      const Duration(minutes: 12, seconds: 7),
    );
  });

  test('a running session counts at most its planned length', () {
    final start = today.add(const Duration(hours: 10));
    final running = session(start, const Duration(minutes: 25));
    final now = start.add(const Duration(hours: 2)); // not refreshed yet
    expect(
      FocusViewModel.focusedOn(today, const [], running, now),
      const Duration(minutes: 25),
    );
  });

  test('a session that just ended is not counted twice', () {
    final start = today.add(const Duration(hours: 10));
    final running = session(start, const Duration(minutes: 25));
    final finished = session(
      start,
      const Duration(minutes: 25),
      ran: const Duration(minutes: 25),
    );
    final now = start.add(const Duration(minutes: 25));
    expect(
      FocusViewModel.focusedOn(today, [finished], running, now),
      const Duration(minutes: 25),
    );
  });

  test('a session crossing midnight is split between the two days', () {
    // 23:40 yesterday to 00:20 today.
    final start = today.subtract(const Duration(minutes: 20));
    final yesterday = DateTime(2026, 3, 9);
    final done = [
      session(
        start,
        const Duration(minutes: 40),
        ran: const Duration(minutes: 40),
      ),
    ];
    final now = today.add(const Duration(hours: 8));
    expect(
      FocusViewModel.focusedOn(today, done, null, now),
      const Duration(minutes: 20),
    );
    expect(
      FocusViewModel.focusedOn(yesterday, done, null, now),
      const Duration(minutes: 20),
    );

    // Still running just after midnight: only today's part counts today.
    final running = session(start, const Duration(minutes: 40));
    final justAfter = today.add(const Duration(minutes: 5));
    expect(
      FocusViewModel.focusedOn(today, const [], running, justAfter),
      const Duration(minutes: 5),
    );
    expect(
      FocusViewModel.focusedOn(yesterday, const [], running, justAfter),
      const Duration(minutes: 20),
    );
  });

  test('formatHms always shows hours', () {
    expect(formatHms(const Duration(seconds: 5)), '00:00:05');
    expect(formatHms(const Duration(minutes: 12, seconds: 5)), '00:12:05');
    expect(
      formatHms(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '01:02:03',
    );
    expect(formatHms(const Duration(seconds: -3)), '00:00:00');
  });
}
