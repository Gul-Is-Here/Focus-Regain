import 'package:get/get.dart';

import '../../modules/auth/auth_binding.dart';
import '../../modules/auth/login_view.dart';
import '../../modules/auth/sign_up_view.dart';
import '../../modules/onboarding/onboarding_binding.dart';
import '../../modules/onboarding/onboarding_view.dart';
import '../../modules/permissions/permissions_binding.dart';
import '../../modules/permissions/permissions_view.dart';
import '../../modules/schedule_editor/schedule_editor_binding.dart';
import '../../modules/schedule_editor/schedule_editor_view.dart';
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
    GetPage(
      name: AppRoutes.onboarding,
      page: () => const OnboardingView(),
      binding: OnboardingBinding(),
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginView(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.signUp,
      page: () => const SignUpView(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.permissions,
      page: () => const PermissionsView(),
      binding: PermissionsBinding(),
    ),
    GetPage(
      name: AppRoutes.scheduleEditor,
      page: () => const ScheduleEditorView(),
      binding: ScheduleEditorBinding(),
    ),
  ];
}
