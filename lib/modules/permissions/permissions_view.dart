import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';
import '../../app/widgets/glass_card.dart';
import '../../app/widgets/gradient_button.dart';
import '../../app/widgets/step_progress.dart';
import 'permissions_view_model.dart';

typedef _Info = ({IconData icon, String name, String why, String how});

_Info _infoOf(AppPermission p) => switch (p) {
  AppPermission.usageAccess => (
    icon: Icons.query_stats_rounded,
    name: 'Usage access',
    why:
        'Lets Focus Regain count your screen time and see which app is '
        'open, so it can pause the ones you choose.',
    how: 'Tap Focus Regain in the list, then turn on "Permit usage access".',
  ),
  AppPermission.overlay => (
    icon: Icons.layers_rounded,
    name: 'Display over other apps',
    why: 'Lets the pause screen appear on top of an app you blocked.',
    how: 'Turn on "Allow display over other apps".',
  ),
  AppPermission.notifications => (
    icon: Icons.notifications_active_outlined,
    name: 'Notifications',
    why:
        'For limit warnings, the focus timer, and the message when a '
        'session ends.',
    how: 'Turn on "Show notifications".',
  ),
  AppPermission.battery => (
    icon: Icons.battery_charging_full_rounded,
    name: 'Unrestricted battery',
    why:
        "Stops Android from pausing blocking in the background to save "
        'power.',
    how:
        'Switch the list to "All apps", tap Focus Regain and choose '
        '"Don\'t optimise" (or "Unrestricted").',
  ),
};

class PermissionsView extends GetView<PermissionsViewModel> {
  const PermissionsView({super.key});

  static const _count = 4;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: AmbientBackground(
        topGlow: AppColors.pick(AppColors.mint, scheme.brightness),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Obx(() {
              if (controller.loading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              final current = controller.current;
              final info = current == null ? null : _infoOf(current);
              final step = current?.index ?? _count;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StepLabel(current: step.clamp(0, _count - 1), count: _count),
                  const SizedBox(height: 10),
                  StepSegments(current: step, count: _count),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _BigIcon(icon: info?.icon ?? Icons.verified_rounded),
                          const SizedBox(height: 24),
                          Text(
                            info == null
                                ? "You're all set"
                                : 'Allow ${info.name.toLowerCase()}',
                            style: text.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            info?.why ??
                                'Every permission is on. Focus Regain can '
                                    'now track and protect your time.',
                            style: text.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                          if (info != null) ...[
                            const SizedBox(height: 16),
                            _HowCard(how: info.how),
                          ],
                          if (controller.currentMayBeLocked) ...[
                            const SizedBox(height: 12),
                            _RestrictedCard(onOpen: controller.openAppInfo),
                          ],
                          const SizedBox(height: 24),
                          const _Checklist(),
                        ],
                      ),
                    ),
                  ),
                  GradientButton(
                    label: info == null ? 'Go to dashboard' : 'Open settings',
                    icon: info == null
                        ? Icons.arrow_forward_rounded
                        : Icons.open_in_new_rounded,
                    onPressed: info == null
                        ? controller.finish
                        : controller.allow,
                  ),
                  if (info != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      "Turn it on, then come back. We'll check "
                      'automatically.',
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _BigIcon extends StatelessWidget {
  const _BigIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppColors.pick(AppColors.mint, scheme.brightness);
    return ExcludeSemantics(
      child: Container(
        width: 72,
        height: 72,
        decoration: GlassCard.decorationOf(scheme).copyWith(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Icon(icon, size: 36, color: accent),
      ),
    );
  }
}

/// "How": where to tap once Android Settings opens.
class _HowCard extends StatelessWidget {
  const _HowCard({required this.how});

  final String how;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.touch_app_outlined, size: 20, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('In Settings', style: text.labelLarge),
                const SizedBox(height: 2),
                Text(
                  how,
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
    );
  }
}

/// All four permissions with their state.
class _Checklist extends GetView<PermissionsViewModel> {
  const _Checklist();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final accent = AppColors.pick(AppColors.mint, scheme.brightness);
    return Obx(() {
      final current = controller.current;
      return GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          children: [
            for (final p in AppPermission.values)
              MergeSemantics(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        controller.granted.contains(p)
                            ? Icons.check_circle_rounded
                            : p == current
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 22,
                        color: controller.granted.contains(p) || p == current
                            ? accent
                            : scheme.outline,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _infoOf(p).name,
                          style: text.bodyMedium?.copyWith(
                            fontWeight: p == current
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        controller.granted.contains(p)
                            ? 'Allowed'
                            : p == current
                            ? 'Next'
                            : 'Needed',
                        style: text.labelMedium?.copyWith(
                          color: controller.granted.contains(p)
                              ? accent
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

/// Android 13+ greys out usage access and "display over other apps" for apps
/// installed from an APK file until the user allows restricted settings, and
/// only App info can do that (support.google.com/android/answer/12623953).
class _RestrictedCard extends StatelessWidget {
  const _RestrictedCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final amber = AppColors.pick(AppColors.amber, scheme.brightness);
    final steps = [
      'Tap Open App info below.',
      'Tap \u22ee (top right), then Allow restricted settings, and confirm.',
      'Come back here and tap Open settings.',
    ];
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline_rounded, size: 20, color: amber),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Switch greyed out?', style: text.labelLarge),
                    const SizedBox(height: 2),
                    Text(
                      'Android locks this switch for apps installed from a '
                      'file instead of the Play Store. To unlock it:',
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
          const SizedBox(height: 8),
          for (final (i, step) in steps.indexed)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 4),
              child: Text(
                '${i + 1}. $step',
                style: text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: TextButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.info_outline_rounded),
              label: const Text('Open App info'),
            ),
          ),
        ],
      ),
    );
  }
}
