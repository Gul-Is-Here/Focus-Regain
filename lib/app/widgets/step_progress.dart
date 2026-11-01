import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Segmented progress: done steps solid, the current one a gradient, the
/// rest an empty track. Read out as "Step n of m".
class StepSegments extends StatelessWidget {
  const StepSegments({super.key, required this.current, required this.count});

  /// Zero-based.
  final int current;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final accent = AppColors.pick(AppColors.mint, scheme.brightness);
    return Semantics(
      label: 'Step ${current + 1} of $count',
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: i < current
                      ? accent.withValues(alpha: 0.8)
                      : i > current
                      ? scheme.surfaceContainerHigh
                      : null,
                  gradient: i == current
                      ? LinearGradient(
                          colors: dark
                              ? AppColors.accentGradient
                              : [scheme.secondary, scheme.primary],
                        )
                      : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "● STEP 2 OF 4". Decorative: [StepSegments] carries the spoken label.
class StepLabel extends StatelessWidget {
  const StepLabel({super.key, required this.current, required this.count});

  final int current;
  final int count;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.pick(
      AppColors.mint,
      Theme.of(context).colorScheme.brightness,
    );
    return ExcludeSemantics(
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'STEP ${current + 1} OF $count',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
