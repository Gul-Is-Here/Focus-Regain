import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/utils/duration_format.dart';
import '../../app/widgets/app_icon.dart';
import '../../app/widgets/glass_card.dart';
import '../../app/widgets/message_view.dart';
import '../../app/widgets/progress_ring.dart';
import '../../app/widgets/shimmer.dart';
import '../../data/models/app_category.dart';
import '../../data/models/app_usage.dart';
import '../../data/models/daily_usage.dart';
import '../focus/focus_view_model.dart';
import '../shell/shell_view_model.dart';
import 'dashboard_view_model.dart';

/// Widths where the layout changes.
const _twoColumnWidth = 840.0;
const _tabletWidth = 600.0;
const _maxContentWidth = 1200.0;

double _gutter(double width) => width >= _tabletWidth ? 24 : 16;

class DashboardView extends GetView<DashboardViewModel> {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      body: Obx(() {
        final status = controller.status.value;
        final over = status == DashboardStatus.ready && controller.overTarget;
        return AmbientBackground(
          topGlow: over
              ? AppColors.pick(AppColors.coral, brightness)
              : AppColors.pick(AppColors.indigo, brightness),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Thin bar while new numbers load over the ones already shown.
                SizedBox(
                  height: 2,
                  child: controller.refreshing.value
                      ? const LinearProgressIndicator(minHeight: 2)
                      : null,
                ),
                const _Header(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: reduceMotion(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 250),
                    child: KeyedSubtree(
                      key: ValueKey(status),
                      child: switch (status) {
                        DashboardStatus.loading => const _DashboardSkeleton(),
                        DashboardStatus.unsupported => const MessageView(
                          icon: Icons.phone_iphone,
                          text:
                              'Screen-time data on iPhone is coming in a '
                              'later update.',
                        ),
                        DashboardStatus.needsAccess =>
                          const _UsageAccessPrompt(),
                        DashboardStatus.error => MessageView(
                          icon: Icons.cloud_off_outlined,
                          text:
                              "Couldn't read your screen time. Check that "
                              'usage access is still on, then try again.',
                          action: Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: FilledButton.tonalIcon(
                              onPressed: controller.refreshUsage,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Try again'),
                            ),
                          ),
                        ),
                        DashboardStatus.ready => const _UsageOverview(),
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// Big "Today" title, a status dot, the date and the refresh button.
class _Header extends GetView<DashboardViewModel> {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    return Padding(
      padding: EdgeInsets.fromLTRB(_gutter(width), 16, _gutter(width), 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: Obx(() {
            final ready = controller.status.value == DashboardStatus.ready;
            final over = ready && controller.overTarget;
            return Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Today',
                              style: theme.textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusDot(
                            color: over
                                ? AppColors.pick(
                                    AppColors.coral,
                                    theme.brightness,
                                  )
                                : scheme.secondary,
                            pulsing: controller.refreshing.value,
                          ),
                        ],
                      ),
                      Text(
                        MaterialLocalizations.of(context)
                            .formatFullDate(DateTime.now()),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (ready)
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: controller.refreshing.value
                        ? null
                        : controller.refreshUsage,
                    style: IconButton.styleFrom(
                      fixedSize: const Size(48, 48),
                      backgroundColor: dark
                          ? scheme.surfaceContainerLow
                          : scheme.surfaceContainerLowest,
                      foregroundColor: scheme.onSurfaceVariant,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: dark
                              ? Colors.white.withValues(alpha: 0.08)
                              : scheme.outlineVariant,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.sync),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

/// Small dot next to the title: coral when over target, mint when on track.
/// It pulses only while a refresh runs, and never with reduced motion.
class _StatusDot extends StatefulWidget {
  const _StatusDot({required this.color, required this.pulsing});

  final Color color;
  final bool pulsing;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_StatusDot old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.pulsing && !reduceMotion(context)) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true, min: 0.3, max: 1);
      }
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _controller,
    child: Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    ),
  );
}

/// One column on phones; two columns from [_twoColumnWidth], centred and
/// capped at [_maxContentWidth].
class _ResponsivePage extends StatelessWidget {
  const _ResponsivePage({required this.left, required this.right});

  final List<Widget> left;
  final List<Widget> right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final gutter = _gutter(width);
        final content = width >= _twoColumnWidth
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Column(children: left)),
                  SizedBox(width: gutter),
                  Expanded(child: Column(children: right)),
                ],
              )
            : Column(children: [...left, ...right]);
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                child: content,
              ),
            ),
          ],
        );
      },
    );
  }
}

const _gap = SizedBox(height: 16);

class _UsageOverview extends GetView<DashboardViewModel> {
  const _UsageOverview();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.refreshUsage,
      child: const _ResponsivePage(
        left: [
          _RefreshFailedBanner(),
          _TodayRing(),
          SizedBox(height: 24),
          _StatusCard(),
          _gap,
          _FocusTodayCard(),
          _gap,
          _Actions(),
          _gap,
          _MetricTiles(),
          _gap,
        ],
        right: [_CategoriesCard(), _gap, _WeekChartCard()],
      ),
    );
  }
}

class _RefreshFailedBanner extends GetView<DashboardViewModel> {
  const _RefreshFailedBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      if (!controller.refreshFailed.value) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        // A plain Row, not a ListTile: ListTile under the card's
        // IntrinsicHeight reports too small a height and its button
        // ends up outside the tappable area.
        child: GlassCard(
          accent: AppColors.pick(AppColors.coral, theme.brightness),
          child: Row(
            children: [
              const Icon(Icons.sync_problem_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Couldn't update", style: theme.textTheme.titleSmall),
                    Text(
                      'Showing the last numbers we had.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: controller.refreshUsage,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// The key number: today's total against the daily target.
class _TodayRing extends GetView<DashboardViewModel> {
  const _TodayRing();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final b = theme.brightness;
    return Obx(() {
      final total = controller.total.inMinutes;
      final target = controller.targetMinutes.value;
      final over = controller.overTarget;
      final pillColor = over
          ? AppColors.pick(AppColors.coral, b)
          : AppColors.pick(AppColors.emerald, b);
      return Center(
        child: ProgressRing(
          progress: controller.targetProgress,
          size: 240,
          strokeWidth: 17,
          colors: over
              ? [
                  AppColors.pick(AppColors.coralDeep, b),
                  AppColors.pick(AppColors.coral, b),
                  AppColors.pick(AppColors.coralSoft, b),
                ]
              : b == Brightness.dark
              ? AppColors.accentGradient
              : [
                  AppColors.pick(AppColors.indigo, b),
                  AppColors.pick(AppColors.violet, b),
                ],
          semanticsLabel: 'Daily target',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TOTAL TODAY',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              _BigDuration(minutes: total),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: pillColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: pillColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      over ? Icons.arrow_circle_down : Icons.check_circle,
                      size: 14,
                      color: pillColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      over
                          ? '${formatMinutes(total - target)} over target'
                          : '${formatMinutes(target - total)} left',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: pillColor,
                        fontWeight: FontWeight.w600,
                      ),
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

/// "17 h 59 min" with large numbers and smaller units.
class _BigDuration extends StatelessWidget {
  const _BigDuration({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = formatMinutes(minutes);
    final number = theme.textTheme.displaySmall?.copyWith(
      fontWeight: FontWeight.w800,
      color: theme.colorScheme.onSurface,
      fontFeatures: AppTheme.tabularFigures,
    );
    final unit = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w500,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final parts = text.split(' ');
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < parts.length; i++)
            TextSpan(
              text: i == 0 ? parts[i] : ' ${parts[i]}',
              style: int.tryParse(parts[i]) == null ? unit : number,
            ),
        ],
      ),
      semanticsLabel: text,
    );
  }
}

/// Over target: amber "past your target"; otherwise an emerald "on track".
class _StatusCard extends GetView<DashboardViewModel> {
  const _StatusCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = theme.brightness;
    return Obx(() {
      final over = controller.overTarget;
      final accent = over
          ? AppColors.pick(AppColors.amber, b)
          : AppColors.pick(AppColors.emerald, b);
      return GlassCard(
        accent: accent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                over ? Icons.warning_amber_rounded : Icons.spa_outlined,
                size: 22,
                color: accent,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    over ? 'Past your target' : 'On track',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    over
                        ? 'A focus session can help you disconnect and '
                              'reclaim mindful energy.'
                        : '${formatMinutes(controller.minutesLeft)} left '
                              'before you reach your '
                              '${formatMinutes(controller.targetMinutes.value)} '
                              'target.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Primary action (start focusing) and an easy-to-find secondary one.
/// Today's focus time; while a session runs, a live card with its start time,
/// elapsed time and today's total. Reads the Focus tab's view model, so both
/// screens show the same numbers from one source.
class _FocusTodayCard extends StatelessWidget {
  const _FocusTodayCard();

  @override
  Widget build(BuildContext context) {
    final focus = Get.find<FocusViewModel>();
    // Rebuilds only when a session starts or ends; the counters below have
    // their own Obx that follows the 1-second clock.
    return Obx(() {
      if (focus.status.value
          case FocusStatus.unsupported || FocusStatus.unavailable) {
        return const SizedBox.shrink();
      }
      final session = focus.active.value;
      return session == null
          ? _FocusIdle(focus: focus)
          : _FocusLive(focus: focus, startedAt: session.startedAt);
    });
  }
}

class _FocusIdle extends StatelessWidget {
  const _FocusIdle({required this.focus});

  final FocusViewModel focus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final violet = AppColors.pick(AppColors.violet, scheme.brightness);
    return GlassCard(
      child: Row(
        children: [
          _IconBadge(icon: Icons.timer_outlined, color: violet),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total focus time today',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Obx(
                  () => Text(
                    formatHms(focus.focusedToday),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: AppTheme.tabularFigures,
                    ),
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

class _FocusLive extends StatelessWidget {
  const _FocusLive({required this.focus, required this.startedAt});

  final FocusViewModel focus;
  final DateTime startedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final b = scheme.brightness;
    final mint = AppColors.pick(AppColors.mint, b);
    final violet = AppColors.pick(AppColors.violet, b);
    // Local time; the date is added when the session began on another day.
    final now = DateTime.now();
    final sameDay =
        startedAt.year == now.year &&
        startedAt.month == now.month &&
        startedAt.day == now.day;
    final started = [
      if (!sameDay)
        MaterialLocalizations.of(context).formatShortMonthDay(startedAt),
      TimeOfDay.fromDateTime(startedAt).format(context),
    ].join(', ');
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return GlassCard(
      accent: mint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 4, backgroundColor: mint),
                  const SizedBox(width: 8),
                  Text(
                    'FOCUS SESSION · LIVE',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: mint,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              Text('Started $started', style: muted),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _IconBadge(icon: Icons.timelapse, color: violet),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Obx(
                      () => Text(
                        formatHms(focus.elapsed),
                        semanticsLabel: 'Elapsed ${formatHms(focus.elapsed)}',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontFeatures: AppTheme.tabularFigures,
                        ),
                      ),
                    ),
                    Text('elapsed', style: muted),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: scheme.onSurface.withValues(alpha: 0.08)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total focus time today',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Obx(
                () => Text(
                  formatHms(focus.focusedToday),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: AppTheme.tabularFigures,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              // Focus is the second tab; stop and strict mode live there.
              onPressed: () => Get.find<ShellViewModel>().changeTab(1),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Open session'),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions();

  @override
  Widget build(BuildContext context) {
    final shell = Get.find<ShellViewModel>();
    final focus = Get.find<FocusViewModel>();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hidden while a session runs: only one at a time, and the live card
        // above already links to it.
        Obx(
          () => focus.active.value != null
              ? const SizedBox.shrink()
              // Focus is the second tab.
              : _GradientButton(
                  icon: Icons.bolt,
                  label: 'Start a focus session',
                  onPressed: () => shell.changeTab(1),
                ),
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton.icon(
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: scheme.onSurfaceVariant,
            ),
            // Blocking is the third tab.
            onPressed: () => shell.changeTab(2),
            icon: const Icon(Icons.verified_user_outlined, size: 18),
            label: const Text('Manage blocked apps and limits'),
          ),
        ),
      ],
    );
  }
}

/// Violet-to-indigo button with a soft glow. Ink gives hover, focus and
/// pressed feedback; white text keeps 5:1+ contrast on every stop.
class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  static const _radius = BorderRadius.all(Radius.circular(16));

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Dark: sage to green with dark text (5:1+ under the label).
    final foreground = dark ? AppColors.onSage : Colors.white;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: _radius,
        boxShadow: [
          BoxShadow(
            color: (dark ? AppColors.green : const Color(0xFFA855F7))
                .withValues(alpha: 0.4),
            blurRadius: 25,
            spreadRadius: -4,
            offset: const Offset(0, 8),
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
                  : const [
                      Color(0xFF7C3AED),
                      Color(0xFF9333EA),
                      Color(0xFF4F46E5),
                    ],
            ),
          ),
          child: InkWell(
            borderRadius: _radius,
            onTap: onPressed,
            hoverColor: Colors.white.withValues(alpha: 0.06),
            focusColor: Colors.white.withValues(alpha: 0.16),
            splashColor: Colors.white.withValues(alpha: 0.12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      color: dark ? foreground : const Color(0xFFE9D5FF),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: foreground,
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
    );
  }
}

/// Streak and daily average, side by side.
class _MetricTiles extends GetView<DashboardViewModel> {
  const _MetricTiles();

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Obx(() {
      final target = controller.targetMinutes.value;
      final streak = controller.streak.value;
      final average = controller.recentAverage;
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _MetricTile(
                icon: Icons.local_fire_department,
                color: AppColors.pick(AppColors.emerald, b),
                tag: 'STREAK',
                value: '$streak ${streak == 1 ? 'day' : 'days'}',
                caption: streak == 0
                    ? 'Stay under ${formatMinutes(target)} to start one'
                    : 'In a row at or under target',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricTile(
                icon: Icons.trending_up,
                color: AppColors.pick(AppColors.blue, b),
                tag: 'PAST 6D',
                value: average == null ? '–' : formatMinutes(average),
                caption: average == null
                    ? 'Not enough data yet'
                    : 'Daily rolling average',
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.color,
    required this.tag,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final Color color;
  final String tag;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return MergeSemantics(
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 8),
                // Top-right like the mockup; wraps rather than overflows.
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tag,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: AppTheme.tabularFigures,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              caption,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bar colours per app category.
const _categoryGradients = {
  AppCategory.social: [Color(0xFFF43F5E), Color(0xFFEC4899)],
  AppCategory.video: [Color(0xFFA855F7), Color(0xFF6366F1)],
  AppCategory.games: [Color(0xFFF59E0B), Color(0xFFF97316)],
  AppCategory.audio: [Color(0xFF10B981), Color(0xFF14B8A6)],
  AppCategory.images: [Color(0xFFD946EF), Color(0xFFF472B6)],
  AppCategory.news: [Color(0xFF64748B), Color(0xFF94A3B8)],
  AppCategory.maps: [Color(0xFF22C55E), Color(0xFF84CC16)],
  AppCategory.productivity: [Color(0xFF3B82F6), Color(0xFF22D3EE)],
  AppCategory.accessibility: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
  AppCategory.other: [Color(0xFF6B7280), Color(0xFF9CA3AF)],
};

class _CategoriesCard extends GetView<DashboardViewModel> {
  const _CategoriesCard();

  static const _shown = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Obx(() {
      final categories = controller.categories.take(_shown).toList();
      final apps = controller.listedApps.length;
      return GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'MOST USED CATEGORIES',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                if (apps > 0)
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 40),
                      foregroundColor: AppColors.pick(
                        AppColors.indigo,
                        theme.brightness,
                      ),
                    ),
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (_) => const _AppsSheet(),
                    ),
                    child: Text(
                      'Details',
                      semanticsLabel: 'Details: all $apps apps used today',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (categories.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_empty, color: scheme.outline),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No app usage yet today. Apps you open will show up '
                        'here by category.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            for (final c in categories)
              _ShareBar(
                label: c.category.label,
                time: c.time,
                share: controller.shareOfTime(c.time),
                colors: _categoryGradients[c.category]!,
              ),
          ],
        ),
      );
    });
  }
}

/// Label, time and a gradient bar for the share of today.
class _ShareBar extends StatelessWidget {
  const _ShareBar({
    required this.label,
    required this.time,
    required this.share,
    required this.colors,
  });

  final String label;
  final Duration time;
  final double share;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final minutes = formatMinutes(time.inMinutes);
    return Semantics(
      label: '$label, $minutes, ${(share * 100).round()}% of today',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  minutes,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontFeatures: AppTheme.tabularFigures,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: share.clamp(0, 1)),
                duration: reduceMotion(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => FractionallySizedBox(
                  widthFactor: value,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: colors),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Every app used today, opened from "Details".
class _AppsSheet extends GetView<DashboardViewModel> {
  const _AppsSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Obx(() {
        final apps = controller.listedApps;
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Apps today', style: theme.textTheme.titleLarge),
                ),
                Text(
                  '${apps.length} ${apps.length == 1 ? 'app' : 'apps'}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final app in apps)
              _AppRow(app: app, share: controller.shareOf(app)),
          ],
        );
      }),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({required this.app, required this.share});

  final AppUsage app;
  final double share;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final time = formatMinutes(app.foreground.inMinutes);
    final percent = (share * 100).round();
    return Semantics(
      label: '${app.label}, $time, $percent% of today',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            AppIcon(app.packageName),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) => Row(
                      children: [
                        Expanded(
                          child: Text(
                            app.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Right-aligned; may use up to half the row and wraps
                        // beyond that at very large text sizes.
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth / 2,
                          ),
                          child: Text(
                            time,
                            textAlign: TextAlign.end,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontFeatures: AppTheme.tabularFigures,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    app.category.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: share,
                      minHeight: 6,
                      color: scheme.primary,
                      backgroundColor: scheme.surfaceContainerHigh,
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

class _WeekChartCard extends GetView<DashboardViewModel> {
  const _WeekChartCard();

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) => Obx(() => _build(context));

  Widget _build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final b = theme.brightness;
    final over = AppColors.pick(AppColors.coral, b);
    final accent = AppColors.pick(AppColors.indigo, b);
    final week = controller.week;
    final target = controller.targetMinutes.value;
    final top = math.max(
      target,
      week.fold(0, (m, d) => math.max(m, d.minutes)),
    );

    String label(int i) =>
        i == week.length - 1 ? 'Today' : _weekdays[week[i].day.weekday - 1];

    Color barColor(int i, DailyUsage d) {
      if (d.minutes > target) return over;
      return i == week.length - 1 ? accent : accent.withValues(alpha: 0.4);
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LAST 7 DAYS',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _Legend(
                swatch: Container(width: 16, height: 2, color: scheme.outline),
                text: 'Target ${formatMinutes(target)}',
              ),
              _Legend(
                swatch: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: over,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                text: 'Over target',
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: Semantics(
              label:
                  'Last 7 days: ${[for (var i = 0; i < week.length; i++) '${label(i)} ${formatMinutes(week[i].minutes)}'].join(', ')}',
              excludeSemantics: true,
              child: BarChart(
                duration: reduceMotion(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                BarChartData(
                  maxY: top * 1.15,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: math.max(60, top / 3).toDouble(),
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) => Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            label(value.toInt()),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: value.toInt() == week.length - 1
                                  ? FontWeight.w700
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: target.toDouble(),
                        color: scheme.outline,
                        strokeWidth: 1.5,
                        dashArray: const [5, 4],
                      ),
                    ],
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => scheme.inverseSurface,
                      getTooltipItem: (_, _, rod, _) => BarTooltipItem(
                        formatMinutes(rod.toY.toInt()),
                        TextStyle(
                          color: scheme.onInverseSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < week.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: week[i].minutes.toDouble(),
                            width: 18,
                            color: barColor(i, week[i]),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (!controller.hasHistory) ...[
            const SizedBox(height: 8),
            Text(
              'Past days fill in as Regain Focus collects your history.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.swatch, required this.text});

  final Widget swatch;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        const SizedBox(width: 6),
        Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _UsageAccessPrompt extends GetView<DashboardViewModel> {
  const _UsageAccessPrompt();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.query_stats,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Allow usage access',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'To show how long you spend in each app, Regain Focus '
                    'needs Usage access. Android asks for this in Settings, '
                    'not in a pop-up.\n\nYour usage data stays on this phone.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'In Settings, find Regain Focus in the list, turn on '
                    '"Permit usage access", then come back.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _GradientButton(
                    icon: Icons.settings_outlined,
                    label: 'Open settings',
                    onPressed: controller.openUsageAccessSettings,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Placeholder shapes in the same layout as [_UsageOverview].
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget card(double height) => SkeletonBox(height: height, radius: 20);
    return Shimmer(
      child: _ResponsivePage(
        left: [
          const Center(
            child: SkeletonBox(width: 240, height: 240, radius: 120),
          ),
          const SizedBox(height: 24),
          card(88),
          _gap,
          const SkeletonBox(height: 56, radius: 16),
          _gap,
          Row(
            children: [
              Expanded(child: card(130)),
              const SizedBox(width: 12),
              Expanded(child: card(130)),
            ],
          ),
          _gap,
        ],
        right: [card(170), _gap, card(250)],
      ),
    );
  }
}
