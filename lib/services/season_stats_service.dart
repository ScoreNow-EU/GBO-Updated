import 'package:flutter/foundation.dart';
import '../models/game.dart';
import '../models/game_event.dart';
import '../models/season.dart';
import '../models/suspension.dart';
import 'season_service.dart';
import 'game_service.dart';
import 'suspension_service.dart';
import 'stats_aggregator.dart';
import 'tournament_stats_service.dart';

/// Aggregates statistics across every Spieltag (tournament) in a season.
///
/// Reuses the same `PlayerTournamentStats` / `TeamTournamentStats` shapes
/// as `TournamentStatsService` (semantically identical at season scope).
class SeasonStatsService {
  final SeasonService _seasonService = SeasonService();
  final GameService _gameService = GameService();
  final SuspensionService _suspensionService = SuspensionService();

  /// Simple in-memory cache (cleared on app restart). Keyed by seasonId.
  final Map<String, _SeasonStatsCacheEntry> _cache = {};
  static const Duration _cacheTtl = Duration(minutes: 5);

  void invalidateCache([String? seasonId]) {
    if (seasonId == null) {
      _cache.clear();
    } else {
      _cache.remove(seasonId);
    }
  }

  Future<_SeasonStatsCacheEntry> _loadOrCache(String seasonId) async {
    final cached = _cache[seasonId];
    if (cached != null && DateTime.now().difference(cached.loadedAt) < _cacheTtl) {
      return cached;
    }

    final season = await _seasonService.getSeason(seasonId);
    if (season == null) {
      throw Exception('Season $seasonId not found');
    }

    final List<Game> allGames = [];
    for (final tid in season.spieltageIds) {
      try {
        final games = await _gameService.getGamesForTournament(tid).first;
        allGames.addAll(games);
      } catch (e) {
        debugPrint('SeasonStats: could not load games for $tid: $e');
      }
    }
    final gameIds = allGames.map((g) => g.id).toList();
    final events = await StatsAggregator.fetchEventsForGames(gameIds);

    final entry = _SeasonStatsCacheEntry(
      season: season,
      games: allGames,
      events: events,
      loadedAt: DateTime.now(),
    );
    _cache[seasonId] = entry;
    return entry;
  }

  /// Top scorers across all tournaments in this season.
  Future<List<PlayerTournamentStats>> getSeasonTopScorers(String seasonId) async {
    final data = await _loadOrCache(seasonId);
    final stats = StatsAggregator.aggregatePlayerStats(data.events);
    stats.sort((a, b) => b.totalGoals.compareTo(a.totalGoals));
    return stats;
  }

  /// Cumulative team standings across all tournaments in this season.
  Future<List<TeamTournamentStats>> getSeasonTeamStandings(String seasonId) async {
    final data = await _loadOrCache(seasonId);
    return StatsAggregator.aggregateTeamStats(data.games);
  }

  /// Discipline view across the season (sorted by total penalties desc).
  Future<List<PlayerTournamentStats>> getSeasonDiscipline(String seasonId) async {
    final data = await _loadOrCache(seasonId);
    final stats = StatsAggregator.aggregatePlayerStats(data.events);
    stats.sort((a, b) => b.totalPenalties.compareTo(a.totalPenalties));
    return stats.where((s) => s.totalPenalties > 0).toList();
  }

  /// Active suspensions originating from any tournament in this season.
  Future<List<Suspension>> getSeasonSuspensions(String seasonId) async {
    final season = await _seasonService.getSeason(seasonId);
    if (season == null) return [];
    final all = await _suspensionService.getAllActiveSuspensions();
    return all.where((s) {
      final tid = s.tournamentId;
      return tid != null && season.spieltageIds.contains(tid);
    }).toList();
  }
}

class _SeasonStatsCacheEntry {
  final Season season;
  final List<Game> games;
  final List<GameEvent> events;
  final DateTime loadedAt;

  _SeasonStatsCacheEntry({
    required this.season,
    required this.games,
    required this.events,
    required this.loadedAt,
  });
}
