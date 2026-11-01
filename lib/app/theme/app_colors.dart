import 'package:flutter/material.dart';

/// Dark mode uses the user's "Sage" palette: sage #9CB080 (accent text, icons,
/// selected states), green #618764 (fills, rings, switches), deep green
/// #2B5748 (containers, highlights) and slate #273338 (background). Cards are
/// slightly lighter slates. Light mode keeps indigo on neutral greys.
abstract final class AppColors {
  static const seed = Color(0xFF603CE2);

  // The four palette colours.
  static const sage = Color(0xFF9CB080);
  static const green = Color(0xFF618764);
  static const deepGreen = Color(0xFF2B5748);
  static const slate = Color(0xFF273338);

  /// Sage pulled a little toward green: small filled controls keep 5.9:1 with
  /// [onSage] text across their whole width.
  static const sageDeep = Color(0xFF88A170);

  /// Text and icons on sage / green fills (7.2:1 on sage, 4.2:1 on green, so
  /// text sits on the sage half of a gradient).
  static const onSage = Color(0xFF14200F);

  /// Filled accent for buttons and the active choice in dark mode.
  static const accentGradient = [sage, green];

  // Dark
  static const primary = sage;
  static const onPrimary = onSage;
  static const primaryContainer = green;
  static const onPrimaryContainer = Color(0xFFF2F6EC);
  static const secondary = sage;
  static const onSecondary = onSage;
  static const secondaryContainer = deepGreen;
  static const onSecondaryContainer = Color(0xFFDDE8CF);
  static const tertiary = Color(0xFFFFB3B0);
  static const tertiaryContainer = Color(0xFFF16161);
  static const error = Color(0xFFFFB4AB);
  static const surface = slate;
  static const onSurface = Color(0xFFEEF2EC);
  static const onSurfaceVariant = Color(0xFFB3C0B8);
  static const outline = Color(0xFF84948C);
  static const outlineVariant = Color(0xFF3F5056);
  static const surfaceContainerLowest = Color(0xFF202A2E);
  static const surfaceContainerLow = Color(0xFF2D3B41);
  static const surfaceContainer = Color(0xFF33434A);
  static const surfaceContainerHigh = Color(0xFF3A4B52);
  static const surfaceContainerHighest = Color(0xFF42545B);
  static const inverseSurface = Color(0xFFDDE6D6);
  static const inversePrimary = green;

  // Light: indigo accents on neutral surfaces. Accents are darker so they keep
  // contrast on white (primary 6.3:1, secondary 6.6:1, onSurfaceVariant 8:1).
  static const primaryLight = Color(0xFF4F46E5);
  static const secondaryLight = Color(0xFF006C46);
  static const surfaceLight = Color(0xFFF5F6FA);
  static const cardLight = Color(0xFFFFFFFF);
  static const surfaceContainerLight = Color(0xFFEEF0F5);
  static const surfaceContainerHighLight = Color(0xFFE6E8EF);
  static const surfaceContainerHighestLight = Color(0xFFDEE1EA);
  static const onSurfaceLight = Color(0xFF1A1C24);
  static const onSurfaceVariantLight = Color(0xFF4A4D5C);
  static const outlineLight = Color(0xFF6E7182);
  static const outlineVariantLight = Color(0xFFC9CBD6);

  // Accents as [dark, light] pairs. In dark mode the identity accents
  // (emerald, blue, indigo, violet, mint) all use sage; coral and amber stay,
  // since they mean "over target" / "warning". Light variants are deeper so
  // text on white keeps 4.5:1 contrast.
  static const coral = [Color(0xFFFF6B6B), Color(0xFFD9363E)];
  static const coralDeep = [Color(0xFFFF5252), Color(0xFFC0262F)];
  static const coralSoft = [Color(0xFFFFA07A), Color(0xFFF0624F)];
  static const amber = [Color(0xFFF59E0B), Color(0xFFB45309)];
  static const emerald = [sage, Color(0xFF047857)];
  static const mint = [sage, Color(0xFF047857)];
  static const blue = [sage, Color(0xFF1D4ED8)];
  static const indigo = [sage, Color(0xFF4F46E5)];
  static const violet = [sage, Color(0xFF7C3AED)];

  /// Picks the dark or light variant of a status accent.
  static Color pick(List<Color> pair, Brightness brightness) =>
      brightness == Brightness.dark ? pair[0] : pair[1];
}
