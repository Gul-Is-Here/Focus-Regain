import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/theme/app_theme.dart';
import 'data/platform/screen_time_api.dart';
import 'data/platform/screen_time_channel.dart';
import 'data/repositories/app_icon_cache.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/push_messaging.dart';
import 'data/repositories/reminder_store.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/usage_history_repository.dart';
import 'firebase_options.dart';
import 'modules/notifications/notification_center.dart';
import 'modules/permissions/permissions_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Debug only: --dart-define=FIRESTORE_EMULATOR_HOST=<computer's IP>.
  const emulatorHost = String.fromEnvironment('FIRESTORE_EMULATOR_HOST');
  if (emulatorHost.isNotEmpty) {
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
  }
  final prefs = await SharedPreferences.getInstance();
  final screenTime = Get.put<ScreenTimeApi>(
    ScreenTimeChannel(),
    permanent: true,
  );
  final settings = Get.put(SettingsRepository(prefs), permanent: true);
  final auth = Get.put<AuthRepository>(
    FirebaseAuthRepository(),
    permanent: true,
  );
  final notifications = Get.put(
    NotificationCenter(
      FirebasePushMessaging(),
      FirestoreReminderStore(),
      auth,
      settings,
      screenTime,
    ),
    permanent: true,
  );
  // "Remember me" was off: this launch starts signed out.
  if (!settings.rememberMe && auth.currentUser != null) {
    await notifications.onSignedOut();
    await auth.signOut();
  }
  if (auth.currentUser != null) unawaited(notifications.onSignedIn());
  Get.put(UsageHistoryRepository(prefs, screenTime), permanent: true);
  Get.put(AppIconCache(screenTime), permanent: true);
  _registerFontLicenses();
  runApp(RegainApp(needsPermissions: await _missingPermissions(screenTime)));
  // Force-stopping the app clears its alarms, so re-schedule the recap on every launch.
  if (screenTime.isSupported && settings.onboardingDone) {
    screenTime
        .configureWeeklyRecap(
          enabled: settings.weeklyRecap,
          targetMinutes: settings.dailyTargetMinutes,
        )
        .catchError((Object e) => debugPrint('Weekly recap not scheduled: $e'));
  }
}

/// True if any permission is off, so the app opens on the permission steps
/// instead of the dashboard.
Future<bool> _missingPermissions(ScreenTimeApi screenTime) async {
  if (!screenTime.isSupported) return false;
  try {
    final granted = await PermissionsViewModel.check(screenTime);
    return granted.length < AppPermission.values.length;
  } on Exception {
    return true; // The permission screen checks again and explains.
  }
}

// The OFL requires bundled fonts to ship with their licence; this lists them in showLicensePage.
void _registerFontLicenses() {
  for (final font in ['PlusJakartaSans']) {
    LicenseRegistry.addLicense(() async* {
      final text = await rootBundle.loadString('assets/fonts/OFL-$font.txt');
      yield LicenseEntryWithLineBreaks([font], text);
    });
  }
}

class RegainApp extends StatelessWidget {
  const RegainApp({super.key, this.needsPermissions = false});

  /// Some permission is off: open on the permission steps, not the app.
  final bool needsPermissions;

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<SettingsRepository>();
    final signedIn = Get.find<AuthRepository>().currentUser != null;
    return GetMaterialApp(
      title: 'Focus Regain',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      // An account is required before anything else.
      initialRoute: !signedIn
          ? AppRoutes.login
          : !settings.onboardingDone
          ? AppRoutes.onboarding
          : needsPermissions
          ? AppRoutes.permissions
          : AppRoutes.shell,
      getPages: AppPages.pages,
    );
  }
}
