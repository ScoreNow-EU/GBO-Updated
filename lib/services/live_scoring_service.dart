import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/game_event.dart';
import '../models/player.dart';
import 'suspension_service.dart';

class LiveScoringService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, StreamController<GameState>> _gameStateControllers = {};
  final Map<String, GameState> _stateCache = {}; // in-memory cache to avoid per-tick Firestore reads
  Timer? _gameTimer;

  // Get or create a game state controller for a specific game
  StreamController<GameState> _getGameStateController(String gameId) {
    if (!_gameStateControllers.containsKey(gameId)) {
      _gameStateControllers[gameId] = StreamController<GameState>.broadcast();
    }
    return _gameStateControllers[gameId]!;
  }

  // Stream game state for a specific game
  Stream<GameState> streamGameState(String gameId) {
    final controller = _getGameStateController(gameId);
    
    _loadGameState(gameId).then((state) {
      _stateCache[gameId] = state; // seed cache on initial load
      if (!controller.isClosed) {
        controller.add(state);
      }
    });
    
    return controller.stream;
  }

  // Load current game state from Firestore
  Future<GameState> _loadGameState(String gameId) async {
    try {
      // Load game events
      final eventsSnapshot = await _firestore
          .collection('gameEvents')
          .where('gameId', isEqualTo: gameId)
          .get();

      final events = eventsSnapshot.docs
          .map((doc) => GameEvent.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
      
      events.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Load game time and state from Firestore
      final gameStateDoc = await _firestore
          .collection('gameStates')
          .doc(gameId)
          .get();

      GameTime gameTime = GameTime();
      bool isRunning = false;
      int currentHalf = 1;
      int teamAScore = 0;
      int teamBScore = 0;

      if (gameStateDoc.exists) {
        final data = gameStateDoc.data()!;
        gameTime = GameTime(
          minutes: data['minutes'] ?? 0,
          seconds: data['seconds'] ?? 0,
          currentPeriod: data['currentPeriod'] ?? 1,
          halfDurationMinutes: data['halfDurationMinutes'] ?? 15,
        );
        isRunning = data['isRunning'] ?? false;
        currentHalf = data['currentHalf'] ?? data['currentSet'] ?? 1;
        teamAScore = data['teamAScore'] ?? data['teamASetWins'] ?? 0;
        teamBScore = data['teamBScore'] ?? data['teamBSetWins'] ?? 0;
      }

      return GameState(
        gameId: gameId,
        currentHalf: currentHalf,
        teamAScore: teamAScore,
        teamBScore: teamBScore,
        gameTime: gameTime,
        isRunning: isRunning,
        events: events,
      );
    } catch (e) {
      debugPrint('âŒ Error loading game state: $e');
      return GameState(
        gameId: gameId,
        gameTime: GameTime(),
      );
    }
  }

  // Persist clock + run-state for a game atomically.
  //
  // IMPORTANT: This method does NOT write teamAScore / teamBScore. Score
  // changes are routed exclusively through [_applyScoreIncrement] using
  // FieldValue.increment so that two scoring tablets editing the same game
  // concurrently can never overwrite each other's goal with a stale
  // cached score (T38).
  Future<void> _saveGameState(GameState state) async {
    try {
      final docRef = _firestore.collection('gameStates').doc(state.gameId);
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        final clockPatch = <String, dynamic>{
          'minutes': state.gameTime.minutes,
          'seconds': state.gameTime.seconds,
          'currentPeriod': state.gameTime.currentPeriod,
          'halfDurationMinutes': state.gameTime.halfDurationMinutes,
          'isRunning': state.isRunning,
          'currentHalf': state.currentHalf,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (snap.exists) {
          tx.update(docRef, clockPatch);
        } else {
          // First write for this game — seed scores at 0; future score
          // writes go through _applyScoreIncrement.
          tx.set(docRef, {
            ...clockPatch,
            'teamAScore': 0,
            'teamBScore': 0,
          });
        }
      });
    } catch (e) {
      debugPrint('âŒ Error saving game state: $e');
    }
  }

  /// Atomically adjusts the cached score for one team by [delta] and
  /// refreshes the clock fields. Uses runTransaction + FieldValue.increment
  /// so concurrent goal events from multiple tablets cannot overwrite each
  /// other (T38).
  Future<void> _applyScoreIncrement({
    required String gameId,
    required bool isTeamA,
    required int delta,
    required GameState clockState,
  }) async {
    try {
      final docRef = _firestore.collection('gameStates').doc(gameId);
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        final scoreField = isTeamA ? 'teamAScore' : 'teamBScore';
        final clockPatch = <String, dynamic>{
          'minutes': clockState.gameTime.minutes,
          'seconds': clockState.gameTime.seconds,
          'currentPeriod': clockState.gameTime.currentPeriod,
          'halfDurationMinutes': clockState.gameTime.halfDurationMinutes,
          'isRunning': clockState.isRunning,
          'currentHalf': clockState.currentHalf,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (snap.exists) {
          tx.update(docRef, {
            ...clockPatch,
            scoreField: FieldValue.increment(delta),
          });
        } else {
          tx.set(docRef, {
            ...clockPatch,
            'teamAScore': isTeamA && delta > 0 ? delta : 0,
            'teamBScore': !isTeamA && delta > 0 ? delta : 0,
          });
        }
      });
    } catch (e) {
      debugPrint('âŒ Error applying score increment: $e');
    }
  }

  /// Set the half duration for a game (from tournament settings).
  Future<void> setHalfDuration(String gameId, int minutes) async {
    final currentState = await _loadGameState(gameId);
    final newTime = currentState.gameTime.copyWith(halfDurationMinutes: minutes);
    final updatedState = currentState.copyWith(gameTime: newTime);
    await _saveGameState(updatedState);
    _updateGameState(gameId, updatedState);
  }

  // Start game timer
  void startGameTimer(String gameId) async {
    // Use cached state if available for instant response; otherwise load once from Firestore
    final currentState = _stateCache[gameId] ?? await _loadGameState(gameId);
    final updatedState = currentState.copyWith(isRunning: true);

    // Update UI immediately (no await) then persist in background
    _updateGameState(gameId, updatedState);
    _saveGameState(updatedState); // fire-and-forget

    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Read directly from cache — no Firestore round-trip per tick
      final state = _stateCache[gameId];
      if (state == null || !state.isRunning) {
        timer.cancel();
        return;
      }

      final newGameTime = state.gameTime.addSecond();
      final newState = state.copyWith(gameTime: newGameTime);

      _updateGameState(gameId, newState); // instant stream update
      _saveGameState(newState); // fire-and-forget background persist

      // Auto-pause at half time or full time
      if (newGameTime.isHalfTime && state.gameTime.currentPeriod == 1) {
        pauseGameTimer(gameId);
      } else if (newGameTime.isFullTime) {
        pauseGameTimer(gameId);
      }
    });
  }

  // Pause game timer
  Future<void> pauseGameTimer(String gameId) async {
    _gameTimer?.cancel();
    // Use cache for instant response; fall back to Firestore if cache is cold
    final currentState = _stateCache[gameId] ?? await _loadGameState(gameId);
    final updatedState = currentState.copyWith(isRunning: false);

    _updateGameState(gameId, updatedState);
    await _saveGameState(updatedState);
  }

  // Start second half (time continues from where period 1 ended)
  Future<void> startSecondHalf(String gameId) async {
    final currentState = await _loadGameState(gameId);
    final newGameTime = GameTime(
      minutes: currentState.gameTime.halfDurationMinutes,
      seconds: 0,
      currentPeriod: 2,
      halfDurationMinutes: currentState.gameTime.halfDurationMinutes,
    );
    final updatedState = currentState.copyWith(
      currentHalf: 2,
      gameTime: newGameTime,
      isRunning: false,
    );
    
    await _saveGameState(updatedState);
    _updateGameState(gameId, updatedState);
  }

  // Add game event
  Future<void> addGameEvent({
    required String gameId,
    required String playerId,
    required String playerName,
    required String teamId,
    required String teamName,
    required GameEventType eventType,
    String? notes,
  }) async {
    try {
      final currentState = await _loadGameState(gameId);
      
      final event = GameEvent(
        id: '',
        gameId: gameId,
        playerId: playerId,
        playerName: playerName,
        teamId: teamId,
        teamName: teamName,
        eventType: eventType,
        timestamp: DateTime.now(),
        gameMinute: currentState.gameTime.minutes,
        half: currentState.currentHalf,
        notes: notes,
      );

      // Save event to Firestore
      final docRef = await _firestore.collection('gameEvents').add(event.toJson());
      final savedEvent = event.copyWith(id: docRef.id);

      // Update scores if it's a scoring event.
      // Score writes go through _applyScoreIncrement (atomic) so a
      // simultaneous goal from another scoring tablet is never lost.
      final isScoring = eventType == GameEventType.goal ||
          eventType == GameEventType.sevenMeterHit;
      int newTeamAScore = currentState.teamAScore;
      int newTeamBScore = currentState.teamBScore;
      bool? scoringIsTeamA;
      if (isScoring) {
        scoringIsTeamA = teamId == (currentState.events.isNotEmpty
            ? _getTeamAId(currentState)
            : teamId);
        if (scoringIsTeamA == true) {
          newTeamAScore++;
        } else {
          newTeamBScore++;
        }
      }

      // Update local state and broadcast (optimistic UI)
      final updatedEvents = [...currentState.events, savedEvent];
      final updatedState = currentState.copyWith(
        events: updatedEvents,
        teamAScore: newTeamAScore,
        teamBScore: newTeamBScore,
      );

      if (isScoring && scoringIsTeamA != null) {
        await _applyScoreIncrement(
          gameId: gameId,
          isTeamA: scoringIsTeamA,
          delta: 1,
          clockState: updatedState,
        );
      } else {
        await _saveGameState(updatedState);
      }
      _updateGameState(gameId, updatedState);
      
      debugPrint('âœ… Game event added: ${eventType.toString()} by $playerName');
      // Auto-create tournament suspension for blue cards
      if (eventType == GameEventType.blueCard) {
        try {
          final suspensionService = SuspensionService();
          // Get tournament ID from the game document
          final gameDoc = await _firestore.collection('games').doc(gameId).get();
          final tournamentId = gameDoc.data()?['tournamentId'] as String? ?? '';
          final currentUser = FirebaseAuth.instance.currentUser;
          await suspensionService.createBlueCardSuspension(
            playerId: playerId,
            playerName: playerName,
            teamId: teamId,
            teamName: teamName,
            tournamentId: tournamentId,
            gameId: gameId,
            issuedByUserId: currentUser?.uid ?? 'system',
            issuedByName: currentUser?.displayName ?? 'System',
          );
          debugPrint('\u2705 Blue card suspension created for $playerName');
        } catch (e) {
          debugPrint('\u26a0\ufe0f Failed to create blue card suspension: $e');
        }
      }    } catch (e) {
      debugPrint('âŒ Error adding game event: $e');
      throw e;
    }
  }

  // Helper to determine team A from events
  String? _getTeamAId(GameState state) {
    // Team A is determined by the first scoring event's team
    for (final event in state.events) {
      if (event.eventType == GameEventType.goal || 
          event.eventType == GameEventType.sevenMeterHit) {
        return event.teamId;
      }
    }
    return null;
  }

  // Remove last event (undo)
  Future<void> removeLastEvent(String gameId, String teamId) async {
    try {
      final currentState = await _loadGameState(gameId);
      final teamEvents = currentState.events
          .where((e) => e.teamId == teamId)
          .toList();
      
      if (teamEvents.isEmpty) return;
      
      final lastEvent = teamEvents.last;
      final wasScoring = lastEvent.eventType == GameEventType.goal ||
          lastEvent.eventType == GameEventType.sevenMeterHit;

      // Remove from Firestore
      await _firestore.collection('gameEvents').doc(lastEvent.id).delete();

      // Update local state
      final updatedEvents = currentState.events
          .where((e) => e.id != lastEvent.id)
          .toList();

      // Recalculate scores locally for UI
      final updatedState = _recalculateScores(
        currentState.copyWith(events: updatedEvents),
      );

      if (wasScoring) {
        final teamAId = _getTeamAId(currentState);
        final isTeamA = teamAId == null ? true : lastEvent.teamId == teamAId;
        await _applyScoreIncrement(
          gameId: gameId,
          isTeamA: isTeamA,
          delta: -1,
          clockState: updatedState,
        );
      } else {
        await _saveGameState(updatedState);
      }
      _updateGameState(gameId, updatedState);
      
      debugPrint('âœ… Last event removed: ${lastEvent.eventType.toString()}');
    } catch (e) {
      debugPrint('âŒ Error removing last event: $e');
      throw e;
    }
  }

  // Recalculate scores from events
  GameState _recalculateScores(GameState state) {
    int teamAScore = 0;
    int teamBScore = 0;
    String? teamAId;
    
    for (final event in state.events) {
      if (event.eventType == GameEventType.goal || 
          event.eventType == GameEventType.sevenMeterHit) {
        teamAId ??= event.teamId;
        if (event.teamId == teamAId) {
          teamAScore++;
        } else {
          teamBScore++;
        }
      }
    }
    
    return state.copyWith(
      teamAScore: teamAScore,
      teamBScore: teamBScore,
    );
  }

  // Complete current half
  Future<void> completeHalf(String gameId) async {
    try {
      final currentState = await _loadGameState(gameId);
      
      if (currentState.currentHalf == 1) {
        // Move to second half
        await startSecondHalf(gameId);
      } else {
        // Game is complete
        final updatedState = currentState.copyWith(isRunning: false);
        await _saveGameState(updatedState);
        _updateGameState(gameId, updatedState);
      }
      
      debugPrint('âœ… Half ${currentState.currentHalf} completed');
    } catch (e) {
      debugPrint('âŒ Error completing half: $e');
      throw e;
    }
  }

  // Clear all game data (full reset)
  Future<void> clearAllGameData(String gameId) async {
    try {
      // Delete all game events
      final eventsSnapshot = await _firestore
          .collection('gameEvents')
          .where('gameId', isEqualTo: gameId)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in eventsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      // Reset game state
      await _firestore.collection('gameStates').doc(gameId).set({
        'minutes': 0,
        'seconds': 0,
        'currentPeriod': 1,
        'isRunning': false,
        'currentHalf': 1,
        'teamAScore': 0,
        'teamBScore': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Update local state
      final resetState = GameState(
        gameId: gameId,
        gameTime: GameTime(),
      );
      
      _updateGameState(gameId, resetState);
      
      debugPrint('âœ… All game data cleared for game: $gameId');
    } catch (e) {
      debugPrint('âŒ Error clearing all game data: $e');
      throw e;
    }
  }

  // Clear current half data only
  Future<void> clearCurrentHalfData(String gameId, int currentHalf) async {
    try {
      // Delete events from current half only
      final eventsSnapshot = await _firestore
          .collection('gameEvents')
          .where('gameId', isEqualTo: gameId)
          .where('half', isEqualTo: currentHalf)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in eventsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      // Reload and update game state
      final updatedState = await _loadGameState(gameId);
      _updateGameState(gameId, updatedState);
      
      debugPrint('âœ… Current half data cleared for game: $gameId, half: $currentHalf');
    } catch (e) {
      debugPrint('âŒ Error clearing current half data: $e');
      throw e;
    }
  }

  // Update game state and notify listeners
  void _updateGameState(String gameId, GameState state) {
    _stateCache[gameId] = state; // always keep cache in sync
    final controller = _getGameStateController(gameId);
    if (!controller.isClosed) {
      controller.add(state);
    }
  }

  // Clean up resources
  void dispose() {
    _gameTimer?.cancel();
    for (final controller in _gameStateControllers.values) {
      controller.close();
    }
    _gameStateControllers.clear();
  }
}

// Extension method to add copyWith to GameEvent
extension GameEventCopyWith on GameEvent {
  GameEvent copyWith({
    String? id,
    String? gameId,
    String? playerId,
    String? playerName,
    String? teamId,
    String? teamName,
    GameEventType? eventType,
    DateTime? timestamp,
    int? gameMinute,
    int? half,
    String? notes,
  }) {
    return GameEvent(
      id: id ?? this.id,
      gameId: gameId ?? this.gameId,
      playerId: playerId ?? this.playerId,
      playerName: playerName ?? this.playerName,
      teamId: teamId ?? this.teamId,
      teamName: teamName ?? this.teamName,
      eventType: eventType ?? this.eventType,
      timestamp: timestamp ?? this.timestamp,
      gameMinute: gameMinute ?? this.gameMinute,
      half: half ?? this.half,
      notes: notes ?? this.notes,
    );
  }
} 