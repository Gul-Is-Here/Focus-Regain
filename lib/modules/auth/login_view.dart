import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/widgets/gradient_button.dart';
import 'auth_view_model.dart';
import 'auth_widgets.dart';

class LoginView extends GetView<AuthViewModel> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      title: 'Log in',
      children: [
        const AuthHero(
          badge: 'Mindful clarity',
          title: 'Welcome back',
          subtitle: 'Log in to see your focus stats, rituals and blocked apps.',
        ),
        const SizedBox(height: 24),
        const SocialButtons(verb: 'Continue'),
        const SizedBox(height: 24),
        const OrDivider('or log in with email'),
        const SizedBox(height: 20),
        AutofillGroup(
          child: Form(
            key: controller.loginForm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthField(
                  label: 'Email address',
                  controller: controller.loginEmail,
                  icon: Icons.mail_outline_rounded,
                  hint: 'name@example.com',
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: AuthViewModel.validateEmail,
                  validHint: 'Looks great',
                ),
                const SizedBox(height: 16),
                Obx(
                  () => AuthField(
                    label: 'Password',
                    controller: controller.loginPassword,
                    icon: Icons.lock_outline_rounded,
                    hint: 'Your password',
                    obscure: controller.hidePassword.value,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    validator: AuthViewModel.validateLoginPassword,
                    suffix: const PasswordVisibilityButton(),
                    onSubmitted: controller.logIn,
                  ),
                ),
                const SizedBox(height: 4),
                // Side by side; stacked when large text can't fit both.
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Obx(
                      () => AuthCheckbox(
                        checked: controller.rememberMe.value,
                        onChanged: controller.toggleRememberMe,
                        label: Text(
                          'Remember me',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: controller.resetPassword,
                      child: const Text('Forgot password?'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const AuthErrorBanner(),
        const SizedBox(height: 16),
        Obx(
          () => GradientButton(
            label: 'Log in',
            busy: controller.busy.value == AuthMethod.email,
            onPressed: controller.busy.value == null ? controller.logIn : null,
          ),
        ),
        const SizedBox(height: 24),
        const PrivacyPill(),
        const SizedBox(height: 16),
        SwitchModeLink(
          question: "Don't have an account?",
          action: 'Sign up',
          onPressed: () {
            controller.clearError();
            Get.toNamed(AppRoutes.signUp);
          },
        ),
      ],
    );
  }
}
