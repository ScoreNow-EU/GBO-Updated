import 'team_service.dart';
import 'tournament_service.dart';
import 'referee_service.dart';

class PreloaderService {
  static final PreloaderService _instance = PreloaderService._internal();
  factory PreloaderService() => _instance;
  PreloaderService._internal();

  final TeamService _teamService = TeamService();
  final TournamentService _tournamentService = TournamentService();
  final RefereeService _refereeService = RefereeService();

  bool _isPreloaded = false;

  // Preload all essential data
  Future<void> preloadEssentialData() async {
    if (_isPreloaded) return;

    try {
      // Preload in parallel for maximum speed
      await Future.wait([
        _teamService.preloadTeams(),
        _tournamentService.preloadTournaments(),
        _preloadReferees(),
      ]);

      _isPreloaded = true;
      print('✅ Essential data preloaded successfully');
    } catch (e) {
      print('❌ Error preloading essential data: $e');
    }
  }

  // Preload referees (basic implementation since referee service may not have caching yet)
  Future<void> _preloadReferees() async {
    try {
      // Just trigger a load to populate any internal caches
      await _refereeService.getReferees().first;
    } catch (e) {
      print('Error preloading referees: $e');
    }
  }

  // Check if data is preloaded
  bool get isPreloaded => _isPreloaded;

  // Clear all caches
  void clearAllCaches() {
    _teamService.clearCache();
    _tournamentService.clearCache();
    _isPreloaded = false;
  }

  // Refresh all data
  Future<void> refreshAllData() async {
    clearAllCaches();
    await preloadEssentialData();
  }
} 