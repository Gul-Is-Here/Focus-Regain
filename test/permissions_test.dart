import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'fakes.dart';
import 'test_app.dart';

/// Leaves for Android Settings and comes back.
Future<void> returnFromSettings(WidgetTester tester) async {
  for (final state in const [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pumpAndSettle();
}

void main() {
  setUp(Get.reset);

  testWidgets('each permission is asked in turn before the dashboard', (
    tester,
  ) async {
    final screenTime = FakeScreenTime()
      ..access = false
      ..overlay = false
      ..notifications = false
      ..batteryUnrestricted = false;
    await startApp(
      tester,
      screenTime: screenTime,
      prefs: {'onboarding_done': true},
      needsPermissions: true,
    );

    expect(find.text('Allow usage access'), findsOneWidget);
    expect(find.text('Go to dashboard'), findsNothing);
    expect(find.byTooltip('Dashboard'), findsNothing);

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(screenTime.settingsOpened, 1);

    // Back without allowing it: still on the same step.
    await returnFromSettings(tester);
    expect(find.text('Allow usage access'), findsOneWidget);

    screenTime.access = true;
    await returnFromSettings(tester);
    expect(find.text('Allow display over other apps'), findsOneWidget);
    expect(find.text('Allowed'), findsOneWidget);

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(screenTime.overlaySettingsOpened, 1);
    screenTime.overlay = true;
    await returnFromSettings(tester);
    expect(find.text('Allow notifications'), findsOneWidget);

    screenTime.notifications = true;
    await returnFromSettings(tester);
    expect(find.text('Allow unrestricted battery'), findsOneWidget);

    screenTime.batteryUnrestricted = true;
    await returnFromSettings(tester);
    expect(find.text("You're all set"), findsOneWidget);
    expect(find.text('Allowed'), findsNWidgets(4));

    await tester.tap(find.text('Go to dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('TOTAL TODAY'), findsOneWidget);
  });

  testWidgets('already allowed: goes straight to the dashboard', (
    tester,
  ) async {
    await startApp(
      tester,
      prefs: {'onboarding_done': true},
      needsPermissions: true, // e.g. allowed while the app was closed
    );
    expect(find.text('TOTAL TODAY'), findsOneWidget);
  });

  testWidgets('Android Go: overlay step is skipped, Blocking explains why', (
    tester,
  ) async {
    final screenTime = FakeScreenTime()
      ..overlay = false
      ..overlayRequestable = false;
    await startApp(
      tester,
      screenTime: screenTime,
      prefs: {'onboarding_done': true},
      needsPermissions: true,
    );
    // Never stuck on a step the phone can't allow.
    expect(find.text('TOTAL TODAY'), findsOneWidget);

    await tester.tap(find.text('Blocking').last);
    await tester.pumpAndSettle();
    expect(
      find.textContaining("doesn't let apps cover other apps"),
      findsOneWidget,
    );

    await tester.tap(find.text('Focus').last);
    await tester.pumpAndSettle();
    expect(find.textContaining("doesn't let"), findsOneWidget);
    expect(find.text('Set up blocking'), findsNothing);
  });

  testWidgets(
    'installed from a file: shows how to unlock restricted settings',
    (tester) async {
      final screenTime = FakeScreenTime()
        ..access = false
        ..overlay = false
        ..restrictedSettings = true;
      await startApp(
        tester,
        screenTime: screenTime,
        prefs: {'onboarding_done': true},
        needsPermissions: true,
      );
      expect(find.text('Switch greyed out?'), findsOneWidget);
      await tester.ensureVisible(find.text('Open App info'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open App info'));
      await tester.pumpAndSettle();
      expect(screenTime.appInfoOpened, 1);

      // Same help on the overlay step, none on the others.
      screenTime.access = true;
      await returnFromSettings(tester);
      expect(find.text('Allow display over other apps'), findsOneWidget);
      expect(find.text('Switch greyed out?'), findsOneWidget);
      screenTime.overlay = true;
      await returnFromSettings(tester);
      expect(find.text('Switch greyed out?'), findsNothing);
    },
  );

  testWidgets('installed from a store: no restricted-settings help', (
    tester,
  ) async {
    await startApp(
      tester,
      screenTime: FakeScreenTime()..access = false,
      prefs: {'onboarding_done': true},
      needsPermissions: true,
    );
    expect(find.text('Allow usage access'), findsOneWidget);
    expect(find.text('Switch greyed out?'), findsNothing);
  });
}
