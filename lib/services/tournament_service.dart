import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tournament.dart';

class TournamentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'tournaments';

  // Get all tournaments (simplified to avoid indexing issues)
  Stream<List<Tournament>> getTournaments() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) {
          List<Tournament> tournaments = snapshot.docs
              .map((doc) => Tournament.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();
          
          // Sort locally instead of using orderBy to avoid index requirements
          tournaments.sort((a, b) => a.startDate.compareTo(b.startDate));
          return tournaments;
        });
  }

  // Get tournaments by status (simplified)
  Stream<List<Tournament>> getTournamentsByStatus(String status) {
    return _firestore
        .collection(_collection)
        .where('status', isEqualTo: status)
        .snapshots()
        .map((snapshot) {
          List<Tournament> tournaments = snapshot.docs
              .map((doc) => Tournament.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();
          
          // Sort locally instead of using orderBy to avoid index requirements
          tournaments.sort((a, b) => a.startDate.compareTo(b.startDate));
          return tournaments;
        });
  }

  // Get tournaments by category
  Stream<List<Tournament>> getTournamentsByCategory(String category) {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) {
          List<Tournament> tournaments = snapshot.docs
              .map((doc) => Tournament.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .where((tournament) => tournament.hasCategory(category))
              .toList();
          
          // Sort locally
          tournaments.sort((a, b) => a.startDate.compareTo(b.startDate));
          return tournaments;
        });
  }

  // Add a new tournament
  Future<void> addTournament(Tournament tournament) async {
    await _firestore.collection(_collection).add(tournament.toMap());
  }

  // Update tournament
  Future<void> updateTournament(Tournament tournament) async {
    await _firestore
        .collection(_collection)
        .doc(tournament.id)
        .update(tournament.toMap());
  }

  // Delete tournament
  Future<void> deleteTournament(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  // Get tournament by ID
  Future<Tournament?> getTournamentById(String id) async {
    DocumentSnapshot doc = await _firestore.collection(_collection).doc(id).get();
    if (doc.exists) {
      return Tournament.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  // Update referee nominations for a tournament
  Future<void> updateTournamentReferees(String tournamentId, List<String> refereeIds) async {
    await _firestore
        .collection(_collection)
        .doc(tournamentId)
        .update({'refereeIds': refereeIds});
  }

  // Initialize with sample data
  Future<void> initializeSampleData() async {
    // Check if data already exists
    QuerySnapshot existing = await _firestore.collection(_collection).limit(1).get();
    if (existing.docs.isNotEmpty) return;

    // Add sample tournaments with multiple categories
    List<Tournament> sampleTournaments = [
      Tournament(
        id: '',
        name: 'Herrenhäuser Beachcup 2025',
        categories: ['GBO Juniors Cup', 'GBO Seniors Cup'], // Both categories
        location: 'Hannover, DEU',
        startDate: DateTime(2025, 6, 13),
        endDate: DateTime(2025, 6, 14),
        points: 20,
        status: 'upcoming',
        description: 'Annual beach handball tournament in Hannover for all age groups',
      ),
      Tournament(
        id: '',
        name: 'Verdener Beach-Cup mU18 + mU16',
        categories: ['GBO Juniors Cup'], // Juniors only
        location: 'Verden (Aller), DEU',
        startDate: DateTime(2025, 6, 14),
        points: 20,
        status: 'upcoming',
        description: 'Youth tournament for U18 and U16 categories',
      ),
      Tournament(
        id: '',
        name: 'MOB BeachCup 2025',
        categories: ['GBO Juniors Cup', 'GBO Seniors Cup'], // Both categories
        location: 'Wittingen, DEU',
        startDate: DateTime(2025, 6, 15),
        points: 20,
        status: 'upcoming',
        description: 'Multi-age beach handball competition',
      ),
      Tournament(
        id: '',
        name: 'HVNB Cuxhaven Tournament',
        categories: ['GBO Seniors Cup'], // Seniors only
        location: 'Cuxhaven, DEU',
        startDate: DateTime(2025, 6, 19),
        endDate: DateTime(2025, 6, 21),
        points: 20,
        status: 'upcoming',
        description: 'Senior tournament at the coast',
      ),
    ];

    for (Tournament tournament in sampleTournaments) {
      await addTournament(tournament);
    }
  }
} 