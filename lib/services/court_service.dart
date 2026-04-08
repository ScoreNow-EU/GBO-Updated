import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/court.dart';

/// Simplified court service â€” courts are now just labels embedded in tournaments.
/// This service is kept for any standalone court operations but most court CRUD
/// happens through the TournamentService (as courts are embedded in the Tournament document).
class CourtService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'courts';

  // Get all courts as a stream (from standalone collection, if any remain)
  Stream<List<Court>> getCourts() {
    return _firestore.collection(_collection).snapshots().map((snapshot) {
      final courts = snapshot.docs
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return Court.fromMap(data);
          })
          .toList();
      courts.sort((a, b) => a.name.compareTo(b.name));
      return courts;
    });
  }

  // Get a specific court by ID
  Future<Court?> getCourt(String courtId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(courtId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Court.fromMap(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting court: $e');
      return null;
    }
  }

  // Create a new court
  Future<String?> createCourt(Court court) async {
    try {
      final docRef = _firestore.collection(_collection).doc();
      final courtWithId = court.copyWith(id: docRef.id);
      await docRef.set(courtWithId.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating court: $e');
      return null;
    }
  }

  // Update an existing court
  Future<bool> updateCourt(Court court) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(court.id)
          .update(court.toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating court: $e');
      return false;
    }
  }

  // Delete a court permanently
  Future<bool> deleteCourt(String courtId) async {
    try {
      await _firestore.collection(_collection).doc(courtId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting court: $e');
      return false;
    }
  }
}