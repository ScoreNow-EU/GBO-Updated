import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game.dart';
import '../models/team.dart';
import '../models/tournament.dart';

class GameService {
  static const String _gameKey = 'games';
  final StreamController<List<Game>> _gameController = StreamController<List<Game>>.broadcast();
  List<Game> _games = [];

  Stream<List<Game>> get gameStream => _gameController.stream;

  GameService() {
    _loadGames();
  }

  Future<void> _loadGames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gameJson = prefs.getStringList(_gameKey) ?? [];
      
      _games = gameJson
          .map((json) => Game.fromJson(jsonDecode(json)))
          .toList();
      
      _gameController.add(_games);
    } catch (e) {
      print('Error loading games: $e');
      _games = [];
      _gameController.add(_games);
    }
  }

  Future<void> _saveGames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gameJson = _games
          .map((game) => jsonEncode(game.toJson()))
          .toList();
      
      await prefs.setStringList(_gameKey, gameJson);
      _gameController.add(_games);
    } catch (e) {
      print('Error saving games: $e');
      throw Exception('Fehler beim Speichern der Spiele');
    }
  }

  // Get all games
  Stream<List<Game>> getGames() {
    return gameStream;
  }

  // Get games for a specific tournament
  List<Game> getGamesForTournament(String tournamentId) {
    return _games.where((game) => game.tournamentId == tournamentId).toList();
  }

  // Get pool games for a tournament
  List<Game> getPoolGames(String tournamentId, String poolId) {
    return _games.where((game) => 
      game.tournamentId == tournamentId && 
      game.gameType == GameType.pool && 
      game.poolId == poolId
    ).toList();
  }

  // Get elimination games for a tournament
  List<Game> getEliminationGames(String tournamentId) {
    return _games.where((game) => 
      game.tournamentId == tournamentId && 
      game.gameType == GameType.elimination
    ).toList();
  }

  // Generate pool games (everyone vs everyone)
  Future<void> generatePoolGames(String tournamentId, String poolId, List<Team> teams) async {
    if (teams.length < 2) return;

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

    // Remove existing pool games for this pool
    _games.removeWhere((game) => 
      game.tournamentId == tournamentId && 
      game.poolId == poolId
    );

    // Add new pool games
    _games.addAll(poolGames);
    await _saveGames();
  }

  // Generate elimination bracket
  Future<void> generateEliminationBracket(String tournamentId, Map<String, List<Team>> poolResults) async {
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

    // Remove existing elimination games
    _games.removeWhere((game) => 
      game.tournamentId == tournamentId && 
      game.gameType == GameType.elimination
    );

    // Add new bracket games
    _games.addAll(bracketGames);
    await _saveGames();
  }

  // Update game result
  Future<void> updateGameResult(String gameId, GameResult result) async {
    final gameIndex = _games.indexWhere((game) => game.id == gameId);
    if (gameIndex != -1) {
      _games[gameIndex] = _games[gameIndex].copyWith(
        result: result,
        status: GameStatus.completed,
        updatedAt: DateTime.now(),
      );

      await _saveGames();
      
      // Update dependent games (placeholders)
      await _updateDependentGames(_games[gameIndex]);
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
      
      final nextGame = _games.firstWhere(
        (game) => 
          game.tournamentId == tournamentId &&
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
        final gameIndex = _games.indexWhere((game) => game.id == nextGame.id);
        if (gameIndex != -1) {
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
          _games[gameIndex] = updatedGame;
        }
      }
    }

    await _saveGames();
  }

  // Add a new game
  Future<void> addGame(Game game) async {
    _games.add(game);
    await _saveGames();
  }

  // Delete a game
  Future<void> deleteGame(String gameId) async {
    _games.removeWhere((game) => game.id == gameId);
    await _saveGames();
  }

  // Get game by ID
  Game? getGameById(String gameId) {
    try {
      return _games.firstWhere((game) => game.id == gameId);
    } catch (e) {
      return null;
    }
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
    final tournamentGames = getGamesForTournament(tournamentId);
    return {
      'total': tournamentGames.length,
      'completed': tournamentGames.where((g) => g.status == GameStatus.completed).length,
      'scheduled': tournamentGames.where((g) => g.status == GameStatus.scheduled).length,
      'inProgress': tournamentGames.where((g) => g.status == GameStatus.inProgress).length,
    };
  }

  void dispose() {
    _gameController.close();
  }
} 