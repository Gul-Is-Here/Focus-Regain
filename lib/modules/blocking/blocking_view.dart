import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/utils/duration_format.dart';
import '../../app/widgets/app_icon.dart';
import '../../app/widgets/glass_card.dart';
import '../../app/widgets/message_view.dart';
import '../../data/models/app_category.dart';
import '../../data/models/blocking_rules.dart';
import '../../data/models/installed_app.dart';
import 'blocking_view_model.dart';

/// Neon mint from the blocking mockup (dark); deep emerald on white.
Color _mint(ColorScheme scheme) =>
    AppColors.pick(AppColors.mint, scheme.brightness);

/// Side padding that keeps the page at most 760 wide on tablets and desktop.
double _gutter(double width) => math.max(20, (width - 760) / 2);

class BlockingView extends GetView<BlockingViewModel> {
  const BlockingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AmbientBackground(
        topGlow: _mint(Theme.of(context).colorScheme),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) => Obx(() {
              final status = controller.status.value;
              final gutter = _gutter(constraints.maxWidth);
              final header = _Header(
                gutter: gutter,
                active: status == BlockingStatus.ready
                    ? !controller.rules.value.isEmpty
                    : null,
              );
              // Ready: the header scrolls with the list, so large text keeps room.
              if (status == BlockingStatus.ready) {
                return _RulesOverview(gutter: gutter, header: header);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  Expanded(
                    child: switch (status) {
                      BlockingStatus.loading => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      BlockingStatus.unsupported => const MessageView(
                        icon: Icons.phone_iphone,
                        text: 'Blocking on iPhone is coming in a later update.',
                      ),
                      BlockingStatus.unavailable => const MessageView(
                        icon: Icons.block,
                        text:
                            "This phone doesn't let apps cover other apps, "
                            "so blocking can't work here.",
                      ),
                      BlockingStatus.setup => const _SetupSteps(),
                      BlockingStatus.error ||
                      BlockingStatus.ready => MessageView(
                        icon: Icons.error_outline,
                        text: "Couldn't load your apps.",
                        action: TextButton(
                          onPressed: controller.refreshState,
                          child: const Text('Try again'),
                        ),
                      ),
                    },
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// "Blocking" with an Active / Off badge once the rules are loaded.
class _Header extends StatelessWidget {
  const _Header({required this.gutter, required this.active});

  final double gutter;

  /// Null hides the badge (rules not loaded yet).
  final bool? active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final on = active;
    final badgeColor = on == true ? _mint(scheme) : scheme.onSurfaceVariant;
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 4,
            children: [
              Text(
                'Blocking',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (on != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.1),
                    border: Border.all(
                      color: badgeColor.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    on ? 'ACTIVE' : 'OFF',
                    semanticsLabel: on ? 'Blocking is on' : 'Blocking is off',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: badgeColor,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Choose what to block, and when',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded square with a tinted icon, used across this screen.
class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.color, this.size = 40});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

/// Prominent disclosure + the two permissions blocking needs.
class _SetupSteps extends GetView<BlockingViewModel> {
  const _SetupSteps();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(
      () => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Set up blocking', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How blocking works',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'While blocking is on, Regain Focus checks which app is on '
                    'screen. If it is one you picked, a pause screen covers it.\n\n'
                    'This check happens only on your phone. Nothing about the '
                    'apps you use is sent anywhere.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _StepTile(
            number: 1,
            title: 'Usage access',
            subtitle: 'Lets Regain Focus see which app is open.',
            done: controller.hasUsageAccess.value,
            onAllow: controller.openUsageAccessSettings,
          ),
          _StepTile(
            number: 2,
            title: 'Display over other apps',
            subtitle: 'Lets the pause screen appear on top of a blocked app.',
            done: controller.hasOverlayPermission.value,
            onAllow: controller.openOverlaySettings,
          ),
          const SizedBox(height: 8),
          Text(
            'Each step opens Settings. Turn on Regain Focus there, then come back.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.onAllow,
  });

  final int number;
  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        child: done
            ? const Icon(Icons.check, semanticLabel: 'Done')
            : Text('$number'),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: done
          ? null
          : FilledButton.tonal(onPressed: onAllow, child: const Text('Allow')),
    );
  }
}

class _RulesOverview extends GetView<BlockingViewModel> {
  const _RulesOverview({required this.gutter, required this.header});

  final double gutter;
  final Widget header;

  /// Categories that get a one-tap "+ Block" instead of "Configure".
  static const _distracting = {
    AppCategory.social,
    AppCategory.video,
    AppCategory.games,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Obx(() {
      // Read here so this Obx also rebuilds the lazily built rows below.
      final rules = controller.rules.value;
      final apps = controller.visibleApps;
      final summaries = {
        for (final a in apps)
          a.packageName: controller.summaryFor(a.packageName),
      };

      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: header),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 0),
            sliver: SliverList.list(
              children: [
                _StatusCard(rules),
                if (!controller.batteryUnrestricted.value &&
                    !controller.batteryTipDismissed.value)
                  _TipCard(
                    icon: Icons.battery_charging_full,
                    title: 'Keep blocking running',
                    text:
                        'Some phones stop background apps to save battery. '
                        'Set Regain Focus to "Unrestricted" so your limits '
                        'keep working.',
                    action: 'Fix settings',
                    onAction: controller.openBatteryOptimizationSettings,
                    onDismiss: () =>
                        controller.batteryTipDismissed.value = true,
                  ),
                if (rules.dailyLimits.isNotEmpty &&
                    !controller.notificationsAllowed.value)
                  _TipCard(
                    icon: Icons.notifications_outlined,
                    title: 'Get a heads-up before a limit runs out',
                    text: 'Allow notifications to hear when 80% of a limit is used.',
                    action: 'Allow notifications',
                    onAction: controller.openNotificationSettings,
                  ),
                const SizedBox(height: 24),
                _SectionLabel('WHEN A BLOCKED APP OPENS'),
                const SizedBox(height: 10),
                _StyleSwitch(
                  value: rules.style,
                  onChanged: controller.setStyle,
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: CircleAvatar(
                        radius: 3,
                        backgroundColor: _mint(scheme),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        rules.style == BlockStyle.block
                            ? 'The app stays closed.'
                            : 'A short breathing pause first. After that you '
                                  'can choose to open the app for 5 minutes.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _SchedulesHeading(
                  onAdd: () => Get.toNamed(AppRoutes.scheduleEditor),
                ),
                const SizedBox(height: 12),
                if (rules.schedules.isEmpty)
                  GlassCard(
                    child: Text(
                      'Block apps at set times, like work hours or bedtime.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 560 ? 3 : 2;
                      const gap = 10.0;
                      final width =
                          (constraints.maxWidth - gap * (columns - 1)) /
                          columns;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final s in rules.schedules)
                            SizedBox(width: width, child: _ScheduleCard(s)),
                        ],
                      );
                    },
                  ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            'Installed apps',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${controller.apps.length} total',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontFeatures: AppTheme.tabularFigures,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${controller.restrictedCount} restricted',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: _mint(scheme),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search apps or categories',
                    filled: true,
                    fillColor: scheme.brightness == Brightness.dark
                        ? AppColors.surfaceContainerLowest
                        : scheme.surfaceContainer,
                    enabledBorder: _border(
                      scheme.brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.1)
                          : scheme.outlineVariant,
                    ),
                    border: _border(scheme.outlineVariant),
                    focusedBorder: _border(_mint(scheme), width: 1.5),
                  ),
                  onChanged: (v) => controller.query.value = v,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          if (apps.isEmpty)
            const SliverToBoxAdapter(
              child: MessageView(
                icon: Icons.search_off,
                text: 'No apps found.',
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 24),
              sliver: DecoratedSliver(
                decoration: GlassCard.decorationOf(scheme),
                sliver: SliverList.separated(
                  itemCount: apps.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: scheme.onSurface.withValues(alpha: 0.06),
                  ),
                  itemBuilder: (context, i) {
                    final app = apps[i];
                    final summary = summaries[app.packageName];
                    return _AppRow(
                      app: app,
                      summary: summary,
                      onOpen: () => showModalBottomSheet<void>(
                        context: context,
                        showDragHandle: true,
                        builder: (_) => _AppRulesSheet(app),
                      ),
                      onQuickBlock:
                          summary == null && _distracting.contains(app.category)
                          ? () => controller.setAlwaysBlocked(
                              app.packageName,
                              true,
                            )
                          : null,
                    );
                  },
                ),
              ),
            ),
        ],
      );
    });
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// "Nothing blocked yet", or a count of what is active.
class _StatusCard extends StatelessWidget {
  const _StatusCard(this.rules);

  final BlockingRules rules;

  static String _count(int n, String one) => '$n $one${n == 1 ? '' : 's'}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final on = !rules.isEmpty;
    final parts = [
      if (rules.alwaysBlocked.isNotEmpty)
        '${rules.alwaysBlocked.length} always blocked',
      if (rules.dailyLimits.isNotEmpty)
        _count(rules.dailyLimits.length, 'daily limit'),
      if (rules.schedules.isNotEmpty)
        _count(rules.schedules.length, 'schedule'),
    ];
    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBox(
            icon: on ? Icons.shield_outlined : Icons.block,
            color: on ? _mint(scheme) : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        on ? 'Blocking is on' : 'Nothing blocked yet',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    CircleAvatar(
                      radius: 4,
                      backgroundColor: on
                          ? _mint(scheme)
                          : scheme.outline.withValues(alpha: 0.6),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  on
                      ? '${parts.join(' · ')}. Tap an app below to change '
                            'its rules.'
                      : 'Tap an app below to block it, give it a daily '
                            'limit, or add it to a schedule.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
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

/// Mint-tinted card with an action button, e.g. the battery tip.
class _TipCard extends StatelessWidget {
  const _TipCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.action,
    required this.onAction,
    this.onDismiss,
  });

  final IconData icon;
  final String title;
  final String text;
  final String action;
  final VoidCallback onAction;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mint = _mint(scheme);
    final dark = scheme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: GlassCard.radius,
          gradient: LinearGradient(
            colors: [
              mint.withValues(alpha: dark ? 0.1 : 0.08),
              dark
                  ? AppColors.slate.withValues(alpha: 0.6)
                  : scheme.surfaceContainerLowest,
            ],
          ),
          border: Border.all(color: mint.withValues(alpha: 0.25)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBox(icon: icon, color: mint),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Recommended',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: mint,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      text,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: mint,
                            foregroundColor: dark
                                ? AppColors.onSage
                                : Colors.white,
                            minimumSize: const Size(0, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: onAction,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(child: Text(action)),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right, size: 18),
                            ],
                          ),
                        ),
                        if (onDismiss != null)
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: scheme.onSurfaceVariant,
                            ),
                            onPressed: onDismiss,
                            child: const Text('Dismiss'),
                          ),
                      ],
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

/// Two-way switch: Block or Mindful pause. The chosen side is a mint pill.
class _StyleSwitch extends StatelessWidget {
  const _StyleSwitch({required this.value, required this.onChanged});

  final BlockStyle value;
  final ValueChanged<BlockStyle> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark
            ? AppColors.surfaceContainerLowest
            : scheme.surfaceContainer,
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.1)
              : scheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          for (final (style, icon, label) in const [
            (BlockStyle.block, Icons.block, 'Block'),
            (BlockStyle.pause, Icons.self_improvement, 'Mindful pause'),
          ])
            Expanded(
              child: _Segment(
                icon: icon,
                label: label,
                selected: value == style,
                onTap: () => onChanged(style),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const _radius = BorderRadius.all(Radius.circular(14));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final mint = _mint(scheme);
    final foreground = selected
        ? (dark ? AppColors.onSage : Colors.white)
        : scheme.onSurfaceVariant;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: _radius,
          gradient: selected
              ? LinearGradient(
                  colors: dark
                      ? const [AppColors.sage, AppColors.sageDeep]
                      : [const Color(0xFF059669), mint],
                )
              : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: mint.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
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
                  horizontal: 8,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      selected ? Icons.check : icon,
                      size: 18,
                      color: foreground,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: foreground,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w500,
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

/// "Schedules" + "Add schedule"; the button drops below at large text sizes.
class _SchedulesHeading extends StatelessWidget {
  const _SchedulesHeading({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Schedules',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          'Automatic blocking at set times',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    final button = _AddScheduleButton(onPressed: onAdd);
    if (MediaQuery.textScalerOf(context).scale(1) > 1.3) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [title, const SizedBox(height: 8), button],
      );
    }
    return Row(
      children: [
        Expanded(child: title),
        const SizedBox(width: 8),
        button,
      ],
    );
  }
}

class _AddScheduleButton extends StatelessWidget {
  const _AddScheduleButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final indigo = scheme.brightness == Brightness.dark
        ? AppColors.sage
        : AppColors.indigo[1];
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: indigo,
        backgroundColor: indigo.withValues(alpha: 0.12),
        side: BorderSide(color: indigo.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Add schedule'),
    );
  }
}

/// One schedule as a small card: icon, time window, name, days and apps.
class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard(this.schedule);

  final BlockSchedule schedule;

  static const _dayLetters = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static String _days(Set<int> days) {
    if (days.length == 7) return 'Every day';
    if (days.length == 5 && days.containsAll([1, 2, 3, 4, 5])) {
      return 'Weekdays';
    }
    if (days.length == 2 && days.containsAll([6, 7])) return 'Weekends';
    return [for (final d in days.toList()..sort()) _dayLetters[d - 1]]
        .join(', ');
  }

  static String _time(BuildContext context, int minute) =>
      TimeOfDay(hour: minute ~/ 60, minute: minute % 60).format(context);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = schedule;
    // A window that ends "earlier" than it starts runs overnight.
    final overnight = s.endMinute <= s.startMinute;
    final color = AppColors.pick(
      overnight ? AppColors.amber : AppColors.indigo,
      scheme.brightness,
    );
    final apps = s.packages.length;
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => Get.toNamed(AppRoutes.scheduleEditor, arguments: s),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IconBox(
                  icon: overnight ? Icons.bedtime_outlined : Icons.work_outline,
                  color: color,
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${_time(context, s.startMinute)} – '
                  '${_time(context, s.endMinute)}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontFeatures: AppTheme.tabularFigures,
                  ),
                ),
                Text(
                  '${_days(s.days)} · $apps ${apps == 1 ? 'app' : 'apps'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// App icon, name, its rules (or "category · Unrestricted"), and Configure or a one-tap "+ Block".
class _AppRow extends StatelessWidget {
  const _AppRow({
    required this.app,
    required this.summary,
    required this.onOpen,
    required this.onQuickBlock,
  });

  final InstalledApp app;
  final String? summary;
  final VoidCallback onOpen;

  /// Null shows "Configure" instead.
  final VoidCallback? onQuickBlock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = summary ?? 'Unrestricted';
    final coral = AppColors.pick(AppColors.coral, scheme.brightness);
    final quick = onQuickBlock;
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          children: [
            AppIcon(app.packageName),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    summary != null || app.category == AppCategory.other
                        ? status
                        : '${app.category.label} · $status',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: summary == null
                          ? scheme.onSurfaceVariant
                          : _mint(scheme),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                foregroundColor: quick == null ? scheme.onSurface : coral,
                backgroundColor: (quick == null ? scheme.onSurface : coral)
                    .withValues(alpha: 0.06),
                side: BorderSide(
                  color: quick == null
                      ? scheme.outlineVariant
                      : coral.withValues(alpha: 0.4),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: quick ?? onOpen,
              child: Text(
                quick == null ? 'Configure' : '+ Block',
                semanticsLabel: quick == null
                    ? 'Configure ${app.label}'
                    : 'Block ${app.label}',
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _AppRulesSheet extends GetView<BlockingViewModel> {
  const _AppRulesSheet(this.app);

  final InstalledApp app;

  static const _limitChoices = [15, 30, 60, 120];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Obx(() {
        final rules = controller.rules.value;
        final limit = rules.dailyLimits[app.packageName];
        final choices = <int?>[
          null,
          if (kDebugMode) 1, // quick on-device test of the limit path
          ..._limitChoices,
          if (limit != null && !_limitChoices.contains(limit) && limit != 1)
            limit,
        ];
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppIcon(app.packageName),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(app.label, style: theme.textTheme.titleLarge),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Always block'),
                subtitle: const Text('Blocked all day, every day.'),
                value: rules.alwaysBlocked.contains(app.packageName),
                onChanged: (on) =>
                    controller.setAlwaysBlocked(app.packageName, on),
              ),
              const SizedBox(height: 8),
              Text('Daily limit', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                'Blocked for the rest of the day once the time is used up.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in choices)
                    ChoiceChip(
                      label: Text(
                        c == null
                            ? 'Off'
                            : c == 1
                            ? '1 min (test)'
                            : formatMinutes(c),
                      ),
                      selected: limit == c,
                      onSelected: (_) =>
                          controller.setDailyLimit(app.packageName, c),
                    ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }
}
