import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:netlaunch_auth/netlaunch_auth.dart';

class UserPreferencesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthProvider _auth;

  UserPreferencesService(this._auth);

  /// Get the current user's preferences document reference
  DocumentReference? _getUserPrefsRef() {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _firestore.collection('userPreferences').doc(user.uid);
  }

  /// Save the last used API key for the current user
  Future<void> saveLastUsedApiKey(String apiKey) async {
    final ref = _getUserPrefsRef();
    if (ref == null) return;

    await ref.set({
      'lastUsedApiKey': apiKey,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get the last used API key for the current user
  Future<String?> getLastUsedApiKey() async {
    final ref = _getUserPrefsRef();
    if (ref == null) return null;

    try {
      final doc = await ref.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        return data?['lastUsedApiKey'] as String?;
      }
    } catch (e) {
      // Silently fail - user might not have preferences yet
    }
    return null;
  }

  /// Clear the saved API key
  Future<void> clearLastUsedApiKey() async {
    final ref = _getUserPrefsRef();
    if (ref == null) return;

    await ref.update({
      'lastUsedApiKey': FieldValue.delete(),
    });
  }
}
