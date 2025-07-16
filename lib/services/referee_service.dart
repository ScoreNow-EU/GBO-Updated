import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Add a new referee
  Future<void> addReferee(Referee referee) async {
    // Check if email already exists
    QuerySnapshot existingEmail = await _firestore
        .collection(_collection)
        .where('email', isEqualTo: referee.email.toLowerCase())
        .get();
        
    if (existingEmail.docs.isNotEmpty) {
      throw Exception('Ein Schiedsrichter mit dieser E-Mail-Adresse existiert bereits');
    }

    // Create referee with lowercase email for consistency
    final refereeToAdd = referee.copyWith(
      email: referee.email.toLowerCase(),
    );

    await _firestore.collection(_collection).add(refereeToAdd.toMap());
  }

  // Update referee
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

    // Update with lowercase email and updated timestamp
    final refereeToUpdate = updatedReferee.copyWith(
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
    // Get all referees and filter locally (Firestore doesn't support complex text search)
    List<Referee> allReferees = await getAllReferees();
    final term = searchTerm.toLowerCase();
    
    return allReferees.where((r) => 
      r.firstName.toLowerCase().contains(term) ||
      r.lastName.toLowerCase().contains(term) ||
      r.email.toLowerCase().contains(term) ||
      r.licenseType.toLowerCase().contains(term)
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

  // Initialize with sample data
  Future<void> initializeSampleData() async {
    // Check if data already exists
    QuerySnapshot existing = await _firestore.collection(_collection).limit(1).get();
    if (existing.docs.isNotEmpty) return;

    // Add sample referees
    List<Referee> sampleReferees = [
      Referee(
        id: '',
        firstName: 'Max',
        lastName: 'Mustermann',
        email: 'max.mustermann@example.com',
        licenseType: 'DHB Elitekader',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Referee(
        id: '',
        firstName: 'Anna',
        lastName: 'Schmidt',
        email: 'anna.schmidt@example.com',
        licenseType: 'DHB Stamm+Anschlusskader',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Referee(
        id: '',
        firstName: 'Thomas',
        lastName: 'Weber',
        email: 'thomas.weber@example.com',
        licenseType: 'Perspektivkader',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Referee(
        id: '',
        firstName: 'Lisa',
        lastName: 'Müller',
        email: 'lisa.mueller@example.com',
        licenseType: 'Basis-Lizenz',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    for (Referee referee in sampleReferees) {
      await addReferee(referee);
    }
  }

  // Create sample referees for testing
  Future<void> createSampleReferees() async {
    List<Referee> sampleReferees = [
      Referee(
        id: '',
        firstName: 'Max',
        lastName: 'Mustermann',
        email: 'referee1@gbo.test',
        licenseType: 'DHB Elitekader',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Referee(
        id: '',
        firstName: 'Anna',
        lastName: 'Schmidt',
        email: 'referee2@gbo.test',
        licenseType: 'DHB Stamm+Anschlusskader',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Referee(
        id: '',
        firstName: 'Thomas',
        lastName: 'Weber',
        email: 'referee3@gbo.test',
        licenseType: 'Basis-Lizenz',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    for (Referee referee in sampleReferees) {
      // Check if referee already exists
      final existingReferees = await getAllReferees();
      final exists = existingReferees.any((r) => r.email == referee.email);
      
      if (!exists) {
        await addReferee(referee);
        print('Created sample referee: ${referee.fullName} (${referee.email})');
      }
    }
  }

  // Clear cache and close stream
  void dispose() {
    // Firebase streams dispose automatically
  }

  // Update referee pending invitations array
  Future<void> updatePendingInvitations(String refereeId, List<String> tournamentIds) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(refereeId)
          .set({
        'invitationsPending': tournamentIds,
        'updatedAt': DateTime.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating pending invitations: $e');
    }
  }

  // Add pending invitation for a tournament
  Future<void> addPendingInvitation(String refereeId, String tournamentId) async {
    try {
      final referee = await getRefereeById(refereeId);
      if (referee != null && !referee.hasPendingInvitation(tournamentId)) {
        final updatedPending = [...referee.invitationsPending, tournamentId];
        await updatePendingInvitations(refereeId, updatedPending);
      }
    } catch (e) {
      print('Error adding pending invitation: $e');
    }
  }

  // Remove pending invitation for a tournament
  Future<void> removePendingInvitation(String refereeId, String tournamentId) async {
    try {
      final referee = await getRefereeById(refereeId);
      if (referee != null && referee.hasPendingInvitation(tournamentId)) {
        final updatedPending = referee.invitationsPending.where((id) => id != tournamentId).toList();
        await updatePendingInvitations(refereeId, updatedPending);
      }
    } catch (e) {
      print('Error removing pending invitation: $e');
    }
  }

  // Get pending invitations count for a referee
  Future<int> getPendingInvitationsCount(String refereeId) async {
    try {
      final referee = await getRefereeById(refereeId);
      return referee?.pendingInvitationsCount ?? 0;
    } catch (e) {
      print('Error getting pending invitations count: $e');
      return 0;
    }
  }

  // Get pending tournament IDs for a referee
  Future<List<String>> getPendingInvitations(String refereeId) async {
    try {
      final referee = await getRefereeById(refereeId);
      return referee?.invitationsPending ?? [];
    } catch (e) {
      print('Error getting pending invitations: $e');
      return [];
    }
  }

  // Update multiple referees' pending invitations (batch operation)
  Future<void> updateMultipleRefereesPendingInvitations(Map<String, List<String>> refereeInvitationsMap) async {
    try {
      final batch = _firestore.batch();
      final now = DateTime.now();
      
      for (final entry in refereeInvitationsMap.entries) {
        final refereeId = entry.key;
        final tournamentIds = entry.value;
        
        final docRef = _firestore.collection(_collection).doc(refereeId);
        batch.set(docRef, {
          'invitationsPending': tournamentIds,
          'updatedAt': now,
        }, SetOptions(merge: true));
      }
      
      await batch.commit();
    } catch (e) {
      print('Error updating multiple referees pending invitations: $e');
    }
  }

  // Update all referees to have invitationsPending field set to empty array if missing
  Future<void> initializePendingInvitationsFieldForAllReferees() async {
    try {
      final batch = _firestore.batch();
      final now = DateTime.now();
      
      // Get all referees
      final snapshot = await _firestore.collection(_collection).get();
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        // Initialize if missing or if it's the old int format
        if (!data.containsKey('invitationsPending') || data['invitationsPending'] is int) {
          batch.set(doc.reference, {
            'invitationsPending': <String>[],
            'updatedAt': now,
          }, SetOptions(merge: true));
        }
      }
      
      await batch.commit();
      print('Initialized invitationsPending field for all referees');
    } catch (e) {
      print('Error initializing pending invitations field: $e');
    }
  }

  // Legacy methods for backward compatibility (deprecated)
  @Deprecated('Use addPendingInvitation instead')
  Future<void> incrementPendingInvitations(String refereeId) async {
    // This method is deprecated and does nothing
    print('Warning: incrementPendingInvitations is deprecated');
  }

  @Deprecated('Use removePendingInvitation instead')
  Future<void> decrementPendingInvitations(String refereeId) async {
    // This method is deprecated and does nothing
    print('Warning: decrementPendingInvitations is deprecated');
  }

  @Deprecated('Use updatePendingInvitations instead')
  Future<void> updatePendingInvitationsCount(String refereeId, int count) async {
    // This method is deprecated and does nothing
    print('Warning: updatePendingInvitationsCount is deprecated');
  }

  @Deprecated('Use updateMultipleRefereesPendingInvitations instead')
  Future<void> updateMultipleRefereesPendingCount(Map<String, int> refereeCountMap) async {
    // This method is deprecated and does nothing
    print('Warning: updateMultipleRefereesPendingCount is deprecated');
  }
} 