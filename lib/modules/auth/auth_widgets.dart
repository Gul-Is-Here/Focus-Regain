import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';
import '../../app/widgets/frosted_glass.dart';
import '../../app/widgets/glass_card.dart';
import 'auth_view_model.dart';

/// Page frame shared by Log in and Sign up: glow, a header with back (when
/// there's somewhere to go back to) and a centred title, then [children] in
/// a scrolling column.
class AuthPage extends StatelessWidget {
  const AuthPage({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canPop = Navigator.of(context).canPop();
    final dark = scheme.brightness == Brightness.dark;
    Widget glow(Color color, double size) => IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
    return Scaffold(
      body: AmbientBackground(
        topGlow: AppColors.pick(AppColors.mint, scheme.brightness),
        child: Stack(
          children: [
            Positioned(
              top: -60,
              left: -70,
              child: glow(
                scheme.primary.withValues(alpha: dark ? 0.22 : 0.14),
                300,
              ),
            ),
            Positioned(
              top: 280,
              right: -90,
              child: glow(
                (dark ? AppColors.green : scheme.secondary).withValues(
                  alpha: dark ? 0.22 : 0.10,
                ),
                320,
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                    child: Row(
                      children: [
                        SizedBox.square(
                          dimension: 48,
                          child: canPop
                              ? IconButton(
                                  onPressed: Get.back,
                                  tooltip: 'Back',
                                  icon: const Icon(Icons.arrow_back_rounded),
                                )
                              : null,
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: scheme.primary.withValues(
                                        alpha: 0.7,
                                      ),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  title,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Expanded(
                    // Not a lazy list: the form must keep every field built to
                    // validate it.
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: children,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Glass leaf emblem, an optional badge, heading and one line under it.
class AuthHero extends StatelessWidget {
  const AuthHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.badge,
  });

  final String title;
  final String subtitle;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final dark = scheme.brightness == Brightness.dark;
    return Column(
      children: [
        ExcludeSemantics(
          child: Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  scheme.primary.withValues(alpha: 0.28),
                  scheme.primary.withValues(alpha: 0),
                ],
              ),
            ),
            child: SizedBox.square(
              dimension: 64,
              child: FrostedGlass(
                circle: true,
                child: DecoratedBox(
                  // A tint of the accent lit from the top left.
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.3, -0.5),
                      colors: [
                        scheme.primary.withValues(alpha: 0.2),
                        scheme.primary.withValues(alpha: 0),
                      ],
                    ),
                  ),
                  child: Center(
                    child: ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (rect) => LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: dark
                            ? const [AppColors.sage, AppColors.green]
                            : [scheme.primary, scheme.secondary],
                      ).createShader(rect),
                      child: const Icon(Icons.spa_rounded, size: 36),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (badge case final badge?) ...[
          const SizedBox(height: 8),
          FrostedGlass(
            radius: 99,
            blur: 10,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      badge.toUpperCase(),
                      style: text.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// "Continue with Google" / "Continue with Apple".
class SocialButtons extends GetView<AuthViewModel> {
  const SocialButtons({super.key, required this.verb});

  /// "Sign up" or "Continue".
  final String verb;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final busy = controller.busy.value;
      return Column(
        children: [
          _SocialButton(
            logo: const _GoogleLogo(),
            label: '$verb with Google',
            busy: busy == AuthMethod.google,
            onPressed: busy == null ? controller.continueWithGoogle : null,
          ),
          const SizedBox(height: 8),
          _SocialButton(
            logo: Icon(
              Icons.apple,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            label: '$verb with Apple',
            busy: busy == AuthMethod.apple,
            onPressed: busy == null ? controller.continueWithApple : null,
          ),
        ],
      );
    });
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.logo,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final Widget logo;
  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: onPressed == null && !busy ? 0.55 : 1,
        child: FrostedGlass(
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onPressed,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox.square(
                        dimension: 20,
                        child: busy
                            ? const CircularProgressIndicator(strokeWidth: 2)
                            : Center(child: logo),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: text.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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

/// Google's four-colour "G", drawn so no image asset is needed.
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(size: Size.square(18), painter: _GooglePainter());
}

class _GooglePainter extends CustomPainter {
  const _GooglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.2;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    // Arcs clockwise from the bar on the right (angles in degrees).
    for (final (from, sweep, color) in const [
      (-40.0, -100.0, Color(0xFFEA4335)), // red, top
      (-140.0, -90.0, Color(0xFFFBBC05)), // yellow, left
      (-230.0, -95.0, Color(0xFF34A853)), // green, bottom
      (35.0, -35.0, Color(0xFF4285F4)), // blue, lower right
    ]) {
      canvas.drawArc(
        rect,
        from * math.pi / 180,
        sweep * math.pi / 180,
        false,
        paint..color = color,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(
        size.width / 2,
        size.height / 2 - stroke / 2,
        size.width / 2 - stroke / 4,
        stroke,
      ),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(_GooglePainter oldDelegate) => false;
}

/// "——  OR LOG IN WITH EMAIL  ——"
class OrDivider extends StatelessWidget {
  const OrDivider(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final line = Expanded(
      child: Divider(color: scheme.outlineVariant.withValues(alpha: 0.6)),
    );
    return Row(
      children: [
        line,
        // Fixed max width keeps both lines equal; wraps at large text sizes.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              text.toUpperCase(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
        line,
      ],
    );
  }
}

/// Label above a see-through field with a leading icon. [validHint] shows
/// on the right of the label once the value passes [validator].
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    required this.icon,
    required this.validator,
    this.hint,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction = TextInputAction.next,
    this.obscure = false,
    this.suffix,
    this.onSubmitted,
    this.validHint,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final FormFieldValidator<String> validator;
  final String? hint;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction textInputAction;
  final bool obscure;
  final Widget? suffix;
  final VoidCallback? onSubmitted;
  final String? validHint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final dark = scheme.brightness == Brightness.dark;
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    // Merged so screen readers read the label with the field.
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: text.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (validHint case final hint?)
                ValueListenableBuilder(
                  valueListenable: controller,
                  builder: (context, value, _) => ExcludeSemantics(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity:
                          value.text.isNotEmpty && validator(value.text) == null
                          ? 1
                          : 0,
                      child: Text(
                        hint,
                        style: text.labelSmall?.copyWith(color: scheme.primary),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            validator: validator,
            obscureText: obscure,
            keyboardType: keyboardType,
            autofillHints: autofillHints,
            textInputAction: textInputAction,
            autocorrect: !obscure && keyboardType != TextInputType.emailAddress,
            enableSuggestions: !obscure,
            onFieldSubmitted: (_) => onSubmitted?.call(),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: scheme.outline),
              filled: true,
              fillColor: dark
                  ? AppColors.surfaceContainerLowest.withValues(alpha: 0.65)
                  : Colors.white.withValues(alpha: 0.8),
              prefixIcon: Icon(icon, size: 20, color: scheme.outline),
              suffixIcon: suffix,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: border(Colors.transparent),
              enabledBorder: border(
                dark
                    ? Colors.white.withValues(alpha: 0.1)
                    : scheme.outlineVariant.withValues(alpha: 0.7),
              ),
              focusedBorder: border(scheme.primary.withValues(alpha: 0.6), 2),
              errorBorder: border(scheme.error),
              focusedErrorBorder: border(scheme.error, 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Eye button that shows or hides every password field. Read inside an Obx.
class PasswordVisibilityButton extends GetView<AuthViewModel> {
  const PasswordVisibilityButton({super.key});

  @override
  Widget build(BuildContext context) {
    final hidden = controller.hidePassword.value;
    return IconButton(
      onPressed: controller.hidePassword.toggle,
      tooltip: hidden ? 'Show password' : 'Hide password',
      icon: Icon(
        hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 20,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}

/// Three bars and a word for the new password.
class PasswordStrengthMeter extends GetView<AuthViewModel> {
  const PasswordStrengthMeter({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final b = scheme.brightness;
    final text = Theme.of(context).textTheme;
    return Obx(() {
      final score = controller.passwordStrength.value;
      final (label, color) = switch (score) {
        0 => ('Too short', AppColors.pick(AppColors.coral, b)),
        1 => ('Weak', AppColors.pick(AppColors.amber, b)),
        2 => ('Good', scheme.primary),
        _ => ('Strong', scheme.primary),
      };
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Password strength',
                    style: text.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  label,
                  style: text.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: i < score
                              ? color
                              : scheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// The last sign-in error, announced to screen readers.
class AuthErrorBanner extends GetView<AuthViewModel> {
  const AuthErrorBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final coral = AppColors.pick(AppColors.coral, scheme.brightness);
    return Obx(() {
      final message = controller.error.value;
      if (message == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: coral.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: coral.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded, size: 20, color: coral),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// Pill with a short reassurance under the form.
class PrivacyPill extends StatelessWidget {
  const PrivacyPill({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: FrostedGlass(
        radius: 99,
        blur: 10,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.eco_outlined, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Your screen-time data stays on this phone',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Already have an account? Log in"
class SwitchModeLink extends StatelessWidget {
  const SwitchModeLink({
    super.key,
    required this.question,
    required this.action,
    required this.onPressed,
  });

  final String question;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          question,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        TextButton(
          onPressed: onPressed,
          child: Text(
            action,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}

/// Small rounded checkbox with a label; the whole row is the tap target.
class AuthCheckbox extends StatelessWidget {
  const AuthCheckbox({
    super.key,
    required this.checked,
    required this.onChanged,
    required this.label,
  });

  final bool checked;
  final VoidCallback onChanged;
  final Widget label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      checked: checked,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onChanged,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(top: 1),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: checked ? scheme.primary : null,
                  borderRadius: BorderRadius.circular(5),
                  border: checked
                      ? null
                      : Border.all(color: scheme.outline, width: 1.5),
                  boxShadow: checked
                      ? [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.35),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: checked
                    ? Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: scheme.onPrimary,
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Flexible(child: label),
            ],
          ),
        ),
      ),
    );
  }
}
