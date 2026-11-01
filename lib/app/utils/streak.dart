import '../../data/models/daily_usage.dart';
import '../../data/models/focus_session.dart';

/// Consecutive days, counting back from the most recent, at or under
/// [targetMinutes]. A day with no usage at all counts as "no data" (phone
/// off, or before the app was installed) and ends the streak.
int underTargetStreak(List<DailyUsage> pastOldestFirst, int targetMinutes) {
  var streak = 0;
  for (final day in pastOldestFirst.reversed) {
    if (day.minutes == 0 || day.minutes > targetMinutes) break;
    streak++;
  }
  return streak;
}

/// Days in a row with at least one completed focus session. Today counts if
/// it already has one; otherwise the streak is still alive from yesterday.
int focusStreak(List<FocusSession> history, DateTime now) {
  DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);
  final days = {
    for (final s in history)
      if (s.completed) dayOf(s.startedAt),
  };
  var day = dayOf(now);
  if (!days.contains(day)) day = DateTime(day.year, day.month, day.day - 1);
  var streak = 0;
  while (days.contains(day)) {
    streak++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return streak;
}
