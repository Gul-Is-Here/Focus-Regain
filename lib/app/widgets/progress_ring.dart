import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'shimmer.dart';

/// A thick progress ring with content in the middle. One colour draws a
/// solid arc, several draw a gradient with a soft glow. Changes in progress
/// animate (instantly with reduced motion). The ring grows with
/// the user's text size (up to 1.6x) and the content shrinks to fit beyond
/// that, so large text never spills out of the circle.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    required this.colors,
    required this.size,
    required this.semanticsLabel,
    required this.child,
    this.strokeWidth = 14,
  });

  /// 0..1; values outside are clamped.
  final double progress;
  final List<Color> colors;
  final double size;
  final String semanticsLabel;
  final Widget child;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = progress.clamp(0.0, 1.0);
    final scaled = MediaQuery.textScalerOf(context)
        .scale(size)
        .clamp(size, size * 1.6);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Never wider than the space, or the ring would be squashed to an oval.
        final dimension = math.min(scaled, constraints.maxWidth);
        return _ring(context, value, dimension, scheme);
      },
    );
  }

  Widget _ring(
    BuildContext context,
    double value,
    double dimension,
    ColorScheme scheme,
  ) {
    return Semantics(
      label: semanticsLabel,
      value: '${(value * 100).round()}%',
      child: SizedBox.square(
        dimension: dimension,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value),
          duration: reduceMotion(context)
              ? Duration.zero
              : const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, animated, child) => CustomPaint(
            painter: _RingPainter(
              progress: animated,
              colors: colors,
              track: scheme.surfaceContainerHighest,
              strokeWidth: strokeWidth,
            ),
            child: child,
          ),
          child: Padding(
            // Keeps the content inside the ring's inner circle.
            padding: EdgeInsets.all(dimension * 0.16),
            child: Center(
              child: FittedBox(fit: BoxFit.scaleDown, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.colors,
    required this.track,
    required this.strokeWidth,
  });

  final double progress;
  final List<Color> colors;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2 + 4);
    Paint stroke() => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, 2 * math.pi, false, stroke()..color = track);
    if (progress == 0) return;

    final sweep = 2 * math.pi * progress;
    final arc = stroke();
    if (colors.length == 1) {
      arc.color = colors.single;
    } else {
      // Diagonal gradient instead of a sweep, so the round start cap has no seam.
      arc.shader = LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..shader = arc.shader
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    canvas.drawArc(rect, -math.pi / 2, sweep, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.track != track ||
      old.strokeWidth != strokeWidth ||
      !_sameColors(old.colors, colors);

  static bool _sameColors(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
