/// 150 -> "2 h 30 min", 60 -> "1 h", 45 -> "45 min".
String formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m min';
  if (m == 0) return '$h h';
  return '$h h $m min';
}

/// Countdown style: 24:05, or 1:02:03 for an hour or more.
String formatClock(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Stopwatch style, always with hours: 00:12:05, 01:02:03.
String formatHms(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final safe = d.isNegative ? Duration.zero : d;
  return '${two(safe.inHours)}:${two(safe.inMinutes % 60)}:'
      '${two(safe.inSeconds % 60)}';
}
