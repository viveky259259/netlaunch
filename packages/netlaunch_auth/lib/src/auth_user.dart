/// Provider-agnostic user model.
/// No dependency on Firebase or any specific auth provider.
class AuthUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  const AuthUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
  });

  String get initials {
    if (displayName != null && displayName!.isNotEmpty) {
      return displayName!
          .split(' ')
          .where((p) => p.isNotEmpty)
          .take(2)
          .map((p) => p[0].toUpperCase())
          .join();
    }
    if (email != null && email!.isNotEmpty) {
      return email![0].toUpperCase();
    }
    return 'U';
  }
}
