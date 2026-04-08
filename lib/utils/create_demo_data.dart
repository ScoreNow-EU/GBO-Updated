import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/team.dart';
import '../models/tournament.dart';
import '../models/game.dart';

/// Script to create demo teams, tournaments, and games for testing
/// Run this from a Flutter app or test
class DemoDataCreator {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createDemoData() async {
    debugPrint('ðŸŽ¯ Creating demo data...');
    
    // Create demo teams
    final teamIds = await _createDemoTeams();
    debugPrint('âœ… Created ${teamIds.length} demo teams');
    
    // Create demo tournaments
    final tournamentIds = await _createDemoTournaments(teamIds);
    debugPrint('âœ… Created demo tournaments');
    
    // Create demo games for tournaments
    await _createDemoGames(tournamentIds, teamIds);
    debugPrint('âœ… Created demo games');
    
    debugPrint('ðŸŽ‰ Demo data creation complete!');
  }

  Future<List<String>> _createDemoTeams() async {
    final teams = [
      {
        'name': 'Hamburg Beach Kings',
        'city': 'Hamburg',
        'bundesland': 'Hamburg',
      },
      {
        'name': 'Berlin Sand Warriors',
        'city': 'Berlin',
        'bundesland': 'Berlin',
      },
      {
        'name': 'MÃ¼nchen Beach Stars',
        'city': 'MÃ¼nchen',
        'bundesland': 'Bayern',
      },
      {
        'name': 'KÃ¶ln Coastal Crew',
        'city': 'KÃ¶ln',
        'bundesland': 'Nordrhein-Westfalen',
      },
      {
        'name': 'Frankfurt Sand Fighters',
        'city': 'Frankfurt am Main',
        'bundesland': 'Hessen',
      },
      {
        'name': 'Stuttgart Beach United',
        'city': 'Stuttgart',
        'bundesland': 'Baden-WÃ¼rttemberg',
      },
      {
        'name': 'Dresden Dunes',
        'city': 'Dresden',
        'bundesland': 'Sachsen',
      },
      {
        'name': 'Hannover Heat',
        'city': 'Hannover',
        'bundesland': 'Niedersachsen',
      },
      {
        'name': 'Bremen Beach Blazers',
        'city': 'Bremen',
        'bundesland': 'Bremen',
      },
      {
        'name': 'Leipzig Ladies',
        'city': 'Leipzig',
        'bundesland': 'Sachsen',
      },
      {
        'name': 'DÃ¼sseldorf Divas',
        'city': 'DÃ¼sseldorf',
        'bundesland': 'Nordrhein-Westfalen',
      },
      {
        'name': 'NÃ¼rnberg Nets',
        'city': 'NÃ¼rnberg',
        'bundesland': 'Bayern',
      },
      {
        'name': 'Essen Eagles',
        'city': 'Essen',
        'bundesland': 'Nordrhein-Westfalen',
      },
      {
        'name': 'Dortmund Dolphins',
        'city': 'Dortmund',
        'bundesland': 'Nordrhein-Westfalen',
      },
      {
        'name': 'Karlsruhe Kickers',
        'city': 'Karlsruhe',
        'bundesland': 'Baden-WÃ¼rttemberg',
      },
      {
        'name': 'Mannheim Mavericks',
        'city': 'Mannheim',
        'bundesland': 'Baden-WÃ¼rttemberg',
      },
    ];

    List<String> teamIds = [];
    
    for (var teamData in teams) {
      final teamRef = _firestore.collection('teams').doc();
      final team = Team(
        id: teamRef.id,
        name: teamData['name'] as String,
        city: teamData['city'] as String,
        bundesland: teamData['bundesland'] as String,
        createdAt: DateTime.now(),
        totalPoints: _getRandomPoints(),
        pointsHistory: _generatePointsHistory(),
      );
      
      await teamRef.set(team.toFirestore());
      teamIds.add(teamRef.id);
    }
    
    return teamIds;
  }

  int _getRandomPoints() {
    // Random points between 0 and 500
    return (DateTime.now().millisecondsSinceEpoch % 500);
  }

  List<Map<String, dynamic>> _generatePointsHistory() {
    // Generate 2-5 random tournament results
    final numTournaments = 2 + (DateTime.now().millisecondsSinceEpoch % 4);
    List<Map<String, dynamic>> history = [];
    
    for (int i = 0; i < numTournaments; i++) {
      final points = 50 + (DateTime.now().millisecondsSinceEpoch % 150);
      history.add({
        'tournamentId': 'demo_tournament_$i',
        'tournamentName': 'Demo Tournament ${i + 1}',
        'points': points,
        'placement': (i % 4) + 1,
        'date': DateTime.now().subtract(Duration(days: 30 * (i + 1))).toIso8601String(),
      });
    }
    
    return history;
  }

  Future<List<String>> _createDemoTournaments(List<String> teamIds) async {
    final now = DateTime.now();
    
    final tournaments = [
      {
        'name': 'RHBL Spieltag 1',
        'location': 'Hamburg',
        'startDate': now.add(Duration(days: 30)),
        'endDate': now.add(Duration(days: 32)),
        'status': 'upcoming',
        'description': 'RHBL Spieltag in Hamburg.',
      },
      {
        'name': 'RHBL Spieltag 2',
        'location': 'Berlin',
        'startDate': now.add(Duration(days: 15)),
        'endDate': now.add(Duration(days: 16)),
        'status': 'upcoming',
        'description': 'RHBL Spieltag in der Hauptstadt.',
      },
      {
        'name': 'RHBL Spieltag 3',
        'location': 'MÃ¼nchen',
        'startDate': now.add(Duration(days: 45)),
        'endDate': now.add(Duration(days: 47)),
        'status': 'upcoming',
        'description': 'RHBL Spieltag in Bayern.',
      },
      {
        'name': 'RHBL Spieltag 4',
        'location': 'KÃ¶ln',
        'startDate': now.subtract(Duration(days: 10)),
        'endDate': now.subtract(Duration(days: 8)),
        'status': 'finished',
        'description': 'RHBL Spieltag am Rhein.',
      },
    ];

    List<String> tournamentIds = [];

    for (var tournamentData in tournaments) {
      final tournamentRef = _firestore.collection('tournaments').doc();
      
      // Randomly assign some teams to the tournament
      final numTeams = 4 + (DateTime.now().millisecondsSinceEpoch % 8);
      final assignedTeams = teamIds.take(numTeams.toInt()).toList();
      
      final tournament = Tournament(
        id: tournamentRef.id,
        name: tournamentData['name'] as String,
        location: tournamentData['location'] as String,
        startDate: tournamentData['startDate'] as DateTime,
        endDate: tournamentData['endDate'] as DateTime,
        status: tournamentData['status'] as String,
        description: tournamentData['description'] as String,
        teamIds: assignedTeams,
        approvalStatus: 'approved',
        isRegistrationOpen: tournamentData['status'] == 'upcoming',
      );
      
      await tournamentRef.set(tournament.toMap());
      tournamentIds.add(tournamentRef.id);
    }
    
    return tournamentIds;
  }

  Future<void> _createDemoGames(List<String> tournamentIds, List<String> teamIds) async {
    final now = DateTime.now();
    
    // Create games for each tournament
    for (int i = 0; i < tournamentIds.length; i++) {
      final tournamentId = tournamentIds[i];
      
      // Create 4-6 games per tournament
      final numGames = 4 + (i % 3);
      
      for (int j = 0; j < numGames; j++) {
        final gameRef = _firestore.collection('games').doc();
        
        // Pick two random teams
        final team1Index = (j * 2) % teamIds.length;
        final team2Index = (j * 2 + 1) % teamIds.length;
        
        // Determine game status and time
        GameStatus status;
        DateTime? scheduledTime;
        GameResult? result;
        
        if (i == 0 && j < 2) {
          // First tournament, first 2 games are LIVE
          status = GameStatus.inProgress;
          scheduledTime = now.subtract(Duration(minutes: 15 + j * 10));
          result = GameResult(
            teamAScore: 15 + j,
            teamBScore: 12 + j,
            winnerName: '',
          );
        } else if (j < 3) {
          // Upcoming games in next few hours
          status = GameStatus.scheduled;
          scheduledTime = now.add(Duration(hours: 1 + j, minutes: j * 15));
        } else {
          // Upcoming games tomorrow
          status = GameStatus.scheduled;
          scheduledTime = now.add(Duration(days: 1, hours: j));
        }
        
        final game = Game(
          id: gameRef.id,
          tournamentId: tournamentId,
          teamAId: teamIds[team1Index],
          teamBId: teamIds[team2Index],
          teamAName: 'Team ${String.fromCharCode(65 + team1Index)}',
          teamBName: 'Team ${String.fromCharCode(65 + team2Index)}',
          gameType: GameType.pool,
          status: status,
          scheduledTime: scheduledTime,
          result: result,
          createdAt: now,
          updatedAt: now,
        );
        
        await gameRef.set(game.toJson());
      }
    }
  }
}
