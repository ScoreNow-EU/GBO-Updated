import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/club.dart';

class ClubService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'clubs';

  // Get all clubs as a stream
  Stream<List<Club>> getClubs() {
    return _firestore.collection(_collection)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Club.fromFirestore(doc)).toList());
  }

  // Get a specific club by ID
  Future<Club?> getClub(String clubId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection(_collection).doc(clubId).get();
      if (doc.exists) {
        return Club.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting club: $e');
      return null;
    }
  }

  // Create a new club
  Future<String?> createClub(Club club) async {
    try {
      DocumentReference docRef = await _firestore.collection(_collection).add(club.toFirestore());
      print('Club created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Error creating club: $e');
      return null;
    }
  }

  // Update a club
  Future<bool> updateClub(String clubId, Club club) async {
    try {
      await _firestore.collection(_collection).doc(clubId).update(
        club.copyWith(updatedAt: DateTime.now()).toFirestore()
      );
      print('Club updated: $clubId');
      return true;
    } catch (e) {
      print('Error updating club: $e');
      return false;
    }
  }

  // Delete a club
  Future<bool> deleteClub(String clubId) async {
    try {
      await _firestore.collection(_collection).doc(clubId).delete();
      print('Club deleted: $clubId');
      return true;
    } catch (e) {
      print('Error deleting club: $e');
      return false;
    }
  }

  // Add team to club
  Future<bool> addTeamToClub(String clubId, String teamId) async {
    try {
      DocumentReference clubRef = _firestore.collection(_collection).doc(clubId);
      await clubRef.update({
        'teamIds': FieldValue.arrayUnion([teamId]),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      print('Team $teamId added to club $clubId');
      return true;
    } catch (e) {
      print('Error adding team to club: $e');
      return false;
    }
  }

  // Remove team from club
  Future<bool> removeTeamFromClub(String clubId, String teamId) async {
    try {
      DocumentReference clubRef = _firestore.collection(_collection).doc(clubId);
      await clubRef.update({
        'teamIds': FieldValue.arrayRemove([teamId]),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      print('Team $teamId removed from club $clubId');
      return true;
    } catch (e) {
      print('Error removing team from club: $e');
      return false;
    }
  }

  // Get clubs by city/region
  Stream<List<Club>> getClubsByRegion(String bundesland) {
    return _firestore.collection(_collection)
        .where('bundesland', isEqualTo: bundesland)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Club.fromFirestore(doc)).toList());
  }

  // Search clubs by name
  Stream<List<Club>> searchClubs(String searchQuery) {
    return _firestore.collection(_collection)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Club.fromFirestore(doc))
            .where((club) => club.name.toLowerCase().contains(searchQuery.toLowerCase()))
            .toList());
  }
} 