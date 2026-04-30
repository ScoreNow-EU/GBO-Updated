import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/game_event.dart';
import '../models/team.dart';
import '../models/suspension.dart';
import 'team_service.dart';
import 'suspension_service.dart';
import 'stats_aggregator.dart';
import 'tournament_stats_service.dart';

/// Aggregates per-player statistics across all tournaments and seasons.
class PlayerStatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TeamService _teamService = TeamService();
  final SuspensionService _suspensionService = SuspensionService();

  /// Career stats for a single player across every game they appear in.
  /// Returns null if the player has no recorded events.
  Future<PlayerTournamentStats?> getCareerStats(String playerId) async {
    if (playerId.isEmpty) return null;
    final snap = await _firestore
        .collection('gameEvents')
        .where('playerId', isEqualTo: playerId)
        .get();
    if (snap.docs.isEmpty) return null;

    final events = <GameEvent>[];
    for (final d in snap.docs) {
      try {
        events.add(GameEvent.fromJson({...d.data(), 'id': d.id}));
      } catch (e) {
        debugPrint('PlayerStats: bad event ${d.id}: $e');
      }
    }
    final stats = StatsAggregator.aggregatePlayerStats(events);
    if (stats.isEmpty) return null;
    return stats.firstWhere(
      (s) => s.playerId == playerId,
      orElse: () => stats.first,
    );
  }

  /// Active suspensions for this player.
  Future<List<Suspension>> getSuspensions(String playerId) {
    return _suspensionService.getActiveSuspensionsForPlayer(playerId);
  }

  /// Resolve the team currently rostering this player, or null.
  Future<Team?> findCurrentTeam(String playerId) async {
    final teams = await _teamService.getAllTeams();
    for (final t in teams) {
      if (t.rosterPlayerIds.contains(playerId)) return t;
    }
    return null;
  }
}
