/// NetLaunch Auth — provider-agnostic authentication package.
///
/// Use [AuthProvider] as the interface in your app.
/// Use [FirebaseAuthProvider] as the concrete implementation.
///
/// ```dart
/// // In main.dart:
/// Provider<AuthProvider>(create: (_) => FirebaseAuthProvider())
///
/// // In any screen:
/// final auth = Provider.of<AuthProvider>(context, listen: false);
/// await auth.signInWithGoogle();
/// ```
library netlaunch_auth;

// Abstract interface (depend on these)
export 'src/auth_provider.dart';
export 'src/auth_user.dart';
export 'src/auth_state.dart';
export 'src/auth_exception.dart';

// Implementations (inject in main.dart)
export 'src/firebase_auth_provider.dart';
