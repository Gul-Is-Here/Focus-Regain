// Store screenshots only: the real app UI with made-up data, so no real
// usage, account or installed apps appear in the listing.
// flutter run -t store_listing/demo_main.dart -d emulator-5554
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:regain_app/data/models/app_category.dart';
import 'package:regain_app/data/models/blocking_rules.dart';
import 'package:regain_app/data/models/focus_session.dart';
import 'package:regain_app/data/models/notification_prefs.dart';
import 'package:regain_app/data/platform/screen_time_api.dart';
import 'package:regain_app/data/repositories/app_icon_cache.dart';
import 'package:regain_app/data/repositories/auth_repository.dart';
import 'package:regain_app/data/repositories/settings_repository.dart';
import 'package:regain_app/data/repositories/usage_history_repository.dart';
import 'package:regain_app/main.dart';
import 'package:regain_app/modules/notifications/notification_center.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/fakes.dart';

const _apps = [
  ('Loopwave', AppCategory.video),
  ('Circle', AppCategory.social),
  ('Chatline', AppCategory.social),
  ('Headlines', AppCategory.news),
  ('Block Builder', AppCategory.games),
  ('Snapshot', AppCategory.images),
  ('Tunes', AppCategory.audio),
  ('Mail', AppCategory.productivity),
  ('Calendar', AppCategory.productivity),
  ('Notes', AppCategory.productivity),
  ('Maps', AppCategory.maps),
  ('Camera', AppCategory.images),
];

String _pkg(String label) => 'com.$label';

/// Plain coloured letter tiles, so no real app's logo appears in the listing.
class _DemoScreenTime extends FakeScreenTime {
  final icons = <String, Uint8List>{};

  @override
  Future<Uint8List?> getAppIcon(String packageName) async => icons[packageName];
}

const _tileColors = [
  Color(0xFFE2725B),
  Color(0xFF5B8DEF),
  Color(0xFF3FB68B),
  Color(0xFFF2B33D),
  Color(0xFF9B6BDF),
  Color(0xFFE85D9A),
  Color(0xFF4FB3C9),
  Color(0xFF7A8B99),
];

Future<Uint8List> _tile(String label, Color color) async {
  const size = 144.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, size, size),
      const Radius.circular(40),
    ),
    Paint()..color = color,
  );
  final text = TextPainter(
    text: TextSpan(
      text: label[0],
      style: const TextStyle(
        color: Color(0xFFFFFFFF),
        fontSize: 72,
        fontWeight: FontWeight.w700,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  text.paint(canvas, Offset((size - text.width) / 2, (size - text.height) / 2));
  final image = await recorder.endRecording().toImage(
    size.toInt(),
    size.toInt(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const theme = String.fromEnvironment('THEME', defaultValue: 'dark');
  // In-memory prefs: a fresh demo state every launch, the phone's own untouched.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({
    'onboarding_done': true,
    'daily_target_minutes': 180,
    'theme_mode': theme,
    'focus_packages': [_pkg('Loopwave'), _pkg('Circle'), _pkg('Headlines')],
  });
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  // Past week in minutes, oldest first; today is the usage list below.
  const week = [212, 175, 168, 151, 143, 132, 126];
  final screenTime = _DemoScreenTime();
  for (var i = 0; i < _apps.length; i++) {
    final label = _apps[i].$1;
    screenTime.icons[_pkg(label)] = await _tile(
      label,
      _tileColors[i % _tileColors.length],
    );
  }
  screenTime
    ..usage = [
      usageOf('Loopwave', const Duration(minutes: 38), AppCategory.video),
      usageOf('Circle', const Duration(minutes: 24), AppCategory.social),
      usageOf('Chatline', const Duration(minutes: 19), AppCategory.social),
      usageOf('Headlines', const Duration(minutes: 12), AppCategory.news),
      usageOf('Mail', const Duration(minutes: 9), AppCategory.productivity),
      usageOf('Maps', const Duration(minutes: 6), AppCategory.maps),
      usageOf('Tunes', const Duration(minutes: 4), AppCategory.audio),
    ]
    ..usageByDay = {
      for (var i = 0; i < week.length; i++)
        DateTime(today.year, today.month, today.day - week.length + i): [
          usageOf('Loopwave', Duration(minutes: week[i]), AppCategory.video),
        ],
    }
    ..installed = [for (final (l, c) in _apps) appOf(l, c)]
    ..rules = BlockingRules(
      alwaysBlocked: {_pkg('Block Builder')},
      dailyLimits: {_pkg('Loopwave'): 45, _pkg('Circle'): 30},
      schedules: [
        BlockSchedule(
          id: 'work',
          name: 'Deep work',
          days: const {1, 2, 3, 4, 5},
          startMinute: 9 * 60,
          endMinute: 13 * 60,
          packages: {_pkg('Circle'), _pkg('Headlines'), _pkg('Loopwave')},
        ),
        BlockSchedule(
          id: 'bed',
          name: 'Wind down',
          days: const {1, 2, 3, 4, 5, 6, 7},
          startMinute: 22 * 60 + 30,
          endMinute: 7 * 60,
          packages: {_pkg('Loopwave'), _pkg('Circle'), _pkg('Block Builder')},
        ),
      ],
      style: BlockStyle.pause,
    )
    ..focusHistory = [
      for (var d = 6; d >= 1; d--)
        FocusSession(
          startedAt: today
              .subtract(Duration(days: d))
              .add(const Duration(hours: 10)),
          endsAt: today
              .subtract(Duration(days: d))
              .add(const Duration(hours: 10, minutes: 50)),
          packages: const {},
          strict: false,
          endedAt: today
              .subtract(Duration(days: d))
              .add(const Duration(hours: 10, minutes: 50)),
        ),
      FocusSession(
        startedAt: today.add(const Duration(hours: 7, minutes: 30)),
        endsAt: today.add(const Duration(hours: 8, minutes: 20)),
        packages: const {},
        strict: false,
        endedAt: today.add(const Duration(hours: 8, minutes: 20)),
      ),
    ]
    ..interceptions = 7;
  if (const bool.fromEnvironment('FOCUSING')) {
    screenTime.activeFocus = FocusSession(
      startedAt: now.subtract(const Duration(minutes: 18)),
      endsAt: now.add(const Duration(minutes: 32)),
      packages: {_pkg('Loopwave'), _pkg('Circle'), _pkg('Headlines')},
      strict: false,
    );
  }

  final prefs = await SharedPreferences.getInstance();
  final api = Get.put<ScreenTimeApi>(screenTime, permanent: true);
  final settings = Get.put(SettingsRepository(prefs), permanent: true);
  final auth = Get.put<AuthRepository>(FakeAuth(), permanent: true);
  final reminders = FakeReminderStore()
    ..prefs = const NotificationPrefs(
      focusNudge: TimedReminder(enabled: true, minute: 18 * 60),
      dailySummary: TimedReminder(enabled: true, minute: 21 * 60),
    );
  final center = Get.put(
    NotificationCenter(
      FakePush(),
      reminders,
      auth,
      settings,
      api,
      timezone: () async => 'Europe/London',
    ),
    permanent: true,
  );
  await center.onSignedIn();
  Get.put(UsageHistoryRepository(prefs, api), permanent: true);
  Get.put(AppIconCache(api), permanent: true);
  runApp(const RegainApp());
}
