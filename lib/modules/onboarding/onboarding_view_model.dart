import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../data/models/focus_goal.dart';
import '../../data/platform/screen_time_api.dart';
import '../../data/repositories/settings_repository.dart';

class OnboardingViewModel extends GetxController {
  OnboardingViewModel(this._settings, this._screenTime);

  final SettingsRepository _settings;
  final ScreenTimeApi _screenTime;

  static const pageCount = 3;
  static const minTargetMinutes = 60;
  static const maxTargetMinutes = 360;
  static const targetStepMinutes = 30;

  final page = 0.obs;
  final goals = <FocusGoal>{}.obs;
  final dailyTargetMinutes = SettingsRepository.defaultDailyTargetMinutes.obs;
  final saving = false.obs;

  bool get isLastPage => page.value == pageCount - 1;

  bool get canContinue =>
      !saving.value && (page.value != 1 || goals.isNotEmpty);

  void toggleGoal(FocusGoal goal) =>
      goals.contains(goal) ? goals.remove(goal) : goals.add(goal);

  void setDailyTarget(int minutes) => dailyTargetMinutes.value = minutes;

  void back() {
    if (page.value > 0) page.value--;
  }

  Future<void> next() async {
    if (!canContinue) return;
    if (!isLastPage) {
      page.value++;
      return;
    }
    await _finish();
  }

  /// Finishes now with whatever was picked so far (the default target if the
  /// target page wasn't reached).
  Future<void> skip() async {
    if (!saving.value) await _finish();
  }

  Future<void> _finish() async {
    saving.value = true;
    try {
      await _settings.saveOnboarding(
        goals: goals,
        dailyTargetMinutes: dailyTargetMinutes.value,
      );
      if (_screenTime.isSupported) {
        await _screenTime.configureWeeklyRecap(
          enabled: _settings.weeklyRecap,
          targetMinutes: dailyTargetMinutes.value,
        );
      }
      Get.offAllNamed(AppRoutes.permissions);
    } finally {
      saving.value = false;
    }
  }
}
