import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/document.dart';

class DocumentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<List<Document>> getDocuments() {
    return _firestore
        .collection('documents')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Document.fromFirestore(doc)).toList());
  }

  Stream<List<Document>> getDocumentsByCategory(String category) {
    return _firestore
        .collection('documents')
        .where('category', isEqualTo: category)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Document.fromFirestore(doc)).toList());
  }

  Future<Document> uploadDocument({
    required String name,
    required String category,
    required Uint8List fileBytes,
    required String fileName,
    required String mimeType,
    required String uploadedByUserId,
  }) async {
    try {
      // Check for existing document with same name to increment version
      final existing = await _firestore
          .collection('documents')
          .where('name', isEqualTo: name)
          .orderBy('version', descending: true)
          .limit(1)
          .get();
      
      final nextVersion = existing.docs.isNotEmpty
          ? (existing.docs.first.data()['version'] as int? ?? 0) + 1
          : 1;

      // Upload file to Firebase Storage
      final sanitizedName = fileName.replaceAll(RegExp(r'[^\w\.\-]'), '_');
      final storagePath = 'documents/$category/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName';
      final ref = _storage.ref().child(storagePath);
      
      final metadata = SettableMetadata(contentType: mimeType);
      await ref.putData(fileBytes, metadata);
      final downloadUrl = await ref.getDownloadURL();

      // Save metadata to Firestore
      final docRef = await _firestore.collection('documents').add({
        'name': name,
        'category': category,
        'version': nextVersion,
        'uploadedBy': uploadedByUserId,
        'uploadedAt': FieldValue.serverTimestamp(),
        'storageUrl': downloadUrl,
        'fileSize': fileBytes.length,
        'mimeType': mimeType,
      });

      debugPrint('✅ Document uploaded: $name v$nextVersion');
      
      return Document(
        id: docRef.id,
        name: name,
        category: category,
        version: nextVersion,
        uploadedBy: uploadedByUserId,
        uploadedAt: DateTime.now(),
        storageUrl: downloadUrl,
        fileSize: fileBytes.length,
        mimeType: mimeType,
      );
    } catch (e) {
      debugPrint('❌ Error uploading document: $e');
      rethrow;
    }
  }

  Future<void> deleteDocument(Document document) async {
    try {
      // Delete from Storage
      try {
        final ref = _storage.refFromURL(document.storageUrl);
        await ref.delete();
      } catch (e) {
        debugPrint('⚠️ Could not delete from storage: $e');
      }
      
      // Delete from Firestore
      await _firestore.collection('documents').doc(document.id).delete();
      debugPrint('✅ Document deleted: ${document.name}');
    } catch (e) {
      debugPrint('❌ Error deleting document: $e');
      rethrow;
    }
  }
}
