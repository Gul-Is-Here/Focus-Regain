import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:regain_app/app/widgets/gradient_button.dart';
import 'package:regain_app/data/models/notification_prefs.dart';
import 'package:regain_app/data/repositories/push_messaging.dart';
import 'package:regain_app/modules/settings/settings_view.dart';
import 'package:regain_app/modules/shell/shell_view_model.dart';

import 'fakes.dart';
import 'permissions_test.dart' show returnFromSettings;
import 'test_app.dart';

const done = {'onboarding_done': true};
int tab() => Get.find<ShellViewModel>().tabIndex.value;

Finder settingsList() => find
    .descendant(
      of: find.byType(SettingsView),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.text('Settings').last);
  await tester.pumpAndSettle();
}

/// Scrolls Settings to [finder] and taps it.
Future<void> tapInSettings(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: settingsList());
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(Get.reset);

  testWidgets(
    'not asked yet: explains, asks only on tap, then shows the controls',
    (tester) async {
      final push = FakePush()..status = PushPermission.notDetermined;
      final store = FakeReminderStore();
      await startApp(tester, prefs: done, push: push, reminders: store);
      expect(push.requests, 0); // never asked on its own
      expect(store.devices, isEmpty);

      await openSettings(tester);
      await tester.scrollUntilVisible(
        find.text('Get gentle reminders'),
        200,
        scrollable: settingsList(),
      );
      await tapInSettings(tester, find.widgetWithText(FilledButton, 'Turn on'));
      expect(push.requests, 1);
      expect(store.devices.values.single, (
        uid: 'alex',
        fid: 'fid-1',
        platform: 'android',
      ));
      expect(find.text('Focus nudge'), findsOneWidget);
    },
  );

  testWidgets(
    'denied or unavailable: Settings explains and the app still works',
    (tester) async {
      final push = FakePush()..status = PushPermission.denied;
      await startApp(tester, prefs: done, push: push);
      expect(find.text('TOTAL TODAY'), findsOneWidget);
      await openSettings(tester);
      await tester.scrollUntilVisible(
        find.text('Turn them on in your phone settings to get reminders.'),
        200,
        scrollable: settingsList(),
      );
      expect(find.text('Focus nudge'), findsNothing);

      // Turned on in phone settings, back in the app: controls appear.
      push.status = PushPermission.granted;
      await returnFromSettings(tester);
      await tester.scrollUntilVisible(
        find.text('Focus nudge'),
        200,
        scrollable: settingsList(),
      );

      push.status = PushPermission.unavailable;
      await returnFromSettings(tester);
      await tester.scrollUntilVisible(
        find.text("Reminders aren't available on this device"),
        200,
        scrollable: settingsList(),
      );
      await tester.tap(find.text('Focus').last);
      await tester.pumpAndSettle();
      expect(tab(), 1);
    },
  );

  testWidgets(
    'reminder settings are saved to the account; a failed save is undone',
    (tester) async {
      final store = FakeReminderStore()
        ..prefs = const NotificationPrefs(
          dailySummary: TimedReminder(enabled: true, minute: 23 * 60),
        );
      await startApp(tester, prefs: done, reminders: store);
      await openSettings(tester);
      await tester.scrollUntilVisible(
        find.text('Focus nudge'),
        200,
        scrollable: settingsList(),
      );
      // 23:00 is inside the default quiet hours (22:00-07:00).
      expect(
        find.text("It's inside your quiet hours, so it won't be sent."),
        findsOneWidget,
      );

      await tapInSettings(tester, find.text('Focus nudge'));
      expect(store.prefs.focusNudge.enabled, isTrue);
      expect(find.text('Nudge time'), findsOneWidget);
      await tapInSettings(tester, find.text('Check-ins'));
      expect(store.prefs.checkIns, isTrue);
      await tapInSettings(tester, find.text('Quiet hours'));
      expect(store.prefs.quietHours.enabled, isFalse);
      expect(
        find.text("It's inside your quiet hours, so it won't be sent."),
        findsNothing,
      );

      store.failSave = true;
      await tapInSettings(tester, find.text('Check-ins'));
      expect(store.prefs.checkIns, isTrue);
      final tile = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Check-ins'),
      );
      expect(tile.value, isTrue);
      expect(find.text('Not saved'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'a refreshed installation id replaces this device, not adds one',
    (tester) async {
      final push = FakePush();
      final store = FakeReminderStore();
      await startApp(tester, prefs: done, push: push, reminders: store);
      final deviceId = store.devices.keys.single;
      push.refresh('fid-2');
      await tester.pumpAndSettle();
      expect(store.devices, {
        deviceId: (uid: 'alex', fid: 'fid-2', platform: 'android'),
      });
    },
  );

  testWidgets('sign out removes this device and stops pushes first', (
    tester,
  ) async {
    final push = FakePush();
    final store = FakeReminderStore();
    final auth = FakeAuth();
    await startApp(
      tester,
      prefs: done,
      push: push,
      reminders: store,
      auth: auth,
    );
    expect(store.devices, hasLength(1));
    await openSettings(tester);
    await tapInSettings(tester, find.text('Sign out'));
    await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(store.devices, isEmpty);
    expect(push.unregisters, 1);
    expect(auth.user, isNull);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('sign out still finishes when offline', (tester) async {
    final store = FakeReminderStore()..removeGate = Completer<void>();
    final auth = FakeAuth();
    await startApp(tester, prefs: done, reminders: store, auth: auth);
    await openSettings(tester);
    await tapInSettings(tester, find.text('Sign out'));
    await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(auth.user, isNull);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('tapping a push opens its screen once and records the open', (
    tester,
  ) async {
    final push = FakePush();
    final store = FakeReminderStore();
    await startApp(tester, prefs: done, push: push, reminders: store);
    expect(tab(), 0);
    push.tap(pushOf());
    await tester.pumpAndSettle();
    expect(tab(), 1);
    expect(store.opened, ['alex/focusEncouragement_2026-11-01']);

    // The same tap event again (e.g. delivered twice): no second jump.
    Get.find<ShellViewModel>().changeTab(0);
    push.tap(pushOf());
    await tester.pumpAndSettle();
    expect(tab(), 0);
    expect(store.opened, hasLength(1));

    push.tap(pushOf(id: 'reEngagement_2026-11-04', route: 'dashboard'));
    await tester.pumpAndSettle();
    expect(tab(), 0);
  });

  testWidgets("a push sent to another account isn't opened", (tester) async {
    final push = FakePush();
    final store = FakeReminderStore();
    await startApp(tester, prefs: done, push: push, reminders: store);
    push.tap(pushOf(uid: 'someone-else'));
    await tester.pumpAndSettle();
    expect(tab(), 0);
    expect(store.opened, isEmpty);
    push.arrive(pushOf(id: 'dailySummary_2026-11-01', uid: 'someone-else'));
    await tester.pumpAndSettle();
    expect(find.text('Ready for a focus session?'), findsNothing);
  });

  testWidgets(
    'cold start from a push before signing in: opens it after login',
    (tester) async {
      final push = FakePush()..initialMessage = pushOf();
      final store = FakeReminderStore();
      await startApp(
        tester,
        prefs: done,
        push: push,
        reminders: store,
        auth: FakeAuth(user: null),
      );
      expect(find.text('Welcome back'), findsOneWidget);
      expect(store.opened, isEmpty);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'alex@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'secret');
      final login = find.widgetWithText(GradientButton, 'Log in');
      await tester.ensureVisible(login);
      await tester.pumpAndSettle();
      await tester.tap(login);
      await tester.pumpAndSettle();
      expect(tab(), 1);
      expect(store.opened, ['alex/focusEncouragement_2026-11-01']);
    },
  );

  testWidgets('in the foreground: one in-app banner, even if delivered twice', (
    tester,
  ) async {
    final push = FakePush();
    await startApp(tester, prefs: done, push: push);
    push
      ..arrive(pushOf())
      ..arrive(pushOf());
    await tester.pumpAndSettle();
    expect(find.text('Ready for a focus session?'), findsOneWidget);
    await tester.tap(find.text('Ready for a focus session?'));
    await tester.pumpAndSettle();
    expect(tab(), 1);
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'time zone and "opened today" are synced; a zone change is picked up',
    (tester) async {
      final store = FakeReminderStore();
      var zone = 'Asia/Karachi';
      await startApp(
        tester,
        prefs: done,
        reminders: store,
        timezone: () async => zone,
      );
      expect(store.activity.single.timezone, 'Asia/Karachi');
      expect(store.activity.single.activeDay, isNotNull);

      zone = 'Europe/London'; // travelled
      await returnFromSettings(tester);
      expect(store.activity.last.timezone, 'Europe/London');
      // "Opened today" is sent once a day only.
      expect(store.activity.last.activeDay, isNull);
    },
  );
}
