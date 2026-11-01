/// The category an Android app declares for itself (`ApplicationInfo.category`).
/// Apps that declare none, or anything new, fall into [other].
enum AppCategory {
  social('Social networking', 4),
  video('Entertainment & video', 2),
  games('Games', 0),
  audio('Music & audio', 1),
  images('Photos & images', 3),
  news('News & reading', 5),
  maps('Maps & travel', 6),
  productivity('Productivity & utilities', 7),
  accessibility('Accessibility', 8),
  other('Other apps', -1);

  const AppCategory(this.label, this.androidCode);

  final String label;

  /// The matching `ApplicationInfo.CATEGORY_*` value.
  final int androidCode;

  static AppCategory fromAndroid(int code) => values.firstWhere(
    (c) => c.androidCode == code,
    orElse: () => AppCategory.other,
  );
}
