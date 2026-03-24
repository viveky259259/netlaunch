import 'auth_user.dart';

/// Abstract authentication provider interface.
///
/// All screens and services depend on this interface — never on a
/// concrete provider (Firebase, Supabase, etc.) directly.
///
/// Swap implementations by changing the Provider<AuthProvider> in main.dart.
abstract class AuthProvider {
  /// Current authenticated user, or null.
  AuthUser? get currentUser;

  /// Stream of auth state changes. Emits null when signed out.
  Stream<AuthUser?> get authStateChanges;

  /// Sign in with email and password.
  Future<AuthUser> signInWithEmail(String email, String password);

  /// Register a new account with email and password.
  Future<AuthUser> registerWithEmail(String email, String password);

  /// Sign in with Google. Returns null if the user cancels.
  Future<AuthUser?> signInWithGoogle();

  /// Sign out of all providers.
  Future<void> signOut();

  /// Send a password reset email.
  Future<void> sendPasswordResetEmail(String email);

  /// Get the current ID token for API calls. Returns null if not signed in.
  Future<String?> getIdToken();
}
