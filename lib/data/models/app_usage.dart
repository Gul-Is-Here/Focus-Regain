import 'app_category.dart';

/// Foreground time for one app over a time range.
class AppUsage {
  const AppUsage({
    required this.packageName,
    required this.label,
    required this.foreground,
    this.category = AppCategory.other,
  });

  factory AppUsage.fromMap(Map<Object?, Object?> map) => AppUsage(
    packageName: map['packageName']! as String,
    label: map['label']! as String,
    foreground: Duration(milliseconds: (map['foregroundMs']! as num).toInt()),
    category: AppCategory.fromAndroid((map['category'] as num?)?.toInt() ?? -1),
  );

  final String packageName;
  final String label;
  final Duration foreground;
  final AppCategory category;
}
