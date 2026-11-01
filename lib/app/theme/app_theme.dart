import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static const fontFamily = 'PlusJakartaSans';

  // Indigo accents on neutral grey/white surfaces (the seed alone tints every
  // surface lavender). Text colours keep 4.5:1+ contrast on all surfaces.
  static final light = _build(
    ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      primary: AppColors.primaryLight,
      secondary: AppColors.secondaryLight,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.onSurfaceLight,
      onSurfaceVariant: AppColors.onSurfaceVariantLight,
      outline: AppColors.outlineLight,
      outlineVariant: AppColors.outlineVariantLight,
      surfaceContainerLowest: AppColors.cardLight,
      surfaceContainerLow: AppColors.cardLight,
      surfaceContainer: AppColors.surfaceContainerLight,
      surfaceContainerHigh: AppColors.surfaceContainerHighLight,
      surfaceContainerHighest: AppColors.surfaceContainerHighestLight,
    ),
  );

  static final dark = _build(
    const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      tertiary: AppColors.tertiary,
      onTertiary: Color(0xFF68000F),
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiaryContainer: Color(0xFF5C000C),
      error: AppColors.error,
      onError: Color(0xFF690005),
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
      surfaceContainerLowest: AppColors.surfaceContainerLowest,
      surfaceContainerLow: AppColors.surfaceContainerLow,
      surfaceContainer: AppColors.surfaceContainer,
      surfaceContainerHigh: AppColors.surfaceContainerHigh,
      surfaceContainerHighest: AppColors.surfaceContainerHighest,
      inverseSurface: AppColors.inverseSurface,
      onInverseSurface: AppColors.slate,
      inversePrimary: AppColors.inversePrimary,
    ),
  );

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(
      colorScheme: scheme,
      fontFamily: fontFamily,
      // A soft shadow lifts white cards off the grey background in light mode;
      // dark mode separates cards by surface colour instead.
      cardTheme: CardThemeData(
        elevation: scheme.brightness == Brightness.light ? 1.5 : 0,
        shadowColor: const Color(0x1F1A1C24),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      // Dialogs and sheets match the glass cards: tinted, with a light edge.
      dialogTheme: DialogThemeData(
        backgroundColor: _glassPanel(scheme),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(28)),
          side: _glassEdge(scheme),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _glassPanel(scheme),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          side: _glassEdge(scheme),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      // Same indigo highlight on the side rail (tablets, desktop).
      navigationRailTheme: NavigationRailThemeData(
        indicatorColor: _navAccent(scheme).withValues(alpha: 0.2),
        selectedIconTheme: IconThemeData(color: _navAccent(scheme)),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          color: _navAccent(scheme),
        ),
        unselectedLabelTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: _navAccent(scheme).withValues(alpha: 0.2),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? _navAccent(scheme)
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? _navAccent(scheme)
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
    final t = base.textTheme;
    return base.copyWith(
      textTheme: t.copyWith(
        displayLarge: _heavy(t.displayLarge, -1.5),
        displayMedium: _heavy(t.displayMedium, -1.2),
        displaySmall: _heavy(t.displaySmall, -1),
        headlineLarge: _bold(t.headlineLarge, -0.6),
        headlineMedium: _bold(t.headlineMedium, -0.4),
        headlineSmall: _bold(t.headlineSmall, -0.2),
        titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  /// Indigo for the active tab (from the dashboard mockup).
  static Color _navAccent(ColorScheme scheme) =>
      AppColors.pick(AppColors.indigo, scheme.brightness);

  // Nearly opaque: modals have no blur, so the page must not show through.
  static Color _glassPanel(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark
      ? AppColors.surfaceContainerLow.withValues(alpha: 0.96)
      : Colors.white.withValues(alpha: 0.96);

  static BorderSide _glassEdge(ColorScheme scheme) => BorderSide(
    color: scheme.brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.12)
        : scheme.outlineVariant,
  );

  static TextStyle? _heavy(TextStyle? s, double spacing) =>
      s?.copyWith(fontWeight: FontWeight.w800, letterSpacing: spacing);

  static TextStyle? _bold(TextStyle? s, double spacing) =>
      s?.copyWith(fontWeight: FontWeight.w700, letterSpacing: spacing);

  /// Equal-width digits so timers and minutes don't jitter while counting.
  static const tabularFigures = [FontFeature.tabularFigures()];

  /// Violet to mint: the focus ring and the main call to action.
  static List<Color> focusGradient(ColorScheme scheme) => [
    scheme.primary,
    scheme.primaryContainer,
    scheme.secondary,
  ];
}
