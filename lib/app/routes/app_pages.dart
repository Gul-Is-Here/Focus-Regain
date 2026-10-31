import 'package:get/get.dart';

import '../../modules/shell/shell_binding.dart';
import '../../modules/shell/shell_view.dart';
import 'app_routes.dart';

abstract final class AppPages {
  static final pages = [
    GetPage(
      name: AppRoutes.shell,
      page: () => const ShellView(),
      binding: ShellBinding(),
    ),
  ];
}
