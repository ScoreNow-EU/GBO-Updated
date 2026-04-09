import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/season.dart';

class SeasonService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _collection => _firestore.collection('seasons');

  /// Create a new season
  Future<String> createSeason(Season season) async {
    final docRef = await _collection.add(season.toFirestore());
    debugPrint('Season created: ${docRef.id} - ${season.name}');
    return docRef.id;
  }

  /// Get all seasons
  Future<List<Season>> getAllSeasons() async {
    final snapshot = await _collection
        .orderBy('startDate', descending: true)
        .get();
    return snapshot.docs.map((doc) => Season.fromFirestore(doc)).toList();
  }

  /// Get active season
  Future<Season?> getActiveSeason() async {
    final snapshot = await _collection
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return Season.fromFirestore(snapshot.docs.first);
  }

  /// Get season by ID
  Future<Season?> getSeason(String seasonId) async {
    final doc = await _collection.doc(seasonId).get();
    if (!doc.exists) return null;
    return Season.fromFirestore(doc);
  }

  /// Stream all seasons (real-time)
  Stream<List<Season>> streamSeasons() {
    return _collection
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Season.fromFirestore(doc)).toList());
  }

  /// Update a season
  Future<void> updateSeason(String seasonId, Map<String, dynamic> updates) async {
    await _collection.doc(seasonId).update(updates);
    debugPrint('Season updated: $seasonId');
  }

  /// Add a Spieltag (tournament) to a season
  Future<void> addSpieltag(String seasonId, String tournamentId) async {
    await _collection.doc(seasonId).update({
      'spieltageIds': FieldValue.arrayUnion([tournamentId]),
    });
    debugPrint('Spieltag $tournamentId added to season $seasonId');
  }

  /// Remove a Spieltag from a season
  Future<void> removeSpieltag(String seasonId, String tournamentId) async {
    await _collection.doc(seasonId).update({
      'spieltageIds': FieldValue.arrayRemove([tournamentId]),
    });
    debugPrint('Spieltag $tournamentId removed from season $seasonId');
  }

  /// Set active season (deactivates all others)
  Future<void> setActiveSeason(String seasonId) async {
    final batch = _firestore.batch();
    // Deactivate all seasons
    final allSeasons = await _collection.get();
    for (final doc in allSeasons.docs) {
      batch.update(doc.reference, {'isActive': false});
    }
    // Activate the selected one
    batch.update(_collection.doc(seasonId), {'isActive': true});
    await batch.commit();
    debugPrint('Active season set to: $seasonId');
  }

  /// Delete a season
  Future<void> deleteSeason(String seasonId) async {
    await _collection.doc(seasonId).delete();
    debugPrint('Season deleted: $seasonId');
  }
}
