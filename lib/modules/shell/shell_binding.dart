import 'package:get/get.dart';

import 'shell_view_model.dart';

class ShellBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(ShellViewModel.new);
  }
}
