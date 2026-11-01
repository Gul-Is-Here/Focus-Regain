import 'app_category.dart';

/// A launchable app the user can choose to block.
class InstalledApp {
  const InstalledApp({
    required this.packageName,
    required this.label,
    this.category = AppCategory.other,
  });

  factory InstalledApp.fromMap(Map<Object?, Object?> map) => InstalledApp(
    packageName: map['packageName']! as String,
    label: map['label']! as String,
    category: AppCategory.fromAndroid(map['category'] as int? ?? -1),
  );

  final String packageName;
  final String label;
  final AppCategory category;
}
