import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:regain_app/data/platform/screen_time_api.dart';
import 'package:regain_app/data/repositories/app_icon_cache.dart';
import 'package:regain_app/data/repositories/auth_repository.dart';
import 'package:regain_app/data/repositories/settings_repository.dart';
import 'package:regain_app/data/repositories/usage_history_repository.dart';
import 'package:regain_app/main.dart';
import 'package:regain_app/modules/notifications/notification_center.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

/// Typical Android phone, in logical pixels.
const phone = Size(360, 800);
const tablet = Size(800, 1280);
const desktop = Size(1440, 900);

/// Registers fakes and pumps the app at [size] (a phone by default instead
/// of the 800x600 test default). With [settle] false it returns after the
/// first frame, e.g. to see loading placeholders.
Future<SettingsRepository> startApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  FakeScreenTime? screenTime,
  FakeAuth? auth,
  bool needsPermissions = false,
  FakePush? push,
  FakeReminderStore? reminders,
  Future<String> Function()? timezone,
  Size size = phone,
  bool settle = true,
}) async {
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.resetStatic();
  SharedPreferences.setMockInitialValues(prefs);
  final store = await SharedPreferences.getInstance();
  final api = Get.put<ScreenTimeApi>(screenTime ?? FakeScreenTime());
  final repo = Get.put(SettingsRepository(store));
  // Signed in unless a test passes a signed-out fake.
  Get.put<AuthRepository>(auth ?? FakeAuth());
  Get.put(UsageHistoryRepository(store, api));
  Get.put(AppIconCache(api));
  final center = Get.put(
    NotificationCenter(
      push ?? FakePush(),
      reminders ?? FakeReminderStore(),
      Get.find(),
      repo,
      api,
      timezone: timezone ?? () async => 'Asia/Karachi',
    ),
  );
  // As main() does at launch.
  if (Get.find<AuthRepository>().currentUser != null) {
    unawaited(center.onSignedIn());
  }
  await tester.pumpWidget(RegainApp(needsPermissions: needsPermissions));
  if (settle) await tester.pumpAndSettle();
  return repo;
}
