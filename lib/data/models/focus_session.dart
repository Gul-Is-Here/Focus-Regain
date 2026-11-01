/// A focus session: [packages] are blocked from [startedAt] until [endsAt].
class FocusSession {
  const FocusSession({
    required this.startedAt,
    required this.endsAt,
    required this.packages,
    required this.strict,
    this.endedAt,
  });

  factory FocusSession.fromJson(Map<String, Object?> json) => FocusSession(
    startedAt: _time(json['startedAt']!),
    endsAt: _time(json['endsAt']!),
    packages: {for (final p in json['packages']! as List) p as String},
    strict: json['strict'] as bool? ?? false,
    endedAt: json['endedAt'] == null ? null : _time(json['endedAt']!),
  );

  final DateTime startedAt;
  final DateTime endsAt;
  final Set<String> packages;

  /// Strict sessions can't be stopped early.
  final bool strict;

  /// Null while running.
  final DateTime? endedAt;

  Duration get planned => endsAt.difference(startedAt);

  bool get completed => endedAt != null && !endedAt!.isBefore(endsAt);

  /// Time actually spent focused.
  Duration get focused => (endedAt ?? DateTime.now()).difference(startedAt);

  static DateTime _time(Object ms) =>
      DateTime.fromMillisecondsSinceEpoch((ms as num).toInt());
}
