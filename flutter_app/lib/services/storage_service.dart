import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadZipFile(String apiKey, Uint8List fileData, String fileName) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uploadFileName = '${timestamp}_$fileName';
      final path = 'uploads/$apiKey/$uploadFileName';

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

