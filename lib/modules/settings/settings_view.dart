import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/utils/duration_format.dart';
import '../../app/widgets/glass_card.dart';
import '../../data/models/notification_prefs.dart';
import '../../data/repositories/push_messaging.dart';
import '../notifications/notification_center.dart';
import 'settings_view_model.dart';

class SettingsView extends GetView<SettingsViewModel> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final b = scheme.brightness;
    return Scaffold(
      body: AmbientBackground(
        topGlow: AppColors.pick(AppColors.mint, b),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // At most 760 wide on tablets and desktop.
              final gutter = math.max(20.0, (constraints.maxWidth - 760) / 2);
              return Obx(
                () => ListView(
                  padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 24),
                  children: [
                    Text(
                      'Settings',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Your targets, reminders and how the app looks',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const _SectionTitle('GOALS'),
                    _Panel(
                      children: [
                        _Row(
                          icon: Icons.flag_outlined,
                          color: AppColors.pick(AppColors.indigo, b),
                          title: 'Daily screen-time target',
                          subtitle: 'Days under it count toward your streak',
                          value: formatMinutes(
                            controller.dailyTargetMinutes.value,
                          ),
                          onTap: () => _editMinutes(
                            context,
                            title: 'Daily target',
                            current: controller.dailyTargetMinutes.value,
                            min: SettingsViewModel.minTargetMinutes,
                            max: SettingsViewModel.maxTargetMinutes,
                            step: SettingsViewModel.targetStepMinutes,
                            onSave: controller.setDailyTarget,
                          ),
                        ),
                        _Row(
                          icon: Icons.bolt,
                          color: AppColors.pick(AppColors.amber, b),
                          title: 'Daily focus goal',
                          subtitle: 'Focus time to aim for each day',
                          value: formatMinutes(
                            controller.focusGoalMinutes.value,
                          ),
                          onTap: () => _editMinutes(
                            context,
                            title: 'Daily focus goal',
                            current: controller.focusGoalMinutes.value,
                            min: SettingsViewModel.minFocusGoalMinutes,
                            max: SettingsViewModel.maxFocusGoalMinutes,
                            step: SettingsViewModel.focusGoalStepMinutes,
                            onSave: controller.setFocusGoal,
                          ),
                        ),
                      ],
                    ),
                    if (controller.isSupported) ...[
                      _SectionTitle(
                        'NOTIFICATIONS',
                        status: controller.notificationsAllowed.value
                            ? ('Allowed', AppColors.pick(AppColors.mint, b))
                            : ('Off', scheme.onSurfaceVariant),
                      ),
                      _Panel(
                        children: [
                          SwitchListTile(
                            contentPadding: _Row.padding,
                            secondary: _IconBox(
                              icon: Icons.auto_awesome,
                              color: AppColors.pick(AppColors.violet, b),
                            ),
                            title: Text(
                              'Weekly recap',
                              style: _Row.titleStyle(theme),
                            ),
                            subtitle: Text(
                              'Monday morning: last week’s screen time and how '
                              'many days you stayed on target.',
                              style: _Row.subtitleStyle(theme),
                            ),
                            value: controller.weeklyRecap.value,
                            onChanged: controller.setWeeklyRecap,
                            activeThumbColor: Colors.white,
                            activeTrackColor: AppColors.pick(
                              AppColors.indigo,
                              b,
                            ),
                          ),
                          if (!controller.notificationsAllowed.value)
                            ListTile(
                              contentPadding: _Row.padding,
                              leading: _IconBox(
                                icon: Icons.notifications_off_outlined,
                                color: AppColors.pick(AppColors.blue, b),
                              ),
                              title: Text(
                                'Notifications are off',
                                style: _Row.titleStyle(theme),
                              ),
                              subtitle: Text(
                                'Needed for the recap, limit warnings and '
                                'focus reminders.',
                                style: _Row.subtitleStyle(theme),
                              ),
                              trailing: FilledButton.tonal(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 40),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                ),
                                onPressed: controller.openNotificationSettings,
                                child: const Text('Allow'),
                              ),
                            ),
                        ],
                      ),
                    ],
                    _RemindersSection(
                      reminders: controller.reminders,
                      onOpenSettings: controller.isSupported
                          ? controller.openNotificationSettings
                          : null,
                    ),
                    const _SectionTitle('APPEARANCE'),
                    _ThemeSwitch(
                      value: controller.themeMode.value,
                      onChanged: controller.setThemeMode,
                    ),
                    const _SectionTitle('ACCOUNT'),
                    _Panel(
                      children: [
                        _Row(
                          icon: Icons.logout_rounded,
                          color: AppColors.pick(AppColors.coral, b),
                          title: 'Sign out',
                          subtitle:
                              controller.account?.email ??
                              controller.account?.name,
                          onTap: () => _confirmSignOut(context),
                        ),
                      ],
                    ),
                    const _SectionTitle('ABOUT'),
                    _Panel(
                      children: [
                        _Row(
                          icon: Icons.shield_outlined,
                          color: AppColors.pick(AppColors.emerald, b),
                          title: 'Privacy',
                          subtitle:
                              'What Focus Regain reads, and where it stays',
                          onTap: () => _showPrivacy(context),
                        ),
                        _Row(
                          icon: Icons.description_outlined,
                          color: scheme.onSurfaceVariant,
                          title: 'Open-source licences',
                          onTap: () => showLicensePage(
                            context: context,
                            applicationName: 'Focus Regain',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your screen-time history and settings stay on this phone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (yes ?? false) await controller.signOut();
  }

  void _showPrivacy(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Privacy', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              for (final (icon, text) in const [
                (
                  Icons.phone_android,
                  'Your app usage is read and stored only on this phone. '
                      'Focus Regain doesn\'t send it anywhere.',
                ),
                (
                  Icons.person_outline,
                  'Your account (name and email) is kept by Firebase '
                      'Authentication so you can sign in. Your usage data '
                      'is not linked to it.',
                ),
                (
                  Icons.notifications_none,
                  'For reminders, your account also stores your reminder '
                      'settings, time zone, the day you last opened the app '
                      'and when your focus sessions ran (not which apps). '
                      'Screen time stays on this phone.',
                ),
                (
                  Icons.visibility_outlined,
                  'Usage access lets the app see which app is open, to count '
                      'screen time and to block the apps you picked.',
                ),
                (
                  Icons.layers_outlined,
                  'Display over other apps lets the pause screen cover a '
                      'blocked app.',
                ),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(text, style: theme.textTheme.bodyMedium),
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

  Future<void> _editMinutes(
    BuildContext context, {
    required String title,
    required int current,
    required int min,
    required int max,
    required int step,
    required Future<void> Function(int) onSave,
  }) async {
    var minutes = current;
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatMinutes(minutes),
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontFeatures: AppTheme.tabularFigures),
              ),
              Slider(
                value: minutes.toDouble(),
                min: min.toDouble(),
                max: max.toDouble(),
                divisions: (max - min) ~/ step,
                label: formatMinutes(minutes),
                onChanged: (v) => setState(() => minutes = v.round()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, minutes),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (picked != null) await onSave(picked);
  }
}

/// Small uppercase heading, with an optional coloured status on the right.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.status});

  final String text;
  final (String, Color)? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = status;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 28, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.pick(AppColors.indigo, theme.brightness),
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          if (s != null) ...[
            CircleAvatar(radius: 3, backgroundColor: s.$2),
            const SizedBox(width: 6),
            Text(
              s.$1,
              style: theme.textTheme.labelMedium?.copyWith(color: s.$2),
            ),
          ],
        ],
      ),
    );
  }
}

/// Glass card holding rows separated by thin dividers.
class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final divider = Divider(
      height: 1,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
    );
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) divider,
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.color});

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

/// Icon, title, optional subtitle, optional value chip, and a chevron.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.value,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback onTap;

  static const padding = EdgeInsets.symmetric(horizontal: 16, vertical: 6);

  static TextStyle? titleStyle(ThemeData theme) =>
      theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700);

  static TextStyle? subtitleStyle(ThemeData theme) => theme.textTheme.bodySmall
      ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final v = value;
    // At large text sizes the value moves under the title to leave room.
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final chip = v == null
        ? null
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(alpha: 0.06),
              border: Border.all(
                color: scheme.onSurface.withValues(alpha: 0.08),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              v,
              softWrap: false,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: AppTheme.tabularFigures,
              ),
            ),
          );
    return ListTile(
      contentPadding: padding,
      leading: _IconBox(icon: icon, color: color),
      title: Text(title, style: titleStyle(theme)),
      subtitle: subtitle == null && !(stacked && chip != null)
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null)
                  Text(subtitle!, style: subtitleStyle(theme)),
                if (stacked && chip != null) ...[
                  const SizedBox(height: 6),
                  chip,
                ],
              ],
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!stacked && chip != null) chip,
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// System / Light / Dark: the chosen one is a raised glass pill with a check.
class _ThemeSwitch extends StatelessWidget {
  const _ThemeSwitch({required this.value, required this.onChanged});

  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mint = AppColors.pick(AppColors.mint, scheme.brightness);
    const radius = BorderRadius.all(Radius.circular(12));
    return GlassCard(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final (mode, icon, label) in const [
            (ThemeMode.system, Icons.brightness_auto_outlined, 'System'),
            (ThemeMode.light, Icons.light_mode_outlined, 'Light'),
            (ThemeMode.dark, Icons.dark_mode_outlined, 'Dark'),
          ])
            Expanded(
              child: Semantics(
                selected: value == mode,
                inMutuallyExclusiveGroup: true,
                child: Material(
                  color: value == mode
                      ? scheme.onSurface.withValues(alpha: 0.08)
                      : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: radius,
                    side: value == mode
                        ? BorderSide(
                            color: scheme.onSurface.withValues(alpha: 0.1),
                          )
                        : BorderSide.none,
                  ),
                  child: InkWell(
                    borderRadius: radius,
                    onTap: () => onChanged(mode),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              value == mode ? Icons.check : icon,
                              size: 18,
                              color: value == mode
                                  ? mint
                                  : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                label,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: value == mode
                                      ? scheme.onSurface
                                      : scheme.onSurfaceVariant,
                                  fontWeight: value == mode
                                      ? FontWeight.w700
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
            ),
        ],
      ),
    );
  }
}

/// Push reminders sent by the server. Nothing here blocks the app: without
/// permission the section just explains and offers to turn them on.
class _RemindersSection extends StatelessWidget {
  const _RemindersSection({required this.reminders, this.onOpenSettings});

  final NotificationCenter reminders;

  /// Android: the app's notification settings (null where unsupported).
  final VoidCallback? onOpenSettings;

  // Its own Obx: reads inside a child widget's build aren't seen by the
  // parent's Obx, so permission or settings changes wouldn't redraw it.
  @override
  Widget build(BuildContext context) => Obx(() => _build(context));

  Widget _build(BuildContext context) {
    final theme = Theme.of(context);
    final b = theme.brightness;
    final permission = reminders.permission.value;
    final prefs = reminders.prefs.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('REMINDERS'),
        _Panel(
          children: switch (permission) {
            PushPermission.unavailable => [
              _note(
                theme,
                Icons.notifications_off_outlined,
                AppColors.pick(AppColors.blue, b),
                "Reminders aren't available on this device",
                'Everything else in Focus Regain works as usual.',
              ),
            ],
            PushPermission.notDetermined => [
              _note(
                theme,
                Icons.notifications_active_outlined,
                AppColors.pick(AppColors.violet, b),
                'Get gentle reminders',
                'A nudge to focus at a time you pick, and a short summary '
                    'of your real focus time. You choose which, and when.',
                action: FilledButton.tonal(
                  onPressed: reminders.requestPermission,
                  child: const Text('Turn on'),
                ),
              ),
            ],
            PushPermission.denied => [
              _note(
                theme,
                Icons.notifications_off_outlined,
                AppColors.pick(AppColors.blue, b),
                'Notifications are off',
                'Turn them on in your phone settings to get reminders.',
                action: onOpenSettings == null
                    ? null
                    : FilledButton.tonal(
                        onPressed: onOpenSettings,
                        child: const Text('Open'),
                      ),
              ),
            ],
            PushPermission.granted when prefs == null => [
              _note(
                theme,
                Icons.cloud_off_outlined,
                AppColors.pick(AppColors.blue, b),
                reminders.prefsFailed.value
                    ? "Couldn't load your reminders"
                    : 'Loading your reminders…',
                null,
                action: reminders.prefsFailed.value
                    ? TextButton(
                        onPressed: reminders.loadPrefs,
                        child: const Text('Retry'),
                      )
                    : null,
              ),
            ],
            PushPermission.granted => _controls(context, prefs!),
          },
        ),
        if (permission == PushPermission.granted && prefs != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: Text(
              'Times use your time zone'
              '${reminders.timezone.value == null ? '' : ' (${reminders.timezone.value})'}. '
              'Nudges and check-ins: at most one a day and three a week, '
              'and fewer if you don\'t open them.',
              style: _Row.subtitleStyle(theme),
            ),
          ),
      ],
    );
  }

  List<Widget> _controls(BuildContext context, NotificationPrefs p) {
    final theme = Theme.of(context);
    final b = theme.brightness;
    String time(int minute) => MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay(hour: minute ~/ 60, minute: minute % 60));
    String? quietNote(TimedReminder r) =>
        r.enabled && p.quietHours.contains(r.minute)
        ? "It's inside your quiet hours, so it won't be sent."
        : null;
    void save(NotificationPrefs next) => reminders.updatePrefs(next);

    return [
      _switch(
        theme,
        icon: Icons.bolt,
        color: AppColors.pick(AppColors.amber, b),
        title: 'Focus nudge',
        subtitle:
            quietNote(p.focusNudge) ??
            "A suggestion to start a session. Skipped while you're focusing.",
        value: p.focusNudge.enabled,
        onChanged: (on) =>
            save(p.copyWith(focusNudge: p.focusNudge.copyWith(enabled: on))),
      ),
      if (p.focusNudge.enabled)
        _Row(
          icon: Icons.schedule,
          color: AppColors.pick(AppColors.amber, b),
          title: 'Nudge time',
          value: time(p.focusNudge.minute),
          onTap: () => _pickTime(context, p.focusNudge.minute, (m) {
            save(p.copyWith(focusNudge: p.focusNudge.copyWith(minute: m)));
          }),
        ),
      _switch(
        theme,
        icon: Icons.insights,
        color: AppColors.pick(AppColors.violet, b),
        title: 'Daily focus summary',
        subtitle:
            quietNote(p.dailySummary) ??
            'Your real focus time that day. Not sent on days without any.',
        value: p.dailySummary.enabled,
        onChanged: (on) => save(
          p.copyWith(dailySummary: p.dailySummary.copyWith(enabled: on)),
        ),
      ),
      if (p.dailySummary.enabled)
        _Row(
          icon: Icons.schedule,
          color: AppColors.pick(AppColors.violet, b),
          title: 'Summary time',
          value: time(p.dailySummary.minute),
          onTap: () => _pickTime(context, p.dailySummary.minute, (m) {
            save(p.copyWith(dailySummary: p.dailySummary.copyWith(minute: m)));
          }),
        ),
      _switch(
        theme,
        icon: Icons.waving_hand_outlined,
        color: AppColors.pick(AppColors.mint, b),
        title: 'Check-ins',
        subtitle:
            "A gentle note if you haven't opened the app for 3 days. "
            'At most twice in a row.',
        value: p.checkIns,
        onChanged: (on) => save(p.copyWith(checkIns: on)),
      ),
      _switch(
        theme,
        icon: Icons.bedtime_outlined,
        color: AppColors.pick(AppColors.indigo, b),
        title: 'Quiet hours',
        subtitle: p.quietHours.enabled
            ? '${time(p.quietHours.start)} – ${time(p.quietHours.end)}: no reminders'
            : 'Reminders can arrive at any time you chose',
        value: p.quietHours.enabled,
        onChanged: (on) =>
            save(p.copyWith(quietHours: p.quietHours.copyWith(enabled: on))),
      ),
      if (p.quietHours.enabled)
        _Row(
          icon: Icons.schedule,
          color: AppColors.pick(AppColors.indigo, b),
          title: 'Change quiet hours',
          onTap: () async {
            final start = await _askTime(
              context,
              p.quietHours.start,
              'Quiet hours start',
            );
            if (start == null || !context.mounted) return;
            final end = await _askTime(
              context,
              p.quietHours.end,
              'Quiet hours end',
            );
            if (end == null) return;
            save(
              p.copyWith(
                quietHours: p.quietHours.copyWith(start: start, end: end),
              ),
            );
          },
        ),
    ];
  }

  static Widget _switch(
    ThemeData theme, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => SwitchListTile(
    contentPadding: _Row.padding,
    secondary: _IconBox(icon: icon, color: color),
    title: Text(title, style: _Row.titleStyle(theme)),
    subtitle: Text(subtitle, style: _Row.subtitleStyle(theme)),
    value: value,
    onChanged: onChanged,
    activeThumbColor: Colors.white,
    activeTrackColor: AppColors.pick(AppColors.indigo, theme.brightness),
  );

  static Widget _note(
    ThemeData theme,
    IconData icon,
    Color color,
    String title,
    String? subtitle, {
    Widget? action,
  }) => ListTile(
    contentPadding: _Row.padding,
    leading: _IconBox(icon: icon, color: color),
    title: Text(title, style: _Row.titleStyle(theme)),
    subtitle: subtitle == null
        ? null
        : Text(subtitle, style: _Row.subtitleStyle(theme)),
    trailing: action,
  );

  static Future<int?> _askTime(
    BuildContext context,
    int minute,
    String help,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
      helpText: help,
    );
    return picked == null ? null : picked.hour * 60 + picked.minute;
  }

  static Future<void> _pickTime(
    BuildContext context,
    int minute,
    ValueChanged<int> onPicked,
  ) async {
    final picked = await _askTime(context, minute, 'Select time');
    if (picked != null) onPicked(picked);
  }
}
