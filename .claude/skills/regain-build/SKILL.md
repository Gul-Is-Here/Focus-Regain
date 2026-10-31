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
| Block app | Full-screen overlay (`SYSTEM_ALERT_WINDOW`) or launch our block Activity | `ManagedSettings` shields (`ManagedSettingsStore.shield.applications`) |
| Pick apps | Our own list from `PackageManager` | `FamilyActivityPicker` (opaque tokens, no app names) |
| Entitlement / policy | Play: Accessibility and Usage access need a prominent in-app disclosure and a Play Console declaration. Android 14+: foreground service type `specialUse` | `com.apple.developer.family-controls` must be requested from Apple before App Store release |

All of this is native code reached from Dart through a `MethodChannel` (+ `EventChannel` for live updates).
Keep the Dart side platform-neutral behind one interface.

## Architecture: MVVM with GetX

- **Model:** plain Dart data classes + repositories/services in `lib/data/`.
- **View:** widgets only, no logic. A view with state extends `GetView<XViewModel>` and reads it through `controller` inside `Obx`.
- **ViewModel:** extends `GetxController`; holds `.obs` state and the actions the view calls. Never imports widgets, apart from `material.dart` types like `ThemeMode`.
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

## Theme: Calm Forest
Colours live in `app/theme/app_colors.dart`. Green is primary (progress), amber is secondary (focus)
and terracotta means over the limit; it's mapped to `error`. Never use red on the block screen.
Cards have 16 px corners and no elevation. Show timers and minutes with `AppTheme.tabularFigures`.
The theme follows the system light/dark setting.

Packages: `get` (state, DI, routing) is installed. Add the others only when a phase needs them:
`get_storage` or `shared_preferences` (settings), `drift` or `isar` (history), `fl_chart`,
`flutter_local_notifications`, `permission_handler`.

---

## Phase 0: Project setup
- [x] Package ID changed to `com.focuseregain.app`
- [ ] Set the display name (Android `android:label`, iOS `CFBundleDisplayName`) to our own app name
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
- [ ] 3–5 onboarding pages (value, goal question, daily target picker)
- [ ] Save answers + `onboardingDone` flag (`get_storage` or `shared_preferences`, behind a repository)
- [ ] Initial route: first launch → onboarding, otherwise → shell (a `GetMiddleware` or a check before `runApp`)
- [ ] Settings: manual theme switch (System / Light / Dark) saved locally, applied with `Get.changeThemeMode`
- [ ] Models: `AppLimit`, `BlockSchedule`, `FocusSession`, `DailyUsage`

**Done when:** onboarding shows once, and the answers survive an app restart.

## Phase 3: Platform bridge (Android first)
- [ ] `ScreenTimeApi` interface in Dart: `hasPermissions`, `requestPermissions`, `getInstalledApps`, `getUsage(from, to)`, `setBlockedApps`, `startFocus`, `stopFocus`
- [ ] Kotlin `MethodChannel` handler in `MainActivity.kt`
- [ ] Usage access: check + open `Settings.ACTION_USAGE_ACCESS_SETTINGS`
- [ ] `getUsage` via `UsageStatsManager.queryEvents` (compute foreground time per package)
- [ ] `getInstalledApps` with name + icon (launchable apps only)
- [ ] Permission screen with a plain-language explanation before each system prompt

**Done when:** the dashboard lists real per-app minutes for today on an Android device.

## Phase 4: Dashboard and stats
- [ ] Today's total vs target (progress ring)
- [ ] Top apps list with icons and minutes
- [ ] 7-day bar chart (`fl_chart`)
- [ ] Pull-to-refresh; cache daily totals locally for history

**Done when:** the numbers match Android's own Digital Wellbeing within a few minutes.

## Phase 5: Blocking engine (Android)
- [ ] Foreground service (type `specialUse`) that watches the foreground app via `UsageEvents`
- [ ] Block screen: our own full-screen Activity with a "Go back" action
- [ ] Block list UI: pick apps, saved locally and sent to native
- [ ] Service restarts after reboot (`BOOT_COMPLETED` receiver)
- [ ] Prominent disclosure screen (needed for Play review)

**Done when:** opening a blocked app shows the block screen within ~1 second, and this still works after a reboot.

## Phase 6: Limits, schedules and the mindful pause
- [ ] Per-app daily limit; native side blocks once the limit is used up
- [ ] Recurring schedules (days + time window)
- [ ] Mindful pause mode: breathing animation → "Open anyway / Close"
- [ ] Limit warning notification at 80%

**Done when:** a 1-minute test limit blocks the app, and a schedule switches blocking on and off at the right times.

## Phase 7: Focus sessions
- [ ] Timer UI (presets + custom), persistent notification with time left
- [ ] Blocks the selected apps during the session; strict mode disables early stop
- [ ] Save sessions to history; end-of-session notification

**Done when:** a session survives the app being killed and ends on time.

## Phase 8: iOS Screen Time
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
- [ ] Streak = consecutive days under target; weekly recap notification
- [ ] Empty states, loading states, error states
- [ ] Accessibility: labels, contrast, text scaling
- [ ] App icon + splash (our own design)

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
