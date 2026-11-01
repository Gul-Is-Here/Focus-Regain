import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Full-width gradient call to action, dimmed while it can't be used.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;

  /// Shows a spinner in place of the icon and ignores taps.
  final bool busy;

  static const _radius = BorderRadius.all(Radius.circular(16));

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Dark: sage to green with dark text (5:1+ under the label).
    final foreground = dark ? AppColors.onSage : Colors.white;
    final enabled = onPressed != null && !busy;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: onPressed != null ? 1 : 0.45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: _radius,
          boxShadow: [
            if (enabled)
              BoxShadow(
                color: (dark ? AppColors.green : const Color(0xFF4F46E5))
                    .withValues(alpha: 0.45),
                blurRadius: 30,
                spreadRadius: -5,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: _radius,
              gradient: LinearGradient(
                colors: dark
                    ? AppColors.accentGradient
                    : const [Color(0xFF4F46E5), Color(0xFF4338CA)],
              ),
            ),
            child: InkWell(
              borderRadius: _radius,
              onTap: enabled ? onPressed : null,
              splashColor: Colors.white.withValues(alpha: 0.12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: foreground,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      busy
                          ? SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: foreground,
                              ),
                            )
                          : Icon(icon, color: foreground),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
