import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/game_squad.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../models/game.dart';
import 'coach_auth_monitoring_service.dart';
import 'suspension_service.dart';

class GameSquadService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _gameSquadsCollection = 
      FirebaseFirestore.instance.collection('game_squads');

  // Create or update squad selection for a game
  Future<bool> selectSquadForGame({
    required String gameId,
    required String teamId,
    required List<Player> selectedPlayers,
    required String selectedByUserId,
    required String selectedByName,
    String? tournamentId,
    bool shouldSign = false,
  }) async {
    try {
      // Validate squad size (max 16 players)
      if (selectedPlayers.length > 16 || selectedPlayers.isEmpty) {
        debugPrint('\u274c Invalid squad size: ${selectedPlayers.length}');
        return false;
      }

      // Check for suspended players
      if (tournamentId != null) {
        final suspensionService = SuspensionService();
        for (final player in selectedPlayers) {
          final isSuspended = await suspensionService.isPlayerSuspendedForTournament(
            player.id,
            tournamentId,
          );
          if (isSuspended) {
            debugPrint('\u274c Player ${player.fullName} is suspended for tournament $tournamentId');
            return false;
          }
        }
      }

      // Convert players to SquadPlayer objects
      final squadPlayers = selectedPlayers.map((player) => 
        SquadPlayer(
          playerId: player.id,
          firstName: player.firstName,
          lastName: player.lastName,
          jerseyNumber: player.jerseyNumber,
          classification: player.classification,
          gender: player.gender,
        )
      ).toList();

      // Check if squad already exists for this game and team
      final existingSquad = await getSquadForGame(gameId, teamId);
      
      // Create coach approval if signing directly
      CoachApproval? coachApproval;
      if (shouldSign) {
        coachApproval = CoachApproval(
          isApproved: true,
          approvalTime: DateTime.now(),
          approvedByUserId: selectedByUserId,
          approvedByName: selectedByName,
          approvalMethod: 'biometric',
          notes: 'Direkt beim Erstellen signiert',
        );
      }

      if (existingSquad != null) {
        // Update existing squad
        final updatedSquad = existingSquad.copyWith(
          selectedPlayers: squadPlayers,
          selectedByUserId: selectedByUserId,
          selectedByName: selectedByName,
          updatedAt: DateTime.now(),
          coachApproval: shouldSign ? coachApproval : null, // Keep or reset approval
        );
        
        await _gameSquadsCollection.doc(existingSquad.id).update(updatedSquad.toFirestore());
        debugPrint('âœ… Updated squad for game $gameId, team $teamId');
      } else {
        // Create new squad
        final newSquad = GameSquad(
          id: '',
          gameId: gameId,
          teamId: teamId,
          selectedPlayers: squadPlayers,
          selectionTime: DateTime.now(),
          selectedByUserId: selectedByUserId,
          selectedByName: selectedByName,
          coachApproval: coachApproval,
          updatedAt: DateTime.now(),
        );
        
        await _gameSquadsCollection.add(newSquad.toFirestore());
        debugPrint('âœ… Created new squad for game $gameId, team $teamId');
      }
      
      return true;
    } catch (e) {
      debugPrint('âŒ Error selecting squad: $e');
      return false;
    }
  }

  // Get squad for a specific game and team
  Future<GameSquad?> getSquadForGame(String gameId, String teamId) async {
    try {
      final querySnapshot = await _gameSquadsCollection
          .where('gameId', isEqualTo: gameId)
          .where('teamId', isEqualTo: teamId)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        return GameSquad.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      debugPrint('âŒ Error getting squad: $e');
      return null;
    }
  }

  // Get all squads for a specific game (both teams)
  Future<List<GameSquad>> getSquadsForGame(String gameId) async {
    try {
      final querySnapshot = await _gameSquadsCollection
          .where('gameId', isEqualTo: gameId)
          .get();
      
      return querySnapshot.docs
          .map((doc) => GameSquad.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('âŒ Error getting game squads: $e');
      return [];
    }
  }

  // Stream squads for real-time updates (for iPads)
  Stream<List<GameSquad>> streamSquadsForGame(String gameId) {
    return _gameSquadsCollection
        .where('gameId', isEqualTo: gameId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => GameSquad.fromFirestore(doc)).toList());
  }

  // Coach approve/reject squad
  Future<bool> approveSquad({
    required String squadId,
    required bool isApproved,
    required String approvedByUserId,
    required String approvedByName,
    required String approvalMethod,
    String? notes,
  }) async {
    try {
      final approval = CoachApproval(
        isApproved: isApproved,
        approvalTime: DateTime.now(),
        approvedByUserId: approvedByUserId,
        approvedByName: approvedByName,
        approvalMethod: approvalMethod,
        notes: notes,
      );

      await _gameSquadsCollection.doc(squadId).update({
        'coachApproval': approval.toFirestore(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      debugPrint('âœ… Squad ${isApproved ? 'approved' : 'rejected'} by $approvedByName');
      return true;
    } catch (e) {
      debugPrint('âŒ Error approving squad: $e');
      return false;
    }
  }

  // Get squads managed by a specific team manager
  Future<List<GameSquad>> getSquadsByTeamManager(String userId) async {
    try {
      final querySnapshot = await _gameSquadsCollection
          .where('selectedByUserId', isEqualTo: userId)
          .orderBy('selectionTime', descending: true)
          .get();
      
      return querySnapshot.docs
          .map((doc) => GameSquad.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('âŒ Error getting squads by manager: $e');
      return [];
    }
  }

  // Get pending squads needing coach approval
  Future<List<GameSquad>> getPendingSquads() async {
    try {
      final querySnapshot = await _gameSquadsCollection
          .where('coachApproval', isNull: true)
          .orderBy('selectionTime', descending: true)
          .get();
      
      return querySnapshot.docs
          .map((doc) => GameSquad.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('âŒ Error getting pending squads: $e');
      return [];
    }
  }

  // Delete squad selection
  Future<bool> deleteSquad(String squadId) async {
    try {
      await _gameSquadsCollection.doc(squadId).delete();
      debugPrint('âœ… Deleted squad $squadId');
      return true;
    } catch (e) {
      debugPrint('âŒ Error deleting squad: $e');
      return false;
    }
  }

  // Get squad statistics
  Future<Map<String, int>> getSquadStatistics() async {
    try {
      final querySnapshot = await _gameSquadsCollection.get();
      
      int totalSquads = querySnapshot.docs.length;
      int approvedSquads = 0;
      int rejectedSquads = 0;
      int pendingSquads = 0;

      for (final doc in querySnapshot.docs) {
        final squad = GameSquad.fromFirestore(doc);
        if (squad.isApproved) {
          approvedSquads++;
        } else if (squad.isRejected) {
          rejectedSquads++;
        } else {
          pendingSquads++;
        }
      }

      return {
        'total': totalSquads,
        'approved': approvedSquads,
        'rejected': rejectedSquads,
        'pending': pendingSquads,
      };
    } catch (e) {
      debugPrint('âŒ Error getting squad statistics: $e');
      return {
        'total': 0,
        'approved': 0,
        'rejected': 0,
        'pending': 0,
      };
    }
  }

  // Check if team can select squad (team manager permissions)
  Future<bool> canTeamManagerSelectSquad(String userId, String teamId) async {
    try {
      // Check if user is a team manager for this specific team
      final teamDoc = await _firestore.collection('teams').doc(teamId).get();
      if (!teamDoc.exists) return false;
      
      final teamData = teamDoc.data() as Map<String, dynamic>;
      final teamManagerName = teamData['teamManager'] as String?;
      
      if (teamManagerName == null) return false;
      
      // Get team manager details from users collection to match userId
      final userQuery = await _firestore.collection('users')
          .where('displayName', isEqualTo: teamManagerName)
          .limit(1)
          .get();
          
      if (userQuery.docs.isEmpty) return false;
      
      final userDoc = userQuery.docs.first;
      return userDoc.id == userId;
      
    } catch (e) {
      debugPrint('âŒ Error checking team manager permissions: $e');
      return false;
    }
  }

  // Validate squad selection rules
  bool validateSquadSelection(List<Player> selectedPlayers) {
    // Check maximum 16 players
    if (selectedPlayers.length > 16) return false;
    
    // Check minimum 1 player
    if (selectedPlayers.isEmpty) return false;
    
    // Check for duplicate players
    final playerIds = selectedPlayers.map((p) => p.id).toSet();
    if (playerIds.length != selectedPlayers.length) return false;
    
    return true;
  }

  // Get available players for squad selection (from team roster)
  Future<List<Player>> getAvailablePlayersForTeam(String teamId) async {
    try {
      final teamDoc = await _firestore.collection('teams').doc(teamId).get();
      if (!teamDoc.exists) return [];
      
      final team = Team.fromFirestore(teamDoc);
      final playerIds = team.rosterPlayerIds;
      
      if (playerIds.isEmpty) return [];
      
      final players = <Player>[];
      for (final playerId in playerIds) {
        final playerDoc = await _firestore.collection('players').doc(playerId).get();
        if (playerDoc.exists) {
          final player = Player.fromFirestore(playerDoc);
          if (player.isActive) { // Only include active players
            players.add(player);
          }
        }
      }
      
      // Sort players by jersey number, then by name
      players.sort((a, b) {
        if (a.jerseyNumber != null && b.jerseyNumber != null) {
          final numA = int.tryParse(a.jerseyNumber!) ?? 999;
          final numB = int.tryParse(b.jerseyNumber!) ?? 999;
          if (numA != numB) return numA.compareTo(numB);
        }
        return a.fullName.compareTo(b.fullName);
      });
      
      return players;
    } catch (e) {
      debugPrint('âŒ Error getting available players: $e');
      return [];
    }
  }

  // Request coach authentication for squad approval
  Future<bool> requestCoachAuthentication({
    required String gameId,
    required String teamId,
    required String squadId,
    required String teamName,
    required String gameTitle,
    required DateTime gameDate,
    required String requestedByUserId,
    required String requestedByName,
    required String coachEmail,
    required String coachName,
  }) async {
    try {
      return await CoachAuthMonitoringService.createAuthRequest(
        gameId: gameId,
        teamId: teamId,
        squadId: squadId,
        teamName: teamName,
        gameTitle: gameTitle,
        gameDate: gameDate,
        requestedByUserId: requestedByUserId,
        requestedByName: requestedByName,
        coachEmail: coachEmail,
        coachName: coachName,
      );
    } catch (e) {
      debugPrint('âŒ Error requesting coach authentication: $e');
      return false;
    }
  }

  // Update team officials for a squad
  Future<void> updateSquadOfficials(String gameId, String teamId, List<TeamOfficial> officials) async {
    try {
      final squad = await getSquadForGame(gameId, teamId);
      if (squad != null) {
        await _gameSquadsCollection.doc(squad.id).update({
          'officials': officials.map((o) => o.toFirestore()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('âœ… Updated officials for game $gameId, team $teamId');
      }
    } catch (e) {
      debugPrint('âŒ Error updating squad officials: $e');
    }
  }
} 