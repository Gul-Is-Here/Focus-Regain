import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:regain_app/app/widgets/gradient_button.dart';
import 'package:regain_app/data/repositories/auth_repository.dart';
import 'package:regain_app/modules/auth/auth_view_model.dart';
import 'package:regain_app/modules/settings/settings_view.dart';

import 'fakes.dart';
import 'test_app.dart';

Finder field(int i) => find.byType(TextFormField).at(i);
Finder cta(String label) => find.widgetWithText(GradientButton, label);

Future<void> tap(
  WidgetTester tester,
  Finder finder, {
  Finder? scrollable,
}) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: scrollable ?? find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(Get.reset);

  testWidgets('signed out: log in is required, then onboarding', (
    tester,
  ) async {
    final auth = FakeAuth(user: null);
    await startApp(tester, auth: auth);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing); // Nothing to go back to.

    await tap(tester, cta('Log in'));
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(auth.calls, isEmpty);

    await tester.enterText(field(0), 'alex@');
    await tap(tester, cta('Log in'));
    expect(find.text("That email address doesn't look right"), findsOneWidget);

    await tester.enterText(field(0), ' alex@example.com ');
    await tester.enterText(field(1), 'secret');
    auth.failNext = const AuthFailure('Wrong email or password.');
    await tap(tester, cta('Log in'));
    expect(find.text('Wrong email or password.'), findsOneWidget);

    await tap(tester, cta('Log in'));
    expect(auth.calls.last, 'logIn  alex@example.com ');
    expect(find.text('Take back your time'), findsOneWidget);
  });

  testWidgets('Remember me is saved and on by default', (tester) async {
    final repo = await startApp(tester, auth: FakeAuth(user: null));
    expect(repo.rememberMe, isTrue);
    await tap(tester, find.text('Remember me'));
    expect(repo.rememberMe, isFalse);
    double hintOpacity() => tester
        .widget<AnimatedOpacity>(
          find.ancestor(
            of: find.text('Looks great'),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;
    await tester.enterText(field(0), 'alex@');
    await tester.pumpAndSettle();
    expect(hintOpacity(), 0);
    await tester.enterText(field(0), 'alex@example.com');
    await tester.pumpAndSettle();
    expect(hintOpacity(), 1);
  });

  testWidgets('forgot password needs an email, then sends a link', (
    tester,
  ) async {
    final auth = FakeAuth(user: null);
    await startApp(tester, auth: auth);

    await tap(tester, find.text('Forgot password?'));
    expect(find.textContaining('Enter your email, then tap'), findsOneWidget);
    expect(auth.calls, isEmpty);

    await tester.enterText(field(0), 'alex@example.com');
    await tap(tester, find.text('Forgot password?'));
    expect(auth.calls, ['reset alex@example.com']);
    expect(find.text('Check your email'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget); // Still signed out.
    await tester.pump(const Duration(seconds: 5)); // Let the snackbar go.
    await tester.pumpAndSettle();
  });

  testWidgets('sign up needs the terms and a long password', (tester) async {
    final auth = FakeAuth(user: null);
    await startApp(tester, auth: auth, prefs: {'onboarding_done': true});
    await tap(tester, find.text('Sign up'));
    expect(
      find.text(
        'Start your mindful journey and take control of your '
        'screen time',
      ),
      findsOneWidget,
    );

    await tester.enterText(field(0), 'Alex Morgan');
    await tester.enterText(field(1), 'alex@example.com');
    await tester.enterText(field(2), 'short');
    await tester.pumpAndSettle();
    expect(find.text('Too short'), findsOneWidget);
    await tap(tester, cta('Create account'));
    expect(find.text('Use at least 8 characters'), findsOneWidget);

    await tester.enterText(field(2), 'Calm&Focus99');
    await tester.pumpAndSettle();
    expect(find.text('Strong'), findsOneWidget);
    await tap(tester, cta('Create account'));
    expect(find.textContaining('accept the Terms'), findsOneWidget);
    expect(auth.calls, isEmpty);

    await tap(tester, find.textContaining('I agree to the'));
    expect(find.textContaining('accept the Terms'), findsNothing);
    await tap(tester, cta('Create account'));
    expect(auth.calls, ['signUp Alex Morgan alex@example.com']);
    // Onboarding was done before, so straight to the app.
    expect(find.text('TOTAL TODAY'), findsOneWidget);
  });

  testWidgets('Google: closing the sheet stays put, success signs in', (
    tester,
  ) async {
    final auth = FakeAuth(user: null)..providerResult = false;
    await startApp(tester, auth: auth);

    await tap(tester, find.text('Continue with Google'));
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsNothing);

    auth.providerResult = true;
    await tap(tester, find.text('Continue with Google'));
    expect(find.text('Take back your time'), findsOneWidget);
  });

  testWidgets('Settings: sign out returns to log in', (tester) async {
    final auth = FakeAuth();
    await startApp(tester, auth: auth, prefs: {'onboarding_done': true});
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    await tap(
      tester,
      find.text('Sign out'),
      scrollable: find
          .descendant(
            of: find.byType(SettingsView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(auth.calls, ['signOut']);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('large text (200%): log in and sign up lay out', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await startApp(tester, auth: FakeAuth(user: null));
    await tap(tester, find.text('Sign up'));
    await tester.enterText(find.byType(TextFormField).at(2), 'abc');
    await tester.pumpAndSettle();
    // Any RenderFlex overflow would have failed the test already.
  });

  test('password strength', () {
    expect(AuthViewModel.strengthOf('short'), 0);
    expect(AuthViewModel.strengthOf('longenough'), 1);
    expect(AuthViewModel.strengthOf('Longenough'), 2);
    expect(AuthViewModel.strengthOf('Longenough1'), 3);
    expect(AuthViewModel.strengthOf('longenough!!'), 3); // 12+ and a symbol
  });

  test('Firebase error codes become plain messages', () {
    expect(
      FirebaseAuthRepository.messageFor('invalid-credential'),
      'Wrong email or password.',
    );
    expect(
      FirebaseAuthRepository.messageFor('something-new'),
      'Something went wrong. Try again.',
    );
  });
}
