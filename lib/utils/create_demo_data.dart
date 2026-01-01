import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/team.dart';
import '../models/tournament.dart';
import '../models/tournament_criteria.dart';
import '../models/game.dart';

/// Script to create demo teams, tournaments, and games for testing
/// Run this from a Flutter app or test
class DemoDataCreator {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createDemoData() async {
    print('🎯 Creating demo data...');
    
    // Create demo teams
    final teamIds = await _createDemoTeams();
    print('✅ Created ${teamIds.length} demo teams');
    
    // Create demo tournaments
    final tournamentIds = await _createDemoTournaments(teamIds);
    print('✅ Created demo tournaments');
    
    // Create demo games for tournaments
    await _createDemoGames(tournamentIds, teamIds);
    print('✅ Created demo games');
    
    print('🎉 Demo data creation complete!');
  }

  Future<List<String>> _createDemoTeams() async {
    final teams = [
      {
        'name': 'Hamburg Beach Kings',
        'city': 'Hamburg',
        'bundesland': 'Hamburg',
        'division': 'Men\'s Seniors',
      },
      {
        'name': 'Berlin Sand Warriors',
        'city': 'Berlin',
        'bundesland': 'Berlin',
        'division': 'Men\'s Seniors',
      },
      {
        'name': 'München Beach Stars',
        'city': 'München',
        'bundesland': 'Bayern',
        'division': 'Men\'s Seniors',
      },
      {
        'name': 'Köln Coastal Crew',
        'city': 'Köln',
        'bundesland': 'Nordrhein-Westfalen',
        'division': 'Men\'s Seniors',
      },
      {
        'name': 'Frankfurt Sand Fighters',
        'city': 'Frankfurt am Main',
        'bundesland': 'Hessen',
        'division': 'Men\'s Seniors',
      },
      {
        'name': 'Stuttgart Beach United',
        'city': 'Stuttgart',
        'bundesland': 'Baden-Württemberg',
        'division': 'Men\'s Seniors',
      },
      {
        'name': 'Dresden Dunes',
        'city': 'Dresden',
        'bundesland': 'Sachsen',
        'division': 'Men\'s Seniors',
      },
      {
        'name': 'Hannover Heat',
        'city': 'Hannover',
        'bundesland': 'Niedersachsen',
        'division': 'Men\'s Seniors',
      },
      {
        'name': 'Bremen Beach Blazers',
        'city': 'Bremen',
        'bundesland': 'Bremen',
        'division': 'Women\'s Seniors',
      },
      {
        'name': 'Leipzig Ladies',
        'city': 'Leipzig',
        'bundesland': 'Sachsen',
        'division': 'Women\'s Seniors',
      },
      {
        'name': 'Düsseldorf Divas',
        'city': 'Düsseldorf',
        'bundesland': 'Nordrhein-Westfalen',
        'division': 'Women\'s Seniors',
      },
      {
        'name': 'Nürnberg Nets',
        'city': 'Nürnberg',
        'bundesland': 'Bayern',
        'division': 'Women\'s Seniors',
      },
      {
        'name': 'Essen Eagles',
        'city': 'Essen',
        'bundesland': 'Nordrhein-Westfalen',
        'division': 'U18',
      },
      {
        'name': 'Dortmund Dolphins',
        'city': 'Dortmund',
        'bundesland': 'Nordrhein-Westfalen',
        'division': 'U18',
      },
      {
        'name': 'Karlsruhe Kickers',
        'city': 'Karlsruhe',
        'bundesland': 'Baden-Württemberg',
        'division': 'U16',
      },
      {
        'name': 'Mannheim Mavericks',
        'city': 'Mannheim',
        'bundesland': 'Baden-Württemberg',
        'division': 'U16',
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
        division: teamData['division'] as String,
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
        'name': 'German Beach Open 2025',
        'location': 'Hamburg',
        'startDate': now.add(Duration(days: 30)),
        'endDate': now.add(Duration(days: 32)),
        'categories': ['Men\'s Seniors', 'Women\'s Seniors'],
        'points': 500,
        'status': 'upcoming',
        'description': 'The biggest beach handball tournament in Germany!',
      },
      {
        'name': 'Berlin Beach Championship',
        'location': 'Berlin',
        'startDate': now.add(Duration(days: 15)),
        'endDate': now.add(Duration(days: 16)),
        'categories': ['Men\'s Seniors', 'U18'],
        'points': 300,
        'status': 'upcoming',
        'description': 'Annual beach handball championship in the capital.',
      },
      {
        'name': 'Munich Summer Cup',
        'location': 'München',
        'startDate': now.add(Duration(days: 45)),
        'endDate': now.add(Duration(days: 47)),
        'categories': ['Women\'s Seniors', 'U16'],
        'points': 400,
        'status': 'upcoming',
        'description': 'Summer beach handball tournament in Bavaria.',
      },
      {
        'name': 'Rhine Beach Festival',
        'location': 'Köln',
        'startDate': now.subtract(Duration(days: 10)),
        'endDate': now.subtract(Duration(days: 8)),
        'categories': ['Men\'s Seniors', 'Women\'s Seniors', 'U18', 'U16'],
        'points': 600,
        'status': 'finished',
        'description': 'Major beach handball festival at the Rhine.',
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
        categories: List<String>.from(tournamentData['categories'] as List),
        location: tournamentData['location'] as String,
        startDate: tournamentData['startDate'] as DateTime,
        endDate: tournamentData['endDate'] as DateTime,
        points: tournamentData['points'] as int,
        status: tournamentData['status'] as String,
        description: tournamentData['description'] as String,
        teamIds: assignedTeams,
        approvalStatus: 'approved', // Make it approved so it's visible
        isRegistrationOpen: tournamentData['status'] == 'upcoming',
        divisions: List<String>.from(tournamentData['categories'] as List),
        divisionMaxTeams: {
          for (var cat in tournamentData['categories'] as List)
            cat as String: 16
        },
        criteria: TournamentCriteria(
          officialBeachhandballRules: true,
          twoRefereesPerGame: true,
          cleanZone: true,
          gboOnlineSchedule: true,
          gboScoringSystem: true,
        ),
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
            teamASetWins: j % 2,
            teamBSetWins: (j + 1) % 2,
            sets: [
              SetResult(
                setNumber: 1,
                teamAScore: 15 + j,
                teamBScore: 12 + j,
                winnerName: 'Team A',
              ),
            ],
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
