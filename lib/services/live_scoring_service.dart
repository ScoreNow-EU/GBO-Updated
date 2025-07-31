import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_event.dart';
import '../models/player.dart';

class LiveScoringService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, StreamController<GameState>> _gameStateControllers = {};
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
    
    // Initialize with default state if not already done
    _loadGameState(gameId).then((state) {
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
      
      // Sort events by timestamp in memory (avoids need for compound index)
      events.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Load game time and state from Firestore if exists
      final gameStateDoc = await _firestore
          .collection('gameStates')
          .doc(gameId)
          .get();

      GameTime gameTime = GameTime();
      bool isRunning = false;
      int currentSet = 1;
      int teamASetWins = 0;
      int teamBSetWins = 0;
      List<SetScore> setScores = [];

      if (gameStateDoc.exists) {
        final data = gameStateDoc.data()!;
        gameTime = GameTime(
          minutes: data['minutes'] ?? 0,
          seconds: data['seconds'] ?? 0,
          currentPeriod: data['currentPeriod'] ?? 1,
        );
        isRunning = data['isRunning'] ?? false;
        currentSet = data['currentSet'] ?? 1;
        teamASetWins = data['teamASetWins'] ?? 0;
        teamBSetWins = data['teamBSetWins'] ?? 0;
        
        if (data['setScores'] != null) {
          setScores = (data['setScores'] as List)
              .map((s) => SetScore(
                    setNumber: s['setNumber'],
                    teamAId: s['teamAId'],
                    teamBId: s['teamBId'],
                    teamAScore: s['teamAScore'],
                    teamBScore: s['teamBScore'],
                    isCompleted: s['isCompleted'] ?? false,
                  ))
              .toList();
        }
      }

      return GameState(
        gameId: gameId,
        currentSet: currentSet,
        teamASetWins: teamASetWins,
        teamBSetWins: teamBSetWins,
        setScores: setScores,
        gameTime: gameTime,
        isRunning: isRunning,
        events: events,
      );
    } catch (e) {
      print('❌ Error loading game state: $e');
      return GameState(
        gameId: gameId,
        gameTime: GameTime(),
      );
    }
  }

  // Save game state to Firestore
  Future<void> _saveGameState(GameState state) async {
    try {
      await _firestore.collection('gameStates').doc(state.gameId).set({
        'minutes': state.gameTime.minutes,
        'seconds': state.gameTime.seconds,
        'currentPeriod': state.gameTime.currentPeriod,
        'isRunning': state.isRunning,
        'currentSet': state.currentSet,
        'teamASetWins': state.teamASetWins,
        'teamBSetWins': state.teamBSetWins,
        'setScores': state.setScores.map((s) => {
          'setNumber': s.setNumber,
          'teamAId': s.teamAId,
          'teamBId': s.teamBId,
          'teamAScore': s.teamAScore,
          'teamBScore': s.teamBScore,
          'isCompleted': s.isCompleted,
        }).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error saving game state: $e');
    }
  }

  // Start game timer
  void startGameTimer(String gameId) async {
    final currentState = await _loadGameState(gameId);
    final updatedState = currentState.copyWith(isRunning: true);
    
    await _saveGameState(updatedState);
    _updateGameState(gameId, updatedState);
    
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final state = await _loadGameState(gameId);
      if (!state.isRunning) {
        timer.cancel();
        return;
      }
      
      final newGameTime = state.gameTime.addSecond();
      final newState = state.copyWith(gameTime: newGameTime);
      
      await _saveGameState(newState);
      _updateGameState(gameId, newState);
      
      // Auto-pause at half time and full time
      if (newGameTime.isHalfTime && state.gameTime.currentPeriod == 1) {
        await pauseGameTimer(gameId);
      } else if (newGameTime.isFullTime) {
        await pauseGameTimer(gameId);
      }
    });
  }

  // Pause game timer
  Future<void> pauseGameTimer(String gameId) async {
    _gameTimer?.cancel();
    final currentState = await _loadGameState(gameId);
    final updatedState = currentState.copyWith(isRunning: false);
    
    await _saveGameState(updatedState);
    _updateGameState(gameId, updatedState);
  }

  // Start second half
  Future<void> startSecondHalf(String gameId) async {
    final currentState = await _loadGameState(gameId);
    final newGameTime = GameTime(
      minutes: 0,
      seconds: 0,
      currentPeriod: 2,
    );
    final updatedState = currentState.copyWith(
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
        id: '', // Will be set by Firestore
        gameId: gameId,
        playerId: playerId,
        playerName: playerName,
        teamId: teamId,
        teamName: teamName,
        eventType: eventType,
        timestamp: DateTime.now(),
        gameMinute: currentState.gameTime.minutes,
        setNumber: currentState.currentSet,
        notes: notes,
      );

      // Save event to Firestore
      final docRef = await _firestore.collection('gameEvents').add(event.toJson());
      final savedEvent = event.copyWith(id: docRef.id);

      // Update local state and broadcast
      final updatedEvents = [...currentState.events, savedEvent];
      final updatedState = currentState.copyWith(events: updatedEvents);
      
      _updateGameState(gameId, updatedState);
      
      print('✅ Game event added: ${eventType.toString()} by $playerName');
    } catch (e) {
      print('❌ Error adding game event: $e');
      throw e;
    }
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
      
      // Remove from Firestore
      await _firestore.collection('gameEvents').doc(lastEvent.id).delete();
      
      // Update local state
      final updatedEvents = currentState.events
          .where((e) => e.id != lastEvent.id)
          .toList();
      final updatedState = currentState.copyWith(events: updatedEvents);
      
      _updateGameState(gameId, updatedState);
      
      print('✅ Last event removed: ${lastEvent.eventType.toString()}');
    } catch (e) {
      print('❌ Error removing last event: $e');
      throw e;
    }
  }

  // Complete current set by time (beach handball rules)
  Future<void> completeSetByTime(String gameId, String teamAId, String teamBId) async {
    try {
      final currentState = await _loadGameState(gameId);
      final teamAScore = currentState.getCurrentSetScore(teamAId);
      final teamBScore = currentState.getCurrentSetScore(teamBId);
      
      // Determine winner based on score when time runs out
      String? winnerId;
      if (teamAScore > teamBScore) {
        winnerId = teamAId;
      } else if (teamBScore > teamAScore) {
        winnerId = teamBId;
      }
      // If tied, winnerId remains null (tie)
      
      // Create completed set score
      final completedSet = SetScore(
        setNumber: currentState.currentSet,
        teamAId: teamAId,
        teamBId: teamBId,
        teamAScore: teamAScore,
        teamBScore: teamBScore,
        isCompleted: true,
      );
      
      // Update set wins (only if there's a winner)
      final newTeamASetWins = winnerId == teamAId 
          ? currentState.teamASetWins + 1 
          : currentState.teamASetWins;
      final newTeamBSetWins = winnerId == teamBId 
          ? currentState.teamBSetWins + 1 
          : currentState.teamBSetWins;
      
      // Reset timer for next set
      final newGameTime = GameTime(
        minutes: 0,
        seconds: 0,
        currentPeriod: 1,
      );
      
      // Update state
      final updatedSetScores = [...currentState.setScores, completedSet];
      final updatedState = currentState.copyWith(
        currentSet: currentState.currentSet + 1,
        teamASetWins: newTeamASetWins,
        teamBSetWins: newTeamBSetWins,
        setScores: updatedSetScores,
        gameTime: newGameTime,
        isRunning: false,
      );
      
      await _saveGameState(updatedState);
      _updateGameState(gameId, updatedState);
      
      print('✅ Set ${currentState.currentSet} completed by time - Score: $teamAScore:$teamBScore');
    } catch (e) {
      print('❌ Error completing set by time: $e');
      throw e;
    }
  }

  // Complete current set (traditional rules - keeping for compatibility)
  Future<void> completeCurrentSet(String gameId, String teamAId, String teamBId) async {
    try {
      final currentState = await _loadGameState(gameId);
      final teamAScore = currentState.getCurrentSetScore(teamAId);
      final teamBScore = currentState.getCurrentSetScore(teamBId);
      
      // Determine winner (assuming 15 points to win, must win by 2)
      String? winnerId;
      if (teamAScore >= 15 && teamAScore >= teamBScore + 2) {
        winnerId = teamAId;
      } else if (teamBScore >= 15 && teamBScore >= teamAScore + 2) {
        winnerId = teamBId;
      }
      
      if (winnerId == null) {
        throw Exception('Set cannot be completed: No clear winner yet');
      }
      
      // Create completed set score
      final completedSet = SetScore(
        setNumber: currentState.currentSet,
        teamAId: teamAId,
        teamBId: teamBId,
        teamAScore: teamAScore,
        teamBScore: teamBScore,
        isCompleted: true,
      );
      
      // Update set wins
      final newTeamASetWins = winnerId == teamAId 
          ? currentState.teamASetWins + 1 
          : currentState.teamASetWins;
      final newTeamBSetWins = winnerId == teamBId 
          ? currentState.teamBSetWins + 1 
          : currentState.teamBSetWins;
      
      // Update state
      final updatedSetScores = [...currentState.setScores, completedSet];
      final updatedState = currentState.copyWith(
        currentSet: currentState.currentSet + 1,
        teamASetWins: newTeamASetWins,
        teamBSetWins: newTeamBSetWins,
        setScores: updatedSetScores,
      );
      
      await _saveGameState(updatedState);
      _updateGameState(gameId, updatedState);
      
      print('✅ Set ${currentState.currentSet} completed');
    } catch (e) {
      print('❌ Error completing set: $e');
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
        'currentSet': 1,
        'teamASetWins': 0,
        'teamBSetWins': 0,
        'setScores': [],
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Update local state
      final resetState = GameState(
        gameId: gameId,
        gameTime: GameTime(),
      );
      
      _updateGameState(gameId, resetState);
      
      print('✅ All game data cleared for game: $gameId');
    } catch (e) {
      print('❌ Error clearing all game data: $e');
      throw e;
    }
  }

  // Clear current set data only
  Future<void> clearCurrentSetData(String gameId, int currentSet) async {
    try {
      // Delete events from current set only
      final eventsSnapshot = await _firestore
          .collection('gameEvents')
          .where('gameId', isEqualTo: gameId)
          .where('setNumber', isEqualTo: currentSet)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in eventsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      // Reload and update game state (this will recalculate scores)
      final updatedState = await _loadGameState(gameId);
      _updateGameState(gameId, updatedState);
      
      print('✅ Current set data cleared for game: $gameId, set: $currentSet');
    } catch (e) {
      print('❌ Error clearing current set data: $e');
      throw e;
    }
  }

  // Update game state and notify listeners
  void _updateGameState(String gameId, GameState state) {
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
    int? setNumber,
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
      setNumber: setNumber ?? this.setNumber,
      notes: notes ?? this.notes,
    );
  }
} 