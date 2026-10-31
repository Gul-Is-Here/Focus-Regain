import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static final light = _build(
    ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      primary: AppColors.primaryLight,
      secondary: AppColors.secondaryLight,
      surface: AppColors.backgroundLight,
      surfaceContainerLow: AppColors.cardLight,
      onSurface: AppColors.textLight,
      error: AppColors.overLimitLight,
    ),
  );

  static final dark = _build(
    ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: Brightness.dark,
      primary: AppColors.primaryDark,
      secondary: AppColors.secondaryDark,
      surface: AppColors.backgroundDark,
      surfaceContainerLow: AppColors.cardDark,
      onSurface: AppColors.textDark,
      error: AppColors.overLimitDark,
    ),
  );

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(
      colorScheme: scheme,
      fontFamily: 'Inter',
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      appBarTheme: const AppBarTheme(centerTitle: false),
    );
    final t = base.textTheme;
    return base.copyWith(
      textTheme: t.copyWith(
        displayLarge: _heading(t.displayLarge),
        displayMedium: _heading(t.displayMedium),
        displaySmall: _heading(t.displaySmall),
        headlineLarge: _heading(t.headlineLarge),
        headlineMedium: _heading(t.headlineMedium),
        headlineSmall: _heading(t.headlineSmall),
      ),
    );
  }

  static TextStyle? _heading(TextStyle? style) =>
      style?.copyWith(fontFamily: 'Fraunces', fontWeight: FontWeight.w600);

  /// Equal-width digits so timers and minutes don't jitter while counting.
  static const tabularFigures = [FontFeature.tabularFigures()];
}
