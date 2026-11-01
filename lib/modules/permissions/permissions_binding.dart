import 'package:get/get.dart';

import 'permissions_view_model.dart';

class PermissionsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => PermissionsViewModel(Get.find()));
  }
}
