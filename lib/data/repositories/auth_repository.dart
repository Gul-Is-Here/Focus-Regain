import 'package:firebase_auth/firebase_auth.dart';

/// The signed-in account, as much of it as the app shows.
typedef AuthUser = ({String id, String? name, String? email});

/// A sign-in step failed. [message] is ready to show to the user.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Accounts. Tests replace it with a fake.
abstract class AuthRepository {
  AuthUser? get currentUser;

  Future<void> logIn({required String email, required String password});

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  });

  /// False if the user closed Google's sign-in screen.
  Future<bool> signInWithGoogle();

  /// False if the user closed Apple's sign-in screen.
  Future<bool> signInWithApple();

  Future<void> sendPasswordReset(String email);

  Future<void> signOut();
}

/// Firebase Authentication. Google and Apple use Firebase's own provider
/// flow, so no extra sign-in packages are needed.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository([FirebaseAuth? auth])
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  AuthUser? get currentUser {
    final user = _auth.currentUser;
    return user == null
        ? null
        : (id: user.uid, name: user.displayName, email: user.email);
  }

  @override
  Future<void> logIn({required String email, required String password}) => _run(
    () => _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ),
  );

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) => _run(() async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    // The account exists and is signed in by now; a lost name (e.g. the
    // connection drops) only shows the email in Settings instead.
    try {
      await credential.user?.updateDisplayName(name.trim());
    } on Exception {
      // Ignored on purpose.
    }
  });

  @override
  Future<bool> signInWithGoogle() => _withProvider(GoogleAuthProvider());

  @override
  Future<bool> signInWithApple() => _withProvider(AppleAuthProvider());

  @override
  Future<void> sendPasswordReset(String email) =>
      _run(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> signOut() => _auth.signOut();

  Future<bool> _withProvider(AuthProvider provider) async {
    try {
      await _auth.signInWithProvider(provider);
      return true;
    } on FirebaseAuthException catch (e) {
      // "web-context-canceled" (Android), "web-context-cancelled" / "canceled" (iOS).
      if (e.code.contains('cancel')) return false;
      throw AuthFailure(messageFor(e.code));
    } on Exception {
      throw const AuthFailure(_fallback);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(messageFor(e.code));
    } on Exception {
      throw const AuthFailure(_fallback);
    }
  }

  static const _fallback = 'Something went wrong. Try again.';

  /// Plain-language text for a Firebase Auth error code.
  static String messageFor(String code) => switch (code) {
    'invalid-email' => "That email address doesn't look right.",
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' => 'Wrong email or password.',
    'email-already-in-use' =>
      'An account with this email already exists. Log in instead.',
    'weak-password' => 'Choose a stronger password.',
    'user-disabled' => 'This account has been turned off.',
    'too-many-requests' => 'Too many tries. Wait a minute and try again.',
    'network-request-failed' =>
      'No internet connection. Check it and try again.',
    'operation-not-allowed' => "This sign-in method isn't turned on yet.",
    'account-exists-with-different-credential' =>
      'This email already uses another sign-in method.',
    _ => _fallback,
  };
}
