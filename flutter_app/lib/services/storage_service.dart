import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Creates a file upload request document in Firestore before uploading
  /// This stores the API key and site name securely so the Cloud Function can retrieve it
  Future<String> _createUploadRequest({
    required String apiKey,
    required String filePath,
    required String fileName,
    required String siteName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    
    final doc = await _firestore.collection('fileUploadRequests').add({
      'apiKey': apiKey,
      'filePath': filePath,
      'fileName': fileName,
      'siteName': siteName,
      'userId': user?.uid,
      'userEmail': user?.email,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    return doc.id;
  }
  
  /// Validates site name format
  /// Must be 3-30 chars, lowercase, start with letter, only letters/numbers/hyphens
  static String? validateSiteName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a site name';
    }
    if (value.length < 3) {
      return 'Site name must be at least 3 characters';
    }
    if (value.length > 30) {
      return 'Site name must be 30 characters or less';
    }
    if (!RegExp(r'^[a-z]').hasMatch(value)) {
      return 'Site name must start with a letter';
    }
    if (!RegExp(r'^[a-z][a-z0-9-]*$').hasMatch(value)) {
      return 'Only lowercase letters, numbers, and hyphens allowed';
    }
    if (value.endsWith('-')) {
      return 'Site name cannot end with a hyphen';
    }
    return null;
  }

  Future<String> uploadZipFile(String apiKey, Uint8List fileData, String fileName, String siteName) async {
    try {
      // Validate site name
      final validationError = validateSiteName(siteName);
      if (validationError != null) {
        throw Exception(validationError);
      }
      
      final user = FirebaseAuth.instance.currentUser;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uploadFileName = '${timestamp}_$fileName';
      final userId = user?.uid ?? 'anonymous';
      final path = 'uploads/$userId/$uploadFileName';

      // Create upload request in Firestore first with site name
      await _createUploadRequest(
        apiKey: apiKey,
        filePath: path,
        fileName: fileName,
        siteName: siteName,
      );

      final ref = _storage.ref().child(path);
      final uploadTask = ref.putData(fileData);

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  Future<FilePickerResult?> pickZipFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      return result;
    } catch (e) {
      throw Exception('Failed to pick file: $e');
    }
  }

  /// Upload with progress - creates Firestore request first, then uploads
  /// [siteName] is the user-chosen subdomain (e.g., "my-app" -> my-app.web.app)
  Future<Stream<TaskSnapshot>> uploadZipFileWithProgressAsync(
    String apiKey,
    Uint8List fileData,
    String fileName,
    String siteName,
  ) async {
    // Validate site name
    final validationError = validateSiteName(siteName);
    if (validationError != null) {
      throw Exception(validationError);
    }
    
    final user = FirebaseAuth.instance.currentUser;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uploadFileName = '${timestamp}_$fileName';
    final userId = user?.uid ?? 'anonymous';
    final path = 'uploads/$userId/$uploadFileName';

    // Create upload request in Firestore first with the site name
    await _createUploadRequest(
      apiKey: apiKey,
      filePath: path,
      fileName: fileName,
      siteName: siteName,
    );

    final ref = _storage.ref().child(path);
    final uploadTask = ref.putData(fileData);

    return uploadTask.snapshotEvents;
  }
  
  /// Legacy method - kept for backwards compatibility but use uploadZipFileWithProgressAsync instead
  @Deprecated('Use uploadZipFileWithProgressAsync instead')
  Stream<TaskSnapshot> uploadZipFileWithProgress(
    String apiKey,
    Uint8List fileData,
    String fileName,
  ) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uploadFileName = '${timestamp}_$fileName';
    final path = 'uploads/$apiKey/$uploadFileName';

    final ref = _storage.ref().child(path);
    final uploadTask = ref.putData(fileData);

    return uploadTask.snapshotEvents;
  }
}

