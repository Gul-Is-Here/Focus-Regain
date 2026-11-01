import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../notifications/notification_center.dart';

enum AuthMethod { email, google, apple }

/// Log in and Sign up. Each screen has its own fields (both can be open at
/// once); busy state and errors are shared.
class AuthViewModel extends GetxController {
  AuthViewModel(this._auth, this._settings);

  final AuthRepository _auth;
  final SettingsRepository _settings;

  static const minPasswordLength = 8;

  final loginForm = GlobalKey<FormState>();
  final loginEmail = TextEditingController();
  final loginPassword = TextEditingController();

  final signUpForm = GlobalKey<FormState>();
  final signUpName = TextEditingController();
  final signUpEmail = TextEditingController();
  final signUpPassword = TextEditingController();

  /// The method being tried; every button waits while one runs.
  final busy = Rxn<AuthMethod>();
  final error = RxnString();
  final hidePassword = true.obs;
  final termsAccepted = false.obs;
  late final rememberMe = _settings.rememberMe.obs;
  final passwordStrength = 0.obs;

  @override
  void onInit() {
    super.onInit();
    signUpPassword.addListener(
      () => passwordStrength.value = strengthOf(signUpPassword.text),
    );
  }

  @override
  void onClose() {
    for (final c in [
      loginEmail,
      loginPassword,
      signUpName,
      signUpEmail,
      signUpPassword,
    ]) {
      c.dispose();
    }
    super.onClose();
  }

  /// 0 = under [minPasswordLength], then one point each for mixed case (or 12+
  /// characters) and for a digit or symbol, up to 3.
  static int strengthOf(String password) {
    if (password.length < minPasswordLength) return 0;
    final mixedCase =
        password.contains(RegExp('[a-z]')) &&
        password.contains(RegExp('[A-Z]'));
    final digitOrSymbol = password.contains(RegExp(r'[^A-Za-z]'));
    return 1 +
        (mixedCase || password.length >= 12 ? 1 : 0) +
        (digitOrSymbol ? 1 : 0);
  }

  static String? validateName(String? value) =>
      (value ?? '').trim().isEmpty ? 'Enter your name' : null;

  static String? validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Enter your email';
    // Firebase does the real check; this catches typos before a round trip.
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
        ? null
        : "That email address doesn't look right";
  }

  static String? validateLoginPassword(String? value) =>
      (value ?? '').isEmpty ? 'Enter your password' : null;

  static String? validateNewPassword(String? value) =>
      (value ?? '').length < minPasswordLength
      ? 'Use at least $minPasswordLength characters'
      : null;

  Future<void> logIn() async {
    if (!loginForm.currentState!.validate()) return;
    await _attempt(AuthMethod.email, () async {
      await _auth.logIn(email: loginEmail.text, password: loginPassword.text);
      return true;
    });
  }

  Future<void> signUp() async {
    if (!signUpForm.currentState!.validate()) return;
    if (!termsAccepted.value) {
      error.value = 'Please accept the Terms and Privacy Policy to continue.';
      return;
    }
    await _attempt(AuthMethod.email, () async {
      await _auth.signUp(
        name: signUpName.text,
        email: signUpEmail.text,
        password: signUpPassword.text,
      );
      return true;
    });
  }

  Future<void> continueWithGoogle() =>
      _attempt(AuthMethod.google, _auth.signInWithGoogle);

  Future<void> continueWithApple() =>
      _attempt(AuthMethod.apple, _auth.signInWithApple);

  /// Sends a reset link to the email typed on the Log in screen.
  Future<void> resetPassword() async {
    final problem = validateEmail(loginEmail.text);
    if (problem != null) {
      error.value = '$problem, then tap "Forgot password?" again.';
      return;
    }
    await _attempt(AuthMethod.email, () async {
      await _auth.sendPasswordReset(loginEmail.text);
      Get.snackbar(
        'Check your email',
        'We sent a reset link to ${loginEmail.text.trim()}.',
      );
      return false; // Still signed out.
    });
  }

  void toggleRememberMe() {
    rememberMe.toggle();
    _settings.setRememberMe(rememberMe.value);
  }

  void clearError() => error.value = null;

  /// Runs one sign-in step; [step] returns true once the user is signed in.
  Future<void> _attempt(AuthMethod method, Future<bool> Function() step) async {
    if (busy.value != null) return;
    busy.value = method;
    error.value = null;
    try {
      if (await step()) {
        unawaited(Get.find<NotificationCenter>().onSignedIn());
        Get.offAllNamed(
          _settings.onboardingDone
              ? AppRoutes.permissions
              : AppRoutes.onboarding,
        );
      }
    } on AuthFailure catch (e) {
      error.value = e.message;
    } finally {
      busy.value = null;
    }
  }
}
