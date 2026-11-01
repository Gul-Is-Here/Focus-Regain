import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/utils/duration_format.dart';
import '../../app/widgets/app_icon.dart';
import '../../app/widgets/glass_card.dart';
import '../../data/models/app_category.dart';
import 'schedule_editor_view_model.dart';

Color _mint(ColorScheme scheme) =>
    AppColors.pick(AppColors.mint, scheme.brightness);

bool _isDark(ColorScheme scheme) => scheme.brightness == Brightness.dark;

/// Filled field look shared by the name and search inputs.
BoxDecoration _fieldDecoration(ColorScheme scheme) => BoxDecoration(
  color: _isDark(scheme)
      ? AppColors.surfaceContainerLowest
      : scheme.surfaceContainer,
  border: Border.all(
    color: _isDark(scheme)
        ? Colors.white.withValues(alpha: 0.09)
        : scheme.outlineVariant,
  ),
  borderRadius: BorderRadius.circular(16),
);

class ScheduleEditorView extends GetView<ScheduleEditorViewModel> {
  const ScheduleEditorView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: AmbientBackground(
        topGlow: _mint(scheme),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // At most 640 wide on tablets and desktop.
              final gutter = math.max(20.0, (constraints.maxWidth - 640) / 2);
              return Column(
                children: [
                  _Header(gutter: gutter),
                  Expanded(child: _Form(gutter: gutter)),
                  _SaveBar(gutter: gutter),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Round back button, centred title, and delete when editing.
class _Header extends GetView<ScheduleEditorViewModel> {
  const _Header({required this.gutter});

  final double gutter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final editing = controller.existing != null;
    final roundStyle = IconButton.styleFrom(
      backgroundColor: _isDark(scheme)
          ? Colors.white.withValues(alpha: 0.05)
          : scheme.surfaceContainerLowest,
      side: BorderSide(
        color: _isDark(scheme)
            ? Colors.white.withValues(alpha: 0.08)
            : scheme.outlineVariant,
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter - 4, 8, gutter - 4, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            style: roundStyle,
            icon: const Icon(Icons.arrow_back),
            onPressed: Get.back<void>,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  editing ? 'Edit schedule' : 'New schedule',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                // Decorative; dropped at large text sizes to save room.
                if (MediaQuery.textScalerOf(context).scale(1) <= 1.3)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(radius: 3, backgroundColor: _mint(scheme)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Blocks apps automatically',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: _mint(scheme),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (editing)
            IconButton(
              tooltip: 'Delete schedule',
              style: roundStyle,
              icon: Icon(Icons.delete_outline, color: scheme.error),
              onPressed: controller.delete,
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _Form extends GetView<ScheduleEditorViewModel> {
  const _Form({required this.gutter});

  final double gutter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Obx(() {
      final apps = controller.visibleApps;
      final selected = controller.packages.toSet();
      final days = controller.days.toSet();
      final start = controller.startMinute.value;
      final end = controller.endMinute.value;
      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 0),
            sliver: SliverList.list(
              children: [
                const _Label('SCHEDULE NAME'),
                const SizedBox(height: 8),
                _NameField(overnight: controller.isOvernight),
                const SizedBox(height: 28),
                // Wraps the shortcuts under the label at large text sizes.
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const _Label('REPEATS ON'),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _QuickDays(
                          label: 'Weekdays',
                          active: setEquals(
                            days,
                            ScheduleEditorViewModel.weekdays,
                          ),
                          onTap: () => controller.setDays(
                            ScheduleEditorViewModel.weekdays,
                          ),
                        ),
                        _QuickDays(
                          label: 'Every day',
                          active: setEquals(
                            days,
                            ScheduleEditorViewModel.everyDay,
                          ),
                          onTap: () => controller.setDays(
                            ScheduleEditorViewModel.everyDay,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var d = 1; d <= 7; d++) ...[
                      if (d > 1) const SizedBox(width: 6),
                      Expanded(
                        child: _DayPill(
                          day: d,
                          selected: days.contains(d),
                          onTap: () => controller.toggleDay(d),
                        ),
                      ),
                    ],
                  ],
                ),
                if (days.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Pick at least one day.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                Row(
                  children: [
                    const Expanded(child: _Label('ACTIVE WINDOW')),
                    if (start != end)
                      _Pill(
                        icon: Icons.hourglass_top,
                        text: formatMinutes(controller.durationMinutes),
                        color: AppColors.pick(
                          AppColors.indigo,
                          scheme.brightness,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _TimeCard(
                            label: 'STARTS',
                            icon: Icons.wb_sunny_outlined,
                            color: AppColors.pick(
                              AppColors.amber,
                              scheme.brightness,
                            ),
                            minute: start,
                            onPicked: (m) => controller.startMinute.value = m,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TimeCard(
                            label: 'ENDS',
                            icon: Icons.nightlight_outlined,
                            color: AppColors.pick(
                              AppColors.indigo,
                              scheme.brightness,
                            ),
                            minute: end,
                            note: controller.isOvernight && start != end
                                ? 'Next day'
                                : null,
                            onPicked: (m) => controller.endMinute.value = m,
                          ),
                        ),
                      ],
                    ),
                    // Decorative arrow between the two cards.
                    ExcludeSemantics(
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _isDark(scheme)
                              ? AppColors.surfaceContainerLowest
                              : scheme.surfaceContainerLowest,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: scheme.onSurface.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_forward,
                          size: 14,
                          color: _mint(scheme),
                        ),
                      ),
                    ),
                  ],
                ),
                if (start == end) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Start and end must be different.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const _Label('APPS TO RESTRICT'),
                          _Pill(
                            text: '${selected.length} selected',
                            color: selected.isEmpty
                                ? scheme.onSurfaceVariant
                                : _mint(scheme),
                          ),
                        ],
                      ),
                    ),
                    if (apps.isNotEmpty)
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.onSurfaceVariant,
                        ),
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
                DecoratedBox(
                  decoration: _fieldDecoration(scheme),
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search apps or categories',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    onChanged: (v) => controller.query.value = v,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 16),
            sliver: SliverList.separated(
              itemCount: apps.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final app = apps[i];
                final picked = selected.contains(app.packageName);
                final distracting = const {
                  AppCategory.social,
                  AppCategory.video,
                  AppCategory.games,
                }.contains(app.category);
                return GlassCard(
                  padding: EdgeInsets.zero,
                  child: Material(
                    type: MaterialType.transparency,
                    child: CheckboxListTile(
                      contentPadding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
                      secondary: AppIcon(app.packageName),
                      title: Text(
                        app.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: app.category == AppCategory.other
                          ? null
                          : Text.rich(
                              TextSpan(
                                text: app.category.label,
                                children: [
                                  if (distracting)
                                    TextSpan(
                                      text: ' · Often distracting',
                                      style: TextStyle(
                                        color: AppColors.pick(
                                          AppColors.coral,
                                          scheme.brightness,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                      value: picked,
                      onChanged: (_) => controller.toggleApp(app.packageName),
                      activeColor: _mint(scheme),
                      checkColor: _isDark(scheme)
                          ? AppColors.onSage
                          : Colors.white,
                      checkboxShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      side: BorderSide(color: scheme.outline, width: 1.5),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

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
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// Small tinted pill: the duration and the "N selected" count.
class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontFeatures: AppTheme.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

/// Name input in a card with an icon and a clear button.
class _NameField extends StatefulWidget {
  const _NameField({required this.overnight});

  final bool overnight;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  final _vm = Get.find<ScheduleEditorViewModel>();
  late final _text = TextEditingController(text: _vm.name.value);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mint = _mint(scheme);
    return DecoratedBox(
      decoration: _fieldDecoration(scheme),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: mint.withValues(alpha: 0.12),
                border: Border.all(color: mint.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                widget.overnight ? Icons.bedtime_outlined : Icons.work_outline,
                size: 18,
                color: mint,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _text,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  hintText: 'e.g. Deep work, Bedtime',
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (v) {
                  _vm.name.value = v;
                  setState(() {}); // shows / hides the clear button
                },
              ),
            ),
            if (_text.text.isNotEmpty)
              IconButton(
                tooltip: 'Clear name',
                icon: Icon(
                  Icons.cancel,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
                onPressed: () {
                  _text.clear();
                  _vm.name.value = '';
                  setState(() {});
                },
              )
            else
              const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

class _QuickDays extends StatelessWidget {
  const _QuickDays({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: active ? _mint(scheme) : scheme.onSurfaceVariant,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        textStyle: Theme.of(context).textTheme.labelMedium
            ?.copyWith(fontWeight: active ? FontWeight.w800 : FontWeight.w500),
      ),
      onPressed: onTap,
      child: Text(label),
    );
  }
}

/// One weekday: a mint gradient pill with a check when on, glass when off.
class _DayPill extends StatelessWidget {
  const _DayPill({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final int day;
  final bool selected;
  final VoidCallback onTap;

  static const _short = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _full = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _radius = BorderRadius.all(Radius.circular(16));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = _isDark(scheme);
    final mint = _mint(scheme);
    final foreground = selected
        ? (dark ? AppColors.onSage : Colors.white)
        : scheme.onSurfaceVariant;
    return Semantics(
      label: _full[day - 1],
      button: true,
      selected: selected,
      onTap: onTap,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: selected
            ? BoxDecoration(
                borderRadius: _radius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: dark
                      ? const [AppColors.sage, AppColors.sageDeep]
                      : [const Color(0xFF059669), mint],
                ),
                boxShadow: [
                  BoxShadow(
                    color: mint.withValues(alpha: 0.3),
                    blurRadius: 18,
                    spreadRadius: -4,
                  ),
                ],
              )
            : GlassCard.decorationOf(scheme)
                  .copyWith(borderRadius: _radius, boxShadow: const []),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: _radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  SizedBox(
                    height: 14,
                    child: selected
                        ? Icon(Icons.check, size: 14, color: foreground)
                        : Center(
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: scheme.outline),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 6),
                  // Seven pills share one row, so long labels shrink to fit.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _short[day - 1],
                      style: theme.textTheme.labelMedium?.copyWith(
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
    );
  }
}

/// Start or end time: tap to pick. Big digits with a small AM/PM.
class _TimeCard extends StatelessWidget {
  const _TimeCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.minute,
    required this.onPicked,
    this.note,
  });

  final String label;
  final IconData icon;
  final Color color;
  final int minute;
  final ValueChanged<int> onPicked;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final time = TimeOfDay(hour: minute ~/ 60, minute: minute % 60);
    final formatted = time.format(context);
    // "9:00 AM" → digits + period; 24-hour formats have no period.
    final split = formatted.lastIndexOf(' ');
    final digits = split < 0 ? formatted : formatted.substring(0, split);
    final period = split < 0 ? '' : formatted.substring(split + 1);
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: time,
            );
            if (picked != null) onPicked(picked.hour * 60 + picked.minute);
          },
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 15, color: color),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.expand_more,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        text: digits,
                        children: [
                          if (period.isNotEmpty)
                            TextSpan(
                              text: ' $period',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      semanticsLabel: '$label ${formatted.toLowerCase()}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontFeatures: AppTheme.tabularFigures,
                      ),
                    ),
                    // Always one line, so both cards keep the same height.
                    Text(
                      note ?? '',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0),
                        color.withValues(alpha: 0.45),
                        color.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pinned "Save schedule": mint gradient with a glow, flat while not ready.
class _SaveBar extends GetView<ScheduleEditorViewModel> {
  const _SaveBar({required this.gutter});

  final double gutter;

  static const _radius = BorderRadius.all(Radius.circular(18));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = _isDark(scheme);
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 12),
      child: Obx(() {
        final enabled = controller.canSave;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: _radius,
            gradient: enabled
                ? LinearGradient(
                    colors: dark
                        ? AppColors.accentGradient
                        : const [Color(0xFF059669), Color(0xFF047857)],
                  )
                : null,
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: _mint(scheme).withValues(alpha: 0.35),
                      blurRadius: 24,
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
            onPressed: enabled ? controller.save : null,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Save schedule'),
          ),
        );
      }),
    );
  }
}
