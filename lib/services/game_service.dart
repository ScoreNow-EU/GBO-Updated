import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game.dart';
import '../models/team.dart';
import '../models/tournament.dart';

class GameService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _tournamentsCollection = 'tournaments';
  final String _gamesSubcollection = 'games';
  
  // Cache for faster subsequent loads per tournament
  Map<String, List<Game>> _cachedGamesByTournament = {};
  Map<String, DateTime> _lastCacheTimeByTournament = {};
  static const Duration _cacheTimeout = Duration(minutes: 5);

  // Get games for a specific tournament with real-time updates
  Stream<List<Game>> getGamesForTournament(String tournamentId) {
    print('🎮 GameService: Creating real-time stream for tournament $tournamentId');
    
    return _firestore
        .collection(_tournamentsCollection)
        .doc(tournamentId)
        .collection(_gamesSubcollection)
        .snapshots()
        .map((snapshot) {
          print('🎮 GameService: Firebase snapshot received - ${snapshot.docs.length} documents');
          List<Game> games = [];
          
          for (final doc in snapshot.docs) {
            try {
              final gameData = {...doc.data(), 'id': doc.id};
              print('🎮 GameService: Processing game ${doc.id}');
              final game = Game.fromJson(gameData);
              games.add(game);
            } catch (e) {
              print('❌ Error parsing game ${doc.id}: $e');
              print('❌ Game data: ${doc.data()}');
            }
          }
          
          print('🎮 GameService: Successfully processed ${games.length} games from Firebase');
          
          // Update cache with fresh data
          _cachedGamesByTournament[tournamentId] = games;
          _lastCacheTimeByTournament[tournamentId] = DateTime.now();
          
          return games;
        });
  }

  // Get all games (for backward compatibility - now aggregates from all tournaments)
  Stream<List<Game>> getGames() {
    // This is more complex now since games are in subcollections
    // For now, we'll use a simple approach that may not be as efficient
    return _firestore
        .collection(_tournamentsCollection)
        .snapshots()
        .asyncMap((tournamentSnapshot) async {
          List<Game> allGames = [];
          
          for (final tournamentDoc in tournamentSnapshot.docs) {
            final gamesSnapshot = await tournamentDoc.reference
                .collection(_gamesSubcollection)
                .get();
            
            final tournamentGames = gamesSnapshot.docs
                .map((doc) => Game.fromJson({...doc.data(), 'id': doc.id}))
                .toList();
            
            allGames.addAll(tournamentGames);
          }
          
          return allGames;
        });
  }

  // Get games for a specific tournament (synchronous - from cache)
  List<Game> getGamesForTournamentSync(String tournamentId) {
    return _cachedGamesByTournament[tournamentId] ?? [];
  }

  // Get pool games for a tournament
  List<Game> getPoolGames(String tournamentId, String poolId) {
    return (_cachedGamesByTournament[tournamentId] ?? []).where((game) => 
      game.gameType == GameType.pool && 
      game.poolId == poolId
    ).toList();
  }

  // Get elimination games for a tournament
  List<Game> getEliminationGames(String tournamentId) {
    return (_cachedGamesByTournament[tournamentId] ?? []).where((game) => 
      game.gameType == GameType.elimination
    ).toList();
  }

  // Generate pool games (everyone vs everyone)
  Future<void> generatePoolGames(String tournamentId, String poolId, List<Team> teams) async {
    if (teams.length < 2) return;

    // First, delete existing pool games
    await deletePoolGames(tournamentId, poolId);

    final now = DateTime.now();
    List<Game> poolGames = [];

    // Generate all possible combinations (everyone vs everyone)
    for (int i = 0; i < teams.length; i++) {
      for (int j = i + 1; j < teams.length; j++) {
        final gameId = '${tournamentId}_pool_${poolId}_${teams[i].id}_${teams[j].id}';
        
        final game = Game(
          id: gameId,
          tournamentId: tournamentId,
          teamAId: teams[i].id,
          teamBId: teams[j].id,
          teamAName: teams[i].name,
          teamBName: teams[j].name,
          gameType: GameType.pool,
          poolId: poolId,
          status: GameStatus.scheduled,
          createdAt: now,
          updatedAt: now,
        );

        poolGames.add(game);
      }
    }

    // Save new pool games to Firebase
    for (final game in poolGames) {
      await addGame(game);
    }
  }

  // Generate elimination bracket
  Future<void> generateEliminationBracket(String tournamentId, Map<String, List<Team>> poolResults) async {
    // First, delete existing elimination games
    await deleteEliminationGames(tournamentId);

    final now = DateTime.now();
    List<Game> bracketGames = [];

    // Create placeholder names based on pool positions
    List<String> teamPlaceholders = [];
    poolResults.forEach((poolId, teams) {
      for (int i = 0; i < teams.length; i++) {
        teamPlaceholders.add('${i + 1}. aus Pool ${poolId.toUpperCase()}');
      }
    });

    // Generate bracket based on number of teams
    int totalTeams = teamPlaceholders.length;
    int rounds = (log(totalTeams) / log(2)).ceil();

    // Keep track of game names for proper referencing
    List<List<String>> gameNames = [];
    
    // Generate first round with pool placeholders
    List<String> firstRoundNames = [];
    for (int i = 0; i < totalTeams; i += 2) {
      if (i + 1 < totalTeams) {
        final gameId = '${tournamentId}_elim_1_${(i / 2).floor()}';
        final gameName = '${teamPlaceholders[i]} vs ${teamPlaceholders[i + 1]}';
        firstRoundNames.add(gameName);
        
        final game = Game(
          id: gameId,
          tournamentId: tournamentId,
          teamAName: teamPlaceholders[i],
          teamBName: teamPlaceholders[i + 1],
          gameType: GameType.elimination,
          bracketRound: 1,
          bracketPosition: (i / 2).floor(),
          status: GameStatus.scheduled,
          createdAt: now,
          updatedAt: now,
        );

        bracketGames.add(game);
      }
    }
    gameNames.add(firstRoundNames);

    // Generate subsequent rounds with proper references
    int gamesInPreviousRound = (totalTeams / 2).floor();
    for (int round = 2; round <= rounds; round++) {
      int gamesInThisRound = (gamesInPreviousRound / 2).floor();
      List<String> currentRoundNames = [];
      
      for (int i = 0; i < gamesInThisRound; i++) {
        final gameId = '${tournamentId}_elim_${round}_$i';
        
        // Create meaningful names based on which games feed into this one
        String teamAName, teamBName;
        if (round == 2) {
          // Reference first round games directly
          teamAName = 'Sieger: ${gameNames[0][(i * 2)]}';
          teamBName = 'Sieger: ${gameNames[0][(i * 2) + 1]}';
        } else {
          // Reference previous round
          teamAName = 'Sieger: ${gameNames[round - 2][(i * 2)]}';
          teamBName = 'Sieger: ${gameNames[round - 2][(i * 2) + 1]}';
        }
        
        final gameName = '$teamAName vs $teamBName';
        currentRoundNames.add(gameName);
        
        final game = Game(
          id: gameId,
          tournamentId: tournamentId,
          teamAName: teamAName,
          teamBName: teamBName,
          gameType: GameType.elimination,
          bracketRound: round,
          bracketPosition: i,
          status: GameStatus.scheduled,
          createdAt: now,
          updatedAt: now,
        );

        bracketGames.add(game);
      }
      
      gameNames.add(currentRoundNames);
      gamesInPreviousRound = gamesInThisRound;
    }

    // Save new bracket games to Firebase
    for (final game in bracketGames) {
      await addGame(game);
    }
  }

  // Update game result
  Future<void> updateGameResult(String gameId, GameResult result) async {
    final game = await getGameById(gameId);
    if (game != null) {
      final updatedGame = game.copyWith(
        result: result,
        status: GameStatus.completed,
        updatedAt: DateTime.now(),
      );

      await updateGame(updatedGame);
      
      // Update dependent games (placeholders)
      await _updateDependentGames(updatedGame);
    }
  }

  // Update dependent games when a game is completed
  Future<void> _updateDependentGames(Game completedGame) async {
    if (completedGame.result == null || !completedGame.result!.isComplete) return;

    final winner = completedGame.result!.winnerName;
    final tournamentId = completedGame.tournamentId;

    // Update elimination bracket games
    if (completedGame.gameType == GameType.elimination) {
      final nextRound = (completedGame.bracketRound ?? 0) + 1;
      final nextPosition = (completedGame.bracketPosition ?? 0) ~/ 2;
      
      // Find the next game
      final allGames = await _getAllGamesFromFirestore(tournamentId);
      final nextGame = allGames.firstWhere(
        (game) => 
          game.gameType == GameType.elimination &&
          game.bracketRound == nextRound &&
          game.bracketPosition == nextPosition,
        orElse: () => Game(
          id: '',
          tournamentId: '',
          teamAName: '',
          teamBName: '',
          gameType: GameType.elimination,
          status: GameStatus.scheduled,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      if (nextGame.id.isNotEmpty) {
        Game updatedGame;
        if ((completedGame.bracketPosition ?? 0) % 2 == 0) {
          // Update team A
          updatedGame = nextGame.copyWith(
            teamAName: winner,
            teamAId: completedGame.result!.winnerId,
            updatedAt: DateTime.now(),
          );
        } else {
          // Update team B
          updatedGame = nextGame.copyWith(
            teamBName: winner,
            teamBId: completedGame.result!.winnerId,
            updatedAt: DateTime.now(),
          );
        }
        await updateGame(updatedGame);
      }
    }
  }

  // Helper method to get all games from Firestore for a tournament
  Future<List<Game>> _getAllGamesFromFirestore(String tournamentId) async {
    final snapshot = await _firestore
        .collection(_tournamentsCollection)
        .doc(tournamentId)
        .collection(_gamesSubcollection)
        .get();
    
    return snapshot.docs
        .map((doc) => Game.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
  }

  // Add a new game
  Future<void> addGame(Game game) async {
    print('🎮 GameService: Adding game ${game.id} to tournament ${game.tournamentId}');
    
    final gameData = game.toJson();
    gameData.remove('id'); // Remove ID from data since it's used as document ID
    
    final tournamentRef = _firestore
        .collection(_tournamentsCollection)
        .doc(game.tournamentId)
        .collection(_gamesSubcollection);
    
    try {
      if (game.id.isEmpty) {
        // Create new game with auto-generated ID
        final docRef = await tournamentRef.add(gameData);
        print('🎮 GameService: Game added with auto-generated ID: ${docRef.id}');
      } else {
        // Create game with specific ID
        await tournamentRef.doc(game.id).set(gameData);
        print('🎮 GameService: Game added with specific ID: ${game.id}');
      }
      
      // Force cache invalidation and immediate refresh
      _invalidateCache(game.tournamentId);
      
      // Also preload to refresh cache immediately
      await preloadGames(game.tournamentId);
      
    } catch (e) {
      print('❌ Error adding game ${game.id}: $e');
      throw e;
    }
  }

  // Update a game
  Future<void> updateGame(Game game) async {
    print('🎮 GameService: Updating game ${game.id} in tournament ${game.tournamentId}');
    
    final gameData = game.toJson();
    gameData.remove('id'); // Remove ID from data since it's used as document ID
    
    try {
      await _firestore
          .collection(_tournamentsCollection)
          .doc(game.tournamentId)
          .collection(_gamesSubcollection)
          .doc(game.id)
          .set(gameData);
      
      print('🎮 GameService: Game ${game.id} updated successfully');
      
      // Force cache invalidation and immediate refresh
      _invalidateCache(game.tournamentId);
      
      // Also preload to refresh cache immediately
      await preloadGames(game.tournamentId);
      
    } catch (e) {
      print('❌ Error updating game ${game.id}: $e');
      throw e;
    }
  }

  // Delete a game
  Future<void> deleteGame(String tournamentId, String gameId) async {
    await _firestore
        .collection(_tournamentsCollection)
        .doc(tournamentId)
        .collection(_gamesSubcollection)
        .doc(gameId)
        .delete();
    
    _invalidateCache(tournamentId);
  }

  // Delete all games for a tournament
  Future<void> deleteAllGamesForTournament(String tournamentId) async {
    final snapshot = await _firestore
        .collection(_tournamentsCollection)
        .doc(tournamentId)
        .collection(_gamesSubcollection)
        .get();
    
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    
    _invalidateCache(tournamentId);
  }

  // Delete pool games for a specific pool
  Future<void> deletePoolGames(String tournamentId, String poolId) async {
    final snapshot = await _firestore
        .collection(_tournamentsCollection)
        .doc(tournamentId)
        .collection(_gamesSubcollection)
        .where('poolId', isEqualTo: poolId)
        .get();
    
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    
    _invalidateCache(tournamentId);
  }

  // Delete elimination games for a tournament
  Future<void> deleteEliminationGames(String tournamentId) async {
    final snapshot = await _firestore
        .collection(_tournamentsCollection)
        .doc(tournamentId)
        .collection(_gamesSubcollection)
        .where('gameType', isEqualTo: 'GameType.elimination')
        .get();
    
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    
    _invalidateCache(tournamentId);
  }

  // Get game by ID
  Future<Game?> getGameById(String gameId) async {
    // Since games are now in subcollections, we need tournament ID
    // This is a limitation - we need to search across all tournaments
    final tournamentsSnapshot = await _firestore.collection(_tournamentsCollection).get();
    
    for (final tournamentDoc in tournamentsSnapshot.docs) {
      final gameDoc = await tournamentDoc.reference
          .collection(_gamesSubcollection)
          .doc(gameId)
          .get();
      
      if (gameDoc.exists) {
        return Game.fromJson({...gameDoc.data()!, 'id': gameDoc.id});
      }
    }
    
    return null;
  }

  // Get game by ID within a specific tournament (more efficient)
  Future<Game?> getGameByIdInTournament(String tournamentId, String gameId) async {
    final doc = await _firestore
        .collection(_tournamentsCollection)
        .doc(tournamentId)
        .collection(_gamesSubcollection)
        .doc(gameId)
        .get();
    
    if (doc.exists) {
      return Game.fromJson({...doc.data()!, 'id': doc.id});
    }
    return null;
  }

  // Get bracket round name
  String getBracketRoundName(int round, int totalRounds) {
    switch (totalRounds - round) {
      case 0:
        return 'Finale';
      case 1:
        return 'Halbfinale';
      case 2:
        return 'Viertelfinale';
      case 3:
        return 'Achtelfinale';
      default:
        return 'Runde $round';
    }
  }

  // Get tournament statistics
  Map<String, int> getTournamentStats(String tournamentId) {
    final tournamentGames = getGamesForTournamentSync(tournamentId);
    return {
      'total': tournamentGames.length,
      'completed': tournamentGames.where((g) => g.status == GameStatus.completed).length,
      'scheduled': tournamentGames.where((g) => g.status == GameStatus.scheduled).length,
      'inProgress': tournamentGames.where((g) => g.status == GameStatus.inProgress).length,
    };
  }

  // Update placeholder team with actual team
  Future<void> updatePlaceholderTeam(String tournamentId, String placeholderName, String actualTeamId, String actualTeamName) async {
    final snapshot = await _firestore
        .collection(_tournamentsCollection)
        .doc(tournamentId)
        .collection(_gamesSubcollection)
        .get();
    
    final batch = _firestore.batch();
    bool hasUpdates = false;
    
    for (final doc in snapshot.docs) {
      final game = Game.fromJson({...doc.data(), 'id': doc.id});
      Game? updatedGame;
      
      // Check if team A is the placeholder
      if (game.teamAName == placeholderName) {
        updatedGame = game.copyWith(
          teamAId: actualTeamId,
          teamAName: actualTeamName,
          updatedAt: DateTime.now(),
        );
      }
      // Check if team B is the placeholder
      else if (game.teamBName == placeholderName) {
        updatedGame = game.copyWith(
          teamBId: actualTeamId,
          teamBName: actualTeamName,
          updatedAt: DateTime.now(),
        );
      }
      
      if (updatedGame != null) {
        final gameData = updatedGame.toJson();
        gameData.remove('id');
        batch.set(doc.reference, gameData);
        hasUpdates = true;
      }
    }
    
    if (hasUpdates) {
      await batch.commit();
      _invalidateCache(tournamentId);
    }
  }

  // Update multiple placeholder teams at once (for pool completion)
  Future<void> updatePoolPlaceholders(String tournamentId, String poolId, List<String> rankedTeamIds, List<String> rankedTeamNames) async {
    if (rankedTeamIds.length != rankedTeamNames.length) return;
    
    final snapshot = await _firestore
        .collection(_tournamentsCollection)
        .doc(tournamentId)
        .collection(_gamesSubcollection)
        .get();
    
    final batch = _firestore.batch();
    bool hasUpdates = false;
    
    for (int position = 1; position <= rankedTeamIds.length; position++) {
      final placeholderName = '${position}. aus Pool ${poolId.toUpperCase()}';
      final actualTeamId = rankedTeamIds[position - 1];
      final actualTeamName = rankedTeamNames[position - 1];
      
      for (final doc in snapshot.docs) {
        final game = Game.fromJson({...doc.data(), 'id': doc.id});
        Game? updatedGame;
        
        // Check if team A is the placeholder
        if (game.teamAName == placeholderName) {
          updatedGame = game.copyWith(
            teamAId: actualTeamId,
            teamAName: actualTeamName,
            updatedAt: DateTime.now(),
          );
        }
        // Check if team B is the placeholder
        else if (game.teamBName == placeholderName) {
          updatedGame = game.copyWith(
            teamBId: actualTeamId,
            teamBName: actualTeamName,
            updatedAt: DateTime.now(),
          );
        }
        
        if (updatedGame != null) {
          final gameData = updatedGame.toJson();
          gameData.remove('id');
          batch.set(doc.reference, gameData);
          hasUpdates = true;
        }
      }
    }
    
    if (hasUpdates) {
      await batch.commit();
      _invalidateCache(tournamentId);
    }
  }

  // Invalidate cache when data changes
  void _invalidateCache(String tournamentId) {
    _cachedGamesByTournament.remove(tournamentId);
    _lastCacheTimeByTournament.remove(tournamentId);
  }

  // Clear cache manually
  void clearCache() {
    _cachedGamesByTournament.clear();
    _lastCacheTimeByTournament.clear();
  }

  // Clear cache for specific tournament
  void clearCacheForTournament(String tournamentId) {
    _invalidateCache(tournamentId);
  }

  // Preload games for faster initial access
  Future<void> preloadGames(String tournamentId) async {
    print('🎮 GameService: Preloading games for tournament $tournamentId');
    
    if (!_cachedGamesByTournament.containsKey(tournamentId) || 
        (_lastCacheTimeByTournament.containsKey(tournamentId) && 
         DateTime.now().difference(_lastCacheTimeByTournament[tournamentId]!) > _cacheTimeout)) {
      try {
        print('🎮 GameService: Fetching from Firebase subcollection: tournaments/$tournamentId/games');
        final snapshot = await _firestore
            .collection(_tournamentsCollection)
            .doc(tournamentId)
            .collection(_gamesSubcollection)
            .get();
        
        List<Game> games = [];
        
        for (final doc in snapshot.docs) {
          try {
            final gameData = {...doc.data(), 'id': doc.id};
            final game = Game.fromJson(gameData);
            games.add(game);
          } catch (e) {
            print('❌ Error parsing game ${doc.id} during preload: $e');
            print('❌ Game data: ${doc.data()}');
          }
        }
        
        print('🎮 GameService: Preloaded ${games.length} games and cached them');
        
        _cachedGamesByTournament[tournamentId] = games;
        _lastCacheTimeByTournament[tournamentId] = DateTime.now();
      } catch (e) {
        print('❌ Error preloading games for tournament $tournamentId: $e');
      }
    } else {
      print('🎮 GameService: Games already cached for tournament $tournamentId (${_cachedGamesByTournament[tournamentId]?.length ?? 0} games)');
    }
  }

  // Force refresh games for a tournament
  Future<void> forceRefreshGames(String tournamentId) async {
    print('🔄 GameService: Force refreshing games for tournament $tournamentId');
    
    // Clear cache
    _invalidateCache(tournamentId);
    
    // Preload fresh data
    await preloadGames(tournamentId);
    
    print('✅ GameService: Force refresh completed for tournament $tournamentId');
  }

  // Debug method to check Firebase structure
  Future<void> debugFirebaseStructure(String tournamentId) async {
    try {
      print('🔍 DEBUG: Checking Firebase structure for tournament $tournamentId');
      
      // Check if tournament exists
      final tournamentDoc = await _firestore
          .collection(_tournamentsCollection)
          .doc(tournamentId)
          .get();
      
      print('🔍 Tournament exists: ${tournamentDoc.exists}');
      if (tournamentDoc.exists) {
        print('🔍 Tournament data: ${tournamentDoc.data()}');
      }
      
      // Check games subcollection
      final gamesSnapshot = await _firestore
          .collection(_tournamentsCollection)
          .doc(tournamentId)
          .collection(_gamesSubcollection)
          .get();
      
      print('🔍 Games subcollection size: ${gamesSnapshot.docs.length}');
      
      for (final doc in gamesSnapshot.docs) {
        print('🔍 Game ${doc.id}: ${doc.data()}');
      }
      
    } catch (e) {
      print('❌ DEBUG ERROR: $e');
    }
  }

  // Dispose method for cleanup (kept for compatibility)
  void dispose() {
    // Clear cache on disposal
    clearCache();
  }
} 