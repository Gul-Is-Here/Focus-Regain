---
name: regain-build
description: Step-by-step build plan for the regain_app Flutter focus / screen-time app (package com.focuseregain.app). Use when continuing work on this app, picking the next phase, or checking which features are done.
---

# Regain App — Build Plan

An original focus and screen-time app built with Flutter. It helps users notice
how much they use their phone, block distracting apps, and build better habits.
The features below are the usual set for this kind of app. Do not copy another
app's code, assets, text or screen designs: the design, naming and copy are our own.

- Package / bundle ID: `com.focuseregain.app`
- Flutter 3.47 / Dart ^3.13, Android + iOS first (desktop and web are out of scope)
- Work one phase at a time. Tick each box when done, and run its **Done when** check before moving on.

## Feature list

### Core (MVP)
1. **Onboarding:** explain what the app does, ask a few questions (goals, daily screen-time target), and walk through the permission screens with a clear reason for each.
2. **Screen-time dashboard:** today's total, a per-app breakdown, pickups/unlocks, and the trend for the last 7 days.
3. **App blocking:** pick apps; show a block screen when one is opened.
4. **Daily limits:** a time budget per app or group; block once it is used up.
5. **Focus sessions:** a timer (e.g. 25/50 min) that blocks selected apps until it ends, with an optional strict mode (no early exit).
6. **Schedules:** recurring block windows (work hours, bedtime).
7. **Mindful pause:** a short breathing screen with a "do you really want to open X?" prompt before a blocked app, instead of a hard block.
8. **Streaks and stats:** days under target, focus minutes, weekly summary.
9. **Notifications:** limit warnings, session end, daily/weekly recap.
10. **Settings:** edit goals, permissions status, data reset, privacy info.

### Later
11. Accounts + cloud sync with Firebase Auth + Firestore (Firebase is already connected: project `regain-focuse`, `lib/firebase_options.dart`).
12. AI coach: personalised tips from usage trends (only aggregated data leaves the device, with consent).
13. Subscriptions / paywall (RevenueCat or `in_app_purchase`).
14. Home-screen widgets, an accountability partner, achievements.

## Platform reality (read before Phase 3)

| Capability | Android | iOS |
|---|---|---|
| Read usage per app | `UsageStatsManager` (user grants *Usage access* in Settings) | Not readable by the app. Show it only via a `DeviceActivityReport` extension (SwiftUI view) |
| Detect app opened | Poll `UsageEvents` from a foreground service, or an `AccessibilityService` | `DeviceActivity` monitor extension (thresholds/schedules) |
| Block app | Foreground service launches our `BlockActivity`; needs *Display over other apps* (`SYSTEM_ALERT_WINDOW`) to start it from the background | `ManagedSettings` shields (`ManagedSettingsStore.shield.applications`) |
| Pick apps | Our own list from `PackageManager` | `FamilyActivityPicker` (opaque tokens, no app names) |
| Entitlement / policy | Play: Accessibility and Usage access need a prominent in-app disclosure and a Play Console declaration. Android 14+: foreground service type `specialUse` | `com.apple.developer.family-controls` must be requested from Apple before App Store release |

All of this is native code reached from Dart through a `MethodChannel` (+ `EventChannel` for live updates).
Keep the Dart side platform-neutral behind one interface.

## Architecture: MVVM with GetX

- **Model:** plain Dart data classes + repositories/services in `lib/data/`.
- **View:** widgets only, no logic. A view with state extends `GetView<XViewModel>` and reads it through `controller` inside `Obx`.
- **ViewModel:** extends `GetxController`; holds `.obs` state and the actions the view calls. No widget classes or `BuildContext`; plain types like `ThemeMode` and `AppLifecycleListener` are fine.
- **Obx scope:** an `Obx` only tracks `.obs` reads inside its own builder, not inside child widgets' `build`. Every widget that reads ViewModel state wraps its own body in `Obx`, even when a parent already has one.
- **Platform code** sits behind an interface in `data/platform/` so ViewModels can be tested with a fake (see `FakeScreenTime` in `test/widget_test.dart`).
- **Binding:** registers a module's ViewModels (and its repositories) with `Get.lazyPut`; it's attached to the module's `GetPage`.
- **Routing:** `GetMaterialApp` + `GetPage`. Route names live in `app/routes/app_routes.dart`, pages in `app_pages.dart`.
- Long-lived services (storage, the screen-time channel) are registered once with `Get.put(..., permanent: true)` before `runApp`.
- A ViewModel is added to a module only once that module has state. Placeholder tabs are plain `StatelessWidget`s until then.

## Project structure

```
lib/
  main.dart                       # GetMaterialApp, theme, initial route
  app/
    routes/app_routes.dart        # route name constants
    routes/app_pages.dart         # GetPage list (view + binding)
    theme/app_colors.dart         # Calm Forest palette
    theme/app_theme.dart          # light/dark ThemeData
  modules/                        # one folder per feature
    shell/                        # bottom-nav host (view, view_model, binding)
    dashboard/  focus/  blocking/  settings/
    onboarding/  stats/           # added in their phases
      <name>_view.dart
      <name>_view_model.dart
      <name>_binding.dart
  data/
    models/                       # AppLimit, BlockSchedule, FocusSession, DailyUsage
    repositories/                 # local storage access
    platform/
      screen_time_api.dart        # abstract interface (Dart)
      screen_time_channel.dart    # MethodChannel implementation
android/app/src/main/kotlin/com/focuseregain/app/   # native Android code
ios/Runner/ + iOS extensions                         # native iOS code
```

## Theme: Sage (dark) / Indigo (light)
Colours live in `app/theme/app_colors.dart`. **Dark mode** uses the user's palette:
sage `#9CB080` (primary: accent text, icons, selected states), green `#618764` (fills, ring arcs,
switch tracks, glows), deep green `#2B5748` (secondary container, nav indicator, background glow)
and slate `#273338` (page background; cards are lighter slates #2D3B41–#42545B).
- Text on sage/green fills is `AppColors.onSage` (#14200F): 7.2:1 on sage, but only 4.2:1 on green,
  so filled buttons use `AppColors.accentGradient` (sage → green, label over the sage half) and
  small filled chips use sage → `sageDeep` (#88A170, 5.9:1). Never put text on plain #618764.
- Status pairs `AppColors.emerald/mint/blue/indigo/violet` are sage in dark mode; `coral` and
  `amber` keep their colours (over target, warnings, strict). Dashboard category bars keep their
  own data colours in both modes.
- **Light mode** is unchanged: indigo accents on neutral greys (seed #603CE2).
Font: Plus Jakarta Sans 400–800 (`assets/fonts`, OFL licence registered in `main.dart`).
Cards: `GlassCard` (20 px corners). Gradient = `AppTheme.focusGradient(scheme)`, used by the
focus rings and the nudge badge. Rings use `ProgressRing`. Show timers/minutes with
`AppTheme.tabularFigures`. The native block screen (`BlockActivity.kt`) and the Android splash
background use the slate/sage colours; the app icon was not changed.

Packages: `get` (state, DI, routing) is installed. Add the others only when a phase needs them:
`get_storage` or `shared_preferences` (settings), `drift` or `isar` (history), `fl_chart`,
`flutter_local_notifications`, `permission_handler`.

---

## Phase 0: Project setup
- [x] Package ID changed to `com.focuseregain.app`
- [x] Display name "Focus Regain" (Android `android:label`, iOS `CFBundleDisplayName`, `GetMaterialApp.title`)
- [x] Update `pubspec.yaml` description
- [x] Replace the counter demo in `lib/main.dart` with a `GetMaterialApp` shell
- [x] Create the MVVM folder structure (folders under `data/` are created when first needed)
- [ ] `git init` and the first commit

**Done when:** `flutter run` opens an empty home screen on Android and iOS.

## Phase 1: App shell, theme and navigation
- [x] Calm Forest light/dark colour scheme in `app/theme/`
- [x] Bundle fonts: Fraunces 600 (display/headline styles) + Inter 400–700 (everything else) in `assets/fonts/`, OFL licences registered in `main.dart`
- [x] Firebase connected (project `regain-focuse`); `Firebase.initializeApp` runs in `main()` before `runApp`
- [x] GetX routing + bottom nav (`modules/shell`): Dashboard · Focus · Blocking · Settings
- [x] Placeholder screen for each tab
- [x] Widget test: all four tabs switch (`test/widget_test.dart`)

**Done when:** you can switch between all four tabs; dark mode follows the system.

## Phase 2: Onboarding and local data
- [x] 3 onboarding pages (`modules/onboarding`): welcome · goals (`FocusGoal` chips, at least 1) · daily target slider (1–6 h, 30 min steps)
- [x] `SettingsRepository` (`data/repositories/`) over `shared_preferences`; registered with `Get.put(permanent: true)` in `main()`
- [x] Initial route: `onboardingDone` ? shell : onboarding (checked in `RegainApp`); finish uses `Get.offAllNamed`
- [x] Settings: System / Light / Dark switch saved locally, applied with `Get.changeThemeMode`; open-source licences page
- [x] Tests: onboarding flow saves answers, tabs switch, theme choice saved, `formatMinutes`
- Models are created in the phase that first uses them: `DailyUsage` (Phase 3), `AppLimit` / `BlockSchedule` (Phases 5–6), `FocusSession` (Phase 7)

**Done when:** onboarding shows once, and the answers survive an app restart.

## Phase 3: Platform bridge (Android first)
- [x] `ScreenTimeApi` (`data/platform/screen_time_api.dart`): `isSupported`, `hasUsageAccess`, `openUsageAccessSettings`, `getUsage(from, to)`, `getAppIcon`. `ScreenTimeChannel` implements it over channel `com.focuseregain.app/screen_time`; registered in `main()`
- [x] Kotlin: `MainActivity` registers `ScreenTimeHandler.kt` (work runs on a background thread); `UsageCalculator.kt` turns resume/pause events into foreground ms per app (JUnit test in `android/app/src/test`)
- [x] Manifest: `PACKAGE_USAGE_STATS` + `<queries>` for LAUNCHER and HOME intents (Android 11+ package visibility, no `QUERY_ALL_PACKAGES`)
- [x] Usage is limited to launchable apps, leaves out the home-screen app, and comes sorted by time
- [x] Dashboard (`modules/dashboard`): usage-access explanation + "Open settings", re-checks on app resume, total today + per-app list with icons, pull to refresh; iOS shows "coming later"
- [x] Model `AppUsage` (instead of `DailyUsage`; a daily history model comes with the Phase 4 cache)
- Moved to Phase 5: `getInstalledApps` (for the block-list picker), `setBlockedApps`. Phase 7: `startFocus` / `stopFocus`

**Done when:** the dashboard lists real per-app minutes for today on an Android device.

## Phase 4: Dashboard and stats
- [x] Today's total vs target: progress ring, turns terracotta with "X over target" when over (`_TargetRing`)
- [x] Top apps list with icons and minutes (Phase 3), now under "Apps today"
- [x] 7-day bar chart (`fl_chart` 1.3): dashed target line, over-target bars in terracotta, today highlighted, tooltips, screen-reader summary
- [x] Pull-to-refresh; `UsageHistoryRepository` caches finished days' totals (`daily_totals` in shared_preferences, 60 days kept); only missing days are read from the OS
- [x] Tests: history cache (reads the OS once, prunes, corrupt cache), ring/over-target text and refresh redraw; widget tests run at 360x800 dp

**Done when:** the numbers match Android's own Digital Wellbeing within a few minutes.
- [x] Checked on a Pixel 7 Pro (Android 17), 2026-11-01: per-app minutes match Android's own totals within 1-2 min. Android 17 often logs resumed -> stopped with no pause, and logs a reopened activity's old copy as stopped right after the new one resumes; `UsageCalculator` handles both (stop ends a visit unless it follows a reopen within 2 s) and ends every visit at screen-off. Events have no public instance id, so these rules stand in for it. Past-day cache is `daily_totals_v2` (v1 totals were inflated)
- Android's own "today" bucket can start before midnight (11 PM on this phone); ours is local midnight, so apps used late last night show less here

## Phase 5: Blocking engine (Android)
- [x] `BlockerService.kt`: foreground service (type `specialUse`, low-priority notification) that checks `UsageEvents` every 0.7 s while the screen is on; `BlockDecider.kt` picks what to cover: only the latest opened app counts (JUnit tested)
- [x] `BlockActivity.kt`: native full-screen pause screen in Calm Forest dark; "Go back" and the back gesture always go to the home screen; own task, hidden from recents
- [x] Needs **Display over other apps** (`SYSTEM_ALERT_WINDOW`): Android 10+ only lets a background app open a screen with it
- [x] Block list kept natively (`BlockListStore.kt`) so it works before Flutter starts; Dart reads/writes it via `getBlockedApps` / `setBlockedApps`
- [x] `BlockerService.sync()` starts/stops the service to match list + permissions; called on save, in `MainActivity.onResume` and from `BootReceiver.kt` (`BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`)
- [x] Never blocked (`ProtectedApps.kt`): Focus Regain, home screen, default dialer, Settings. They aren't offered in the picker either
- [x] Blocking tab (`modules/blocking`): disclosure ("How blocking works", data stays on the phone) + 2 setup steps, then a searchable app list with switches; battery tip card links to the battery-optimisation list (no `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, which Play restricts)
- [x] Shared `AppIconCache` + `AppIcon` widget and `MessageView` (`app/widgets/`), now used by the dashboard too
- [ ] Device check: Xiaomi/MIUI also needs "Display pop-up windows while running in the background" and Autostart; Samsung may need "Never sleeping apps". Add per-brand hints if testing shows it
- [x] `POST_NOTIFICATIONS` declared in Phase 6; the Blocking tab shows a tip card linking to notification settings once a limit exists

**Done when:** opening a blocked app shows the block screen within ~1 second, and this still works after a reboot.

## Phase 6: Limits, schedules and the mindful pause
- [x] One rules object (`data/models/blocking_rules.dart` ⇄ `BlockingRules.kt`): `alwaysBlocked`, `dailyLimits` (pkg → minutes), `schedules`, `style` (block / pause). Sent to Android as a JSON string; `BlockingStore` keeps it plus "open anyway" allowances. (Replaces Phase 5's plain block list; lists saved during Phase 5 testing are gone.)
- [x] Service tracks the app on screen, so a schedule starting or a limit running out covers an app already open; `BlockDecider.reason` order: always → schedule → limit (JUnit tested, incl. overnight schedules)
- [x] Daily limit: today's usage recomputed at most every 15 s, only for apps that have a limit (so a limit can kick in up to ~15 s late)
- [x] Schedules: days (ISO 1 = Mon) + start/end minute; end ≤ start runs past midnight. Editor screen `modules/schedule_editor` (route `/schedule`, schedule passed as `Get.arguments`)
- [x] Mindful pause (`BlockActivity` pause mode): breathing circle, "Close app", and "Open anyway" enabled after 5 s that allows the app for 5 min
- [x] 80% warning notification, once per app per day (in memory). Notification permission: tip card → app notification settings
- [x] Blocking tab: status, tips, block style, schedules list, searchable apps; tapping an app opens a sheet with "Always block" + daily limit chips (debug builds add "1 min (test)")
- [x] Tests: rules JSON round trip, rules sheet + style, schedule editor save

**Done when:** a 1-minute test limit blocks the app, and a schedule switches blocking on and off at the right times.

## Phase 7: Focus sessions
- [x] Session lives natively (`FocusStore.kt`: start/end time, apps, strict) and the service enforces it, so it keeps going when Flutter is closed or killed. `FocusStore.active()` records and clears a session once its end time has passed
- [x] Session apps are always a hard block (`BlockReason.Focus` comes before every other rule, and "open anyway" is never offered); JUnit tested
- [x] Strict mode is enforced natively: `stopFocus` returns false
- [x] Service notification switches to "Focus session" with the system's own countdown (`setChronometerCountDown`); "Focus session done" notification when one completes
- [x] History (last 200, completed + stopped) kept natively; Dart reads it via `getFocusHistory`
- [x] Focus tab (`modules/focus`): presets 15/25/50/90 + 5–180 min slider, app picker sheet (last pick remembered in `SettingsRepository.focusPackages`), strict switch; running view with ring, mm:ss countdown, stop with confirm; "Today" total + 5 recent sessions; "Set up blocking" link when permissions are missing
- [x] Tests: start → countdown → stop; strict hides stop; `formatClock`
- [ ] Device check: the end is detected by the service's 0.7 s check, which keeps running with the screen off, but in deep sleep (Doze) the "done" notification can arrive late. Exact alarms (`SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM`) are restricted on Play, so only add one if testing shows real delays

**Done when:** a session survives the app being killed and ends on time.

## Phase 8: iOS Screen Time (postponed: done after Phase 9, before release)
- [ ] Ask Apple for the Family Controls entitlement (start early, approval takes time)
- [ ] Capabilities: Family Controls, App Groups
- [ ] `AuthorizationCenter.shared.requestAuthorization(for: .individual)`
- [ ] `FamilyActivityPicker` (SwiftUI) presented from Flutter; store the selection in the App Group
- [ ] Shields with `ManagedSettingsStore`
- [ ] `DeviceActivityMonitor` extension for schedules and limits
- [ ] `DeviceActivityReport` extension for the usage view (iOS will not give the raw numbers to Dart)
- [ ] Same `ScreenTimeApi` interface, Swift implementation

**Done when:** blocking, limits and focus work on a real iPhone (the Simulator cannot test Screen Time).

## Phase 9: Streaks, notifications and polish
- [x] Streak (`app/utils/streak.dart`): finished days in a row at or under target, from the last 30 days of `UsageHistoryRepository`; a 0-minute day counts as "no data" and ends it. Shown as a card on the dashboard
- [x] Weekly recap (`WeeklyRecap.kt` + `RecapReceiver`): Monday 09:00 notification for last Mon–Sun (total, daily average, days on target). Inexact `setAndAllowWhileIdle` alarm (no exact-alarm permission); rescheduled on fire, boot, app update and every app launch. Days with no data are left out. JUnit tested
- [x] `UsageTotals.kt`: one place that counts usage the way the dashboard does (launchable apps, no home screen); used by `getUsage` and the recap
- [x] Settings: edit the daily target (refreshes the dashboard and recap), weekly-recap switch, "Notifications are off → Allow", sections Goals / Notifications / Appearance / About
- [x] Empty / loading / error states on every tab (dashboard, blocking, focus) via `MessageView`
- [x] Accessibility: test at 200% text on a 360 dp phone covers onboarding + all tabs. It found and fixed the onboarding button row (now an `OverflowBar`) and the rings (shared `ProgressRing` grows with text size, then scales its content down to fit)
- [x] Own app icon (light ring open at the top + amber dot, on #2F6B4F): Android adaptive vector + Android 13 themed (monochrome) icon + legacy PNGs; iOS AppIcon set. Notification icon `ic_stat_focus` replaces the system placeholders. Splash: #0F1A15 with the mark (Android < 12 layer-list, Android 12+ `windowSplashScreen*`, iOS LaunchScreen). PNGs are rendered with a Pillow script (not kept in the repo; the vector in `res/drawable/ic_launcher_foreground.xml` is the source of truth)
- [ ] Device check: run through as a brand-new user (install → onboarding → block an app) without help; check the icon on a few launchers and the splash in light and dark mode

### Design refresh: Focus tab home (from the user's mockup)
- [x] Whole app switched to the mockup palette + Plus Jakarta Sans (dark mode later changed to Sage, see Theme)
- [x] Focus tab start screen (`modules/focus/focus_view.dart`, `_FocusHome`): greeting + focus-streak pill (days in a row with a completed session, `focusStreak` in `app/utils/streak.dart`), "Quick nudge" card built from today's progress, gradient ring of today's focus vs the **daily focus goal** (new setting, default 2 h, `SettingsRepository.focusGoalMinutes`) with "+/− vs yesterday", big "Start focus session" button that opens the new-session sheet (length, strict, apps), stat cards (screen time today + 7-day average; **interceptions** today), recent sessions
- [x] Interceptions = times the block screen was shown today, counted natively (`BlockingStore.recordInterception`, channel `getInterceptionsToday`)
- [x] Settings: "Daily focus goal" (15 min–8 h)
- Not built (not real features yet): Live Study Rooms, calendar "Next planned block", profile photo, notification bell

### Design refresh: Dashboard (second mockup: glass cards on near-black)
- [x] Dark theme surfaces now near-black (#080B11 background, #121722 cards); accents unchanged. Status accents (`AppColors.coral/amber/emerald/blue/indigo/violet`, each a [dark, light] pair; `AppColors.pick`)
- [x] Shared `GlassCard` (translucent gradient + fine border in dark, white + soft shadow in light; optional left accent stripe)
- [x] Glass everywhere: `GlassCard` is real frosted glass (`FrostedGlass`: blur + `washOf` tint + top-lit edge; soft shadow in light). `AmbientBackground` wraps every page and holds a `BackdropGroup`, so the blurs on one page share one screen read (`BackdropFilter.grouped`). Focus and Blocking now use the glow background; their old `Card`s are `GlassCard`s. `decorationOf` (slivers, tiles) and the bottom bar use the same tint without blur. Dialogs and sheets get a near-opaque glass tint + light edge from the theme (no blur behind modals) and `AmbientBackground` (soft glows) in `app/widgets/glass_card.dart`. Avoid `ListTile` inside a `GlassCard` with `accent`: the stripe's `IntrinsicHeight` makes its trailing button untappable
- [x] Layout: header ("Today", status dot that pulses only while refreshing, date, glass refresh button) → ring (coral gradient + glow when over target, indigo→violet when under; "TOTAL TODAY", big digits with small units, over/left pill) → status card (amber "Past your target" / emerald "On track") → gradient "Start a focus session" (→ Focus) + "Manage blocked apps and limits" (→ Blocking) → Streak and "Past 6D" average tiles → "Most used categories" (top 3; "Details" sheet lists every app) → 7-day chart (coral = over target)
- [x] Categories are real: Android's `ApplicationInfo.category` (Android 8+) is sent with each app in `getUsage` → `AppCategory` (`data/models/app_category.dart`); apps without one count as "Other apps"
- [x] Bottom bar: rounded top, fine border, indigo active tab; icons bolt / clock / block / gear. Side rail (≥ 840) uses the same indigo
- [x] Responsive (phone / ≥ 600 / ≥ 840 two columns, max 1200), shimmer loading (still with reduced motion), refresh keeps content, refresh-failed banner, first-load error, empty state: all kept from the first dashboard refresh
- [x] Tests (`test/dashboard_test.dart`): shimmer, reduced motion, failed refresh + retry, first-load error, categories order, Details sheet, empty state, actions, phone/tablet/desktop × light/dark
- Note for tests: the dashboard is one scrolling column, so use `ensureVisible` (not `scrollUntilVisible`) to reach lower rows

### Design refresh: New focus session sheet (third mockup)
- [x] `_NewSessionSheet.show` in `modules/focus/focus_view.dart`: 32 px top radius + fine border (#10131A in dark, white in light), custom handle, title + round close button, big glowing duration, emerald gradient preset chips with a check, violet slider, strict mode in a `GlassCard` (violet lock box), "Apps to block (n)" + **Select all / Clear all** (`FocusViewModel.toggleAllVisible`, acts on the search results; native `ProtectedApps` still never blocks dialer/settings/launcher/us), filled search field, rows with "Blocked during focus", pinned lavender-gradient "Start session" (indigo in light; flat "Pick at least one app" when nothing is picked)
- [x] Test: presets, select all, clear all, close (`test/widget_test.dart`)

### Design refresh: Blocking tab (fourth mockup)
- [x] `modules/blocking/blocking_view.dart`: header "Blocking" + ACTIVE/OFF badge (scrolls with the list once loaded), status card ("Nothing blocked yet" / counts of blocked, limits, schedules), mint battery tip with "Fix settings" + Dismiss (`batteryTipDismissed`, until restart), mint Block / Mindful pause switch, schedule cards (indigo work / amber overnight icon, name, time, days · apps; 2 columns, 3 from 560), "Installed apps · N total · N restricted", search by name **or category**, apps in one glass panel (`DecoratedSliver` + `GlassCard.decorationOf`)
- [x] Rows: rules in mint if any, else "category · Unrestricted"; social / video / games apps without rules get a one-tap "+ Block" (always block), others "Configure" (opens the rules sheet)
- [x] Categories for installed apps: `getInstalledApps` now sends `ApplicationInfo.category` → `InstalledApp.category`
- [x] Accent is mint on this tab (from the mockup); the nav bar stays indigo app-wide
- Not built (no real data/feature): "High Drain" badge, filter button, shield button in the header, preset schedule suggestions
- [x] Test: badge, dismiss, one-tap block, category search (`test/widget_test.dart`)

### Design refresh: Schedule editor (fifth mockup)
- [x] `modules/schedule_editor/schedule_editor_view.dart`: mint ambient glow; round back button, centred "New / Edit schedule" + "Blocks apps automatically", round delete when editing; name card (briefcase / moon icon, clear button); "Repeats on" with Weekdays / Every day shortcuts (`setDays`) and seven mint day pills (full day names for screen readers); "Active window" with the length pill (`durationMinutes`, wraps past midnight) and Starts / Ends glass cards (tap → time picker, small AM/PM, "Next day" when overnight); "Apps to restrict" + "N selected" + Select all / Clear all (`toggleAllVisible`), search by name or category, apps as glass cards (category, "Often distracting" for social/video/games); pinned mint gradient "Save schedule" (flat while not ready)
- [x] Shared mint accent: `AppColors.mint` ([#00E599, #047857]), used by Blocking and the editor
- Not built: the sparkle "presets" button, "Visible during focus" note, "Morning block / Evening wrap-up" captions, filter button
- [x] Test: Every day, length pill, clear name, select all, back without saving (`test/widget_test.dart`)

### Design refresh: Settings (sixth mockup)
- [x] `modules/settings/settings_view.dart`: mint ambient glow, big "Settings" header, indigo uppercase section titles; glass panels with tinted icon boxes. Goals: screen-time target (indigo flag) + focus goal (amber bolt) with value chips (chip drops under the title at large text). Notifications: "Allowed / Off" status from the real permission, weekly recap switch (violet), "Notifications are off" + Allow when needed. Appearance: System / Light / Dark glass switch with a mint check. About: Privacy sheet (usage stays on the phone, why each permission) + open-source licences
- Not built (no real feature yet): account button, "Over-limit alerts" toggle (the 80% warning is always on natively), app version / "Up to date" row (would need package_info_plus)
- [x] Test: notifications status + privacy sheet; tab test now checks "GOALS" and scrolls to "Dark"

### Design refresh: Running focus session
- [x] `_RunningSession` in `modules/focus/focus_view.dart`: violet ambient glow, "Focusing" + IN PROGRESS (mint) / STRICT (amber lock) pill, "N min session · started …", 240 gradient ring with TIME LEFT, big clock and an "Ends …" pill; tiles for minutes focused so far and distractions stopped today; glass card with the blocked apps' icons (+N beyond 8, labels as tooltips) and "you can close the app"; Stop session (coral outline, confirm dialog) or the strict notice **pinned at the bottom** so it's always reachable
- [x] `ProgressRing` never grows wider than its space (it used to stretch into an oval at large text on narrow phones)

### Live focus card on the Dashboard
- [x] One source of truth: `FocusViewModel` (Dashboard reads it with `Get.find`). Its `clock` (Rx DateTime) ticks each second only while a session runs, and at local midnight (`_armMidnight`, one pending timer); `refreshState` (also on app resume) resets it. `elapsed` and `focusedToday` are derived from the saved `startedAt` / `endedAt` and `clock`, never incremented
- [x] `FocusViewModel.focusedOn(day, finished, running, now)`: overlap of each session with the local day (sessions crossing midnight are split), running session capped at its planned end, and a history entry with the running session's `startedAt` is skipped (no double count while it ends). Unit tests in `test/focus_time_test.dart`
- [x] Dashboard `_FocusTodayCard`: live = "FOCUS SESSION · LIVE", local start time (date added if it began another day), elapsed HH:MM:SS (`formatHms`), total focus today HH:MM:SS, "Open session" → Focus tab (stop/strict there); idle = total today + the existing "Start a focus session" button (hidden while a session runs). Only the counter `Obx`es follow `clock`
- [x] Sessions are persisted natively (`FocusStore`, SharedPreferences); nothing goes to Firebase. Native `start` returns the running session (no duplicates); `FocusViewModel.start` also refuses while one is active
- No pause/resume (sessions can't be paused), so there is no paused time to exclude
- [x] Dashboard screen time ("TOTAL TODAY", ring, categories, today's bar) reloads silently every 30 s (`DashboardViewModel.livePeriod`) while the app is visible (`AppLifecycleListener` onShow/onHide), plus on resume and manual refresh. Silent reloads show no progress bar or failure banner and never overlap

### Design refresh: Onboarding (pages 1–3)
- [x] Shell: ambient glow, step segments (done solid, current gradient, ahead track) + Skip on top; page 1 has short segments, later pages a "STEP n OF 3" label above full-width segments. Bottom: "‹ Back" (pages 2+) beside a full-width gradient Continue / Get started (`_ContinueButton`, dimmed when disabled)
- [x] Skip (`OnboardingViewModel.skip`) finishes onboarding at once with whatever was picked (default 3 h target)
- [x] Welcome: our own leaf emblem (`Icons.spa_rounded`, gradient) in a glass tile with a halo, RECLAIM BALANCE pill, "Take back *your time*", Insights / Pauses / Rituals tiles. Not the mockup's lotus SVG. No float or ping animations (they would also stall `pumpAndSettle` in tests)
- [x] Goals: "What do you want to *change?*", one card per `FocusGoal` with icon + hint, check circle when picked (`Semantics(checked:)`). Selected cards are opaque so their glow doesn't tint them
- [x] Target: "Set a daily *screen-time* target", big "3 h" / "2 h 30 min" (accent units), verdict pill (≤2 h strict, ≤3 h 30 balanced, else gentle), styled slider (1–6 h, 30 min steps) with "1 h · Strict / 6 h · Relaxed", 2 h / 3 h / 4 h preset chips, and a card saying what the target does: Dashboard ring turns coral, weekly recap counts the day, nothing is blocked (the mockup's "pauses feeds" isn't true for the target)

### Permission steps (required before the dashboard)
- [x] `modules/permissions`: one step per permission, in order: Usage access → Display over other apps → Notifications → Unrestricted battery. Each step: icon, why, an "In Settings" hint, a 4-row checklist (Allowed / Next / Needed), "Open settings"; re-checks on resume (`AppLifecycleListener`) and moves to the next missing one. "Go to dashboard" only when all four are on
- [x] Gate: onboarding finish and sign-in go to `/permissions` (forwards to the shell at once if everything is already on). At launch `main` checks (`PermissionsViewModel.check`) and opens on `/permissions` if any is off (`RegainApp.needsPermissions`). Unsupported platforms (iOS for now) skip it
- [x] `StepSegments` / `StepLabel` (`app/widgets/step_progress.dart`) shared with onboarding
- [x] Restricted settings (Android 13+, CDD 9.8): an app installed from an APK file or download can't get usage access or display-over-apps until the user picks App info > ⋮ > Allow restricted settings (the switch is greyed out). `Permissions.mayNeedRestrictedSettings` reads `getInstallSourceInfo().packageSource` (LOCAL_FILE / DOWNLOADED_FILE, the same rule Android uses); the usage-access and overlay steps then show the unlock steps and an "Open App info" button. Play Store installs never see it. (The ECM API Android uses is not public.)
- [x] Android Go (10+) never grants the overlay (`canRequestOverlay` is false): that step counts as done, and Blocking / Focus say blocking can't work on this phone (`unavailable` status) instead of asking forever
- Not re-checked while the app stays open: a permission turned off mid-session is caught at the next launch (Dashboard / Blocking still show their own notices)

### Accounts: Log in / Sign up (required before the app)
- [x] `data/repositories/auth_repository.dart`: `AuthRepository` (fake in tests) and `FirebaseAuthRepository` (`firebase_auth` only). Email/password, Google and Apple through `signInWithProvider` (no google_sign_in / sign_in_with_apple packages), password reset, sign out. Cancelling a provider sheet returns false (no error); Firebase codes become plain messages (`messageFor`)
- [x] Start route: signed out → `/login`, else onboarding / shell. After sign-in: onboarding if not done, else shell
- [x] `modules/auth`: one `AuthViewModel` for both screens (separate fields per screen, shared busy/error), `LoginView` (Welcome back, Google/Apple, email + password, Forgot password? uses the typed email, Log in, "Create account"), `SignUpView` (Create account, name/email/password, strength meter, Terms checkbox off by default and required, "Log in"). Header has back + title only (no profile icon). `SingleChildScrollView`, not a lazy list, so every field validates
- [x] Settings → ACCOUNT → Sign out (confirm; on-device data stays). Privacy sheet says the account (name, email) is kept by Firebase Auth and isn't linked to usage
- [x] `GradientButton` (`app/widgets`) shared by onboarding and auth, with a busy spinner
- [x] Glass look (login mockup): `FrostedGlass` (`app/widgets/frosted_glass.dart`, BackdropFilter blur + white wash + top-lit 1 px edge) on the round emblem, badge, Google/Apple buttons and privacy pill; extra glows in `AuthPage` so the blur shows; see-through fields with a 2 px focus ring and a "Looks great" note once the email is valid (`AuthField.validHint`)
- [x] Remember me (on by default, `SettingsRepository.rememberMe`): off → `main` signs out at the next launch. `AuthCheckbox` shared with the Terms box
- Left out of the mockup: Face ID / Touch ID button (would need local_auth + stored credentials) and the "14,280 active" community card (no real data); "Master passcode" label kept as "Password", "Sign In" kept as "Log in"
- [x] Android SHA-1 + SHA-256 for the debug key (~/.android/debug.keystore) and the release upload key (`android/app/upload-keystore.jks`, alias `upload`, passwords in `android/key.properties`, both git-ignored; release signing reads them, falls back to debug if missing) added to Firebase app `1:763300230706:android:86597297cced221b6aae2b`; `google-services.json` re-downloaded (now has Android + web OAuth clients)
- [ ] Firebase console: enable Email/Password, Google and Apple providers; Apple needs a Services ID + key, and the iOS "Sign in with Apple" capability
- [ ] When publishing with Play App Signing: also add the Play "App signing key" SHA-1/SHA-256 from Play Console to Firebase
- [ ] Terms of Service and Privacy Policy documents (Phase 10) — the checkbox names them but nothing links to them yet

**Done when:** a new user can install the app, complete onboarding and block an app without help.

## Phase 10: Release prep
- [ ] Privacy policy (what usage data is read, stored on the device only)
- [ ] Play Console: Data safety form, Usage access / Accessibility declaration, foreground service declaration
- [ ] App Store: Family Controls entitlement approved, privacy nutrition label
- [ ] Release signing, version bump, store screenshots from our own UI

**Done when:** internal testing tracks are live on Play and TestFlight.

## Phase 11+: Later features
Accounts + sync → AI coach → subscriptions → widgets. Plan each one as its own phase when we get there.

---

## Rules while building
- Usage data stays on the device unless the user opts in to something else.
- Never block the phone's dialer, settings or our own app (users must always be able to escape).
- Test blocking on real devices. Emulators and the Simulator miss OEM battery killers (Xiaomi, Samsung, Oppo): add a "disable battery optimisation" step in Phase 5.
- After each phase: `flutter analyze`, run on a device, tick the boxes in this file.

### Push reminders (FCM + Cloud Functions), 2026-11-01
Not deployed yet (built and tested against the emulators). No Tasks feature exists, so task reminders are not built; the server's `KINDS` list is where they would plug in.
- **Who sends what** (never both for one occurrence): server FCM = focus nudge, daily focus summary, check-ins after 3 inactive days. Native local = limit warnings, "focus session done", weekly screen-time recap (they need screen time, which stays on the phone).
- **Data** (`firestore.rules`, owner-only): `users/{uid}` = `notificationPrefs`, `timezone` (IANA, `flutter_timezone`), `lastActiveDay` + `lastActiveAt` (server time, once a day), `focus.sessions` (last 8 days, times only, no apps). `devices/{deviceId}` = FID + platform. `notifications/{kind_date}` = send log (app may only set `openedAt`, once). `private/engagement` = server-only.
- **Client**: `PushMessaging` (FCM, Firebase Installation IDs; token APIs are deprecated), `ReminderStore` (Firestore), `NotificationCenter` (GetxService: register on sign-in, unregister + delete device on sign-out with a 5 s cap, activity sync on launch/resume/focus start-stop, in-app banner in the foreground, tap -> Focus or Dashboard tab with uid check and opened-id dedupe; cold-start taps wait for sign-in and the shell via `takePendingTab`). Settings -> REMINDERS: Turn on (user tap only) / denied / unavailable states, toggles, times, quiet hours. Android's existing permission gate still requires notifications (user's earlier choice).
- **Server** (`functions/`, Node 22 ESM): `onUserWritten` (re)queues one Cloud Task per enabled kind (`id = uid-kind-date-version`), cancelling old ones; `sendScheduledNotification` (`onTaskDispatched`, 5 retries) rechecks everything, claims `notifications/{kind_date}` in a transaction, sends with the Admin SDK to each FID, deletes `installation-id-not-registered` devices and devices idle > 60 days, logs FCM acceptance (not delivery), queues the next day; `onDeviceWritten` removes the same FID from other accounts; `onAccountDeleted` deletes data and tasks. Caps: nudges + check-ins share 1/day, 3/week, 14-day pause after 3 unopened; check-ins stop after 2 in a row until the user returns. Android tag / APNs collapse id = notification id, so a rare resend replaces the first.
- **Tests**: `cd functions && npm test` (29: unit, emulator integration with fake FCM/queue, security rules). Flutter `test/notifications_test.dart` (11).
- **Deploy checklist**: Blaze plan; create Firestore (Native mode); `firebase deploy --only firestore,functions` (first deploy creates the Cloud Tasks queue; grant the functions' service account `roles/cloudtasks.enqueuer` and `roles/iam.serviceAccountUser` if enqueue is denied); iOS: upload an APNs .p8 key in Firebase console -> Cloud Messaging, enable Push Notifications capability in Xcode (entitlements file is already referenced), use a real device. Web is not a target (no `web/`).
- **Local device test**: `firebase emulators:start --project regain-focuse --only functions,firestore,tasks`, run the app with `--dart-define=FIRESTORE_EMULATOR_HOST=<Mac IP>`. The tasks emulator ignores schedule times (the dispatcher drops runs > 5 min early).
