import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/referee.dart';

class RefereeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'referees';

  // Get all referees
  Stream<List<Referee>> getReferees() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) {
          List<Referee> referees = snapshot.docs
              .map((doc) => Referee.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();
          
          // Sort locally by name
          referees.sort((a, b) => a.fullName.compareTo(b.fullName));
          return referees;
        });
  }

  // Get all referees as a list (non-stream)
  Future<List<Referee>> getAllReferees() async {
    QuerySnapshot snapshot = await _firestore.collection(_collection).get();
    List<Referee> referees = snapshot.docs
        .map((doc) => Referee.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
    
    // Sort by name
    referees.sort((a, b) => a.fullName.compareTo(b.fullName));
    return referees;
  }

  // Add a new referee (auto-geocodes address if provided)
  Future<void> addReferee(Referee referee) async {
    // Check if email already exists
    QuerySnapshot existingEmail = await _firestore
        .collection(_collection)
        .where('email', isEqualTo: referee.email.toLowerCase())
        .get();
        
    if (existingEmail.docs.isNotEmpty) {
      throw Exception('Ein Schiedsrichter mit dieser E-Mail-Adresse existiert bereits');
    }

    // Auto-geocode address
    Referee refereeToAdd = referee.copyWith(
      email: referee.email.toLowerCase(),
    );

    await _firestore.collection(_collection).add(refereeToAdd.toMap());
  }

  // Update referee (auto-geocodes address if changed)
  Future<void> updateReferee(Referee updatedReferee) async {
    // Check if email already exists for other referees
    QuerySnapshot existingEmail = await _firestore
        .collection(_collection)
        .where('email', isEqualTo: updatedReferee.email.toLowerCase())
        .get();
        
    for (var doc in existingEmail.docs) {
      if (doc.id != updatedReferee.id) {
        throw Exception('Ein anderer Schiedsrichter mit dieser E-Mail-Adresse existiert bereits');
      }
    }

    // Update timestamp
    Referee refereeToUpdate = updatedReferee.copyWith(
      email: updatedReferee.email.toLowerCase(),
      updatedAt: DateTime.now(),
    );

    await _firestore
        .collection(_collection)
        .doc(updatedReferee.id)
        .update(refereeToUpdate.toMap());
  }

  // Delete referee
  Future<void> deleteReferee(String refereeId) async {
    await _firestore.collection(_collection).doc(refereeId).delete();
  }

  // Get referee by ID
  Future<Referee?> getRefereeById(String id) async {
    DocumentSnapshot doc = await _firestore.collection(_collection).doc(id).get();
    if (doc.exists) {
      return Referee.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  // Get referees by license type
  Future<List<Referee>> getRefereesByLicenseType(String licenseType) async {
    QuerySnapshot snapshot = await _firestore
        .collection(_collection)
        .where('licenseType', isEqualTo: licenseType)
        .get();
        
    List<Referee> referees = snapshot.docs
        .map((doc) => Referee.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
        
    // Sort by name
    referees.sort((a, b) => a.fullName.compareTo(b.fullName));
    return referees;
  }

  // Search referees
  Future<List<Referee>> searchReferees(String searchTerm) async {
    List<Referee> allReferees = await getAllReferees();
    final term = searchTerm.toLowerCase();
    
    return allReferees.where((r) => 
      r.firstName.toLowerCase().contains(term) ||
      r.lastName.toLowerCase().contains(term) ||
      r.email.toLowerCase().contains(term) ||
      r.licenseType.toLowerCase().contains(term) ||
      (r.city?.toLowerCase().contains(term) ?? false)
    ).toList();
  }

  // Get referee count
  Future<int> get refereeCount async {
    QuerySnapshot snapshot = await _firestore.collection(_collection).get();
    return snapshot.docs.length;
  }

  // Get license type distribution
  Future<Map<String, int>> getLicenseTypeDistribution() async {
    List<Referee> allReferees = await getAllReferees();
    final distribution = <String, int>{};
    
    for (final licenseType in Referee.licenseTypes) {
      distribution[licenseType] = allReferees.where((r) => r.licenseType == licenseType).length;
    }
    return distribution;
  }

  /// Migrate all referees' license types from old values to new values in Firestore.
  /// Call this once from an admin screen when transitioning.
  Future<int> migrateLicenseTypes() async {
    final snapshot = await _firestore.collection(_collection).get();
    final batch = _firestore.batch();
    int migratedCount = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final oldLicense = data['licenseType'] as String? ?? '';
      final newLicense = Referee.migrateLicenseType(oldLicense);
      
      if (newLicense != oldLicense) {
        batch.update(doc.reference, {
          'licenseType': newLicense,
          'updatedAt': DateTime.now(),
        });
        migratedCount++;
      }
    }

    if (migratedCount > 0) {
      await batch.commit();
    }
    return migratedCount;
  }

  /// Remove the legacy invitationsPending field from all referee documents.
  Future<int> cleanupLegacyInvitationFields() async {
    final snapshot = await _firestore.collection(_collection).get();
    final batch = _firestore.batch();
    int cleanedCount = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data.containsKey('invitationsPending')) {
        batch.update(doc.reference, {
          'invitationsPending': FieldValue.delete(),
        });
        cleanedCount++;
      }
    }

    if (cleanedCount > 0) {
      await batch.commit();
    }
    return cleanedCount;
  }

  // Delete referee by user ID
  Future<void> deleteRefereeByUserId(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .get();
      
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Error deleting referee by user ID: $e');
      rethrow;
    }
  }

  // Clear cache and close stream
  void dispose() {
    // Firebase streams dispose automatically
  }
}