import 'package:get/get.dart';

import 'onboarding_view_model.dart';

class OnboardingBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => OnboardingViewModel(Get.find(), Get.find()));
  }
}
