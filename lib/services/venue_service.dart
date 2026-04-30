import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/venue.dart';

class VenueService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _collection => _firestore.collection('venues');

  /// Create a new venue
  Future<String> createVenue(Venue venue) async {
    final docRef = await _collection.add(venue.toFirestore());
    debugPrint('Venue created: ${docRef.id} - ${venue.name}');
    return docRef.id;
  }

  /// Get all venues
  Future<List<Venue>> getAllVenues() async {
    final snapshot = await _collection
        .orderBy('name')
        .get();
    return snapshot.docs.map((doc) => Venue.fromFirestore(doc)).toList();
  }

  /// Get venue by ID
  Future<Venue?> getVenue(String venueId) async {
    final doc = await _collection.doc(venueId).get();
    if (!doc.exists) return null;
    return Venue.fromFirestore(doc);
  }

  /// Get venue by host team
  Future<Venue?> getVenueByHostTeam(String teamId) async {
    final snapshot = await _collection
        .where('hostTeamId', isEqualTo: teamId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return Venue.fromFirestore(snapshot.docs.first);
  }

  /// Stream all venues (real-time)
  Stream<List<Venue>> streamVenues() {
    return _collection
        .orderBy('name')
        .limit(1000)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Venue.fromFirestore(doc)).toList());
  }

  /// Update a venue
  Future<void> updateVenue(String venueId, Venue venue) async {
    await _collection.doc(venueId).update(venue.toFirestore());
    debugPrint('Venue updated: $venueId');
  }

  /// Delete a venue
  Future<void> deleteVenue(String venueId) async {
    await _collection.doc(venueId).delete();
    debugPrint('Venue deleted: $venueId');
  }

  /// Search venues by city
  Future<List<Venue>> searchByCity(String city) async {
    final snapshot = await _collection
        .where('city', isEqualTo: city)
        .get();
    return snapshot.docs.map((doc) => Venue.fromFirestore(doc)).toList();
  }
}
