import 'package:get/get.dart';

import '../notifications/notification_center.dart';

class ShellViewModel extends GetxController {
  final tabIndex = 0.obs;

  @override
  void onInit() {
    super.onInit();
    // A tapped push that arrived before the tabs existed (cold start, sign-in).
    final tab = Get.isRegistered<NotificationCenter>()
        ? Get.find<NotificationCenter>().takePendingTab()
        : null;
    if (tab != null) tabIndex.value = tab;
  }

  void changeTab(int index) => tabIndex.value = index;
}
