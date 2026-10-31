import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../blocking/blocking_view.dart';
import '../dashboard/dashboard_view.dart';
import '../focus/focus_view.dart';
import '../settings/settings_view.dart';
import 'shell_view_model.dart';

class ShellView extends GetView<ShellViewModel> {
  const ShellView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        body: IndexedStack(
          index: controller.tabIndex.value,
          children: const [
            DashboardView(),
            FocusView(),
            BlockingView(),
            SettingsView(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: controller.tabIndex.value,
          onDestinationSelected: controller.changeTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.timer_outlined),
              selectedIcon: Icon(Icons.timer),
              label: 'Focus',
            ),
            NavigationDestination(
              icon: Icon(Icons.block_outlined),
              selectedIcon: Icon(Icons.block),
              label: 'Blocking',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
