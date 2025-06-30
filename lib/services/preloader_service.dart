import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'team_service.dart';
import 'tournament_service.dart';
import 'referee_service.dart';
import 'delegate_service.dart';
import 'preset_service.dart';

class PreloaderService {
  static final PreloaderService _instance = PreloaderService._internal();
  factory PreloaderService() => _instance;
  PreloaderService._internal();

  // Check if Firebase is properly initialized
  bool get isFirebaseAvailable {
    try {
      Firebase.apps.isNotEmpty;
      return true;
    } catch (e) {
      print('Firebase not available: $e');
      return false;
    }
  }

  // Services (lazy initialization)
  TeamService? _teamService;
  TournamentService? _tournamentService;
  RefereeService? _refereeService;
  DelegateService? _delegateService;
  PresetService? _presetService;

  // Getter for services with Firebase check
  TeamService? get teamService {
    if (!isFirebaseAvailable) return null;
    return _teamService ??= TeamService();
  }

  TournamentService? get tournamentService {
    if (!isFirebaseAvailable) return null;
    return _tournamentService ??= TournamentService();
  }

  RefereeService? get refereeService {
    if (!isFirebaseAvailable) return null;
    return _refereeService ??= RefereeService();
  }

  DelegateService? get delegateService {
    if (!isFirebaseAvailable) return null;
    return _delegateService ??= DelegateService();
  }

  PresetService? get presetService {
    if (!isFirebaseAvailable) return null;
    return _presetService ??= PresetService();
  }

  // Preload essential data in the background
  void preloadEssentialData() {
    if (!isFirebaseAvailable) {
      print('Firebase not available - skipping preload');
      return;
    }

    // Don't await these - let them run in background
    Timer.run(() async {
      try {
        print('Starting background preload...');
        
        // Preload core data that's commonly used
        final futures = <Future>[];
        
        if (teamService != null) {
          futures.add(teamService!.preloadTeams());
        }
        
        if (tournamentService != null) {
          futures.add(tournamentService!.initializeSampleData());
          futures.add(tournamentService!.preloadTournaments());
          futures.add(tournamentService!.updateTournamentsWithDefaultDivisions());
        }
        
        // Only preload services that have preload methods implemented
        // TODO: Add preload methods to other services when implemented
        
        // Wait for all preloads to complete (or timeout after 30 seconds)
        await Future.wait(futures).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            print('Preload timeout - some data may not be cached');
            return [];
          },
        );
        
        print('Background preload completed successfully');
      } catch (e) {
        print('Background preload error: $e');
        // Don't throw - this is background loading
      }
    });
  }

  // Clear all cached data
  void clearAllCaches() {
    if (!isFirebaseAvailable) return;
    
    try {
      teamService?.clearCache();
      // Add other cache clearing methods when implemented
      print('All caches cleared');
    } catch (e) {
      print('Error clearing caches: $e');
    }
  }
} 