import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:regain_app/app/utils/duration_format.dart';
import 'package:regain_app/data/models/app_category.dart';
import 'package:regain_app/data/models/blocking_rules.dart';
import 'package:regain_app/data/models/focus_goal.dart';
import 'package:regain_app/data/models/focus_session.dart';
import 'package:regain_app/modules/blocking/blocking_view_model.dart';
import 'package:regain_app/modules/dashboard/dashboard_view_model.dart';
import 'package:regain_app/modules/focus/focus_view.dart';
import 'package:regain_app/modules/focus/focus_view_model.dart';
import 'package:regain_app/modules/onboarding/onboarding_view_model.dart';
import 'package:regain_app/modules/permissions/permissions_view_model.dart';
import 'package:regain_app/modules/schedule_editor/schedule_editor_view_model.dart';
import 'package:regain_app/modules/settings/settings_view.dart';

import 'fakes.dart';
import 'test_app.dart';

/// The Blocking tab's own list, not the search field's inner Scrollable.
final pageScrollable = find
    .descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    )
    .first;

void main() {
  setUp(Get.reset);

  testWidgets('first launch: onboarding saves answers and opens the shell', (
    tester,
  ) async {
    final screenTime = FakeScreenTime();
    final repo = await startApp(tester, screenTime: screenTime);
    expect(find.text('Take back your time'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Goals page needs at least one goal before Continue works.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('What do you want to change?'), findsOneWidget);
    await tester.ensureVisible(find.text('Sleep better'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sleep better'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Recommended for balanced focus'), findsOneWidget);
    await tester.ensureVisible(find.text('Gentle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gentle')); // the 4 h preset
    await tester.pumpAndSettle();
    expect(find.text('4 h'), findsNWidgets(2)); // big number + chip
    expect(find.text('Gentle & gradual change'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('TOTAL TODAY'), findsOneWidget);
    expect(repo.onboardingDone, isTrue);
    expect(repo.goals.map((g) => g.name), ['sleepBetter']);
    expect(repo.dailyTargetMinutes, 240);
    expect(screenTime.recap, (enabled: true, targetMinutes: 240));
  });

  testWidgets('onboarding Skip opens the shell with the default target', (
    tester,
  ) async {
    final repo = await startApp(tester, screenTime: FakeScreenTime());
    expect(find.text('RECLAIM BALANCE'), findsOneWidget);
    expect(find.text('Back'), findsNothing);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('TOTAL TODAY'), findsOneWidget);
    expect(repo.onboardingDone, isTrue);
    expect(repo.goals, isEmpty);
    expect(repo.dailyTargetMinutes, 180);
  });

  testWidgets('returning user: tabs switch and theme choice is saved', (
    tester,
  ) async {
    final repo = await startApp(tester, prefs: {'onboarding_done': true});
    expect(find.text('TOTAL TODAY'), findsOneWidget);

    for (final (tab, body) in [
      ('Focus', 'Ready to focus today?'),
      ('Blocking', 'Nothing blocked yet'),
      ('Settings', 'GOALS'),
      ('Dashboard', 'TOTAL TODAY'),
    ]) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(find.text(body).hitTestable(), findsOneWidget);
    }

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Dark'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(SettingsView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(repo.themeMode, ThemeMode.dark);
    expect(Get.isDarkMode, isTrue);
  });

  testWidgets('dashboard asks for usage access, then lists apps', (
    tester,
  ) async {
    final screenTime = FakeScreenTime()..access = false;
    await startApp(
      tester,
      prefs: {'onboarding_done': true},
      screenTime: screenTime,
    );

    expect(find.text('Allow usage access'), findsOneWidget);
    await tester.ensureVisible(find.text('Open settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open settings'));
    expect(screenTime.settingsOpened, 1);

    // User grants access in Settings and comes back.
    screenTime
      ..access = true
      ..usage = [
        usageOf('Video app', const Duration(minutes: 75)),
        usageOf('Maps', const Duration(seconds: 30)),
      ];
    await Get.find<DashboardViewModel>().refreshUsage();
    await tester.pumpAndSettle();

    // The ring's number is rich text (big digits, small units).
    expect(find.text('1 h 15 min', findRichText: true), findsWidgets);
    expect(find.text('1 h 45 min left'), findsOneWidget); // 3 h target
    expect(find.text('On track'), findsOneWidget);
    expect(find.text('30 days'), findsOneWidget); // streak tile

    // Per-app list lives in the Details sheet.
    await tester.ensureVisible(find.text('Details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.text('Video app'), findsOneWidget);
    expect(find.text('Maps'), findsNothing); // under a minute
    await tester.tapAt(const Offset(10, 10)); // close the sheet
    await tester.pumpAndSettle();

    // Pull-to-refresh path: new numbers redraw without a status change.
    screenTime.usage = [usageOf('Video app', const Duration(minutes: 200))];
    await Get.find<DashboardViewModel>().refreshUsage();
    await tester.pumpAndSettle();
    expect(find.text('3 h 20 min', findRichText: true), findsWidgets);
    expect(find.text('20 min over target'), findsOneWidget);
    expect(find.text('Past your target'), findsOneWidget);
  });

  testWidgets('blocking: setup steps, then picking apps saves the list', (
    tester,
  ) async {
    final screenTime = FakeScreenTime()
      ..overlay = false
      ..batteryUnrestricted = false
      ..installed = [appOf('Chat'), appOf('Video')];
    await startApp(
      tester,
      prefs: {'onboarding_done': true},
      screenTime: screenTime,
    );
    await tester.tap(find.text('Blocking').last);
    await tester.pumpAndSettle();

    expect(find.text('How blocking works'), findsOneWidget);
    // Usage access is already granted, so only one step still needs "Allow".
    expect(find.text('Allow'), findsOneWidget);
    await tester.ensureVisible(find.text('Allow'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow'));
    expect(screenTime.overlaySettingsOpened, 1);

    screenTime.overlay = true;
    await Get.find<BlockingViewModel>().refreshState();
    await tester.pumpAndSettle();

    expect(find.text('Nothing blocked yet'), findsOneWidget);
    expect(find.text('Keep blocking running'), findsOneWidget);

    await tester.tap(find.text('Mindful pause'));
    await tester.pumpAndSettle();
    expect(screenTime.savedRules.last.style, BlockStyle.pause);

    // Per-app rules sheet: always block + a daily limit.
    await tester.scrollUntilVisible(
      find.text('Video'),
      200,
      scrollable: pageScrollable,
    );
    await tester.tap(find.text('Video'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, 'Always block'));
    await tester.pumpAndSettle();
    expect(screenTime.savedRules.last.alwaysBlocked, {'com.Video'});
    await tester.tap(find.widgetWithText(ChoiceChip, '30 min'));
    await tester.pumpAndSettle();
    expect(screenTime.savedRules.last.dailyLimits, {'com.Video': 30});
    expect(screenTime.savedRules.last.style, BlockStyle.pause); // kept
    await tester.tapAt(const Offset(10, 10)); // close the sheet
    await tester.pumpAndSettle();

    expect(find.text('Always blocked · 30 min a day'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ch');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Chat'),
      200,
      scrollable: pageScrollable,
    );
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Video'), findsNothing);
  });

  testWidgets('blocking: badge, dismiss tip, one-tap block, category search', (
    tester,
  ) async {
    final screenTime = FakeScreenTime()
      ..batteryUnrestricted = false
      ..installed = [
        appOf('Chat', AppCategory.social),
        appOf('Notes', AppCategory.productivity),
      ];
    await startApp(
      tester,
      prefs: {'onboarding_done': true},
      screenTime: screenTime,
    );
    await tester.tap(find.text('Blocking').last);
    await tester.pumpAndSettle();

    expect(find.text('OFF'), findsOneWidget);
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text('Keep blocking running'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('2 total'),
      200,
      scrollable: pageScrollable,
    );
    expect(find.text('0 restricted'), findsOneWidget);

    // Only the social app offers "+ Block"; the other one shows Configure.
    await tester.ensureVisible(find.text('+ Block'));
    await tester.pumpAndSettle();
    expect(find.text('Configure'), findsOneWidget);
    await tester.tap(find.text('+ Block'));
    await tester.pumpAndSettle();
    expect(screenTime.savedRules.last.alwaysBlocked, {'com.Chat'});
    expect(find.text('Always blocked'), findsOneWidget);
    expect(find.text('1 restricted'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'productivity');
    await tester.pumpAndSettle();
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Chat'), findsNothing);

    // The header scrolls with the list.
    await tester.scrollUntilVisible(
      find.text('ACTIVE'),
      -200,
      scrollable: pageScrollable,
    );
  });

  testWidgets('schedule editor saves a weekday work-hours schedule', (
    tester,
  ) async {
    final screenTime = FakeScreenTime()
      ..installed = [appOf('Chat'), appOf('Video')];
    await startApp(
      tester,
      prefs: {'onboarding_done': true},
      screenTime: screenTime,
    );
    await tester.tap(find.text('Blocking').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add schedule'));
    await tester.pumpAndSettle();

    expect(find.text('New schedule'), findsOneWidget);
    final save = find.widgetWithText(FilledButton, 'Save schedule');
    // No apps picked yet.
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.ensureVisible(find.widgetWithText(CheckboxListTile, 'Chat'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Chat'));
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    final schedule = screenTime.savedRules.last.schedules.single;
    expect(schedule.name, 'Work hours');
    expect(schedule.days, {1, 2, 3, 4, 5});
    expect((schedule.startMinute, schedule.endMinute), (540, 1020));
    expect(schedule.packages, {'com.Chat'});
    expect(find.text('Work hours'), findsOneWidget);
    expect(find.textContaining('Weekdays'), findsOneWidget);
  });

  testWidgets('new session sheet: presets, select all, clear all', (
    tester,
  ) async {
    final screenTime = FakeScreenTime()
      ..installed = [appOf('Chat'), appOf('Video')];
    await startApp(
      tester,
      prefs: {'onboarding_done': true},
      screenTime: screenTime,
    );
    await tester.tap(find.text('Focus').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('distractions stopped'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(FocusView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Start focus session'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('50 min'));
    await tester.pumpAndSettle();
    expect(Get.find<FocusViewModel>().minutes.value, 50);
    expect(find.text('50 min'), findsNWidgets(2)); // headline + chip

    await tester.ensureVisible(find.text('Select all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    expect(find.text('Apps to block (2)', findRichText: true), findsOneWidget);
    expect(find.text('Blocked during focus'), findsNWidgets(2));

    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    final start = find.widgetWithText(FilledButton, 'Pick at least one app');
    expect(tester.widget<FilledButton>(start).onPressed, isNull);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('New focus session'), findsNothing);
  });

  testWidgets('schedule editor: quick days, select all, clear name, back', (
    tester,
  ) async {
    final screenTime = FakeScreenTime()
      ..installed = [appOf('Chat'), appOf('Video', AppCategory.video)];
    await startApp(
      tester,
      prefs: {'onboarding_done': true},
      screenTime: screenTime,
    );
    await tester.tap(find.text('Blocking').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add schedule'));
    await tester.pumpAndSettle();

    expect(find.text('8 h'), findsOneWidget); // 9:00 to 17:00
    await tester.tap(find.text('Every day'));
    await tester.pumpAndSettle();
    expect(Get.find<ScheduleEditorViewModel>().days, {1, 2, 3, 4, 5, 6, 7});

    await tester.tap(find.byTooltip('Clear name'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Clear name'), findsNothing);

    await tester.ensureVisible(find.text('Select all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    expect(find.text('Clear all'), findsOneWidget);
    // Apps and days are set, but a schedule needs a name.
    final save = find.widgetWithText(FilledButton, 'Save schedule');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('New schedule'), findsNothing);
    expect(screenTime.savedRules, isEmpty);
  });

  testWidgets('settings: notifications status and privacy sheet', (
    tester,
  ) async {
    final screenTime = FakeScreenTime()..notifications = false;
    await startApp(
      tester,
      prefs: {'onboarding_done': true},
      screenTime: screenTime,
    );
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();

    expect(find.text('Off'), findsOneWidget);
    expect(find.text('Notifications are off'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Privacy'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(SettingsView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Privacy'));
    await tester.pumpAndSettle();
    expect(find.textContaining('stored only on this phone'), findsOneWidget);
  });

  testWidgets('focus: start a session, see the countdown, stop it', (
    tester,
  ) async {
    final screenTime = FakeScreenTime()
      ..installed = [appOf('Chat'), appOf('Video')];
    await startApp(
      tester,
      prefs: {'onboarding_done': true},
      screenTime: screenTime,
    );
    await tester.tap(find.text('Focus').last);
    await tester.pumpAndSettle();

    // Scroll past the button to the stat cards, so it isn't under the nav bar.
    await tester.scrollUntilVisible(
      find.text('distractions stopped'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(FocusView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Start focus session'));
    await tester.pumpAndSettle();
    expect(find.text('New focus session'), findsOneWidget);
    final disabled = find.widgetWithText(FilledButton, 'Pick at least one app');
    expect(tester.widget<FilledButton>(disabled).onPressed, isNull);

    await tester.scrollUntilVisible(
      find.widgetWithText(CheckboxListTile, 'Video'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(DraggableScrollableSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.widgetWithText(CheckboxListTile, 'Video'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Video'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start session'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // sheet closes

    expect(screenTime.activeFocus!.packages, {'com.Video'});
    expect(find.textContaining(RegExp(r'^2[45]:\d\d$')), findsOneWidget);
    expect(find.text('Stop session'), findsOneWidget);

    await tester.tap(find.text('Stop session'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    expect(screenTime.activeFocus, isNull);
    await tester.scrollUntilVisible(
      find.textContaining('Stopped after'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(FocusView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.textContaining('Stopped after'), findsOneWidget);
  });

  testWidgets('focus home shows today, yesterday, streak and stats', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12);
    final yesterday = DateTime(now.year, now.month, now.day - 1, 12);
    FocusSession done(DateTime start, int minutes) => FocusSession(
      startedAt: start,
      endsAt: start.add(Duration(minutes: minutes)),
      packages: const {'com.Video'},
      strict: false,
      endedAt: start.add(Duration(minutes: minutes)),
    );
    final screenTime = FakeScreenTime()
      ..focusHistory = [done(yesterday, 30), done(today, 45)]
      ..interceptions = 5
      ..usage = [usageOf('Video app', const Duration(minutes: 70))];
    await startApp(
      tester,
      prefs: {'onboarding_done': true},
      screenTime: screenTime,
    );
    await tester.tap(find.text('Focus').last);
    await tester.pumpAndSettle();

    expect(find.text('2d streak'), findsOneWidget);
    // Goal is 2 h by default.
    expect(
      find.textContaining('1 h 15 min left', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('45 min'), findsWidgets); // ring
    expect(find.text('38% completed'), findsOneWidget);
    expect(find.text('+15 min vs yesterday'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('distractions stopped'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(FocusView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('5'), findsOneWidget);
    expect(find.text('1 h 10 min'), findsOneWidget); // screen time today
  });

  testWidgets('dashboard: live focus card stays in sync, then settles', (
    tester,
  ) async {
    final now = DateTime.now();
    final screenTime = FakeScreenTime()
      ..installed = [appOf('Chat')]
      ..focusHistory = [
        // A finished 20-minute session earlier today (or just after
        // midnight when the test runs early in the day).
        FocusSession(
          startedAt: now.subtract(const Duration(minutes: 40)),
          endsAt: now.subtract(const Duration(minutes: 20)),
          packages: const {'com.Chat'},
          strict: false,
          endedAt: now.subtract(const Duration(minutes: 20)),
        ),
      ]
      ..activeFocus = FocusSession(
        startedAt: now.subtract(const Duration(minutes: 10)),
        endsAt: now.add(const Duration(minutes: 15)),
        packages: const {'com.Chat'},
        strict: false,
      );
    await startApp(
      tester,
      prefs: {'onboarding_done': true},
      screenTime: screenTime,
      settle: false,
    );
    await tester.pump(const Duration(milliseconds: 500));
    final focus = Get.find<FocusViewModel>();
    String hms() => formatHms(focus.elapsed);

    // Elapsed comes from the saved start time, not a counter.
    await tester.ensureVisible(find.text('FOCUS SESSION · LIVE'));
    expect(find.text(hms()), findsOneWidget);
    expect(hms(), matches(RegExp(r'^00:1[01]:\d\d$')));
    expect(find.text('Start a focus session'), findsNothing);
    final midnight = DateTime(now.year, now.month, now.day);
    // Today's part of both sessions (both are fully today unless the test
    // runs in the first 40 minutes after midnight).
    if (now.difference(midnight) > const Duration(minutes: 41)) {
      expect(
        formatHms(focus.focusedToday),
        matches(RegExp(r'^00:3[01]:\d\d$')),
      );
    }

    // Ticks every second without a refresh.
    final before = hms();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1100)),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(hms(), isNot(before));
    expect(find.text(hms()), findsOneWidget);

    // The Focus tab reads the same view model.
    await tester.tap(find.text('Open session'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Focusing'), findsOneWidget);
    await tester.tap(find.text('Dashboard').last);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(hms()), findsOneWidget);

    // Background and back: re-read from the native store, same numbers.
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
    await tester.pump(const Duration(milliseconds: 500));
    expect(hms(), matches(RegExp(r'^00:1[01]:\d\d$')));

    // Stop on the Focus tab: the dashboard settles to the idle total, with
    // the stopped session counted once.
    await tester.tap(find.text('Focus').last);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Stop session'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Stop'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(focus.active.value, isNull);
    await tester.tap(find.text('Dashboard').last);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('FOCUS SESSION · LIVE'), findsNothing);
    await tester.ensureVisible(find.text('Total focus time today'));
    if (now.difference(midnight) > const Duration(minutes: 41)) {
      expect(find.textContaining(RegExp(r'^00:3[01]:\d\d$')), findsOneWidget);
    }
    expect(find.text('Start a focus session'), findsOneWidget);
  });

  testWidgets('app restart picks up the running session from storage', (
    tester,
  ) async {
    final now = DateTime.now();
    final screenTime = FakeScreenTime()
      ..activeFocus = FocusSession(
        startedAt: now.subtract(const Duration(minutes: 42)),
        endsAt: now.add(const Duration(minutes: 8)),
        packages: const {'com.Chat'},
        strict: false,
      );
    await startApp(
      tester,
      prefs: {'onboarding_done': true},
      screenTime: screenTime,
      settle: false,
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.textContaining(RegExp(r'^00:4[23]:\d\d$')),
      findsAtLeastNWidgets(1),
    );
    // Stops the 1-second countdown timer before the test ends.
    await Get.delete<FocusViewModel>(force: true);
  });

  testWidgets('focus: a strict session offers no way to stop', (tester) async {
    final now = DateTime.now();
    final screenTime = FakeScreenTime()
      ..activeFocus = FocusSession(
        startedAt: now,
        endsAt: now.add(const Duration(minutes: 50)),
        packages: const {'com.Video'},
        strict: true,
      );
    await startApp(
      tester,
      prefs: {'onboarding_done': true},
      screenTime: screenTime,
    );
    await tester.tap(find.text('Focus').last);
    await tester.pump();

    expect(find.textContaining("can't be stopped early"), findsOneWidget);
    expect(find.text('Stop session'), findsNothing);
    // Stops the 1-second countdown timer before the test ends.
    await Get.delete<FocusViewModel>(force: true);
  });

  testWidgets('settings: editing the target updates the dashboard and recap', (
    tester,
  ) async {
    final screenTime = FakeScreenTime()
      ..usage = [usageOf('Video app', const Duration(minutes: 75))];
    final repo = await startApp(
      tester,
      prefs: {'onboarding_done': true},
      screenTime: screenTime,
    );
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Daily screen-time target'));
    await tester.pumpAndSettle();

    // Slide to the left end: 1 h.
    await tester.drag(find.byType(Slider), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.dailyTargetMinutes, 60);
    expect(screenTime.recap?.targetMinutes, 60);
    await tester.tap(find.text('Dashboard').last);
    await tester.pumpAndSettle();
    expect(find.text('15 min over target'), findsOneWidget); // ring pill

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly recap'));
    await tester.pumpAndSettle();
    expect(repo.weeklyRecap, isFalse);
    expect(screenTime.recap?.enabled, isFalse);
  });

  testWidgets('large text (200%): every screen lays out without overflow', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final now = DateTime.now();
    final screenTime = FakeScreenTime()
      ..usage = [
        usageOf('A video app with a long name', const Duration(minutes: 250)),
      ]
      ..installed = [appOf('Chat'), appOf('A video app with a long name')]
      ..notifications = false
      ..batteryUnrestricted = false
      ..rules = const BlockingRules(
        dailyLimits: {'com.Chat': 30},
        schedules: [
          BlockSchedule(
            id: '1',
            name: 'Work hours',
            days: {1, 2, 3, 4, 5},
            startMinute: 540,
            endMinute: 1020,
            packages: {'com.Chat'},
          ),
        ],
      )
      ..focusHistory = [
        FocusSession(
          startedAt: now.subtract(const Duration(hours: 1)),
          endsAt: now.subtract(const Duration(minutes: 35)),
          packages: const {'com.Chat'},
          strict: false,
          endedAt: now.subtract(const Duration(minutes: 35)),
        ),
      ];

    // Onboarding pages first. Taps are covered by the onboarding test; here
    // each page only needs to be laid out at 200%.
    await startApp(tester, screenTime: screenTime);
    final onboarding = Get.find<OnboardingViewModel>();
    await onboarding.next();
    await tester.pumpAndSettle();
    onboarding.toggleGoal(FocusGoal.sleepBetter);
    await onboarding.next();
    await tester.pumpAndSettle();
    await onboarding.next();
    await tester.pumpAndSettle();

    // Two permissions are off here, so the permission steps come next.
    expect(find.text('Allow notifications'), findsOneWidget);
    screenTime
      ..notifications = true
      ..batteryUnrestricted = true;
    await Get.find<PermissionsViewModel>().recheck();
    await tester.pumpAndSettle();
    // Off again so Blocking shows its tip cards at this size too.
    screenTime
      ..notifications = false
      ..batteryUnrestricted = false;
    await tester.tap(find.text('Go to dashboard'));
    await tester.pumpAndSettle();

    for (final tab in ['Focus', 'Blocking', 'Settings', 'Dashboard']) {
      await tester.tap(find.byTooltip(tab));
      await tester.pumpAndSettle();
    }
    // Any RenderFlex overflow above would have failed the test already.
  });

  test('formatMinutes', () {
    expect(formatMinutes(45), '45 min');
    expect(formatMinutes(60), '1 h');
    expect(formatMinutes(150), '2 h 30 min');
    expect(formatClock(const Duration(minutes: 24, seconds: 5)), '24:05');
    expect(
      formatClock(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
  });
}
