import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/story.dart';

/// Service for Instagram-style Stories hosted on Firebase Storage.
///
/// Upload flow (fully client-side, no Cloud Function needed):
///   1. Upload video bytes to `stories/{storyId}/video.*` in Firebase Storage
///   2. Get download URL
///   3. Create Firestore doc with status='active'
class StoryService {
  static const String _collection = 'stories';

  final FirebaseFirestore _firestore;

  StoryService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Stream of active, non-expired stories ordered by [order] ascending.
  Stream<List<Story>> getActiveStories() {
    return _firestore
        .collection(_collection)
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs
            .map(Story.fromFirestore)
            .where((s) => s.isActive)
            .toList());
  }

  /// Stream of ALL stories (including uploading + expired) for the admin view.
  Stream<List<Story>> getAllStories() {
    return _firestore
        .collection(_collection)
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs.map(Story.fromFirestore).toList());
  }

  /// Upload a story video directly to Firebase Storage, then create a
  /// Firestore doc with the download URL.
  ///
  /// [onProgress] receives 0.0–1.0 during the upload.
  Future<void> uploadStory({
    required Uint8List bytes,
    required String filename,
    required String title,
    DateTime? expiresAt,
    String? groupTitle,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.0);

    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';

    // Reserve a Firestore doc ID so the storage path is stable
    final storyRef = _firestore.collection(_collection).doc();
    final storyId = storyRef.id;

    final ext = filename.contains('.') ? filename.split('.').last : 'mp4';
    final storagePath = 'stories/$storyId/video.$ext';
    final storageRef = FirebaseStorage.instance.ref(storagePath);

    // Upload to Firebase Storage with progress tracking
    final uploadTask = storageRef.putData(
      bytes,
      SettableMetadata(contentType: 'video/mp4'),
    );

    uploadTask.snapshotEvents.listen((snap) {
      if (snap.totalBytes > 0) {
        onProgress?.call(snap.bytesTransferred / snap.totalBytes * 0.95);
      }
    });

    await uploadTask;
    onProgress?.call(0.95);

    final videoUrl = await storageRef.getDownloadURL();

    // Determine next display order
    final storiesSnap = await _firestore
        .collection(_collection)
        .orderBy('order', descending: true)
        .limit(1)
        .get();
    final maxOrder = storiesSnap.docs.isEmpty
        ? 0
        : (storiesSnap.docs.first.data()['order'] as int? ?? 0);

    // Create Firestore story doc
    await storyRef.set({
      'title': title.trim(),
      'videoUrl': videoUrl,
      'uploadedBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt':
          expiresAt != null ? Timestamp.fromDate(expiresAt.toUtc()) : null,
      'order': maxOrder + 1,
      'status': 'active',
      if (groupTitle != null && groupTitle.isNotEmpty)
        'groupTitle': groupTitle.trim(),
    });

    onProgress?.call(1.0);
  }

  /// Returns the distinct group titles currently in use (for autocomplete).
  Future<List<String>> getGroupTitles() async {
    final snap = await _firestore.collection(_collection).get();
    final titles = snap.docs
        .map((d) => d.data()['groupTitle'] as String?)
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return titles;
  }

  /// Deletes a story from Firestore and its video from Firebase Storage.
  Future<void> deleteStory(Story story) async {
    // Delete Storage file (best-effort)
    try {
      final storageRef = FirebaseStorage.instance
          .ref('stories/${story.id}');
      final listResult = await storageRef.listAll();
      for (final item in listResult.items) {
        await item.delete();
      }
    } catch (_) {}

    await _firestore.doc('$_collection/${story.id}').delete();
  }

  /// Moves a story one position up (lower order value = shown earlier).
  Future<void> moveUp(Story story, List<Story> allStories) async {
    final idx = allStories.indexWhere((s) => s.id == story.id);
    if (idx <= 0) return;
    final above = allStories[idx - 1];
    final batch = _firestore.batch();
    batch.update(
        _firestore.doc('$_collection/${story.id}'), {'order': above.order});
    batch.update(
        _firestore.doc('$_collection/${above.id}'), {'order': story.order});
    await batch.commit();
  }

  /// Moves a story one position down (higher order value = shown later).
  Future<void> moveDown(Story story, List<Story> allStories) async {
    final idx = allStories.indexWhere((s) => s.id == story.id);
    if (idx < 0 || idx >= allStories.length - 1) return;
    final below = allStories[idx + 1];
    final batch = _firestore.batch();
    batch.update(
        _firestore.doc('$_collection/${story.id}'), {'order': below.order});
    batch.update(
        _firestore.doc('$_collection/${below.id}'), {'order': story.order});
    await batch.commit();
  }
}
