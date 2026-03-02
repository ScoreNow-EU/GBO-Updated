import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game.dart';
import '../models/game_event.dart';
import '../services/game_service.dart';

/// Aggregated player statistics across a tournament
class PlayerTournamentStats {
  final String playerId;
  final String playerName;
  final String teamId;
  final String teamName;
  int goals;
  int sevenMeterGoals;
  int sevenMeterMisses;
  int yellowCards;
  int twoMinuteSuspensions;
  int redCards;
  int blueCards;
  int gamesPlayed;

  PlayerTournamentStats({
    required this.playerId,
    required this.playerName,
    required this.teamId,
    required this.teamName,
    this.goals = 0,
    this.sevenMeterGoals = 0,
    this.sevenMeterMisses = 0,
    this.yellowCards = 0,
    this.twoMinuteSuspensions = 0,
    this.redCards = 0,
    this.blueCards = 0,
    this.gamesPlayed = 0,
  });

  int get totalGoals => goals + sevenMeterGoals;
  int get totalPenalties => yellowCards + twoMinuteSuspensions + redCards + blueCards;
  int get sevenMeterTotal => sevenMeterGoals + sevenMeterMisses;
  double get sevenMeterPercentage =>
      sevenMeterTotal > 0 ? (sevenMeterGoals / sevenMeterTotal) * 100 : 0;
}

/// Aggregated team statistics (for group tables)
class TeamTournamentStats {
  final String teamId;
  final String teamName;
  int played;
  int won;
  int drawn;
  int lost;
  int goalsFor;
  int goalsAgainst;
  int points;

  TeamTournamentStats({
    required this.teamId,
    required this.teamName,
    this.played = 0,
    this.won = 0,
    this.drawn = 0,
    this.lost = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
    this.points = 0,
  });

  int get goalDifference => goalsFor - goalsAgainst;
}

/// Service to aggregate tournament-wide statistics from game events
class TournamentStatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GameService _gameService = GameService();

  /// Get all events for every game in a tournament
  Future<List<GameEvent>> getAllTournamentEvents(String tournamentId) async {
    // First get all game IDs for the tournament
    final games = await _gameService.getGamesForTournament(tournamentId).first;
    final gameIds = games.map((g) => g.id).toSet();

    if (gameIds.isEmpty) return [];

    // Firestore 'in' queries max 30 items at a time
    final List<GameEvent> allEvents = [];
    final idList = gameIds.toList();
    print('📊 Stats: Loading events for ${idList.length} games in tournament $tournamentId');
    for (int i = 0; i < idList.length; i += 30) {
      final batch = idList.sublist(i, i + 30 > idList.length ? idList.length : i + 30);
      final snapshot = await _firestore
          .collection('gameEvents')
          .where('gameId', whereIn: batch)
          .get();
      for (final doc in snapshot.docs) {
        try {
          allEvents.add(GameEvent.fromJson({...doc.data(), 'id': doc.id}));
        } catch (e) {
          print('⚠️ Stats: Skipping bad event doc ${doc.id}: $e');
        }
      }
    }
    print('📊 Stats: Loaded ${allEvents.length} events total');
    return allEvents;
  }

  /// Top scorers list
  Future<List<PlayerTournamentStats>> getTopScorers(String tournamentId) async {
    final events = await getAllTournamentEvents(tournamentId);
    final stats = _aggregatePlayerStats(events);
    stats.sort((a, b) => b.totalGoals.compareTo(a.totalGoals));
    return stats;
  }

  /// Player discipline list (sorted by total penalties descending)
  Future<List<PlayerTournamentStats>> getDisciplineStats(String tournamentId) async {
    final events = await getAllTournamentEvents(tournamentId);
    final stats = _aggregatePlayerStats(events);
    stats.sort((a, b) => b.totalPenalties.compareTo(a.totalPenalties));
    return stats.where((s) => s.totalPenalties > 0).toList();
  }

  /// Group/pool table for a specific pool
  Future<List<TeamTournamentStats>> getPoolTable(String tournamentId, String poolId) async {
    final games = await _gameService.getGamesForTournament(tournamentId).first;
    final poolGames = games.where((g) => g.gameType == GameType.pool && g.poolId == poolId && g.status == GameStatus.completed).toList();

    final Map<String, TeamTournamentStats> teamStats = {};

    for (final game in poolGames) {
      final result = game.result;
      if (result == null) continue;

      // Ensure team entries exist
      teamStats.putIfAbsent(game.teamAId ?? '', () => TeamTournamentStats(
        teamId: game.teamAId ?? '',
        teamName: game.teamAName,
      ));
      teamStats.putIfAbsent(game.teamBId ?? '', () => TeamTournamentStats(
        teamId: game.teamBId ?? '',
        teamName: game.teamBName,
      ));

      final statsA = teamStats[game.teamAId]!;
      final statsB = teamStats[game.teamBId]!;

      statsA.played++;
      statsB.played++;
      statsA.goalsFor += result.teamAScore;
      statsA.goalsAgainst += result.teamBScore;
      statsB.goalsFor += result.teamBScore;
      statsB.goalsAgainst += result.teamAScore;

      if (result.teamAScore > result.teamBScore) {
        statsA.won++;
        statsA.points += 2;
        statsB.lost++;
      } else if (result.teamBScore > result.teamAScore) {
        statsB.won++;
        statsB.points += 2;
        statsA.lost++;
      } else {
        statsA.drawn++;
        statsB.drawn++;
        statsA.points += 1;
        statsB.points += 1;
      }
    }

    final table = teamStats.values.toList();
    table.sort((a, b) {
      if (a.points != b.points) return b.points.compareTo(a.points);
      if (a.goalDifference != b.goalDifference) return b.goalDifference.compareTo(a.goalDifference);
      return b.goalsFor.compareTo(a.goalsFor);
    });
    return table;
  }

  /// Overall team rankings across all pool games
  Future<List<TeamTournamentStats>> getOverallTeamStats(String tournamentId) async {
    final games = await _gameService.getGamesForTournament(tournamentId).first;
    final completedGames = games.where((g) => g.status == GameStatus.completed).toList();

    final Map<String, TeamTournamentStats> teamStats = {};

    for (final game in completedGames) {
      final result = game.result;
      if (result == null) continue;

      teamStats.putIfAbsent(game.teamAId ?? '', () => TeamTournamentStats(
        teamId: game.teamAId ?? '',
        teamName: game.teamAName,
      ));
      teamStats.putIfAbsent(game.teamBId ?? '', () => TeamTournamentStats(
        teamId: game.teamBId ?? '',
        teamName: game.teamBName,
      ));

      final statsA = teamStats[game.teamAId]!;
      final statsB = teamStats[game.teamBId]!;

      statsA.played++;
      statsB.played++;
      statsA.goalsFor += result.teamAScore;
      statsA.goalsAgainst += result.teamBScore;
      statsB.goalsFor += result.teamBScore;
      statsB.goalsAgainst += result.teamAScore;

      if (result.teamAScore > result.teamBScore) {
        statsA.won++;
        statsA.points += 2;
        statsB.lost++;
      } else if (result.teamBScore > result.teamAScore) {
        statsB.won++;
        statsB.points += 2;
        statsA.lost++;
      } else {
        statsA.drawn++;
        statsB.drawn++;
        statsA.points += 1;
        statsB.points += 1;
      }
    }

    final table = teamStats.values.toList();
    table.sort((a, b) {
      if (a.points != b.points) return b.points.compareTo(a.points);
      if (a.goalDifference != b.goalDifference) return b.goalDifference.compareTo(a.goalDifference);
      return b.goalsFor.compareTo(a.goalsFor);
    });
    return table;
  }

  /// Aggregate per-player stats from events
  List<PlayerTournamentStats> _aggregatePlayerStats(List<GameEvent> events) {
    final Map<String, PlayerTournamentStats> statsMap = {};
    final Set<String> playerGames = {}; // "playerId_gameId"

    for (final event in events) {
      // Use playerId if non-empty, otherwise playerName as key
      final pid = (event.playerId != null && event.playerId!.isNotEmpty)
          ? event.playerId!
          : event.playerName;
      if (pid.isEmpty) continue;

      statsMap.putIfAbsent(pid, () => PlayerTournamentStats(
        playerId: event.playerId ?? '',
        playerName: event.playerName,
        teamId: event.teamId,
        teamName: event.teamName,
      ));

      final stat = statsMap[pid]!;

      // Track games played
      final gameKey = '${pid}_${event.gameId}';
      if (!playerGames.contains(gameKey)) {
        playerGames.add(gameKey);
        stat.gamesPlayed++;
      }

      switch (event.eventType) {
        case GameEventType.goal:
          stat.goals++;
          break;
        case GameEventType.sevenMeterHit:
          stat.sevenMeterGoals++;
          break;
        case GameEventType.sevenMeterMiss:
          stat.sevenMeterMisses++;
          break;
        case GameEventType.yellowCard:
          stat.yellowCards++;
          break;
        case GameEventType.twoMinuteSuspension:
          stat.twoMinuteSuspensions++;
          break;
        case GameEventType.redCard:
          stat.redCards++;
          break;
        case GameEventType.blueCard:
          stat.blueCards++;
          break;
        default:
          break;
      }
    }

    return statsMap.values.toList();
  }
}
