import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Frosted glass: blurs what's behind it, adds a faint white wash and an
/// edge that is brighter at the top, like light catching it. Only visible
/// over something to blur (glows, images).
class FrostedGlass extends StatelessWidget {
  const FrostedGlass({
    super.key,
    required this.child,
    this.radius = 12,
    this.circle = false,
    this.blur = 16,
  });

  final Widget child;
  final double radius;

  /// Round instead of a rounded rectangle.
  final bool circle;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final shape = circle
        ? const CircleBorder()
        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    return ClipPath(
      clipper: ShapeBorderClipper(shape: shape),
      // Grouped: cards under one [BackdropGroup] share a single read of the
      // screen, so a list of glass cards stays smooth.
      child: BackdropFilter.grouped(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: CustomPaint(
          foregroundPainter: _EdgePainter(shape, dark),
          child: DecoratedBox(
            decoration: ShapeDecoration(shape: shape, gradient: washOf(scheme)),
            child: child,
          ),
        ),
      ),
    );
  }

  /// The glass tint, for surfaces that can't blur (slivers, the bottom bar).
  static LinearGradient washOf(ColorScheme scheme) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: scheme.brightness == Brightness.dark
        ? [_wash(scheme, 0.07), _wash(scheme, 0.03)]
        : [
            Colors.white.withValues(alpha: 0.85),
            Colors.white.withValues(alpha: 0.65),
          ],
  );

  /// White at [alpha] over a see-through dark surface.
  static Color _wash(ColorScheme scheme, double alpha) => Color.alphaBlend(
    Colors.white.withValues(alpha: alpha),
    scheme.surfaceContainer.withValues(alpha: 0.65),
  );
}

/// 1 px outline fading from bright (top) to faint (bottom).
class _EdgePainter extends CustomPainter {
  const _EdgePainter(this.shape, this.dark);

  final ShapeBorder shape;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: dark
            ? [
                Colors.white.withValues(alpha: 0.22),
                Colors.white.withValues(alpha: 0.06),
              ]
            : [Colors.white, const Color(0xFF1A1C24).withValues(alpha: 0.10)],
      ).createShader(rect);
    canvas.drawPath(shape.getOuterPath(rect.deflate(0.5)), paint);
  }

  @override
  bool shouldRepaint(_EdgePainter old) => old.dark != dark;
}
