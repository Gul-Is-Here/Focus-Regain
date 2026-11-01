import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/utils/duration_format.dart';
import '../../app/widgets/glass_card.dart';
import '../../app/widgets/gradient_button.dart';
import '../../app/widgets/step_progress.dart';
import '../../data/models/focus_goal.dart';
import 'onboarding_view_model.dart';

class OnboardingView extends GetView<OnboardingViewModel> {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Obx(() {
      final page = controller.page.value;
      return PopScope(
        // System back steps to the previous page instead of leaving the app.
        canPop: page == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) controller.back();
        },
        child: Scaffold(
          body: AmbientBackground(
            topGlow: AppColors.pick(AppColors.indigo, scheme.brightness),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopBar(page: page),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: KeyedSubtree(
                          key: ValueKey(page),
                          child: const [
                            _WelcomePage(),
                            _GoalsPage(),
                            _TargetPage(),
                          ][page],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        if (page > 0) ...[
                          TextButton.icon(
                            onPressed: controller.back,
                            style: TextButton.styleFrom(
                              foregroundColor: scheme.onSurfaceVariant,
                              minimumSize: const Size(48, 48),
                            ),
                            icon: const Icon(Icons.chevron_left_rounded),
                            label: const Text('Back'),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: GradientButton(
                            label: controller.isLastPage
                                ? 'Get started'
                                : 'Continue',
                            onPressed: controller.canContinue
                                ? controller.next
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// Step segments and Skip. After the first page, a "STEP n OF 3" label sits
/// above full-width segments.
class _TopBar extends GetView<OnboardingViewModel> {
  const _TopBar({required this.page});

  final int page;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const count = OnboardingViewModel.pageCount;
    final segments = StepSegments(current: page, count: count);
    final skip = page < count - 1
        ? TextButton(
            onPressed: controller.saving.value ? null : controller.skip,
            style: TextButton.styleFrom(
              foregroundColor: scheme.onSurfaceVariant,
            ),
            child: const Text('Skip'),
          )
        : const SizedBox(height: 48);
    if (page == 0) {
      return Row(
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: segments,
            ),
          ),
          const Spacer(),
          skip,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: StepLabel(current: page, count: count),
            ),
            skip,
          ],
        ),
        const SizedBox(height: 6),
        segments,
      ],
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final accent = AppColors.pick(AppColors.emerald, scheme.brightness);
    // Centred when it fits, scrolls at large text sizes.
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _Emblem(),
              const SizedBox(height: 32),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: accent.withValues(alpha: 0.25)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'RECLAIM BALANCE',
                          style: text.labelSmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text.rich(
                TextSpan(
                  text: 'Take back ',
                  children: [
                    TextSpan(
                      text: 'your time',
                      style: TextStyle(color: scheme.primary),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: text.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Text(
                  'Focus Regain shows you where your screen time goes and '
                  'helps you step away from the apps that pull you in.',
                  textAlign: TextAlign.center,
                  style: text.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Feature(
                      icon: Icons.bar_chart_rounded,
                      label: 'Insights',
                      color: accent,
                    ),
                    const SizedBox(width: 8),
                    _Feature(
                      icon: Icons.schedule_rounded,
                      label: 'Pauses',
                      color: AppColors.pick(
                        AppColors.indigo,
                        scheme.brightness,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Feature(
                      icon: Icons.bolt_rounded,
                      label: 'Rituals',
                      color: AppColors.pick(AppColors.mint, scheme.brightness),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The app's leaf in a glowing glass tile. Decorative only.
class _Emblem extends StatelessWidget {
  const _Emblem();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final glow = dark ? AppColors.green : scheme.primary;
    final colors = dark
        ? const [AppColors.sage, AppColors.green, AppColors.deepGreen]
        : [scheme.secondary, scheme.primary];
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 176,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Soft halo behind the tile.
            Container(
              width: 176,
              height: 176,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    glow.withValues(alpha: dark ? 0.35 : 0.18),
                    glow.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            // Faint outer ring, 4 px outside the tile.
            Container(
              width: 152,
              height: 152,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: colors.first.withValues(alpha: dark ? 0.2 : 0.25),
                ),
              ),
            ),
            Container(
              width: 144,
              height: 144,
              decoration: GlassCard.decorationOf(scheme).copyWith(
                borderRadius: BorderRadius.circular(24),
                // The dark tile is see-through, so it gets the halo instead.
                boxShadow: dark
                    ? null
                    : [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.12),
                          blurRadius: 40,
                          offset: const Offset(0, 16),
                        ),
                      ],
              ),
              alignment: Alignment.center,
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: colors,
                ).createShader(rect),
                child: const Icon(Icons.spa_rounded, size: 88),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: DecoratedBox(
        decoration: GlassCard.decorationOf(scheme)
            .copyWith(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalsPage extends GetView<OnboardingViewModel> {
  const _GoalsPage();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      children: [
        Text.rich(
          TextSpan(
            text: 'What do you want to ',
            children: [
              TextSpan(
                text: 'change?',
                style: TextStyle(color: scheme.primary),
              ),
            ],
          ),
          style: text.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pick one or more. We use this to shape your personalised daily '
          'focus rituals.',
          style: text.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Obx(
          () => Column(
            children: [
              for (final goal in FocusGoal.values) ...[
                _GoalCard(
                  goal: goal,
                  selected: controller.goals.contains(goal),
                  onTap: () => controller.toggleGoal(goal),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.selected,
    required this.onTap,
  });

  final FocusGoal goal;
  final bool selected;
  final VoidCallback onTap;

  static const _radius = BorderRadius.all(Radius.circular(16));

  (IconData, String) get _details => switch (goal) {
    FocusGoal.scrollLess => (
      Icons.schedule_rounded,
      'Cut mindless feeds & doomscrolling',
    ),
    FocusGoal.deepWork => (
      Icons.bolt_rounded,
      'Protect flow states for priority tasks',
    ),
    FocusGoal.study => (
      Icons.menu_book_rounded,
      'Retain more & stay in the zone',
    ),
    FocusGoal.sleepBetter => (
      Icons.dark_mode_outlined,
      'Put the phone down at bedtime',
    ),
    FocusGoal.bePresent => (
      Icons.wb_sunny_outlined,
      'More real-world family & meal time',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final dark = scheme.brightness == Brightness.dark;
    final accent = AppColors.pick(AppColors.mint, scheme.brightness);
    final (icon, hint) = _details;
    final card = GlassCard.decorationOf(scheme);
    return Semantics(
      checked: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: selected
            ? BoxDecoration(
                borderRadius: _radius,
                border: Border.all(color: accent.withValues(alpha: 0.55)),
                // Opaque, so the glow below doesn't tint the card.
                color: dark
                    ? null
                    : Color.alphaBlend(
                        accent.withValues(alpha: 0.06),
                        scheme.surfaceContainerLowest,
                      ),
                gradient: dark
                    ? LinearGradient(
                        colors: [
                          Color.alphaBlend(
                            accent.withValues(alpha: 0.14),
                            AppColors.surfaceContainerLow,
                          ),
                          AppColors.surfaceContainerLow,
                          AppColors.surfaceContainer,
                        ],
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.18),
                    blurRadius: 25,
                    spreadRadius: -4,
                  ),
                ],
              )
            : card.copyWith(borderRadius: _radius),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: _radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: selected
                          ? accent.withValues(alpha: 0.15)
                          : scheme.surfaceContainerHigh.withValues(alpha: 0.6),
                      border: Border.all(
                        color: selected
                            ? accent.withValues(alpha: 0.3)
                            : scheme.outlineVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: selected ? accent : scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.label,
                          style: text.titleMedium?.copyWith(
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hint,
                          style: text.bodySmall?.copyWith(
                            color: selected ? accent : scheme.onSurfaceVariant,
                            fontWeight: selected
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? accent : null,
                      border: selected
                          ? null
                          : Border.all(color: scheme.outline),
                    ),
                    child: selected
                        ? Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: dark ? AppColors.onSage : Colors.white,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TargetPage extends GetView<OnboardingViewModel> {
  const _TargetPage();

  /// Quick picks: minutes, name.
  static const _presets = [(120, 'Strict'), (180, 'Balanced'), (240, 'Gentle')];

  static String _verdict(int minutes) => minutes <= 120
      ? 'Strict & highly mindful'
      : minutes <= 210
      ? 'Recommended for balanced focus'
      : 'Gentle & gradual change';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final accent = AppColors.pick(AppColors.mint, scheme.brightness);
    // Spread over the page when it fits, scrolls at large text sizes.
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - 48),
          child: Obx(() {
            final minutes = controller.dailyTargetMinutes.value;
            return Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: 'Set a daily ',
                        children: [
                          TextSpan(
                            text: 'screen-time',
                            style: TextStyle(color: scheme.primary),
                          ),
                          const TextSpan(text: ' target'),
                        ],
                      ),
                      style: text.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pick a number that feels realistic. You can adjust it '
                      'later in Settings.',
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Column(
                  children: [
                    _BigDuration(minutes: minutes, accent: accent),
                    const SizedBox(height: 10),
                    _VerdictPill(label: _verdict(minutes), accent: accent),
                    const SizedBox(height: 24),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 6,
                        activeTrackColor: accent,
                        inactiveTrackColor: scheme.surfaceContainerHigh,
                        trackShape: const RoundedRectSliderTrackShape(),
                        tickMarkShape: const RoundSliderTickMarkShape(
                          tickMarkRadius: 2,
                        ),
                        activeTickMarkColor: scheme.surface.withValues(
                          alpha: 0.45,
                        ),
                        inactiveTickMarkColor: scheme.outline,
                        thumbColor: accent,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 13,
                          elevation: 4,
                        ),
                        overlayColor: accent.withValues(alpha: 0.15),
                      ),
                      child: Slider(
                        value: minutes.toDouble(),
                        min: OnboardingViewModel.minTargetMinutes.toDouble(),
                        max: OnboardingViewModel.maxTargetMinutes.toDouble(),
                        divisions:
                            (OnboardingViewModel.maxTargetMinutes -
                                OnboardingViewModel.minTargetMinutes) ~/
                            OnboardingViewModel.targetStepMinutes,
                        semanticFormatterCallback: (v) =>
                            formatMinutes(v.round()),
                        onChanged: (v) => controller.setDailyTarget(v.round()),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: ExcludeSemantics(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (final (label, align) in [
                              ('1 h · Strict', TextAlign.start),
                              ('6 h · Relaxed', TextAlign.end),
                            ])
                              Flexible(
                                child: Text(
                                  label,
                                  textAlign: align,
                                  style: text.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        for (final (i, (value, name)) in _presets.indexed) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: _PresetChip(
                              label: formatMinutes(value),
                              name: name,
                              selected: minutes == value,
                              accent: accent,
                              onTap: () => controller.setDailyTarget(value),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: accent.withValues(alpha: 0.15),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          Icons.verified_outlined,
                          size: 20,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'What happens when you hit '
                              '${formatMinutes(minutes)}?',
                              style: text.labelLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your Dashboard ring turns coral and the weekly '
                              'recap counts the day as over. Nothing is '
                              'blocked; app limits and schedules do that.',
                              style: text.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

/// "3 h" / "2 h 30 min" with big numbers and accent units.
class _BigDuration extends StatelessWidget {
  const _BigDuration({required this.minutes, required this.accent});

  final int minutes;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final unit = text.headlineMedium?.copyWith(
      color: accent,
      fontWeight: FontWeight.w700,
    );
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$hours'),
          TextSpan(text: ' h', style: unit),
          if (rest > 0) ...[
            TextSpan(text: ' $rest'),
            TextSpan(text: ' min', style: unit),
          ],
        ],
      ),
      textAlign: TextAlign.center,
      style: text.displayLarge?.copyWith(
        fontWeight: FontWeight.w800,
        fontFeatures: AppTheme.tabularFigures,
      ),
    );
  }
}

class _VerdictPill extends StatelessWidget {
  const _VerdictPill({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, size: 15, color: accent),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.name,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final String name;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  static const _radius = BorderRadius.all(Radius.circular(12));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: _radius,
          color: selected
              ? accent.withValues(alpha: 0.15)
              : scheme.surfaceContainerHigh.withValues(alpha: 0.6),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.6)
                : scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: _radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Column(
                children: [
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: text.labelLarge?.copyWith(
                      color: selected ? accent : scheme.onSurface,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: text.labelSmall?.copyWith(
                      color: selected ? accent : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
