import 'package:get/get.dart';

import '../../data/models/blocking_rules.dart';
import 'schedule_editor_view_model.dart';

class ScheduleEditorBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () =>
          ScheduleEditorViewModel(Get.find(), Get.arguments as BlockSchedule?),
    );
  }
}
