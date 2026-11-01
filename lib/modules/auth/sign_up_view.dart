import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/widgets/gradient_button.dart';
import 'auth_view_model.dart';
import 'auth_widgets.dart';

class SignUpView extends GetView<AuthViewModel> {
  const SignUpView({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      title: 'Sign up',
      children: [
        const AuthHero(
          title: 'Create account',
          subtitle:
              'Start your mindful journey and take control of your screen time',
        ),
        const SizedBox(height: 24),
        const SocialButtons(verb: 'Sign up'),
        const SizedBox(height: 24),
        const OrDivider('or register with email'),
        const SizedBox(height: 20),
        AutofillGroup(
          child: Form(
            key: controller.signUpForm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthField(
                  label: 'Full name',
                  controller: controller.signUpName,
                  icon: Icons.person_outline_rounded,
                  hint: 'Alex Morgan',
                  keyboardType: TextInputType.name,
                  autofillHints: const [AutofillHints.name],
                  validator: AuthViewModel.validateName,
                ),
                const SizedBox(height: 16),
                AuthField(
                  label: 'Email address',
                  controller: controller.signUpEmail,
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
                    controller: controller.signUpPassword,
                    icon: Icons.lock_outline_rounded,
                    hint:
                        'At least ${AuthViewModel.minPasswordLength} '
                        'characters',
                    obscure: controller.hidePassword.value,
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.done,
                    validator: AuthViewModel.validateNewPassword,
                    suffix: const PasswordVisibilityButton(),
                  ),
                ),
                const SizedBox(height: 8),
                const PasswordStrengthMeter(),
                const SizedBox(height: 12),
                const _TermsCheckbox(),
              ],
            ),
          ),
        ),
        const AuthErrorBanner(),
        const SizedBox(height: 16),
        Obx(
          () => GradientButton(
            label: 'Create account',
            busy: controller.busy.value == AuthMethod.email,
            onPressed: controller.busy.value == null ? controller.signUp : null,
          ),
        ),
        const SizedBox(height: 24),
        const PrivacyPill(),
        const SizedBox(height: 16),
        SwitchModeLink(
          question: 'Already have an account?',
          action: 'Log in',
          onPressed: () {
            controller.clearError();
            // Normally opened from Log in; fall back if it's the first page.
            Navigator.of(context).canPop()
                ? Get.back<void>()
                : Get.offNamed(AppRoutes.login);
          },
        ),
      ],
    );
  }
}

class _TermsCheckbox extends GetView<AuthViewModel> {
  const _TermsCheckbox();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strong = TextStyle(
      color: scheme.onSurface,
      fontWeight: FontWeight.w600,
    );
    return Obx(
      () => AuthCheckbox(
        checked: controller.termsAccepted.value,
        onChanged: () {
          controller.termsAccepted.toggle();
          controller.clearError();
        },
        label: Text.rich(
          TextSpan(
            text: 'I agree to the ',
            children: [
              TextSpan(text: 'Terms of Service', style: strong),
              const TextSpan(text: ' and acknowledge the '),
              TextSpan(text: 'Privacy Policy', style: strong),
              const TextSpan(text: '.'),
            ],
          ),
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
        ),
      ),
    );
  }
}
