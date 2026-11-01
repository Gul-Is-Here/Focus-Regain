/// One reminder the user can turn on, at [minute] past local midnight.
class TimedReminder {
  const TimedReminder({required this.enabled, required this.minute});

  final bool enabled;
  final int minute;

  TimedReminder copyWith({bool? enabled, int? minute}) => TimedReminder(
    enabled: enabled ?? this.enabled,
    minute: minute ?? this.minute,
  );

  Map<String, Object?> toJson() => {'enabled': enabled, 'minute': minute};

  static TimedReminder fromJson(Object? json, TimedReminder fallback) {
    if (json is! Map) return fallback;
    final minute = json['minute'];
    return TimedReminder(
      enabled: json['enabled'] == true,
      minute: minute is int && minute >= 0 && minute < 24 * 60
          ? minute
          : fallback.minute,
    );
  }
}

/// Push reminder settings, kept with the account so the server can send them.
/// Everything is off until the user turns it on.
class NotificationPrefs {
  const NotificationPrefs({
    this.focusNudge = const TimedReminder(enabled: false, minute: 18 * 60),
    this.dailySummary = const TimedReminder(enabled: false, minute: 21 * 60),
    this.checkIns = false,
    this.quietHours = const QuietHours(),
  });

  /// Suggests a focus session (skipped while one is running).
  final TimedReminder focusNudge;

  /// Today's real focus time (skipped on days without any).
  final TimedReminder dailySummary;

  /// A gentle note after a few days without opening the app.
  final bool checkIns;
  final QuietHours quietHours;

  NotificationPrefs copyWith({
    TimedReminder? focusNudge,
    TimedReminder? dailySummary,
    bool? checkIns,
    QuietHours? quietHours,
  }) => NotificationPrefs(
    focusNudge: focusNudge ?? this.focusNudge,
    dailySummary: dailySummary ?? this.dailySummary,
    checkIns: checkIns ?? this.checkIns,
    quietHours: quietHours ?? this.quietHours,
  );

  // Names match the server (functions/src/schedule.js) and firestore.rules.
  Map<String, Object?> toJson() => {
    'focusEncouragement': focusNudge.toJson(),
    'dailySummary': dailySummary.toJson(),
    'reEngagement': {'enabled': checkIns},
    'quietHours': quietHours.toJson(),
  };

  factory NotificationPrefs.fromJson(Object? json) {
    const d = NotificationPrefs();
    if (json is! Map) return d;
    final checkIns = json['reEngagement'];
    return NotificationPrefs(
      focusNudge: TimedReminder.fromJson(
        json['focusEncouragement'],
        d.focusNudge,
      ),
      dailySummary: TimedReminder.fromJson(
        json['dailySummary'],
        d.dailySummary,
      ),
      checkIns: checkIns is Map && checkIns['enabled'] == true,
      quietHours: QuietHours.fromJson(json['quietHours']),
    );
  }
}

/// No pushes between [start] and [end] (minutes past midnight; may cross midnight).
class QuietHours {
  const QuietHours({
    this.enabled = true,
    this.start = 22 * 60,
    this.end = 7 * 60,
  });

  final bool enabled;
  final int start;
  final int end;

  QuietHours copyWith({bool? enabled, int? start, int? end}) => QuietHours(
    enabled: enabled ?? this.enabled,
    start: start ?? this.start,
    end: end ?? this.end,
  );

  bool contains(int minute) {
    if (!enabled || start == end) return false;
    return start < end
        ? minute >= start && minute < end
        : minute >= start || minute < end;
  }

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'start': start,
    'end': end,
  };

  factory QuietHours.fromJson(Object? json) {
    const d = QuietHours();
    if (json is! Map) return d;
    int minute(Object? v, int fallback) =>
        v is int && v >= 0 && v < 24 * 60 ? v : fallback;
    return QuietHours(
      enabled: json['enabled'] != false,
      start: minute(json['start'], d.start),
      end: minute(json['end'], d.end),
    );
  }
}
