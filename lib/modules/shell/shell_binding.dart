import 'package:get/get.dart';

import '../blocking/blocking_view_model.dart';
import '../dashboard/dashboard_view_model.dart';
import '../focus/focus_view_model.dart';
import '../settings/settings_view_model.dart';
import 'shell_view_model.dart';

class ShellBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(ShellViewModel.new);
    Get.lazyPut(() => DashboardViewModel(Get.find(), Get.find(), Get.find()));
    Get.lazyPut(() => FocusViewModel(Get.find(), Get.find(), Get.find()));
    Get.lazyPut(() => BlockingViewModel(Get.find()));
    Get.lazyPut(
      () => SettingsViewModel(Get.find(), Get.find(), Get.find(), Get.find()),
    );
  }
}
