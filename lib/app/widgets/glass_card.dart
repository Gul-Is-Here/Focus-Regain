import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'frosted_glass.dart';

/// Frosted glass card used on every screen: blurs the page glows behind it,
/// with a soft shadow in light mode.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accent,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Optional colour for a 4 px stripe down the left edge (alerts).
  final Color? accent;

  static const radius = BorderRadius.all(Radius.circular(20));

  /// The card's look without the blur, for places that can't use the widget
  /// (e.g. slivers).
  static BoxDecoration decorationOf(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    return BoxDecoration(
      borderRadius: radius,
      gradient: FrostedGlass.washOf(scheme),
      border: Border.all(
        color: dark
            ? Colors.white.withValues(alpha: 0.12)
            : scheme.outlineVariant.withValues(alpha: 0.7),
      ),
      boxShadow: dark ? null : _lightShadow,
    );
  }

  static const _lightShadow = [
    BoxShadow(color: Color(0x141A1C24), blurRadius: 16, offset: Offset(0, 4)),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget content = Padding(padding: padding, child: child);
    if (accent != null) {
      content = IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: accent),
            Expanded(child: content),
          ],
        ),
      );
    }
    final glass = FrostedGlass(radius: 20, child: content);
    if (scheme.brightness == Brightness.dark) return glass;
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: radius,
        boxShadow: _lightShadow,
      ),
      child: glass,
    );
  }
}

/// Soft coloured glows behind a page, as in the dashboard mockup.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({
    super.key,
    required this.topGlow,
    required this.child,
  });

  /// Colour of the glow near the top (e.g. coral when over the target).
  final Color topGlow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        gradient: RadialGradient(
          center: const Alignment(0, -0.75),
          radius: 0.9,
          colors: [
            topGlow.withValues(alpha: dark ? 0.10 : 0.07),
            scheme.surface.withValues(alpha: 0),
          ],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.85, 0.2),
            radius: 0.8,
            colors: [
              dark
                  ? AppColors.deepGreen.withValues(alpha: 0.45)
                  : const Color(0xFF8B5CF6).withValues(alpha: 0.05),
              Colors.transparent,
            ],
          ),
        ),
        child: BackdropGroup(child: child),
      ),
    );
  }
}
