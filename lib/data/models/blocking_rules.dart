/// What the block screen does when a blocked app opens.
enum BlockStyle {
  /// The app stays closed.
  block,

  /// A short breathing pause, then the user may open the app for 5 minutes.
  pause,
}

/// Blocks [packages] on [days] between [startMinute] and [endMinute].
class BlockSchedule {
  const BlockSchedule({
    required this.id,
    required this.name,
    required this.days,
    required this.startMinute,
    required this.endMinute,
    required this.packages,
  });

  factory BlockSchedule.fromJson(Map<String, Object?> json) => BlockSchedule(
    id: json['id']! as String,
    name: json['name']! as String,
    days: {for (final d in json['days']! as List) d as int},
    startMinute: json['startMinute']! as int,
    endMinute: json['endMinute']! as int,
    packages: {for (final p in json['packages']! as List) p as String},
  );

  final String id;
  final String name;

  /// ISO weekdays, like [DateTime.weekday]: 1 = Monday ... 7 = Sunday.
  final Set<int> days;

  /// Minutes after midnight. If [endMinute] <= [startMinute] the window
  /// runs past midnight into the next day.
  final int startMinute;
  final int endMinute;
  final Set<String> packages;

  bool get isOvernight => endMinute <= startMinute;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'days': (days.toList()..sort()),
    'startMinute': startMinute,
    'endMinute': endMinute,
    'packages': packages.toList(),
  };
}

/// Everything the native blocker needs. Sent to Android as JSON.
class BlockingRules {
  const BlockingRules({
    this.alwaysBlocked = const {},
    this.dailyLimits = const {},
    this.schedules = const [],
    this.style = BlockStyle.block,
  });

  /// Unreadable or missing fields fall back to "no rules" instead of failing.
  factory BlockingRules.fromJson(Map<String, Object?> json) {
    try {
      return BlockingRules(
        alwaysBlocked: {
          for (final p in json['alwaysBlocked'] as List? ?? const [])
            p as String,
        },
        dailyLimits: {
          for (final e in (json['dailyLimits'] as Map? ?? const {}).entries)
            e.key as String: e.value as int,
        },
        schedules: [
          for (final s in json['schedules'] as List? ?? const [])
            BlockSchedule.fromJson((s as Map).cast<String, Object?>()),
        ],
        style: BlockStyle.values.firstWhere(
          (s) => s.name == json['style'],
          orElse: () => BlockStyle.block,
        ),
      );
    } on TypeError {
      return const BlockingRules();
    }
  }

  final Set<String> alwaysBlocked;

  /// Package name -> minutes per day.
  final Map<String, int> dailyLimits;
  final List<BlockSchedule> schedules;
  final BlockStyle style;

  bool get isEmpty =>
      alwaysBlocked.isEmpty &&
      dailyLimits.isEmpty &&
      schedules.every((s) => s.packages.isEmpty);

  BlockingRules copyWith({
    Set<String>? alwaysBlocked,
    Map<String, int>? dailyLimits,
    List<BlockSchedule>? schedules,
    BlockStyle? style,
  }) => BlockingRules(
    alwaysBlocked: alwaysBlocked ?? this.alwaysBlocked,
    dailyLimits: dailyLimits ?? this.dailyLimits,
    schedules: schedules ?? this.schedules,
    style: style ?? this.style,
  );

  Map<String, Object?> toJson() => {
    'alwaysBlocked': alwaysBlocked.toList(),
    'dailyLimits': dailyLimits,
    'schedules': [for (final s in schedules) s.toJson()],
    'style': style.name,
  };
}
