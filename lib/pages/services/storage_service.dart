import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadImage(XFile image, String patientId) async {
    try {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(image.path)}';
      final String filePath = 'patients/$patientId/wound_images/$fileName';
      final Reference ref = _storage.ref().child(filePath);
      UploadTask uploadTask;

      if (kIsWeb) {
        // Handle web platform
        final bytes = await image.readAsBytes();
        uploadTask = ref.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        // Handle mobile platforms
        final File file = File(image.path);
        uploadTask = ref.putFile(file);
      }

      // Wait for the upload to complete and get the download URL
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      throw Exception('Failed to upload image');
    }
  }

  Future<void> deleteImage(String imageUrl) async {
    try {
      final Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      print('Error deleting image: $e');
      throw Exception('Failed to delete image');
    }
  }
}
