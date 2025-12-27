import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/tournament.dart';
import '../models/game.dart';
import '../models/team.dart';
import '../services/game_service.dart';
import '../services/tournament_service.dart';
import '../services/team_service.dart';
import '../utils/app_colors.dart';

class OBSGraphicsScreen extends StatefulWidget {
  final String? tournamentId;
  final String? gameId;
  final String? overlayType;

  const OBSGraphicsScreen({
    super.key,
    this.tournamentId,
    this.gameId,
    this.overlayType,
  });

  @override
  State<OBSGraphicsScreen> createState() => _OBSGraphicsScreenState();
}

class _OBSGraphicsScreenState extends State<OBSGraphicsScreen>
    with TickerProviderStateMixin {
  final GameService _gameService = GameService();
  final TournamentService _tournamentService = TournamentService();
  final TeamService _teamService = TeamService();

  Tournament? tournament;
  Game? currentGame;
  List<Game> games = [];
  List<Team> teams = [];
  
  Timer? _refreshTimer;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = true;
  DateTime _lastUpdate = DateTime.now();
  int _gameTime = 0; // Game time in seconds
  Timer? _gameTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadData();
    _startRefreshTimer();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _pulseController.repeat(reverse: true);
    _slideController.forward();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      if (widget.tournamentId != null) {
        final tournamentStream = await _tournamentService.getTournaments();
        final tournaments = await tournamentStream.first;
        tournament = tournaments.firstWhere((t) => t.id == widget.tournamentId!);
        final gamesList = await _gameService.getGamesForTournament(widget.tournamentId!).first;
        games = gamesList;

        if (widget.gameId != null) {
          currentGame = games.firstWhere(
            (g) => g.id == widget.gameId,
            orElse: () => games.isNotEmpty ? games.first : throw Exception('No games found'),
          );
        } else {
          // Find current in-progress game or next scheduled game
          currentGame = games.firstWhere(
            (g) => g.status == GameStatus.inProgress,
            orElse: () => games.firstWhere(
              (g) => g.status == GameStatus.scheduled && g.scheduledTime != null,
              orElse: () => games.isNotEmpty ? games.first : throw Exception('No games found'),
            ),
          );
        }

        if (currentGame?.status == GameStatus.inProgress) {
          _startGameTimer();
        }

        teams = await _teamService.getTeams().first;
      }

      setState(() {
        _isLoading = false;
        _lastUpdate = DateTime.now();
      });
    } catch (e) {
      print('Error loading OBS graphics data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _loadData();
    });
  }

  void _startGameTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (currentGame?.status == GameStatus.inProgress) {
        setState(() {
          _gameTime++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _gameTimer?.cancel();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Make background transparent for OBS
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    
    if (_isLoading || currentGame == null || tournament == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _buildOverlayContent(),
    );
  }

  Widget _buildOverlayContent() {
    switch (widget.overlayType?.toLowerCase()) {
      case 'score':
        return _buildScoreOverlay();
      case 'standings':
        return _buildStandingsOverlay();
      case 'schedule':
        return _buildScheduleOverlay();
      case 'player_info':
        return _buildPlayerInfoOverlay();
      case 'tournament_banner':
        return _buildTournamentBanner();
      default:
        return _buildMainGameOverlay();
    }
  }

  Widget _buildMainGameOverlay() {
    final game = currentGame!;
    final isLive = game.status == GameStatus.inProgress;

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Main game display
            Container(
              width: 800,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.9),
                    Colors.black.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isLive ? Colors.red : AppColors.primaryColor,
                  width: 3,
                ),
              ),
              child: Column(
                children: [
                  _buildGameHeader(game, isLive),
                  _buildTeamsDisplay(game),
                  _buildScoreDisplay(game),
                  if (isLive) _buildGameTimer(),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Tournament info
            _buildTournamentInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildGameHeader(Game game, bool isLive) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isLive ? Colors.red.withOpacity(0.9) : AppColors.primaryColor.withOpacity(0.9),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(17),
          topRight: Radius.circular(17),
        ),
      ),
      child: Row(
        children: [
          if (isLive)
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
          if (isLive) const SizedBox(width: 12),
          Text(
            isLive ? 'LIVE' : 'NEXT GAME',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          Text(
            game.gameType.toString().split('.').last.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          if (game.courtId != null)
            Text(
              'COURT ${game.courtId!.split('_').last}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTeamsDisplay(Game game) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: _buildTeamCard(game.teamAName, true),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: const Text(
              'VS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: _buildTeamCard(game.teamBName, false),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard(String teamName, bool isTeamA) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            teamName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // Team city/division info if available
          if (teams.isNotEmpty) _buildTeamInfo(teamName),
        ],
      ),
    );
  }

  Widget _buildTeamInfo(String teamName) {
    final team = teams.firstWhere(
      (t) => t.name == teamName,
      orElse: () => Team(
        id: '',
        name: teamName,
        city: '',
        division: '',
        bundesland: '',
        createdAt: DateTime.now(),
      ),
    );

    if (team.city.isEmpty) return const SizedBox.shrink();

    return Text(
      '${team.city} • ${team.division}',
      style: TextStyle(
        color: Colors.white.withOpacity(0.8),
        fontSize: 14,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildScoreDisplay(Game game) {
    if (game.result == null || game.result!.sets.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildScoreBox('0'),
            const SizedBox(width: 20),
            const Text(
              ':',
              style: TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 20),
            _buildScoreBox('0'),
          ],
        ),
      );
    }

    final result = game.result!;
    final teamASets = result.sets.where((s) => s.teamAScore > s.teamBScore).length;
    final teamBSets = result.sets.where((s) => s.teamBScore > s.teamAScore).length;

    return Column(
      children: [
        // Set scores
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildScoreBox(teamASets.toString()),
              const SizedBox(width: 20),
              const Text(
                ':',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 20),
              _buildScoreBox(teamBSets.toString()),
            ],
          ),
        ),
        // Current set points
        if (result.sets.isNotEmpty)
          Container(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: result.sets.asMap().entries.map((entry) {
                final index = entry.key;
                final set = entry.value;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Set ${index + 1}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${set.teamAScore} : ${set.teamBScore}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildScoreBox(String score) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.primaryColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          score,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildGameTimer() {
    final minutes = _gameTime ~/ 60;
    final seconds = _gameTime % 60;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.9),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.timer,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.emoji_events,
            color: AppColors.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            tournament!.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '${tournament!.location} • ${_formatDate(tournament!.startDate!)}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreOverlay() {
    // Compact score overlay for corner of screen
    final game = currentGame!;
    
    return Positioned(
      top: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: game.status == GameStatus.inProgress ? Colors.red : AppColors.primaryColor,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (game.status == GameStatus.inProgress)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              '${game.teamAName} vs ${game.teamBName}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _getGameScore(game),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandingsOverlay() {
    // Tournament standings overlay
    return Container(
      margin: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryColor, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'TOURNAMENT STANDINGS',
              style: TextStyle(
                color: AppColors.primaryColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // TODO: Add actual standings data
            Text(
              'Standings will be displayed here',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleOverlay() {
    final upcomingGames = games
        .where((g) => g.status == GameStatus.scheduled && g.scheduledTime != null)
        .take(5)
        .toList();

    return Container(
      margin: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryColor, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'UPCOMING GAMES',
              style: TextStyle(
                color: AppColors.primaryColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...upcomingGames.map((game) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    _formatTime(game.scheduledTime!),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      '${game.teamAName} vs ${game.teamBName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerInfoOverlay() {
    // Player information overlay
    return Container(
      margin: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryColor, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'PLAYER SPOTLIGHT',
              style: TextStyle(
                color: AppColors.primaryColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // TODO: Add actual player data
            Text(
              'Player information will be displayed here',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTournamentBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryColor.withOpacity(0.9),
            AppColors.primaryColor.withOpacity(0.7),
          ],
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.emoji_events,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tournament!.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${tournament!.location} • ${_formatDateRange(tournament!.startDate!, tournament!.endDate!)}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            'LIVE',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  String _getGameScore(Game game) {
    if (game.result == null || game.result!.sets.isEmpty) {
      return '0 : 0';
    }
    
    final result = game.result!;
    final teamASets = result.sets.where((s) => s.teamAScore > s.teamBScore).length;
    final teamBSets = result.sets.where((s) => s.teamBScore > s.teamAScore).length;
    
    return '$teamASets : $teamBSets';
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateRange(DateTime start, DateTime end) {
    if (start.day == end.day && start.month == end.month && start.year == end.year) {
      return _formatDate(start);
    }
    return '${_formatDate(start)} - ${_formatDate(end)}';
  }
}
