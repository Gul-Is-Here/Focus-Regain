import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:regain_app/app/widgets/progress_ring.dart';
import 'package:regain_app/data/models/app_category.dart';
import 'package:regain_app/app/widgets/shimmer.dart';
import 'package:regain_app/modules/dashboard/dashboard_view.dart';
import 'package:regain_app/modules/dashboard/dashboard_view_model.dart';

import 'fakes.dart';
import 'test_app.dart';

const _ready = {'onboarding_done': true};

/// The shimmer's own animation (other tabs show their own spinners).
AnimationController _shimmerAnimation(WidgetTester tester) =>
    tester
            .widget<AnimatedBuilder>(
              find
                  .descendant(
                    of: find.byType(Shimmer),
                    matching: find.byType(AnimatedBuilder),
                  )
                  .first,
            )
            .animation
        as AnimationController;

Finder get _dashboardList => find
    .descendant(
      of: find.byType(DashboardView),
      matching: find.byType(Scrollable),
    )
    .first;

void main() {
  setUp(Get.reset);

  testWidgets('shows shimmer placeholders while the first load runs', (
    tester,
  ) async {
    final screenTime = FakeScreenTime()
      ..gate = Completer()
      ..usage = [usageOf('Video app', const Duration(minutes: 40))];
    await startApp(
      tester,
      prefs: _ready,
      screenTime: screenTime,
      settle: false,
    );
    await tester.pump();
    expect(find.byType(Shimmer), findsOneWidget);
    expect(find.byType(ProgressRing), findsNothing);
    expect(_shimmerAnimation(tester).isAnimating, isTrue);

    screenTime.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(Shimmer), findsNothing);
    expect(find.text('TOTAL TODAY'), findsOneWidget);
  });

  testWidgets('with reduced motion the placeholders stay still', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final screenTime = FakeScreenTime()..gate = Completer();
    await startApp(
      tester,
      prefs: _ready,
      screenTime: screenTime,
      settle: false,
    );
    await tester.pump();
    expect(find.byType(Shimmer), findsOneWidget);
    expect(_shimmerAnimation(tester).isAnimating, isFalse);
    screenTime.gate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a failed refresh keeps the numbers and offers a retry', (
    tester,
  ) async {
    final screenTime = FakeScreenTime()
      ..usage = [usageOf('Video app', const Duration(minutes: 40))];
    await startApp(tester, prefs: _ready, screenTime: screenTime);
    expect(find.text('40 min'), findsWidgets);

    screenTime.failUsage = true;
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't update"), findsOneWidget);
    expect(find.text('TOTAL TODAY'), findsOneWidget); // content kept
    expect(find.text('40 min'), findsWidgets);

    screenTime
      ..failUsage = false
      ..usage = [usageOf('Video app', const Duration(minutes: 50))];
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't update"), findsNothing);
    expect(find.text('50 min'), findsWidgets);
  });

  testWidgets('today updates live while the app is visible', (tester) async {
    final screenTime = FakeScreenTime()
      ..usage = [usageOf('Video app', const Duration(minutes: 40))];
    await startApp(tester, prefs: _ready, screenTime: screenTime);
    final vm = Get.find<DashboardViewModel>();
    expect(vm.total, const Duration(minutes: 40));

    // More use happens; no tap, no pull to refresh.
    screenTime.usage = [usageOf('Video app', const Duration(minutes: 41))];
    await tester.pump(DashboardViewModel.livePeriod);
    await tester.pump();
    expect(vm.total, const Duration(minutes: 41));
    expect(find.text('41 min'), findsWidgets);
    expect(vm.refreshing.value, isFalse); // no progress bar for live updates

    // A failed live update keeps the numbers and shows no banner.
    screenTime.failUsage = true;
    await tester.pump(DashboardViewModel.livePeriod);
    await tester.pump();
    expect(find.text("Couldn't update"), findsNothing);
    expect(vm.total, const Duration(minutes: 41));

    // Hidden: no updates. Shown again: updates resume.
    screenTime
      ..failUsage = false
      ..usage = [usageOf('Video app', const Duration(minutes: 45))];
    for (final state in const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump(DashboardViewModel.livePeriod * 2);
    expect(vm.total, const Duration(minutes: 41));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(DashboardViewModel.livePeriod);
    await tester.pump();
    expect(vm.total, const Duration(minutes: 45));
  });

  testWidgets('first load failure shows an error with a retry', (tester) async {
    final screenTime = FakeScreenTime()..failUsage = true;
    await startApp(tester, prefs: _ready, screenTime: screenTime);
    expect(find.textContaining("Couldn't read your screen time"), findsOne);

    screenTime.failUsage = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('TOTAL TODAY'), findsOneWidget);
  });

  testWidgets('groups today by app category, largest first', (tester) async {
    final screenTime = FakeScreenTime()
      ..usage = [
        usageOf('Chat', const Duration(minutes: 50), AppCategory.social),
        usageOf('Photos feed', const Duration(minutes: 30), AppCategory.social),
        usageOf('Video', const Duration(minutes: 45), AppCategory.video),
        usageOf('Notes', const Duration(minutes: 20), AppCategory.productivity),
        usageOf('Puzzle', const Duration(minutes: 5), AppCategory.games),
      ];
    await startApp(tester, prefs: _ready, screenTime: screenTime);
    await tester.ensureVisible(find.text('MOST USED CATEGORIES'));
    await tester.pumpAndSettle();

    final social = tester.getTopLeft(find.text('Social networking'));
    final video = tester.getTopLeft(find.text('Entertainment & video'));
    final work = tester.getTopLeft(find.text('Productivity & utilities'));
    expect(social.dy < video.dy && video.dy < work.dy, isTrue);
    expect(find.text('1 h 20 min'), findsOneWidget); // 50 + 30 social
    expect(find.text('Games'), findsNothing); // only the top 3 are shown
  });

  testWidgets('Details lists every app used today', (tester) async {
    final screenTime = FakeScreenTime()
      ..usage = [
        for (var i = 1; i <= 7; i++)
          usageOf('App $i', Duration(minutes: 80 - i * 10)),
      ];
    await startApp(tester, prefs: _ready, screenTime: screenTime);
    // The dashboard is one scrolling column, so ensureVisible (not
    // scrollUntilVisible) is what brings a card on screen.
    await tester.ensureVisible(find.text('Details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    expect(find.text('7 apps'), findsOneWidget);
    expect(find.text('App 1'), findsOneWidget);
    await tester.ensureVisible(find.text('App 7'));
    await tester.pumpAndSettle();
    expect(find.text('App 7'), findsOneWidget);
  });

  testWidgets('no usage today shows an empty state', (tester) async {
    await startApp(tester, prefs: _ready);
    await tester.ensureVisible(find.text('MOST USED CATEGORIES'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No app usage yet today'), findsOneWidget);
    expect(find.text('Details'), findsNothing);
  });

  testWidgets('primary and secondary actions open Focus and Blocking', (
    tester,
  ) async {
    await startApp(tester, prefs: _ready);
    await tester.tap(find.text('Start a focus session'));
    await tester.pumpAndSettle();
    expect(find.text('Ready to focus today?').hitTestable(), findsOneWidget);

    await tester.tap(find.text('Dashboard').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Manage blocked apps and limits'));
    await tester.tap(find.text('Manage blocked apps and limits'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing blocked yet').hitTestable(), findsOneWidget);
  });

  for (final (name, size) in [
    ('phone', phone),
    ('tablet', tablet),
    ('desktop', desktop),
  ]) {
    for (final theme in ['light', 'dark']) {
      testWidgets('$name, $theme theme: lays out without overflow', (
        tester,
      ) async {
        final screenTime = FakeScreenTime()
          ..usage = [
            usageOf(
              'A video app with a rather long name',
              Duration(minutes: 190),
            ),
            for (var i = 1; i <= 6; i++)
              usageOf('App $i', Duration(minutes: 30 - i)),
          ];
        await startApp(
          tester,
          prefs: {..._ready, 'theme_mode': theme},
          screenTime: screenTime,
          size: size,
        );
        expect(Get.isDarkMode, theme == 'dark');
        expect(find.text('TOTAL TODAY'), findsOneWidget);
        // Bottom bar on phones and tablets in portrait, side rail on desktop.
        expect(
          find.byType(NavigationRail),
          size.width >= 840 ? findsOneWidget : findsNothing,
        );
        // Scroll through the whole dashboard; any overflow fails the test.
        await tester.fling(_dashboardList, const Offset(0, -3000), 3000);
        await tester.pumpAndSettle();
        expect(
          Get.find<DashboardViewModel>().status.value,
          DashboardStatus.ready,
        );
      });
    }
  }
}
