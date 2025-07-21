import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/team_manager.dart';
import '../models/team.dart';

class TeamManagerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _teamManagersCollection = 
      FirebaseFirestore.instance.collection('team_managers');

  // Create a new team manager
  Future<bool> createTeamManager(TeamManager teamManager) async {
    try {
      await _teamManagersCollection.add(teamManager.toFirestore());
      return true;
    } catch (e) {
      print('Error creating team manager: $e');
      return false;
    }
  }

  // Get all team managers
  Future<List<TeamManager>> getAllTeamManagers() async {
    try {
      final querySnapshot = await _teamManagersCollection
          .orderBy('name')
          .get();
      
      return querySnapshot.docs
          .map((doc) => TeamManager.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting team managers: $e');
      return [];
    }
  }

  // Get team manager by email
  Future<TeamManager?> getTeamManagerByEmail(String email) async {
    try {
      final querySnapshot = await _teamManagersCollection
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        return TeamManager.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      print('Error getting team manager by email: $e');
      return null;
    }
  }

  // Get team manager by name
  Future<TeamManager?> getTeamManagerByName(String name) async {
    try {
      print('🔍 Looking up team manager by name: $name');
      final querySnapshot = await _teamManagersCollection
          .where('name', isEqualTo: name)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        print('❌ No team manager found with name: $name');
        return null;
      }
      
      final teamManager = TeamManager.fromFirestore(querySnapshot.docs.first);
      print('✅ Found team manager: ${teamManager.name} (Email: ${teamManager.email})');
      return teamManager;
    } catch (e) {
      print('❌ Error getting team manager by name: $e');
      return null;
    }
  }

  // Get team manager by user ID
  Future<TeamManager?> getTeamManagerByUserId(String userId) async {
    try {
      final querySnapshot = await _teamManagersCollection
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        return TeamManager.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      print('Error getting team manager by user ID: $e');
      return null;
    }
  }

  // Update team manager
  Future<bool> updateTeamManager(String id, TeamManager teamManager) async {
    try {
      await _teamManagersCollection.doc(id).update(teamManager.toFirestore());
      return true;
    } catch (e) {
      print('Error updating team manager: $e');
      return false;
    }
  }

  // Delete team manager
  Future<bool> deleteTeamManager(String id) async {
    try {
      await _teamManagersCollection.doc(id).delete();
      return true;
    } catch (e) {
      print('Error deleting team manager: $e');
      return false;
    }
  }

  // Assign team to manager
  Future<bool> assignTeamToManager(String managerId, String teamId) async {
    try {
      final doc = await _teamManagersCollection.doc(managerId).get();
      if (doc.exists) {
        final teamManager = TeamManager.fromFirestore(doc);
        final updatedTeamIds = List<String>.from(teamManager.teamIds);
        
        if (!updatedTeamIds.contains(teamId)) {
          updatedTeamIds.add(teamId);
          await _teamManagersCollection.doc(managerId).update({
            'teamIds': updatedTeamIds,
          });
        }
        return true;
      }
      return false;
    } catch (e) {
      print('Error assigning team to manager: $e');
      return false;
    }
  }

  // Remove team from manager
  Future<bool> removeTeamFromManager(String managerId, String teamId) async {
    try {
      final doc = await _teamManagersCollection.doc(managerId).get();
      if (doc.exists) {
        final teamManager = TeamManager.fromFirestore(doc);
        final updatedTeamIds = List<String>.from(teamManager.teamIds);
        
        updatedTeamIds.remove(teamId);
        await _teamManagersCollection.doc(managerId).update({
          'teamIds': updatedTeamIds,
        });
        return true;
      }
      return false;
    } catch (e) {
      print('Error removing team from manager: $e');
      return false;
    }
  }

  // Link user account to team manager (when they register)
  Future<bool> linkUserToTeamManager(String email, String userId) async {
    try {
      final querySnapshot = await _teamManagersCollection
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.update({
          'userId': userId,
          'lastLoginAt': Timestamp.now(),
        });
        return true;
      }
      return false;
    } catch (e) {
      print('Error linking user to team manager: $e');
      return false;
    }
  }

  // Check if user is a team manager
  Future<bool> isUserTeamManager(String userId) async {
    try {
      final teamManager = await getTeamManagerByUserId(userId);
      return teamManager != null && teamManager.isActive;
    } catch (e) {
      print('Error checking if user is team manager: $e');
      return false;
    }
  }

  // Get teams managed by user
  Future<List<Team>> getTeamsManagedByUser(String userId) async {
    try {
      final teamManager = await getTeamManagerByUserId(userId);
      if (teamManager == null || teamManager.teamIds.isEmpty) {
        return [];
      }

      final teams = <Team>[];
      for (final teamId in teamManager.teamIds) {
        final teamDoc = await _firestore.collection('teams').doc(teamId).get();
        if (teamDoc.exists) {
          teams.add(Team.fromFirestore(teamDoc));
        }
      }
      return teams;
    } catch (e) {
      print('Error getting teams managed by user: $e');
      return [];
    }
  }

  // Get managers for a specific team
  Future<List<TeamManager>> getManagersForTeam(String teamId) async {
    try {
      final querySnapshot = await _teamManagersCollection
          .where('teamIds', arrayContains: teamId)
          .get();
      
      return querySnapshot.docs
          .map((doc) => TeamManager.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting managers for team: $e');
      return [];
    }
  }

  // Update last login time
  Future<void> updateLastLogin(String userId) async {
    try {
      final querySnapshot = await _teamManagersCollection
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.update({
          'lastLoginAt': Timestamp.now(),
        });
      }
    } catch (e) {
      print('Error updating last login: $e');
    }
  }
} 