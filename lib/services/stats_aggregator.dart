import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/game.dart';
import '../models/game_event.dart';
import 'tournament_stats_service.dart';

/// Shared helpers to aggregate player and team statistics from a list of
/// game events / completed games. Reused by tournament, season, player and
/// team stats services so aggregation rules stay consistent in one place.
class StatsAggregator {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch all GameEvents for the given gameIds (handles Firestore's 30-id
  /// `whereIn` limit).
  static Future<List<GameEvent>> fetchEventsForGames(List<String> gameIds) async {
    if (gameIds.isEmpty) return [];
    final List<GameEvent> all = [];
    for (int i = 0; i < gameIds.length; i += 30) {
      final batch = gameIds.sublist(i, i + 30 > gameIds.length ? gameIds.length : i + 30);
      final snapshot = await _firestore
          .collection('gameEvents')
          .where('gameId', whereIn: batch)
          .get();
      for (final doc in snapshot.docs) {
        try {
          all.add(GameEvent.fromJson({...doc.data(), 'id': doc.id}));
        } catch (e) {
          debugPrint('StatsAggregator: skipping bad event ${doc.id}: $e');
        }
      }
    }
    return all;
  }

  /// Aggregate per-player statistics from a flat list of events.
  /// Players are keyed by playerId when available, otherwise by playerName.
  static List<PlayerTournamentStats> aggregatePlayerStats(List<GameEvent> events) {
    final Map<String, PlayerTournamentStats> statsMap = {};
    final Set<String> playerGames = {};

    for (final event in events) {
      final pid = (event.playerId != null && event.playerId!.isNotEmpty)
          ? event.playerId!
          : event.playerName;
      if (pid.isEmpty) continue;

      statsMap.putIfAbsent(
        pid,
        () => PlayerTournamentStats(
          playerId: event.playerId ?? '',
          playerName: event.playerName,
          teamId: event.teamId,
          teamName: event.teamName,
        ),
      );

      final stat = statsMap[pid]!;

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

  /// Aggregate team standings from a list of completed games. Standard
  /// 2-points-for-a-win / 1-for-draw scoring (matches existing pool table
  /// rules in TournamentStatsService).
  static List<TeamTournamentStats> aggregateTeamStats(List<Game> games) {
    final Map<String, TeamTournamentStats> teamStats = {};

    for (final game in games) {
      if (game.status != GameStatus.completed) continue;
      final result = game.result;
      if (result == null) continue;

      teamStats.putIfAbsent(
        game.teamAId ?? '',
        () => TeamTournamentStats(teamId: game.teamAId ?? '', teamName: game.teamAName),
      );
      teamStats.putIfAbsent(
        game.teamBId ?? '',
        () => TeamTournamentStats(teamId: game.teamBId ?? '', teamName: game.teamBName),
      );

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
      if (a.goalDifference != b.goalDifference) {
        return b.goalDifference.compareTo(a.goalDifference);
      }
      return b.goalsFor.compareTo(a.goalsFor);
    });
    return table;
  }
}
