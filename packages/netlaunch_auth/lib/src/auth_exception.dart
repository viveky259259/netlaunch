/// Provider-agnostic authentication exception.
class AuthException implements Exception {
  final String code;
  final String message;

  const AuthException({required this.code, required this.message});

  @override
  String toString() => message;

  /// Common error codes (provider-agnostic).
  static const String userNotFound = 'user-not-found';
  static const String wrongPassword = 'wrong-password';
  static const String emailAlreadyInUse = 'email-already-in-use';
  static const String invalidEmail = 'invalid-email';
  static const String weakPassword = 'weak-password';
  static const String tooManyRequests = 'too-many-requests';
  static const String operationNotAllowed = 'operation-not-allowed';
  static const String unknown = 'unknown';
}
