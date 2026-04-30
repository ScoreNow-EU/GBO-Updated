import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game.dart';
import '../models/game_event.dart';
import 'stats_aggregator.dart';
import 'tournament_stats_service.dart';

/// Career-level statistics for a single team across all games it has played.
class TeamCareerStats {
  final int gamesPlayed;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  final List<PlayerTournamentStats> topScorers;

  const TeamCareerStats({
    required this.gamesPlayed,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.topScorers,
  });

  int get goalDifference => goalsFor - goalsAgainst;
  int get points => wins * 2 + draws;
}

class TeamStatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Computes career stats for a team. Considers only completed games
  /// from the top-level `games` collection (per existing project pattern).
  Future<TeamCareerStats> getTeamCareerStats(String teamId) async {
    // Fetch all completed games where the team participated.
    final asA = await _firestore
        .collection('games')
        .where('teamAId', isEqualTo: teamId)
        .get();
    final asB = await _firestore
        .collection('games')
        .where('teamBId', isEqualTo: teamId)
        .get();

    final games = <Game>[];
    for (final doc in [...asA.docs, ...asB.docs]) {
      try {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        final game = Game.fromJson(data);
        if (game.status == GameStatus.completed) games.add(game);
      } catch (_) {
        // Skip malformed docs.
      }
    }

    int wins = 0, draws = 0, losses = 0;
    int gf = 0, ga = 0;
    for (final g in games) {
      final r = g.result;
      if (r == null) continue;
      final isA = g.teamAId == teamId;
      final own = isA ? r.teamAScore : r.teamBScore;
      final opp = isA ? r.teamBScore : r.teamAScore;
      gf += own;
      ga += opp;
      if (own > opp) {
        wins++;
      } else if (own == opp) {
        draws++;
      } else {
        losses++;
      }
    }

    // Top scorers within the team (career).
    final gameIds = games.map((g) => g.id).toList();
    final events = await StatsAggregator.fetchEventsForGames(gameIds);
    final teamEvents =
        events.where((GameEvent e) => e.teamId == teamId).toList();
    final scorers = StatsAggregator.aggregatePlayerStats(teamEvents);
    scorers.sort((a, b) => b.totalGoals.compareTo(a.totalGoals));

    return TeamCareerStats(
      gamesPlayed: games.length,
      wins: wins,
      draws: draws,
      losses: losses,
      goalsFor: gf,
      goalsAgainst: ga,
      topScorers: scorers,
    );
  }
}
