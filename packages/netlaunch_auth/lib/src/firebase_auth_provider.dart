import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'auth_provider.dart';
import 'auth_user.dart';
import 'auth_exception.dart';

/// Firebase implementation of [AuthProvider].
class FirebaseAuthProvider implements AuthProvider {
  final fb.FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  FirebaseAuthProvider({
    fb.FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? fb.FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  @override
  AuthUser? get currentUser => _mapUser(_auth.currentUser);

  @override
  Stream<AuthUser?> get authStateChanges =>
      _auth.authStateChanges().map(_mapUser);

  @override
  Future<AuthUser> signInWithEmail(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _mapUser(result.user)!;
    } on fb.FirebaseAuthException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<AuthUser> registerWithEmail(String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _mapUser(result.user)!;
    } on fb.FirebaseAuthException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<AuthUser?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = fb.GoogleAuthProvider();
        final result = await _auth.signInWithPopup(provider);
        return _mapUser(result.user);
      } else {
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null;

        final googleAuth = await googleUser.authentication;
        final credential = fb.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final result = await _auth.signInWithCredential(credential);
        return _mapUser(result.user);
      }
    } on fb.FirebaseAuthException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on fb.FirebaseAuthException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<String?> getIdToken() async {
    return _auth.currentUser?.getIdToken();
  }

  // ── Mapping helpers ──────────────────────────────────────────

  AuthUser? _mapUser(fb.User? user) {
    if (user == null) return null;
    return AuthUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }

  AuthException _mapException(fb.FirebaseAuthException e) {
    final message = switch (e.code) {
      'user-not-found' => 'No user found with this email.',
      'wrong-password' => 'Wrong password provided.',
      'email-already-in-use' => 'An account already exists with this email.',
      'invalid-email' => 'Invalid email address.',
      'weak-password' => 'Password is too weak.',
      'operation-not-allowed' => 'This sign-in method is not enabled.',
      'too-many-requests' => 'Too many attempts. Please try again later.',
      _ => e.message ?? 'An error occurred. Please try again.',
    };
    return AuthException(code: e.code, message: message);
  }
}
