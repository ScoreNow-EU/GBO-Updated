import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/court.dart';

class CourtService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'courts';

  // Get all courts as a stream
  Stream<List<Court>> getCourts({String? tournamentId}) {
    Query query = _firestore.collection(_collection).where('isActive', isEqualTo: true);
    
    if (tournamentId != null) {
      // If we want to filter courts by tournament in the future
      // query = query.where('tournamentId', isEqualTo: tournamentId);
    }
    
    // Remove orderBy to avoid compound index requirement - we'll sort in memory instead
    return query.snapshots().map((snapshot) {
      final courts = snapshot.docs
          .map((doc) => Court.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
      
      // Sort by name in memory to avoid Firebase compound index
      courts.sort((a, b) => a.name.compareTo(b.name));
      return courts;
    });
  }

  // Get a specific court by ID
  Future<Court?> getCourt(String courtId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(courtId).get();
      if (doc.exists) {
        return Court.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting court: $e');
      return null;
    }
  }

  // Create a new court
  Future<String?> createCourt(Court court) async {
    try {
      final docRef = _firestore.collection(_collection).doc();
      final courtWithId = court.copyWith(
        id: docRef.id,
        createdAt: DateTime.now(),
      );
      
      await docRef.set(courtWithId.toMap());
      return docRef.id;
    } catch (e) {
      print('Error creating court: $e');
      return null;
    }
  }

  // Update an existing court
  Future<bool> updateCourt(Court court) async {
    try {
      final updatedCourt = court.copyWith(updatedAt: DateTime.now());
      await _firestore
          .collection(_collection)
          .doc(court.id)
          .update(updatedCourt.toMap());
      return true;
    } catch (e) {
      print('Error updating court: $e');
      return false;
    }
  }

  // Delete a court (soft delete)
  Future<bool> deleteCourt(String courtId) async {
    try {
      await _firestore.collection(_collection).doc(courtId).update({
        'isActive': false,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error deleting court: $e');
      return false;
    }
  }

  // Hard delete a court (permanently remove)
  Future<bool> permanentlyDeleteCourt(String courtId) async {
    try {
      await _firestore.collection(_collection).doc(courtId).delete();
      return true;
    } catch (e) {
      print('Error permanently deleting court: $e');
      return false;
    }
  }

  // Get courts within a specific radius of a location
  Future<List<Court>> getCourtsNearLocation({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    try {
      // Note: This is a simplified approach. For production, you'd want to use
      // geohashing or a more sophisticated geo-query solution
      final snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();
      
      final courts = snapshot.docs
          .map((doc) => Court.fromMap(doc.data()))
          .toList();
      
      // Filter by distance (simplified distance calculation)
      return courts.where((court) {
        final distance = _calculateDistance(
          latitude, longitude,
          court.latitude, court.longitude,
        );
        return distance <= radiusKm;
      }).toList();
    } catch (e) {
      print('Error getting courts near location: $e');
      return [];
    }
  }

  // Simple distance calculation (Haversine formula approximation)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    
    final double a = 
        (dLat / 2) * (dLat / 2) +
        _degreesToRadians(lat1) * _degreesToRadians(lat2) *
        (dLon / 2) * (dLon / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
} 