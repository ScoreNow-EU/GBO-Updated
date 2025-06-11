import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/team.dart';

class TeamService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'teams';

  // Get all teams
  Stream<List<Team>> getTeams() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) {
          List<Team> teams = snapshot.docs
              .map((doc) => Team.fromFirestore(doc))
              .toList();
          
          // Sort by name
          teams.sort((a, b) => a.name.compareTo(b.name));
          return teams;
        });
  }

  // Get teams by Bundesland
  Stream<List<Team>> getTeamsByBundesland(String bundesland) {
    return _firestore
        .collection(_collection)
        .where('bundesland', isEqualTo: bundesland)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Team.fromFirestore(doc))
            .toList());
  }

  // Get teams by division
  Stream<List<Team>> getTeamsByDivision(String division) {
    return _firestore
        .collection(_collection)
        .where('division', isEqualTo: division)
        .snapshots()
        .map((snapshot) {
          List<Team> teams = snapshot.docs
              .map((doc) => Team.fromFirestore(doc))
              .toList();
          
          // Sort by name
          teams.sort((a, b) => a.name.compareTo(b.name));
          return teams;
        });
  }

  // Add a new team
  Future<void> addTeam(Team team) async {
    await _firestore.collection(_collection).add(team.toFirestore());
  }

  // Update team
  Future<void> updateTeam(Team team) async {
    await _firestore
        .collection(_collection)
        .doc(team.id)
        .update(team.toFirestore());
  }

  // Delete team
  Future<void> deleteTeam(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  // Get team by ID
  Future<Team?> getTeamById(String id) async {
    DocumentSnapshot doc = await _firestore.collection(_collection).doc(id).get();
    if (doc.exists) {
      return Team.fromFirestore(doc);
    }
    return null;
  }

  // Initialize with sample data
  Future<void> initializeSampleData() async {
    // No sample data initialization - teams will be created manually
    return;
  }
} 