import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/utils/duration_format.dart';
import '../../app/widgets/app_icon.dart';
import '../../app/widgets/glass_card.dart';
import '../../app/widgets/message_view.dart';
import '../../app/widgets/progress_ring.dart';
import '../../data/models/focus_session.dart';
import '../shell/shell_view_model.dart';
import 'focus_view_model.dart';

class FocusView extends GetView<FocusViewModel> {
  const FocusView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AmbientBackground(
        topGlow: AppColors.pick(AppColors.violet, Theme.of(context).brightness),
        child: SafeArea(
          child: Obx(
            () => switch (controller.status.value) {
              FocusStatus.loading => const Center(
                child: CircularProgressIndicator(),
              ),
              FocusStatus.unsupported => const MessageView(
                icon: Icons.phone_iphone,
                text: 'Focus sessions on iPhone are coming in a later update.',
              ),
              FocusStatus.unavailable => const MessageView(
                icon: Icons.block,
                text:
                    "Focus sessions block apps, and this phone doesn't let "
                    "apps cover other apps.",
              ),
              FocusStatus.needsSetup => MessageView(
                icon: Icons.lock_outline,
                text:
                    'Focus sessions block apps, so they need the same two '
                    'permissions as Blocking.',
                action: TextButton(
                  // Blocking is the third tab.
                  onPressed: () => Get.find<ShellViewModel>().changeTab(2),
                  child: const Text('Set up blocking'),
                ),
              ),
              FocusStatus.error => MessageView(
                icon: Icons.error_outline,
                text: "Couldn't load focus sessions.",
                action: TextButton(
                  onPressed: controller.refreshState,
                  child: const Text('Try again'),
                ),
              ),
              FocusStatus.idle => const _FocusHome(),
              FocusStatus.running => const _RunningSession(),
            },
          ),
        ),
      ),
    );
  }
}

/// Start screen: greeting, nudge, today's focus ring, start button, stats, history.
class _FocusHome extends GetView<FocusViewModel> {
  const _FocusHome();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.refreshState,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: const [
          _Header(),
          SizedBox(height: 16),
          _NudgeCard(),
          SizedBox(height: 16),
          _GoalCard(),
          SizedBox(height: 20),
          _StartButton(),
          SizedBox(height: 20),
          _StatCards(),
          SizedBox(height: 28),
          _History(),
        ],
      ),
    );
  }
}

class _Header extends GetView<FocusViewModel> {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Obx(() {
      final streak = controller.streak;
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(controller.greeting, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 2),
                Text(
                  'Ready to focus today?',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            label: '$streak-day focus streak',
            excludeSemantics: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.secondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: scheme.secondary.withValues(alpha: 0.2),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department_outlined,
                    size: 16,
                    color: scheme.secondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${streak}d streak',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _NudgeCard extends GetView<FocusViewModel> {
  const _NudgeCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Obx(() {
      final nudge = controller.nudge;
      return GlassCard(
        padding: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: AppTheme.focusGradient(scheme),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.auto_awesome,
                  size: 22,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'QUICK NUDGE',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: nudge.highlight,
                            style: TextStyle(
                              color: scheme.secondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(text: nudge.rest),
                        ],
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _GoalCard extends GetView<FocusViewModel> {
  const _GoalCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Obx(() {
      final focused = controller.focusedToday.inMinutes;
      final percent = (controller.goalProgress * 100).round();
      final up = controller.trendUp;
      return GlassCard(
        padding: EdgeInsets.zero,
        child: DecoratedBox(
          // Soft violet glow from the top, behind the ring.
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.1,
              colors: [
                scheme.primary.withValues(alpha: 0.15),
                Colors.transparent,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                ProgressRing(
                  progress: controller.goalProgress,
                  colors: AppTheme.focusGradient(scheme),
                  size: 208,
                  semanticsLabel: "Today's focus goal",
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatMinutes(focused),
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontFeatures: AppTheme.tabularFigures,
                        ),
                      ),
                      Text(
                        "Today's focus",
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 14,
                            color: scheme.secondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$percent% completed',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  // Wraps onto two lines at large text sizes.
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.flag_outlined,
                            size: 18,
                            color: scheme.outline,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text.rich(
                              TextSpan(
                                text: 'Goal: ',
                                children: [
                                  TextSpan(
                                    text: formatMinutes(
                                      controller.focusGoalMinutes.value,
                                    ),
                                    style: TextStyle(
                                      color: scheme.onSurface,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (up ? scheme.secondary : scheme.tertiary)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              up ? Icons.trending_up : Icons.trending_down,
                              size: 16,
                              color: up ? scheme.secondary : scheme.tertiary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                controller.trendText,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: up
                                      ? scheme.secondary
                                      : scheme.tertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _StartButton extends StatelessWidget {
  const _StartButton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: scheme.primaryContainer.withValues(alpha: 0.45),
            blurRadius: 32,
            spreadRadius: -6,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          // Dark: sage with dark text (7:1); the mid green is too dim for text.
          backgroundColor: dark ? scheme.primary : scheme.primaryContainer,
          foregroundColor: dark ? scheme.onPrimary : scheme.onPrimaryContainer,
          minimumSize: const Size.fromHeight(56),
          shape: const StadiumBorder(),
          textStyle: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        onPressed: () => _NewSessionSheet.show(context),
        icon: const Icon(Icons.bolt),
        label: const Text('Start focus session'),
      ),
    );
  }
}

class _StatCards extends GetView<FocusViewModel> {
  const _StatCards();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Obx(() {
      final screen = controller.screenTimeToday.value;
      final average = controller.dailyAverage.value;
      final stopped = controller.interceptionsToday.value;
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _StatCard(
                label: 'Screen time',
                icon: Icons.smartphone,
                iconColor: scheme.primary,
                value: screen == null ? '–' : formatMinutes(screen.inMinutes),
                valueColor: scheme.onSurface,
                footIcon: Icons.show_chart,
                footColor: scheme.onSurfaceVariant,
                foot: average == null
                    ? 'Today so far'
                    : 'Daily avg ${formatMinutes(average.inMinutes)}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Interceptions',
                icon: Icons.shield_outlined,
                iconColor: scheme.tertiaryContainer,
                value: '$stopped',
                valueColor: scheme.tertiary,
                footIcon: Icons.block,
                footColor: scheme.tertiary,
                foot: stopped == 1
                    ? 'distraction stopped'
                    : 'distractions stopped',
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.valueColor,
    required this.footIcon,
    required this.footColor,
    required this.foot,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final String value;
  final Color valueColor;
  final IconData footIcon;
  final Color footColor;
  final String foot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(icon, size: 18, color: iconColor),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: valueColor,
                fontFeatures: AppTheme.tabularFigures,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(footIcon, size: 14, color: footColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    foot,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: footColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// While a session runs: big countdown ring, progress, blocked apps, stop.
class _RunningSession extends GetView<FocusViewModel> {
  const _RunningSession();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final b = scheme.brightness;
    return AmbientBackground(
      topGlow: AppColors.pick(AppColors.violet, b),
      child: LayoutBuilder(
        builder: (context, constraints) => Obx(() {
          final session = controller.active.value!;
          final remaining = controller.remaining.value;
          final elapsed = controller.elapsed;
          final count = session.packages.length;
          final amber = AppColors.pick(AppColors.amber, b);
          final mint = AppColors.pick(AppColors.mint, b);
          // At most 520 wide on tablets and desktop.
          final gutter = math.max(20.0, (constraints.maxWidth - 520) / 2);
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 16),
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Focusing',
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        _StatusPill(
                          icon: session.strict ? Icons.lock : null,
                          label: session.strict ? 'STRICT' : 'IN PROGRESS',
                          color: session.strict ? amber : mint,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatMinutes(session.planned.inMinutes)} session · '
                      'started ${TimeOfDay.fromDateTime(session.startedAt).format(context)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Center(
                      child: ProgressRing(
                        progress: controller.progress,
                        colors: AppTheme.focusGradient(scheme),
                        size: 260,
                        strokeWidth: 16,
                        semanticsLabel: 'Focus session progress',
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'TIME LEFT',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              formatClock(remaining),
                              style: theme.textTheme.displayMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontFeatures: AppTheme.tabularFigures,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _StatusPill(
                              icon: Icons.flag_outlined,
                              label:
                                  'Ends ${TimeOfDay.fromDateTime(session.endsAt).format(context)}',
                              color: scheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _SessionTile(
                              icon: Icons.timelapse,
                              color: AppColors.pick(AppColors.indigo, b),
                              value: formatMinutes(elapsed.inMinutes),
                              label: 'focused so far',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SessionTile(
                              icon: Icons.shield_outlined,
                              color: mint,
                              value: '${controller.interceptionsToday.value}',
                              label: 'stopped today',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BLOCKED UNTIL IT ENDS · $count '
                            '${count == 1 ? 'APP' : 'APPS'}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final p in session.packages.take(8))
                                Tooltip(
                                  message:
                                      controller.apps
                                          .firstWhereOrNull(
                                            (a) => a.packageName == p,
                                          )
                                          ?.label ??
                                      p,
                                  child: AppIcon(p, size: 36),
                                ),
                              if (count > 8)
                                Container(
                                  width: 36,
                                  height: 36,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '+${count - 8}',
                                    style: theme.textTheme.labelMedium,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'You can close Regain Focus; the session keeps '
                                  'going.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Pinned so stopping (or the strict notice) is always in reach.
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 16),
                child: session.strict
                    ? GlassCard(
                        accent: amber,
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline, color: amber),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Strict mode is on. This session can't be "
                                'stopped early.',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Builder(
                        builder: (context) {
                          final coral = AppColors.pick(AppColors.coral, b);
                          return OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              shape: const StadiumBorder(),
                              foregroundColor: coral,
                              backgroundColor: coral.withValues(alpha: 0.08),
                              side: BorderSide(
                                color: coral.withValues(alpha: 0.4),
                              ),
                              textStyle: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: () => _confirmStop(context),
                            icon: const Icon(Icons.stop_rounded),
                            label: const Text('Stop session'),
                          );
                        },
                      ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Future<void> _confirmStop(BuildContext context) async {
    final stop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop this session?'),
        content: const Text('Your apps will be unblocked now.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    if (stop ?? false) await controller.stop();
  }
}

/// Small tinted pill with an optional icon (session state, end time).
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon case final icon?) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ] else ...[
            CircleAvatar(radius: 3, backgroundColor: color),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                fontFeatures: AppTheme.tabularFigures,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One number about the running session, in a glass card.
class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color.withValues(alpha: 0.25)),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: AppTheme.tabularFigures,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _History extends GetView<FocusViewModel> {
  const _History();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      final today = controller.todaySessions;
      final recent = controller.history.reversed.take(5).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent sessions', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            today.isEmpty
                ? 'No focus sessions yet today.'
                : '${today.length} ${today.length == 1 ? 'session' : 'sessions'}'
                      ' today · ${formatMinutes(controller.focusedToday.inMinutes)} focused',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          for (final s in recent) _HistoryTile(s),
        ],
      );
    });
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile(this.session);

  final FocusSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final day = MaterialLocalizations.of(context)
        .formatShortDate(session.startedAt);
    final time = TimeOfDay.fromDateTime(session.startedAt).format(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (session.completed ? scheme.secondary : scheme.outline)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              session.completed
                  ? Icons.check_circle_outline
                  : Icons.stop_circle_outlined,
              color: session.completed ? scheme.secondary : scheme.outline,
            ),
          ),
          title: Text(
            session.completed
                ? '${formatMinutes(session.planned.inMinutes)} completed'
                : 'Stopped after ${formatMinutes(session.focused.inMinutes)}',
          ),
          subtitle: Text('$day · $time'),
        ),
      ),
    );
  }
}

// Dark colours of the new-session sheet (sage palette); light uses the scheme.
const _sheetDark = AppColors.surfaceContainerLow;
const _fieldDark = AppColors.surfaceContainerLowest;
const _violetDark = AppColors.sage;

bool _isDark(ColorScheme scheme) => scheme.brightness == Brightness.dark;

Color _violet(ColorScheme scheme) =>
    _isDark(scheme) ? _violetDark : scheme.primary;

/// Length, strict mode and apps, then "Start session".
class _NewSessionSheet extends GetView<FocusViewModel> {
  const _NewSessionSheet();

  static Future<void> show(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = _isDark(scheme);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: dark ? _sheetDark : scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        side: BorderSide(
          color: dark
              ? Colors.white.withValues(alpha: 0.12)
              : scheme.outlineVariant,
        ),
      ),
      builder: (_) => const _NewSessionSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = _isDark(scheme);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Obx(() {
        final minutes = controller.minutes.value;
        final apps = controller.visibleApps;
        final selected = controller.selected.toSet();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 44,
                height: 6,
                decoration: BoxDecoration(
                  color: dark ? AppColors.outline : scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'New focus session',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.surfaceContainerHigh,
                      foregroundColor: scheme.onSurfaceVariant,
                    ),
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    sliver: SliverList.list(
                      children: [
                        Center(
                          child: Text(
                            formatMinutes(minutes),
                            style: theme.textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: scheme.onSurface,
                              fontFeatures: AppTheme.tabularFigures,
                              shadows: dark
                                  ? [
                                      Shadow(
                                        color: Colors.white.withValues(
                                          alpha: 0.18,
                                        ),
                                        blurRadius: 25,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final p in FocusViewModel.presets)
                              _DurationChip(
                                minutes: p,
                                selected: minutes == p,
                                onTap: () => controller.minutes.value = p,
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 8,
                            activeTrackColor: _violet(scheme),
                            inactiveTrackColor: dark
                                ? AppColors.outlineVariant
                                : scheme.surfaceContainerHighest,
                            thumbColor: dark ? Colors.white : scheme.primary,
                            overlayColor: _violet(scheme)
                                .withValues(alpha: 0.3),
                            activeTickMarkColor: Colors.white.withValues(
                              alpha: 0.4,
                            ),
                            inactiveTickMarkColor: scheme.onSurface.withValues(
                              alpha: 0.2,
                            ),
                            tickMarkShape: const RoundSliderTickMarkShape(
                              tickMarkRadius: 1.5,
                            ),
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 12,
                              elevation: 4,
                            ),
                            valueIndicatorColor: _violet(scheme),
                          ),
                          child: Slider(
                            value: minutes.toDouble(),
                            min: FocusViewModel.minMinutes.toDouble(),
                            max: FocusViewModel.maxMinutes.toDouble(),
                            divisions:
                                (FocusViewModel.maxMinutes -
                                    FocusViewModel.minMinutes) ~/
                                5,
                            label: formatMinutes(minutes),
                            onChanged: (v) =>
                                controller.minutes.value = v.round(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        GlassCard(
                          padding: EdgeInsets.zero,
                          child: Material(
                            type: MaterialType.transparency,
                            child: SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              secondary: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _violet(scheme)
                                      .withValues(alpha: 0.12),
                                  border: Border.all(
                                    color: _violet(scheme)
                                        .withValues(alpha: 0.25),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.lock_outline,
                                  color: _violet(scheme),
                                ),
                              ),
                              title: Text(
                                'Strict mode',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: const Text(
                                "Once started, the session can't be stopped.",
                              ),
                              value: controller.strict.value,
                              onChanged: (v) => controller.strict.value = v,
                              activeThumbColor: Colors.white,
                              activeTrackColor: dark
                                  ? AppColors.green
                                  : scheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  text: 'Apps to block ',
                                  children: [
                                    TextSpan(
                                      text: '(${selected.length})',
                                      style: TextStyle(
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            if (apps.isNotEmpty)
                              TextButton(
                                onPressed: controller.toggleAllVisible,
                                child: Text(
                                  controller.allVisibleSelected
                                      ? 'Clear all'
                                      : 'Select all',
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: 'Search apps',
                            filled: true,
                            fillColor: dark
                                ? _fieldDark
                                : scheme.surfaceContainer,
                            border: _fieldBorder(
                              dark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : scheme.outlineVariant,
                            ),
                            enabledBorder: _fieldBorder(
                              dark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : scheme.outlineVariant,
                            ),
                            focusedBorder: _fieldBorder(
                              _violet(scheme),
                              width: 1.5,
                            ),
                          ),
                          onChanged: (v) => controller.query.value = v,
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList.separated(
                      itemCount: apps.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: scheme.onSurface.withValues(alpha: 0.06),
                      ),
                      itemBuilder: (context, i) {
                        final app = apps[i];
                        final picked = selected.contains(app.packageName);
                        return CheckboxListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          secondary: AppIcon(app.packageName),
                          title: Text(app.label),
                          subtitle: picked
                              ? const Text('Blocked during focus')
                              : null,
                          value: picked,
                          onChanged: (_) =>
                              controller.toggleApp(app.packageName),
                          activeColor: _violet(scheme),
                          checkColor: dark
                              ? AppColors.onSage
                              : scheme.onPrimary,
                          checkboxShape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          side: BorderSide(color: scheme.outline, width: 1.5),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            _StartSessionButton(
              onPressed: selected.isEmpty
                  ? null
                  : () async {
                      await controller.start();
                      if (context.mounted && controller.active.value != null) {
                        Navigator.pop(context);
                      }
                    },
            ),
          ],
        );
      }),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
}

/// Preset length: an emerald gradient pill with a check when selected.
class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.minutes,
    required this.selected,
    required this.onTap,
  });

  final int minutes;
  final bool selected;
  final VoidCallback onTap;

  static const _radius = BorderRadius.all(Radius.circular(14));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = _isDark(scheme);
    final emerald = dark
        ? const [AppColors.sage, AppColors.sageDeep]
        : const [Color(0xFF059669), Color(0xFF047857)];
    final foreground = selected
        ? (dark ? AppColors.onSage : Colors.white)
        : scheme.onSurfaceVariant;
    return Semantics(
      selected: selected,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: _radius,
          gradient: selected ? LinearGradient(colors: emerald) : null,
          color: selected
              ? null
              : (dark ? AppColors.surfaceContainer : scheme.surfaceContainer),
          border: Border.all(
            color: selected
                ? emerald.first.withValues(alpha: 0.4)
                : (dark
                      ? Colors.white.withValues(alpha: 0.06)
                      : scheme.outlineVariant),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: emerald.first.withValues(alpha: 0.45),
                    blurRadius: 20,
                    spreadRadius: -3,
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: _radius,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected) ...[
                      Icon(Icons.check, size: 16, color: foreground),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      formatMinutes(minutes),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pinned "Start session": a sage gradient with a soft glow (dark) or
/// indigo (light); a flat muted pill while no app is picked.
class _StartSessionButton extends StatelessWidget {
  const _StartSessionButton({required this.onPressed});

  final VoidCallback? onPressed;

  static const _radius = BorderRadius.all(Radius.circular(18));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = _isDark(scheme);
    final enabled = onPressed != null;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: _radius,
            gradient: enabled
                ? LinearGradient(
                    colors: dark
                        ? AppColors.accentGradient
                        : const [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                  )
                : null,
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: (dark ? AppColors.green : const Color(0xFFA78BFA))
                          .withValues(alpha: dark ? 0.45 : 0.3),
                      blurRadius: 25,
                      spreadRadius: -4,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: const RoundedRectangleBorder(borderRadius: _radius),
              backgroundColor: Colors.transparent,
              foregroundColor: dark ? AppColors.onSage : Colors.white,
              disabledBackgroundColor: scheme.surfaceContainerHigh,
              disabledForegroundColor: scheme.onSurfaceVariant,
              textStyle: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            onPressed: onPressed,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(enabled ? 'Start session' : 'Pick at least one app'),
          ),
        ),
      ),
    );
  }
}
