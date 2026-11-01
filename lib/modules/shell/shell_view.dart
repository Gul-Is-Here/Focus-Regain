import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/widgets/frosted_glass.dart';

import '../blocking/blocking_view.dart';
import '../dashboard/dashboard_view.dart';
import '../focus/focus_view.dart';
import '../settings/settings_view.dart';
import 'shell_view_model.dart';

/// Bottom bar on phones; a side rail from [_railWidth] (tablets, desktop),
/// labelled and wider from [_extendedRailWidth].
const _railWidth = 840.0;
const _extendedRailWidth = 1200.0;

class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _tabs = [
  _Tab('Dashboard', Icons.bolt_outlined, Icons.bolt),
  _Tab('Focus', Icons.schedule_outlined, Icons.schedule),
  _Tab('Blocking', Icons.block_outlined, Icons.block),
  _Tab('Settings', Icons.settings_outlined, Icons.settings),
];

class ShellView extends GetView<ShellViewModel> {
  const ShellView({super.key});

  @override
  Widget build(BuildContext context) {
    const pages = IndexedStack(
      children: [DashboardView(), FocusView(), BlockingView(), SettingsView()],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Obx(() {
          final index = controller.tabIndex.value;
          final body = IndexedStack(index: index, children: pages.children);
          if (width < _railWidth) {
            return Scaffold(
              body: body,
              bottomNavigationBar: _RoundedBar(
                child: NavigationBar(
                  selectedIndex: index,
                  onDestinationSelected: controller.changeTab,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  destinations: [
                    for (final t in _tabs)
                      NavigationDestination(
                        icon: Icon(t.icon),
                        selectedIcon: Icon(t.selectedIcon),
                        label: t.label,
                      ),
                  ],
                ),
              ),
            );
          }
          final extended = width >= _extendedRailWidth;
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: controller.changeTab,
                  extended: extended,
                  labelType: extended
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerLow,
                  destinations: [
                    for (final t in _tabs)
                      NavigationRailDestination(
                        icon: Icon(t.icon),
                        selectedIcon: Icon(t.selectedIcon),
                        label: Text(t.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        });
      },
    );
  }
}

/// Bottom bar: glass tint, rounded top corners and a fine top border.
class _RoundedBar extends StatelessWidget {
  const _RoundedBar({required this.child});

  final Widget child;

  static const _radius = BorderRadius.vertical(top: Radius.circular(24));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: _radius,
        // Same tint as the glass cards; nothing scrolls under it, so no blur.
        gradient: FrostedGlass.washOf(scheme),
        border: Border(
          top: BorderSide(
            color: dark
                ? Colors.white.withValues(alpha: 0.10)
                : scheme.outlineVariant,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: _radius, child: child),
    );
  }
}
