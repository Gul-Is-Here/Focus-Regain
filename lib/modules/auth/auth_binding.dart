import 'package:get/get.dart';

import 'auth_view_model.dart';

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    // Shared by Log in and Sign up; kept if the other screen made it first.
    Get.lazyPut(() => AuthViewModel(Get.find(), Get.find()), fenix: true);
  }
}
