import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui';
import 'package:toastification/toastification.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game.dart';
import '../models/tournament.dart';
import '../models/court.dart';
import '../models/team.dart';
import '../models/user.dart' as app_user;
import '../services/game_service.dart';
import '../services/tournament_service.dart';
import '../services/managed_account_service.dart';
import '../services/auth_service.dart';
import '../services/team_service.dart';
import '../services/team_manager_service.dart';
import '../models/managed_account.dart';
import '../models/game_squad.dart';
import '../services/game_squad_service.dart';
import '../services/face_id_service.dart';
import '../services/live_scoring_service.dart';
import '../models/game_event.dart';
import '../models/player.dart';
import '../utils/responsive_helper.dart';
import '../services/player_service.dart';
import 'dart:math' as math;

class ScoringTabletScreen extends StatefulWidget {
  final app_user.User user;
  
  const ScoringTabletScreen({super.key, required this.user});

  @override
  State<ScoringTabletScreen> createState() => _ScoringTabletScreenState();
}

class _ScoringTabletScreenState extends State<ScoringTabletScreen> with TickerProviderStateMixin {
  final GameService _gameService = GameService();
  final TournamentService _tournamentService = TournamentService();
  final ManagedAccountService _managedAccountService = ManagedAccountService();
  final AuthService _authService = AuthService();
  final TeamService _teamService = TeamService();
  final PlayerService _playerService = PlayerService(); // ✅ ADD: PlayerService
  final GameSquadService _gameSquadService = GameSquadService();
  final LiveScoringService _liveScoringService = LiveScoringService();
  
  // Navigation state
  String _selectedTab = 'main'; // main, squad, referees, scoring, statistics, completion
  bool _isInScoringMode = false; // Track if we're in scoring mode or games list mode
  bool _isSidebarExpanded = false; // Track sidebar expansion state
  
  // Live scoring state
  Player? _selectedPlayer;
  String? _selectedPlayerTeamId;
  
  // Player color coding state
  Color _teamAShooterColor = Colors.orange;
  Color _teamASpielerColor = Colors.lightBlue;
  Color _teamBShooterColor = Colors.orange;
  Color _teamBSpielerColor = Colors.lightBlue;
  
  // Player type assignments (playerId -> isShooter)
  Map<String, bool> _playerTypes = {};
  
  ManagedAccount? _managedAccount;
  Tournament? _assignedTournament;
  Court? _assignedCourt;
  Game? _selectedGame; // The game selected for scoring
  Team? _teamA; // Actual team A data
  Team? _teamB; // Actual team B data
  List<Game> _upcomingGames = [];
  List<Game> _currentGames = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  DateTime? _lastRefresh;
  
  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  // Auto-refresh timer
  Timer? _refreshTimer;
  
  // Animation keys for lists
  final GlobalKey<AnimatedListState> _currentGamesListKey = GlobalKey<AnimatedListState>();
  final GlobalKey<AnimatedListState> _upcomingGamesListKey = GlobalKey<AnimatedListState>();

  // Squad data (selected players for this game)
  Map<String, GameSquad> _gameSquads = {}; // teamId -> GameSquad
  bool _squadsLoading = false;
  
  // Set completion overlay
  bool _showSetCompletionOverlay = false;
  SetScore? _completedSet;
  int _lastProcessedSetCount = 0;
  
  // Shootout state
  bool _isInShootout = false;
  bool _showShootoutSetupDialog = false;
  bool _teamAStartsShootout = true; // Track which team starts/is currently playing
  
  // Shootout player assignments
  SquadPlayer? _assignedShooter;
  SquadPlayer? _assignedPlayer;
  SquadPlayer? _assignedGoalkeeper;
  
  // Shootout scoring
  List<int> _teamAShootoutScores = []; // 0, 1, or 2 points per attempt
  List<int> _teamBShootoutScores = []; // 0, 1, or 2 points per attempt
  bool _isTeamATurn = true; // Current team's turn
  
  // Track players who have been used as Werfer to prevent reuse (Shooter and Goalkeeper can be reused)
  Set<String> _usedPlayerIds = {};

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadManagedAccountData();
    _startAutoRefresh();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _fadeController.forward();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (mounted && !_isLoading && !_isInScoringMode) {
        _performBackgroundRefresh();
      }
    });
  }

  Future<void> _performBackgroundRefresh() async {
    if (_isRefreshing) return;
    
    setState(() => _isRefreshing = true);
    
    try {
      print('🔄 ScoringTablet: Starting comprehensive Firebase refresh...');
      
      // Force refresh games data from Firebase
      if (_assignedTournament != null) {
        print('🔄 Force refreshing games for tournament: ${_assignedTournament!.name}');
        await _gameService.forceRefreshGames(_assignedTournament!.id);
      }
      
      // Force refresh team data (clear cache)
      print('🔄 Clearing team cache...');
      _teamService.clearCache();
      
      // Reload games with fresh data
      await _loadGamesWithAnimation();
      
      // Refresh team data for selected game
      if (_selectedGame != null) {
        print('🔄 Refreshing team data for selected game...');
        if (_selectedGame!.teamAId?.isNotEmpty == true) {
          final freshTeamA = await _teamService.getTeamById(_selectedGame!.teamAId!);
          if (mounted && freshTeamA != null) {
            setState(() => _teamA = freshTeamA);
          }
        }
        if (_selectedGame!.teamBId?.isNotEmpty == true) {
          final freshTeamB = await _teamService.getTeamById(_selectedGame!.teamBId!);
          if (mounted && freshTeamB != null) {
            setState(() => _teamB = freshTeamB);
          }
        }
        
        // Also refresh squad data if in scoring mode
        if (_isInScoringMode) {
          print('🔄 Refreshing squad data...');
          setState(() => _squadsLoading = true);
          await _loadGameSquads();
          if (mounted) {
            setState(() => _squadsLoading = false);
          }
        }
      }
      
      setState(() => _lastRefresh = DateTime.now());
      print('✅ ScoringTablet: Comprehensive refresh complete');
      
      // Show success feedback
      _showSuccessToast('Daten erfolgreich von Firebase aktualisiert');
      
    } catch (e) {
      print('❌ Error during comprehensive refresh: $e');
      _showErrorToast('Fehler beim Aktualisieren der Daten: $e');
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _loadManagedAccountData() async {
    try {
      print('🔍 ScoringTablet: Loading managed account data for user: ${widget.user.email}');
      
      final allAccounts = await _managedAccountService.getAllManagedAccounts().first;
      
      _managedAccount = allAccounts.firstWhere(
        (account) => account.email == widget.user.email,
        orElse: () => throw Exception('Managed account not found for email: ${widget.user.email}'),
      );

      if (_managedAccount != null && _managedAccount!.tournamentId != null) {
        _assignedTournament = await _tournamentService.getTournamentById(_managedAccount!.tournamentId!);
        
        if (_assignedTournament != null && _managedAccount!.courtId != null) {
          try {
            _assignedCourt = _assignedTournament!.courts.firstWhere(
              (court) => court.id == _managedAccount!.courtId,
            );
            
            await _loadGames();
          } catch (e) {
            print('❌ Court not found: $e');
            _showErrorToast('Court "${_managedAccount!.courtId}" nicht im Turnier gefunden');
          }
        }
      }
    } catch (e) {
      print('❌ Error loading managed account data: $e');
      _showErrorToast('Fehler beim Laden der Account-Daten: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadGames() async {
    if (_assignedTournament == null || _assignedCourt == null) return;
    
    try {
      final allGames = await _gameService.getGamesForTournament(_assignedTournament!.id).first;
      final courtGames = allGames.where((game) => game.courtId == _assignedCourt!.id).toList();
      
      final now = DateTime.now();
      
      // Current games: games happening within a reasonable time window (6 hours either side)
      final newCurrentGames = courtGames.where((game) {
        if (game.scheduledTime == null) return false;
        
        final timeDiff = game.scheduledTime!.difference(now).inMinutes.abs();
        final isWithinTimeWindow = timeDiff <= 360; // Within 6 hours (360 minutes)
        final isNotCompleted = game.status != GameStatus.completed;
        final isCurrentStatus = game.status == GameStatus.inProgress;
        
        return (isWithinTimeWindow || isCurrentStatus) && isNotCompleted;
      }).toList();
      
      // Upcoming games: ALL other games for this court (very permissive for scoring)
      final newUpcomingGames = courtGames.where((game) {
        if (game.scheduledTime == null) {
          // Show unscheduled games too
          return game.status != GameStatus.completed && !newCurrentGames.contains(game);
        }
        
        final isNotCurrent = !newCurrentGames.contains(game);
        final isNotCompleted = game.status != GameStatus.completed;
        
        // Show all non-current, non-completed games regardless of date
        return isNotCurrent && isNotCompleted;
      }).toList();
      
      // Sort by scheduled time
      newCurrentGames.sort((a, b) => (a.scheduledTime ?? DateTime.now()).compareTo(b.scheduledTime ?? DateTime.now()));
      newUpcomingGames.sort((a, b) => (a.scheduledTime ?? DateTime.now()).compareTo(b.scheduledTime ?? DateTime.now()));
      
      setState(() {
        _currentGames = newCurrentGames;
        _upcomingGames = newUpcomingGames;
      });
      
    } catch (e) {
      print('❌ Error loading games: $e');
    }
  }

  Future<void> _loadGamesWithAnimation() async {
    if (_assignedTournament == null || _assignedCourt == null) return;
    
    try {
      final allGames = await _gameService.getGamesForTournament(_assignedTournament!.id).first;
      final courtGames = allGames.where((game) => game.courtId == _assignedCourt!.id).toList();
      
      final now = DateTime.now();
      
      // Current games: games happening within a reasonable time window (6 hours either side)
      final newCurrentGames = courtGames.where((game) {
        if (game.scheduledTime == null) return false;
        
        final timeDiff = game.scheduledTime!.difference(now).inMinutes.abs();
        final isWithinTimeWindow = timeDiff <= 360; // Within 6 hours (360 minutes)
        final isNotCompleted = game.status != GameStatus.completed;
        final isCurrentStatus = game.status == GameStatus.inProgress;
        
        return (isWithinTimeWindow || isCurrentStatus) && isNotCompleted;
      }).toList();
      
      // Upcoming games: ALL other games for this court (very permissive for scoring)
      final newUpcomingGames = courtGames.where((game) {
        if (game.scheduledTime == null) {
          // Show unscheduled games too
          return game.status != GameStatus.completed && !newCurrentGames.contains(game);
        }
        
        final isNotCurrent = !newCurrentGames.contains(game);
        final isNotCompleted = game.status != GameStatus.completed;
        
        // Show all non-current, non-completed games regardless of date
        return isNotCurrent && isNotCompleted;
      }).toList();
      
      // Sort by scheduled time
      newCurrentGames.sort((a, b) => (a.scheduledTime ?? DateTime.now()).compareTo(b.scheduledTime ?? DateTime.now()));
      newUpcomingGames.sort((a, b) => (a.scheduledTime ?? DateTime.now()).compareTo(b.scheduledTime ?? DateTime.now()));
      
      // Animate changes
      await _animateGameListChanges(_currentGames, newCurrentGames, _currentGamesListKey, true);
      await _animateGameListChanges(_upcomingGames, newUpcomingGames, _upcomingGamesListKey, false);
      
    } catch (e) {
      print('❌ Error loading games with animation: $e');
    }
  }

  Future<void> _animateGameListChanges(
    List<Game> oldList, 
    List<Game> newList, 
    GlobalKey<AnimatedListState> listKey,
    bool isCurrentGames
  ) async {
    // Find removed games
    final removedGames = <Game>[];
    for (int i = 0; i < oldList.length; i++) {
      final game = oldList[i];
      if (!newList.any((newGame) => newGame.id == game.id)) {
        removedGames.add(game);
      }
    }

    // Remove games with animation
    for (final removedGame in removedGames) {
      final index = oldList.indexOf(removedGame);
      if (index != -1) {
        oldList.removeAt(index);
        listKey.currentState?.removeItem(
          index,
          (context, animation) => _buildAnimatedGameCard(removedGame, animation, isRemoval: true),
          duration: const Duration(milliseconds: 300),
        );
        await Future.delayed(const Duration(milliseconds: 100)); // Stagger animations
      }
    }

    // Find added games
    final addedGames = <Game>[];
    for (final game in newList) {
      if (!oldList.any((oldGame) => oldGame.id == game.id)) {
        addedGames.add(game);
      }
    }

    // Add games with animation
    for (final addedGame in addedGames) {
      final insertIndex = newList.indexOf(addedGame);
      oldList.insert(insertIndex, addedGame);
      listKey.currentState?.insertItem(
        insertIndex,
        duration: const Duration(milliseconds: 400),
      );
      await Future.delayed(const Duration(milliseconds: 150)); // Stagger animations
    }

    // Update the list reference
    if (isCurrentGames) {
      setState(() => _currentGames = List.from(oldList));
    } else {
      setState(() => _upcomingGames = List.from(oldList));
    }
  }

  Widget _buildAnimatedGameCard(Game game, Animation<double> animation, {bool isRemoval = false}) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: isRemoval ? Offset.zero : const Offset(1.0, 0.0),
        end: isRemoval ? const Offset(-1.0, 0.0) : Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: isRemoval ? Curves.easeInBack : Curves.easeOutBack,
      )),
      child: FadeTransition(
        opacity: isRemoval 
          ? Tween<double>(begin: 1.0, end: 0.0).animate(animation)
          : animation,
        child: _buildGameCard(game),
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _fadeController.dispose();
    _liveScoringService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    // Show games list by default, scoring interface only after game selection
    if (!_isInScoringMode) {
      return _buildGamesListInterface();
    } else {
      return _buildScoringInterface();
    }
  }

  Widget _buildGamesListInterface() {
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildGamesHeader(),
            Expanded(
              child: isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoringInterface() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        
        if (ResponsiveHelper.shouldUseDrawer(screenWidth)) {
          // Mobile layout - show navigation as drawer
          return Scaffold(
            drawer: _buildNavigationDrawer(screenWidth),
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              toolbarHeight: 0,
              systemOverlayStyle: const SystemUiOverlayStyle(
                statusBarColor: Colors.white,
                statusBarIconBrightness: Brightness.dark,
              ),
            ),
            body: SafeArea(
              top: false,
              child: Container(
                color: Colors.grey[100],
                child: Column(
                  children: [
                    _buildMobileHeader(screenWidth),
                    Expanded(
                      child: _buildTabContent(),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          // Desktop layout - show side navigation
          return Scaffold(
            body: Row(
              children: [
                _buildNavigation(),
                Expanded(
                  child: Container(
                    color: Colors.grey[100],
                    child: Column(
                      children: [
                        Expanded(
                          child: _buildTabContent(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildGamesHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Tournament and Court Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _assignedTournament?.name ?? 'Kein Turnier zugewiesen',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFffd665),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.sports_tennis,
                              size: 16,
                              color: Colors.black87,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Court ${_assignedCourt?.name ?? 'N/A'}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _assignedTournament?.location ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  
                  // Auto-refresh status
                  if (_isRefreshing || _lastRefresh != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (_isRefreshing) ...[
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Aktualisiere Spiele...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ] else if (_lastRefresh != null) ...[
                          Icon(
                            Icons.refresh,
                            size: 12,
                            color: Colors.green.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Zuletzt aktualisiert: ${_formatTime(_lastRefresh!)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            
            // Manual refresh button
            if (!_isRefreshing)
              IconButton(
                onPressed: _performBackgroundRefresh,
                icon: const Icon(Icons.refresh, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.blue.shade50,
                  foregroundColor: Colors.blue.shade600,
                ),
                tooltip: 'Alle Daten von Firebase neu laden',
              ),
            
            const SizedBox(width: 8),
            
            // Logout Button
            IconButton(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout, size: 24),
              style: IconButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red.shade600,
              ),
              tooltip: 'Abmelden',
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inSeconds < 60) {
      return 'vor ${difference.inSeconds}s';
    } else if (difference.inMinutes < 60) {
      return 'vor ${difference.inMinutes}m';
    } else {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  String _formatDateWithWeekday(DateTime date) {
    const germanWeekdays = [
      'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 
      'Freitag', 'Samstag', 'Sonntag'
    ];
    
    final weekday = germanWeekdays[date.weekday - 1];
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    
    return '$weekday, $day.$month.$year';
  }

  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        // Current Games (Left Side)
        Expanded(
          flex: 2,
          child: _buildCurrentGamesSection(),
        ),
        Container(
          width: 1,
          color: Colors.grey.shade300,
        ),
        // Upcoming Games (Right Side)
        Expanded(
          flex: 3,
          child: _buildUpcomingGamesSection(),
        ),
      ],
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
      children: [
        // Current Games (Top)
        Expanded(
          flex: 2,
          child: _buildCurrentGamesSection(),
        ),
        Container(
          height: 1,
          color: Colors.grey.shade300,
        ),
        // Upcoming Games (Bottom)
        Expanded(
          flex: 3,
          child: _buildUpcomingGamesSection(),
        ),
      ],
    );
  }

  Widget _buildCurrentGamesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.play_circle_filled,
                  color: Colors.green.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Aktuelle Spiele',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _currentGames.isEmpty
                ? _buildEmptyState('Keine aktuellen Spiele', Icons.timer)
                : AnimatedList(
                    key: _currentGamesListKey,
                    initialItemCount: _currentGames.length,
                    itemBuilder: (context, index, animation) => _buildAnimatedGameCard(_currentGames[index], animation),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingGamesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.schedule,
                  color: Colors.blue.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Kommende Spiele',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _upcomingGames.isEmpty
                ? _buildEmptyState('Keine kommenden Spiele', Icons.event_available)
                : AnimatedList(
                    key: _upcomingGamesListKey,
                    initialItemCount: _upcomingGames.length,
                    itemBuilder: (context, index, animation) => _buildAnimatedGameCard(_upcomingGames[index], animation),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard(Game game) {
    final isLive = game.status == GameStatus.inProgress;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isLive 
            ? Border.all(color: Colors.green.shade400, width: 2)
            : Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _startScoring(game),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Game Header
              Row(
                children: [
                  // Time
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isLive ? Colors.green.shade100 : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          game.scheduledTime != null 
                              ? '${game.scheduledTime!.hour.toString().padLeft(2, '0')}:${game.scheduledTime!.minute.toString().padLeft(2, '0')}'
                              : 'TBD',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isLive ? Colors.green.shade700 : Colors.blue.shade700,
                          ),
                        ),
                        if (game.scheduledTime != null)
                          Text(
                            _formatDateWithWeekday(game.scheduledTime!),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isLive ? Colors.green.shade600 : Colors.blue.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  
                  // Status
                  if (isLive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Teams
              Row(
                children: [
                  Expanded(
                    child: Text(
                      game.teamAName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'VS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      game.teamBName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _startScoring(game),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLive ? Colors.green.shade600 : const Color(0xFFffd665),
                    foregroundColor: isLive ? Colors.white : Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    isLive ? 'Weiter punkten' : 'Spiel starten',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startScoring(Game game) async {
    setState(() {
      _selectedGame = game;
      _isInScoringMode = true;
      _selectedTab = 'main'; // Reset to main tab when entering scoring mode
      _teamA = null; // Reset team data while loading
      _teamB = null;
      _gameSquads.clear(); // Clear squad data
      _squadsLoading = true;
    });

    // Load actual team data
    if (game.teamAId != null) {
      _teamA = await _teamService.getTeamById(game.teamAId!);
    }
    if (game.teamBId != null) {
      _teamB = await _teamService.getTeamById(game.teamBId!);
    }
    
    // Load squad data for this game
    await _loadGameSquads();
    
    // Update UI with loaded team and squad data
    if (mounted) {
      setState(() {
        _squadsLoading = false;
      });
    }
  }

  Future<void> _loadGameSquads() async {
    if (_selectedGame == null) return;
    
    try {
      final squads = await _gameSquadService.streamSquadsForGame(_selectedGame!.id).first;
      
      // Find squads for each team
      for (final squad in squads) {
        _gameSquads[squad.teamId] = squad;
        print('✅ Loaded squad for team ${squad.teamId}: ${squad.playerCount} players');
      }
      
      print('✅ Total squads loaded: ${_gameSquads.length}');
    } catch (e) {
      print('❌ Error loading game squads: $e');
    }
  }

  Widget _buildNavigation() {
    final double sidebarWidth = _isSidebarExpanded ? 280 : 80;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: sidebarWidth,
      color: const Color(0xFF4A5568),
      child: Column(
        children: [
          // Header with Hamburger
          Container(
            height: _isSidebarExpanded ? 160 : 80,
            width: double.infinity,
            padding: EdgeInsets.all(_isSidebarExpanded ? 16 : 8),
            decoration: const BoxDecoration(
              color: Color(0xFF4A5568),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isSidebarExpanded) ...[
                  // Expanded header layout
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.sports_basketball, color: Colors.white, size: 24),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _isSidebarExpanded = !_isSidebarExpanded;
                          });
                        },
                        icon: const Icon(Icons.menu_open, color: Colors.white, size: 24),
                        tooltip: 'Navigation einklappen',
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        padding: const EdgeInsets.all(8),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'LIVE SCORING',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12 * ResponsiveHelper.getFontScale(MediaQuery.of(context).size.width),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_selectedGame != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${_selectedGame!.teamAName} vs ${_selectedGame!.teamBName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ] else ...[
                  // Collapsed header layout
                  Center(
                    child: IconButton(
                      onPressed: () {
                        setState(() {
                          _isSidebarExpanded = !_isSidebarExpanded;
                        });
                      },
                      icon: const Icon(Icons.menu, color: Colors.white, size: 24),
                      tooltip: 'Navigation ausklappen',
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildNavItem('main', 'Hauptansicht', Icons.home),
                _buildNavItem('squad', 'Kaderverwaltung', Icons.groups),
                _buildNavItem('referees', 'Schiedsrichter und Offizielle', Icons.sports_handball),
                _buildNavItem('scoring', 'Live-Scoring', Icons.scoreboard),
                _buildNavItem('statistics', 'Live-Statistiken', Icons.analytics),
                _buildNavItem('completion', 'Spielabschluss', Icons.check_circle),
              ],
            ),
          ),
          
          // Back to Games Button
          Container(
            padding: EdgeInsets.all(_isSidebarExpanded ? 16 : 8),
            child: _isSidebarExpanded
                ? SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _backToGames,
                      icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 20),
                      label: const Text('Zurück zu Spielen', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  )
                : Center(
                    child: IconButton(
                      onPressed: _backToGames,
                      icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 22),
                      tooltip: 'Zurück zu Spielen',
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      padding: const EdgeInsets.all(12),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationDrawer(double screenWidth) {
    return Drawer(
      child: Container(
        color: const Color(0xFF4A5568),
        child: Column(
          children: [
            // Header
            Container(
              height: 160,
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF4A5568),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sports_basketball, color: Colors.white, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'LIVE SCORING',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12 * ResponsiveHelper.getFontScale(screenWidth),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_selectedGame != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${_selectedGame!.teamAName} vs ${_selectedGame!.teamBName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerNavItem('main', 'Hauptansicht', Icons.home, screenWidth),
                  _buildDrawerNavItem('squad', 'Kaderverwaltung', Icons.groups, screenWidth),
                  _buildDrawerNavItem('referees', 'Schiedsrichter und Offizielle', Icons.sports_handball, screenWidth),
                  _buildDrawerNavItem('scoring', 'Live-Scoring', Icons.scoreboard, screenWidth),
                  _buildDrawerNavItem('statistics', 'Live-Statistiken', Icons.analytics, screenWidth),
                  _buildDrawerNavItem('completion', 'Spielabschluss', Icons.check_circle, screenWidth),
                ],
              ),
            ),
            // Back to Games Button
            Container(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _backToGames,
                  icon: const Icon(Icons.arrow_back, color: Colors.white70),
                  label: const Text('Zurück zu Spielen', style: TextStyle(color: Colors.white70)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileHeader(double screenWidth) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Builder(
            builder: (context) => IconButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(Icons.menu, color: Color(0xFF4A5568)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getTabTitle(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A5568),
              ),
            ),
          ),
          IconButton(
            onPressed: _backToGames,
            icon: const Icon(Icons.arrow_back, color: Color(0xFF4A5568)),
            tooltip: 'Zurück zu Spielen',
          ),
        ],
      ),
    );
  }

  void _backToGames() {
    setState(() {
      _isInScoringMode = false;
      _selectedGame = null;
      _teamA = null; // Clear team data
      _teamB = null; // Clear team data
      _gameSquads.clear(); // Clear squad data
      _squadsLoading = false;
      _selectedPlayer = null; // Clear selected player
      _selectedPlayerTeamId = null;
      _selectedTab = 'main';
      _showSetCompletionOverlay = false; // Clear overlay
      _completedSet = null;
      _lastProcessedSetCount = 0;
    });
  }

  Widget _buildNavItem(String tabId, String title, IconData icon) {
    final isSelected = _selectedTab == tabId;
    
    if (!_isSidebarExpanded) {
      // Collapsed state - only show icon
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Tooltip(
          message: title,
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedTab = tabId;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 52,
              width: 56,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2D3748) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.white70,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      );
    }
    
    // Expanded state - show icon and text
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF2D3748) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.white70,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        onTap: () {
          setState(() {
            _selectedTab = tabId;
          });
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildDrawerNavItem(String tabId, String title, IconData icon, double screenWidth) {
    final isSelected = _selectedTab == tabId;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF2D3748) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Builder(
        builder: (context) => ListTile(
          dense: true,
          leading: Icon(
            icon,
            color: isSelected ? Colors.white : Colors.white70,
            size: 20,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 14,
            ),
          ),
          onTap: () {
            setState(() {
              _selectedTab = tabId;
            });
            Navigator.of(context).pop(); // Close drawer
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
      ),
    );
  }

  String _getTabTitle() {
    switch (_selectedTab) {
      case 'main':
        return 'Hauptansicht';
      case 'squad':
        return 'Kaderverwaltung';
      case 'referees':
        return 'Schiedsrichter und Offizielle';
      case 'scoring':
        return 'Live-Scoring';
      case 'statistics':
        return 'Live-Statistiken';
      case 'completion':
        return 'Spielabschluss';
      default:
        return 'Hauptansicht';
    }
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 'main':
        return _buildMainView();
      case 'squad':
        return _buildSquadManagement();
      case 'referees':
        return _buildRefereesAndOfficials();
      case 'scoring':
        return _buildLiveScoring();
      case 'statistics':
        return _buildLiveStatistics();
      case 'completion':
        return _buildGameCompletion();
      default:
        return _buildMainView();
    }
  }

  Widget _buildMainView() {
    if (_selectedGame == null) {
      return _buildNoGameView();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Tournament and Court Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    _assignedTournament?.name ?? 'Kein Turnier',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFffd665),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.sports_tennis,
                              size: 16,
                              color: Colors.black87,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Court ${_assignedCourt?.name ?? 'N/A'}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_assignedTournament?.location != null) ...[
                        const SizedBox(width: 12),
                        Text(
                          _assignedTournament!.location,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  
                  // Division and Pool Information
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Division Info
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.category,
                              size: 14,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _extractDivisionFromGame(_selectedGame!),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Pool/Game Type Info
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _selectedGame!.gameType == GameType.pool ? Icons.workspaces : Icons.military_tech,
                              size: 14,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _getGameTypeDisplay(_selectedGame!),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Main Game Display
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Game Status
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _getStatusColor(_selectedGame!.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getStatusText(_selectedGame!.status),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(_selectedGame!.status),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Scheduled Time
                    if (_selectedGame!.scheduledTime != null)
                      Text(
                        '${_selectedGame!.scheduledTime!.day.toString().padLeft(2, '0')}.${_selectedGame!.scheduledTime!.month.toString().padLeft(2, '0')}.${_selectedGame!.scheduledTime!.year} - ${_selectedGame!.scheduledTime!.hour.toString().padLeft(2, '0')}:${_selectedGame!.scheduledTime!.minute.toString().padLeft(2, '0')} Uhr',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    
                    const SizedBox(height: 40),
                    
                    // Teams Display
                    Row(
                      children: [
                        // Team A
                        Expanded(
                          child: Column(
                            children: [
                              // Team Logo Placeholder
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.blue.shade300,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.sports_basketball,
                                  color: Colors.blue.shade600,
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _selectedGame!.teamAName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        
                        // VS Divider
                        Container(
                          width: 80,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 3,
                                height: 30,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'VS',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: 3,
                                height: 30,
                                color: Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ),
                        
                        // Team B
                        Expanded(
                          child: Column(
                            children: [
                              // Team Logo Placeholder
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.red.shade300,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.sports_basketball,
                                  color: Colors.red.shade600,
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _selectedGame!.teamBName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Quick Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildQuickActionButton(
                          'Live-Scoring',
                          Icons.scoreboard,
                          Colors.green,
                          () => setState(() => _selectedTab = 'scoring'),
                        ),
                        _buildQuickActionButton(
                          'Statistiken',
                          Icons.analytics,
                          Colors.blue,
                          () => setState(() => _selectedTab = 'statistics'),
                        ),
                        _buildQuickActionButton(
                          'Kaderverwaltung',
                          Icons.groups,
                          Colors.orange,
                          () => setState(() => _selectedTab = 'squad'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildNoGameView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sports_basketball_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 24),
          Text(
            'Kein Spiel ausgewählt',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Wählen Sie ein Spiel aus der Liste aus.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _backToGames,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Zurück zu Spielen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFffd665),
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSquadManagement() {
    if (_selectedGame == null) {
      return _buildNoGameView();
    }

    return StreamBuilder<List<GameSquad>>(
      stream: _gameSquadService.streamSquadsForGame(_selectedGame!.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final squads = snapshot.data ?? [];
        final teamASquad = squads.where((s) => s.teamId == _selectedGame!.teamAId).firstOrNull;
        final teamBSquad = squads.where((s) => s.teamId == _selectedGame!.teamBId).firstOrNull;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Game Header with Force Refresh
              Row(
                children: [
                  Expanded(child: _buildGameHeader()),
                  // Force refresh button for squad data
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: IconButton(
                      onPressed: _isRefreshing ? null : _performBackgroundRefresh,
                      icon: _isRefreshing 
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.orange.shade600,
                            ),
                          )
                        : Icon(Icons.refresh, color: Colors.orange.shade600),
                      tooltip: 'Kader-Daten von Firebase neu laden',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Player Color Settings
              _buildPlayerColorSettings(),
              const SizedBox(height: 24),
              
              // Teams Squad Cards
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Team A Squad
                  Expanded(
                    child: _buildTeamSquadCard(
                      teamName: _selectedGame!.teamAName,
                      team: _teamA,
                      squad: teamASquad,
                      isTeamA: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Team B Squad  
                  Expanded(
                    child: _buildTeamSquadCard(
                      teamName: _selectedGame!.teamBName,
                      team: _teamB,
                      squad: teamBSquad,
                      isTeamA: false,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRefereesAndOfficials() {
    return _buildPlaceholderScreen(
      'Schiedsrichter und Offizielle',
      Icons.sports_handball,
      'Hier können Sie Schiedsrichter und Spieloffizielle verwalten.',
      Colors.purple,
    );
  }

  Widget _buildLiveScoring() {
    if (_selectedGame == null) {
      return _buildNoGameView();
    }

    return StreamBuilder<GameState>(
      stream: _liveScoringService.streamGameState(_selectedGame!.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final gameState = snapshot.data ?? GameState(
          gameId: _selectedGame!.id,
          gameTime: GameTime(),
        );

        // Check for set completion (defer to avoid setState during build)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkForSetCompletion(gameState);
        });

        // Show shootout interface if in shootout mode
        if (_isInShootout) {
          return _buildShootoutInterface(gameState);
        }

        return Stack(
          children: [
            Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Game Header
              _buildLiveScoringHeader(gameState),
              const SizedBox(height: 16),
              
              // Main Scoring Area
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Panel - Team A
                    Expanded(
                      flex: 2,
                      child: _buildTeamScoringPanel(
                        gameState: gameState,
                        teamId: _selectedGame!.teamAId ?? '',
                        teamName: _selectedGame!.teamAName,
                        team: _teamA,
                        isTeamA: true,
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Center Panel - Game Controls & Events
                    Expanded(
                      flex: 1,
                      child: _buildCenterControlPanel(gameState),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Right Panel - Team B
                    Expanded(
                      flex: 2,
                      child: _buildTeamScoringPanel(
                        gameState: gameState,
                        teamId: _selectedGame!.teamBId ?? '',
                        teamName: _selectedGame!.teamBName,
                        team: _teamB,
                        isTeamA: false,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Set Completion Overlay
        if (_showSetCompletionOverlay && _completedSet != null)
          _buildSetCompletionOverlay(_completedSet!),
        
        // Shootout Setup Dialog
        if (_showShootoutSetupDialog && _completedSet != null)
          _buildShootoutSetupDialog(_completedSet!),
      ],
        );
      },
    );
  }

  Widget _buildLiveStatistics() {
    return _buildPlaceholderScreen(
      'Live-Statistiken',
      Icons.analytics,
      'Hier können Sie Live-Statistiken und Spielanalysen einsehen.',
      Colors.blue,
    );
  }

  Widget _buildGameCompletion() {
    if (_selectedGame == null) {
      return _buildNoGameView();
    }

    return StreamBuilder<GameState>(
      stream: _liveScoringService.streamGameState(_selectedGame!.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final gameState = snapshot.data ?? GameState(
          gameId: _selectedGame!.id,
          gameTime: GameTime(),
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.teal.shade100,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Icon(
                        Icons.flag_outlined,
                        size: 30,
                        color: Colors.teal.shade600,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
      'Spielabschluss',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_selectedGame!.teamAName} vs ${_selectedGame!.teamBName}',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Game Summary
              _buildGameSummaryCard(gameState),
              
              const SizedBox(height: 24),
              
              // Reset Options
              _buildResetOptionsCard(gameState),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGameSummaryCard(GameState gameState) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Spielzusammenfassung',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          
          // Current Score
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      _selectedGame!.teamAName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade600,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${gameState.getCurrentSetScore(_selectedGame!.teamAId ?? '')}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const Text(
                ':',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              
              Expanded(
                child: Column(
                  children: [
                    Text(
                      _selectedGame!.teamBName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${gameState.getCurrentSetScore(_selectedGame!.teamBId ?? '')}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Set Wins
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Gewonnene Sätze',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${gameState.teamASetWins}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Gewonnene Sätze',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${gameState.teamBSetWins}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Statistics
          if (gameState.events.isNotEmpty) ...[
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Spielstatistiken',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatisticItem(
                    'Gesamtereignisse',
                    '${gameState.events.length}',
                    Icons.list_alt,
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatisticItem(
                    'Spielzeit',
                    gameState.gameTime.displayTime,
                    Icons.timer,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatisticItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetOptionsCard(GameState gameState) {
    final hasData = gameState.events.isNotEmpty || gameState.setScores.isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.refresh,
                color: Colors.red.shade600,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Spiel zurücksetzen',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Text(
            hasData 
                ? 'Alle Punkte, Ereignisse und Sätze löschen. Diese Aktion kann nicht rückgängig gemacht werden.'
                : 'Aktuell sind keine Daten zum Zurücksetzen vorhanden.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          
          if (hasData) ...[
            // Warning box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: Colors.red.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Achtung: Alle Spielereignisse und Punkte werden dauerhaft gelöscht!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Reset buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showResetConfirmationDialog(gameState, false),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Aktuellen Satz zurücksetzen'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showResetConfirmationDialog(gameState, true),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Gesamtes Spiel zurücksetzen'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // No data message
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.grey.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Das Spiel ist bereits leer oder wurde noch nicht gestartet.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaceholderScreen(String title, IconData icon, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(60),
                border: Border.all(
                  color: color.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                size: 60,
                color: color,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              title,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Diese Funktionalität wird in einer zukünftigen Version implementiert.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFffd665)),
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              'Lade Scoring-Daten...',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(GameStatus status) {
    switch (status) {
      case GameStatus.scheduled:
        return Colors.blue;
      case GameStatus.inProgress:
        return Colors.green;
      case GameStatus.completed:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(GameStatus status) {
    switch (status) {
      case GameStatus.scheduled:
        return 'Geplant';
      case GameStatus.inProgress:
        return 'Live';
      case GameStatus.completed:
        return 'Beendet';
      default:
        return 'Unbekannt';
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abmelden'),
        content: const Text('Möchten Sie sich wirklich abmelden?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _authService.signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Abmelden'),
          ),
        ],
      ),
    );
  }

  void _showSuccessToast(String message) {
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.fillColored,
      title: const Text('Erfolg'),
      description: Text(message),
      alignment: Alignment.topRight,
      autoCloseDuration: const Duration(seconds: 3),
      showProgressBar: false,
    );
  }

  void _showErrorToast(String message) {
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.fillColored,
      title: const Text('Fehler'),
      description: Text(message),
      alignment: Alignment.topRight,
      autoCloseDuration: const Duration(seconds: 4),
      showProgressBar: false,
    );
  }

  String _extractDivisionFromGame(Game game) {
    // Use actual team data if available
    if (_teamA != null && _teamB != null) {
      // If both teams are from the same division, show that
      if (_teamA!.division == _teamB!.division) {
        return _teamA!.division;
      } else {
        // Show both divisions if different
        return '${_teamA!.division} vs ${_teamB!.division}';
      }
    } else if (_teamA != null) {
      return _teamA!.division;
    } else if (_teamB != null) {
      return _teamB!.division;
    }

    // Fallback: try to extract division from team names if no team data loaded yet
    String combinedNames = '${game.teamAName} ${game.teamBName}'.toLowerCase();
    
    if (combinedNames.contains('women') || combinedNames.contains('damen')) {
      if (combinedNames.contains('u14')) return 'Women\'s U14';
      if (combinedNames.contains('u16')) return 'Women\'s U16';
      if (combinedNames.contains('u18')) return 'Women\'s U18';
      if (combinedNames.contains('seniors')) return 'Women\'s Seniors';
      if (combinedNames.contains('fun')) return 'Women\'s FUN';
      return 'Women\'s';
    } else if (combinedNames.contains('men') || combinedNames.contains('herren')) {
      if (combinedNames.contains('u14')) return 'Men\'s U14';
      if (combinedNames.contains('u16')) return 'Men\'s U16';
      if (combinedNames.contains('u18')) return 'Men\'s U18';
      if (combinedNames.contains('seniors')) return 'Men\'s Seniors';
      if (combinedNames.contains('fun')) return 'Men\'s FUN';
      return 'Men\'s';
    } else if (combinedNames.contains('u14')) {
      return 'U14';
    } else if (combinedNames.contains('u16')) {
      return 'U16';
    } else if (combinedNames.contains('u18')) {
      return 'U18';
    } else if (combinedNames.contains('seniors')) {
      return 'Seniors';
    } else if (combinedNames.contains('fun')) {
      return 'FUN';
    }
    
    return 'Lade Division...';
  }

  String _getGameTypeDisplay(Game game) {
    if (game.gameType == GameType.pool) {
      if (game.poolId != null) {
        // For pool games, show a simpler display since poolId is just a number
        return 'Poolspiel';
      }
      return 'Poolspiel';
    } else if (game.gameType == GameType.elimination && game.bracketRound != null) {
      switch (game.bracketRound!) {
        case 1:
          return 'Achtelfinale';
        case 2:
          return 'Viertelfinale';
        case 3:
          return 'Halbfinale';
        case 4:
          return 'Finale';
        case 5:
          return 'Spiel um Platz 3';
        default:
          return 'K.O.-Runde ${game.bracketRound}';
      }
    } else if (game.gameType == GameType.elimination) {
      return 'K.O.-Spiel';
    }
    
    return 'Spieltyp unbekannt';
  }

  String _parsePoolIdToName(String poolId) {
    // Since poolId is just a technical number, show it in a user-friendly way
    return 'Pool $poolId';
  }

  Widget _buildGameHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Kader-Verwaltung',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedGame?.displayName ?? 'Kein Spiel ausgewählt',
            style: const TextStyle(
              fontSize: 18,
              color: Colors.black54,
            ),
          ),
          if (_selectedGame?.scheduledTime != null) ...[
            const SizedBox(height: 4),
            Text(
              'Anpfiff: ${_formatDateTime(_selectedGame!.scheduledTime!)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTeamSquadCard({
    required String teamName,
    required Team? team,
    required GameSquad? squad,
    required bool isTeamA,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Team Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isTeamA ? Colors.blue[700] : Colors.red[700],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    teamName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (squad != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${squad.playerCount}/10',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Squad Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: squad == null
                ? _buildNoSquadMessage()
                : _buildSquadContent(squad),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSquadMessage() {
    return Column(
      children: [
        Icon(
          Icons.group_off,
          size: 48,
          color: Colors.grey[400],
        ),
        const SizedBox(height: 12),
        Text(
          'Kein Kader ausgewählt',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Der Trainer muss noch den Kader für dieses Spiel auswählen.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[500],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSquadContent(GameSquad squad) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Squad Status
        _buildSquadStatus(squad),
        const SizedBox(height: 16),
        
        // Players List
        _buildPlayersList(squad),
      ],
    );
  }

  Widget _buildSquadStatus(GameSquad squad) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (squad.isApproved) {
      statusColor = Colors.green;
      statusText = 'Vom Trainer bestätigt';
      statusIcon = Icons.check_circle;
    } else if (squad.isRejected) {
      statusColor = Colors.red;
      statusText = 'Vom Trainer abgelehnt';
      statusIcon = Icons.cancel;
    } else {
      statusColor = Colors.orange;
      statusText = 'Wartet auf Trainer-Bestätigung';
      statusIcon = Icons.hourglass_empty;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Ausgewählt von ${squad.selectedByName}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersList(GameSquad squad) {
    final teamId = squad.teamId;
    final isTeamA = teamId == _selectedGame?.teamAId;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Ausgewählte Spieler (${squad.playerCount})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            // Color legend
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isTeamA ? _teamAShooterColor : _teamBShooterColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 4),
                                         const Text('Shooter', style: TextStyle(fontSize: 10)),
                const SizedBox(width: 8),
                                 Container(
                   width: 16,
                   height: 16,
                   decoration: BoxDecoration(
                     color: isTeamA ? _teamASpielerColor : _teamBSpielerColor,
                     borderRadius: BorderRadius.circular(8),
                   ),
                 ),
                 const SizedBox(width: 4),
                 const Text('Spieler', style: TextStyle(fontSize: 10)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...squad.selectedPlayers.map((player) {
          final isShooter = _playerTypes[player.playerId] ?? false;
          final playerColor = isShooter 
              ? (isTeamA ? _teamAShooterColor : _teamBShooterColor)
              : (isTeamA ? _teamASpielerColor : _teamBSpielerColor);
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: InkWell(
              onTap: () {
                setState(() {
                  _playerTypes[player.playerId] = !isShooter;
                });
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: playerColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: playerColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: playerColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          player.jerseyNumber ?? '?',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        player.fullName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      isShooter ? 'Shooter' : 'Spieler',
                      style: TextStyle(
                        fontSize: 12,
                        color: playerColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isShooter ? Icons.sports_basketball : Icons.person,
                      size: 16,
                      color: playerColor,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildPlayerColorSettings() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Spielerfarben konfigurieren',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Wählen Sie Farben für Shooter und Spieler. Diese werden in der Live-Punktevergabe verwendet.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          
          Row(
            children: [
              // Team A Colors
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedGame!.teamAName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                                         _buildColorSelector(
                       label: 'Shooter',
                       currentColor: _teamAShooterColor,
                       onColorSelected: (color) {
                         setState(() {
                           _teamAShooterColor = color;
                         });
                       },
                     ),
                    const SizedBox(height: 8),
                                         _buildColorSelector(
                       label: 'Spieler',
                       currentColor: _teamASpielerColor,
                       onColorSelected: (color) {
                         setState(() {
                           _teamASpielerColor = color;
                         });
                       },
                     ),
                  ],
                ),
              ),
              
              const SizedBox(width: 32),
              
              // Team B Colors
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedGame!.teamBName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                                         _buildColorSelector(
                       label: 'Shooter',
                       currentColor: _teamBShooterColor,
                       onColorSelected: (color) {
                         setState(() {
                           _teamBShooterColor = color;
                         });
                       },
                     ),
                    const SizedBox(height: 8),
                                         _buildColorSelector(
                       label: 'Spieler',
                       currentColor: _teamBSpielerColor,
                       onColorSelected: (color) {
                         setState(() {
                           _teamBSpielerColor = color;
                         });
                       },
                     ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorSelector({
    required String label,
    required Color currentColor,
    required Function(Color) onColorSelected,
  }) {
    final availableColors = [
      Colors.red.shade600,
      Colors.blue.shade600,
      Colors.green.shade600,
      Colors.orange.shade600,
      Colors.purple.shade600,
      Colors.teal.shade600,
      Colors.indigo.shade600,
      Colors.pink.shade600,
      Colors.amber.shade600,
      Colors.cyan.shade600,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableColors.map((color) {
            final isSelected = color.value == currentColor.value;
            return InkWell(
              onTap: () => onColorSelected(color),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                  border: isSelected 
                      ? Border.all(color: Colors.black, width: 3)
                      : Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 20,
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLiveScoringHeader(GameState gameState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: Game Time + Controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  gameState.gameTime.displayTime,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: gameState.isRunning 
                      ? () => _liveScoringService.pauseGameTimer(_selectedGame!.id)
                      : () => _liveScoringService.startGameTimer(_selectedGame!.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gameState.isRunning ? Colors.orange : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(60, 32),
                  ),
                  child: Icon(
                    gameState.isRunning ? Icons.pause : Icons.play_arrow,
                    size: 16,
                  ),
                ),
                if (gameState.gameTime.minutes >= 10) ...[
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _showEndSetDialog(gameState),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: const Size(100, 32),
                    ),
                    child: const Text('Satz beenden', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(width: 24),
          
          // Center: Teams + Current Score
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Team A
                  Expanded(
                    child: Text(
                      _selectedGame!.teamAName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  // Current Score
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${gameState.getCurrentSetScore(_selectedGame!.teamAId ?? '')} : ${gameState.getCurrentSetScore(_selectedGame!.teamBId ?? '')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  
                  // Team B
                  Expanded(
                    child: Text(
                      _selectedGame!.teamBName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 24),
          
          // Right: Previous Sets + Set Wins
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Set Wins
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${gameState.teamASetWins}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Text(':', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${gameState.teamBSetWins}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                if (gameState.setScores.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  const Text('Sätze:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 8),
                  ...gameState.setScores.take(3).map((setScore) => Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      '${setScore.teamAScore}:${setScore.teamBScore}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  )).toList(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamScoringPanel({
    required GameState gameState,
    required String teamId,
    required String teamName,
    required Team? team,
    required bool isTeamA,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Team Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isTeamA ? _teamASpielerColor : _teamBSpielerColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isTeamA ? _teamAShooterColor : _teamBShooterColor,
                  width: 8,
                ),
              ),
            ),
            child: Column(
              children: [
                                Row(
                  children: [
                    Expanded(
                      child: Text(
                        teamName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _undoLastAction(teamId),
                      icon: const Icon(Icons.undo, color: Colors.white, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        padding: const EdgeInsets.all(8),
                      ),
                      tooltip: 'Letzte Aktion rückgängig',
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Player Actions
          Expanded(
            child: _buildPlayerActions(gameState, teamId, teamName, team),
          ),
        ],
      ),
    );
  }

  // Helper method to check if a player has received a red card
  bool _hasRedCard(GameState gameState, String playerId) {
    return gameState.events.any((event) => 
      event.playerId == playerId && 
      event.eventType == GameEventType.redCard
    );
  }

  // Helper method to count player suspensions
  int _getPlayerSuspensionCount(GameState gameState, String playerId) {
    return gameState.events.where((event) => 
      event.playerId == playerId && 
      event.eventType == GameEventType.suspension
    ).length;
  }

  // Helper method to check if player has any suspensions
  bool _hasPlayerSuspensions(GameState gameState, String playerId) {
    return _getPlayerSuspensionCount(gameState, playerId) > 0;
  }

  // Helper method to check for newly completed sets
  void _checkForSetCompletion(GameState gameState) {
    final completedSets = gameState.setScores.where((set) => set.isCompleted).toList();
    
    if (completedSets.length > _lastProcessedSetCount) {
      // New set completed
      final newlyCompletedSet = completedSets.last;
      
      // Check if we need a shootout (1:1 in sets)
      if (gameState.teamASetWins == 1 && gameState.teamBSetWins == 1) {
        setState(() {
          _completedSet = newlyCompletedSet;
          _showShootoutSetupDialog = true;
          _lastProcessedSetCount = completedSets.length;
        });
      } else {
        setState(() {
          _completedSet = newlyCompletedSet;
          _showSetCompletionOverlay = true;
          _lastProcessedSetCount = completedSets.length;
        });
      }
    }
  }

  // Build set completion overlay
  Widget _buildSetCompletionOverlay(SetScore completedSet) {
    final winnerId = completedSet.teamAScore > completedSet.teamBScore 
        ? completedSet.teamAId 
        : completedSet.teamBId;
    final winnerName = winnerId == _selectedGame!.teamAId 
        ? _selectedGame!.teamAName 
        : _selectedGame!.teamBName;
    
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Trophy Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFffd665),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(
                  Icons.emoji_events,
                  size: 50,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              
              // Set Number
              Text(
                '${completedSet.setNumber}. Satz beendet',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              
              // Winner Announcement
              Text(
                '$winnerName hat gewonnen!',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Final Score
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Team A
                    Column(
                      children: [
                        Text(
                          _selectedGame!.teamAName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: winnerId == completedSet.teamAId 
                                ? Colors.green.shade600 
                                : Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${completedSet.teamAScore}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(width: 32),
                    
                    // VS Divider
                    const Text(
                      ':',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    
                    const SizedBox(width: 32),
                    
                    // Team B
                    Column(
                      children: [
                        Text(
                          _selectedGame!.teamBName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: winnerId == completedSet.teamBId 
                                ? Colors.green.shade600 
                                : Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${completedSet.teamBScore}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Action Buttons
              Row(
                children: [
                  // Make Changes Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _handleMakeChanges,
                      icon: const Icon(Icons.edit),
                      label: const Text('Änderungen vornehmen'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Confirm Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _handleConfirmSet,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Bestätigen'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build shootout setup dialog
  Widget _buildShootoutSetupDialog(SetScore completedSet) {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Shootout Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.orange.shade600,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(
                  Icons.sports_handball,
                  size: 50,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              const Text(
                'Shootout erforderlich!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Explanation
              const Text(
                'Der Satzstand ist 1:1. Es geht in das Shootout.',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Team Selection
              const Text(
                'Welches Team beginnt das Shootout?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Team Buttons
              Row(
                children: [
                  // Team A Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _startShootout(true), // Team A starts
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _selectedGame!.teamAName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'beginnt',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Team B Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _startShootout(false), // Team B starts
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _selectedGame!.teamBName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'beginnt',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Start shootout with team selection
  void _startShootout(bool teamAStarts) {
    setState(() {
      _isInShootout = true;
      _showShootoutSetupDialog = false;
      _completedSet = null;
      _teamAStartsShootout = teamAStarts;
      _isTeamATurn = teamAStarts; // Set current turn based on who starts
      // Clear any previous player assignments
      _assignedShooter = null;
      _assignedPlayer = null;
      _assignedGoalkeeper = null;
      // Clear shootout scores
      _teamAShootoutScores.clear();
      _teamBShootoutScores.clear();
      // Clear used Werfer players
      _usedPlayerIds.clear();
    });
    
    _showSuccessToast('Shootout gestartet - ${teamAStarts ? _selectedGame!.teamAName : _selectedGame!.teamBName} beginnt');
  }

  // Build shootout interface
  Widget _buildShootoutInterface(GameState gameState) {
    return Container(
      color: Colors.grey.shade100,
      child: Column(
        children: [
          // Top: Results Grid (6x2)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                const Text(
                  'SHOOTOUT',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                _buildShootoutGrid(),
              ],
            ),
          ),
          
          // Middle: Current Turn + Score Selection
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.orange.shade100,
            child: Row(
              children: [
                // Current turn
                Text(
                  'Aktueller Durchgang: ${_isTeamATurn ? _selectedGame!.teamAName : _selectedGame!.teamBName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Score selection buttons
                const Text(
                  'Ergebnis:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _recordShootoutScore(0),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(50, 32),
                  ),
                  child: const Text('0', style: TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: () => _recordShootoutScore(1),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(50, 32),
                  ),
                  child: const Text('1', style: TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: () => _recordShootoutScore(2),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(50, 32),
                  ),
                  child: const Text('2', style: TextStyle(fontSize: 14)),
                ),
                
                const Spacer(),
                
                // Exit button
                ElevatedButton(
                  onPressed: () => _exitShootout(),
                  child: const Text('Beenden'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom: Horizontal Player Layout and Drag & Drop
          Expanded(
            child: _buildShootoutPlayerInterface(gameState),
          ),
        ],
      ),
    );
  }

  // Build shootout results grid (dynamic columns for sudden death)
  Widget _buildShootoutGrid() {
    // Calculate number of columns needed (minimum 5, but expand for sudden death)
    final maxAttempts = math.max(5, math.max(_teamAShootoutScores.length, _teamBShootoutScores.length));
    
    return Container(
      child: Column(
        children: [
          // Top row: Team names and totals
          Row(
            children: [
              // Team A total
              Expanded(
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _selectedGame!.teamAName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${_teamAShootoutScores.fold(0, (sum, score) => sum + score)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Individual attempts (dynamic columns)
              ...List.generate(maxAttempts, (index) => Expanded(
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: (_isTeamATurn && index == _teamAShootoutScores.length) 
                      ? Colors.blue.shade500 
                      : Colors.blue.shade400,
                    border: Border.all(
                      color: (_isTeamATurn && index == _teamAShootoutScores.length) 
                        ? Colors.yellow.shade400 
                        : Colors.white, 
                      width: (_isTeamATurn && index == _teamAShootoutScores.length) 
                        ? 3 
                        : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      index < _teamAShootoutScores.length 
                        ? _teamAShootoutScores[index].toString()
                        : '-',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              )),
            ],
          ),
          // Bottom row: Team B
          Row(
            children: [
              // Team B total
              Expanded(
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _selectedGame!.teamBName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${_teamBShootoutScores.fold(0, (sum, score) => sum + score)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Individual attempts (dynamic columns)
              ...List.generate(maxAttempts, (index) => Expanded(
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: (!_isTeamATurn && index == _teamBShootoutScores.length) 
                      ? Colors.red.shade500 
                      : Colors.red.shade400,
                    border: Border.all(
                      color: (!_isTeamATurn && index == _teamBShootoutScores.length) 
                        ? Colors.yellow.shade400 
                        : Colors.white, 
                      width: (!_isTeamATurn && index == _teamBShootoutScores.length) 
                        ? 3 
                        : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      index < _teamBShootoutScores.length 
                        ? _teamBShootoutScores[index].toString()
                        : '-',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              )),
            ],
          ),
        ],
      ),
    );
  }

  // Build shootout player interface
  Widget _buildShootoutPlayerInterface(GameState gameState) {
    // Determine which section goes where based on current turn
    final bool attackOnLeft = _isTeamATurn; // Team A attacks on left, Team B attacks on right
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Position Assignment Area
          Container(
            height: 120,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: attackOnLeft 
                ? [
                    // Shooter on left
                    _buildShooterPosition(),
                    const SizedBox(width: 16),
                    // Werfer in middle
                    _buildWerferPosition(),
                    const SizedBox(width: 16),
                    // Defense on right
                    _buildDefendingPosition(),
                  ]
                : [
                    // Defense on left
                    _buildDefendingPosition(),
                    const SizedBox(width: 16),
                    // Werfer in middle
                    _buildWerferPosition(),
                    const SizedBox(width: 16),
                    // Shooter on right
                    _buildShooterPosition(),
                  ],
            ),
          ),
          
          // Bottom: Horizontal Player Layout and Drag & Drop
          Expanded(
            child: Row(
              children: [
                // Team A Players
                Expanded(
                  child: _buildHorizontalPlayerList(gameState, true),
                ),
                const SizedBox(width: 16),
                // Team B Players
                Expanded(
                  child: _buildHorizontalPlayerList(gameState, false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  // Build defending position widget
  Widget _buildDefendingPosition() {
    return Expanded(
      child: Column(
        children: [
          const Text(
            'Verteidigung',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: DragTarget<SquadPlayer>(
              onAccept: (player) {
                setState(() {
                  _assignedGoalkeeper = player;
                });
                _showSuccessToast('${player.firstName} ${player.lastName} als Torwart zugewiesen');
              },
              builder: (context, accepted, rejected) => Container(
                decoration: BoxDecoration(
                  color: _assignedGoalkeeper != null ? Colors.green.shade200 : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _assignedGoalkeeper != null ? Colors.green.shade600 : Colors.green.shade300,
                    width: _assignedGoalkeeper != null ? 2 : 1,
                  ),
                ),
                child: _assignedGoalkeeper != null
                  ? Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _assignedGoalkeeper!.jerseyNumber ?? '?',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${_assignedGoalkeeper!.firstName?.substring(0, 1)}. ${_assignedGoalkeeper!.lastName}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _assignedGoalkeeper = null;
                              });
                            },
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.red.shade600,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : const Center(
                      child: Text(
                        'TORWART\nPlayer hierher ziehen',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build horizontal player list for shootout
  Widget _buildHorizontalPlayerList(GameState gameState, bool isTeamA) {
    final teamId = isTeamA ? _selectedGame!.teamAId : _selectedGame!.teamBId;
    final teamName = isTeamA ? _selectedGame!.teamAName : _selectedGame!.teamBName;
    final teamColor = isTeamA ? Colors.blue : Colors.red;
    
    // Get squad for this team
    final squad = _gameSquads[teamId];
    
    if (squad == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            'Kein Kader für $teamName',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          teamName,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: teamColor.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5, // 5 players per row
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.0,
            ),
            itemCount: squad.selectedPlayers.length,
            itemBuilder: (context, index) {
              final squadPlayer = squad.selectedPlayers[index];
              final hasRedCard = _hasRedCard(gameState, squadPlayer.playerId);
              final isUsedAsWerfer = _usedPlayerIds.contains(squadPlayer.playerId); // Only Werfer players are tracked
              
              return Draggable<SquadPlayer>(
                data: squadPlayer,
                feedback: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: teamColor.shade600,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        squadPlayer.jerseyNumber ?? '?',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                childWhenDragging: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade400, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      squadPlayer.jerseyNumber ?? '?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
                // Disable dragging only for red-carded players (used Werfer players can still be Shooter/Goalkeeper)
                child: IgnorePointer(
                  ignoring: hasRedCard,
                  child: Container(
                    decoration: BoxDecoration(
                      color: hasRedCard 
                        ? Colors.grey.shade400 
                        : isUsedAsWerfer 
                          ? teamColor.shade300  // Lighter but still team color
                          : teamColor.shade600,
                      borderRadius: BorderRadius.circular(8),
                      border: hasRedCard 
                        ? Border.all(color: Colors.red.shade300, width: 2)
                        : isUsedAsWerfer
                          ? Border.all(color: Colors.orange.shade300, width: 2)
                          : null,
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            squadPlayer.jerseyNumber ?? '?',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: hasRedCard ? Colors.grey.shade600 : Colors.white,
                              decoration: hasRedCard ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        // Red card indicator
                        if (hasRedCard)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.red.shade600,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 8,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        // Used as Werfer indicator
                        if (isUsedAsWerfer && !hasRedCard)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.orange.shade600,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                size: 8,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Record shootout score and switch turns
  void _recordShootoutScore(int points) {
    // Validate that all positions are assigned
    if (_assignedShooter == null || _assignedPlayer == null || _assignedGoalkeeper == null) {
      _showErrorToast('Alle Positionen müssen besetzt sein!');
      return;
    }

    setState(() {
      // Record the score for the current team
      if (_isTeamATurn) {
        _teamAShootoutScores.add(points);
      } else {
        _teamBShootoutScores.add(points);
      }
      
      // Track used Werfer players to prevent reuse (only Werfer, not Shooter or Goalkeeper)
      if (_assignedPlayer != null) _usedPlayerIds.add(_assignedPlayer!.playerId);
      
      // Check for sudden death reset after 5 throws each
      if (_teamAShootoutScores.length == 5 && _teamBShootoutScores.length == 5) {
        final teamATotal = _teamAShootoutScores.fold(0, (sum, score) => sum + score);
        final teamBTotal = _teamBShootoutScores.fold(0, (sum, score) => sum + score);
        
        if (teamATotal == teamBTotal) {
          // It's a draw after 5 throws each - reset used players for sudden death
          _usedPlayerIds.clear();
          _showSuccessToast('Unentschieden nach 5 Würfen - Sudden Death! Alle Spieler wieder verfügbar.');
        }
      }
      
      // Switch turns
      _isTeamATurn = !_isTeamATurn;
      
      // Clear player assignments for next turn
      _assignedShooter = null;
      _assignedPlayer = null;
      _assignedGoalkeeper = null;
    });
    
    _showSuccessToast('$points Punkte eingetragen');
  }

  // Exit shootout mode
  void _exitShootout() {
    setState(() {
      _isInShootout = false;
      // Clear all player assignments
      _assignedShooter = null;
      _assignedPlayer = null;
      _assignedGoalkeeper = null;
      // Clear shootout scores
      _teamAShootoutScores.clear();
      _teamBShootoutScores.clear();
      _isTeamATurn = true;
      // Clear used Werfer players
      _usedPlayerIds.clear();
    });
  }

  // Handle confirm set completion
  void _handleConfirmSet() {
    setState(() {
      _showSetCompletionOverlay = false;
      _completedSet = null;
    });
    
    _showSuccessToast('Satz bestätigt und weiter zum nächsten Satz');
  }

  // Handle make changes to set
  void _handleMakeChanges() {
    setState(() {
      _showSetCompletionOverlay = false;
      _completedSet = null;
    });
    
    // TODO: Implement score editing functionality
    _showErrorToast('Funktion "Änderungen vornehmen" wird in einer zukünftigen Version implementiert');
  }

  // Show end set dialog for beach handball
  void _showEndSetDialog(GameState gameState) {
    final teamAScore = gameState.getCurrentSetScore(_selectedGame!.teamAId ?? '');
    final teamBScore = gameState.getCurrentSetScore(_selectedGame!.teamBId ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.timer_off,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Satz beenden?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Zeit ist abgelaufen (${gameState.gameTime.displayTime}). Soll der Satz beendet werden?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            
            // Current Score Display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  // Team A
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          _selectedGame!.teamAName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: teamAScore > teamBScore 
                                ? Colors.green.shade600 
                                : (teamAScore == teamBScore ? Colors.orange.shade600 : Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              '$teamAScore',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const Text(
                    ':',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  // Team B
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          _selectedGame!.teamBName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: teamBScore > teamAScore 
                                ? Colors.green.shade600 
                                : (teamAScore == teamBScore ? Colors.orange.shade600 : Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              '$teamBScore',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Winner/Tie indicator
            if (teamAScore > teamBScore) ...[
              Text(
                '${_selectedGame!.teamAName} führt',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ] else if (teamBScore > teamAScore) ...[
              Text(
                '${_selectedGame!.teamBName} führt',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ] else ...[
              Text(
                'Unentschieden',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _endSetByTime(gameState);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Satz beenden'),
          ),
        ],
      ),
         );
   }

  // End set by time (beach handball rules)
  Future<void> _endSetByTime(GameState gameState) async {
    try {
      await _liveScoringService.completeSetByTime(
        _selectedGame!.id,
        _selectedGame!.teamAId ?? '',
        _selectedGame!.teamBId ?? '',
      );
      
      _showSuccessToast('Satz wurde erfolgreich beendet');
      
    } catch (e) {
      print('❌ Error ending set by time: $e');
      _showErrorToast('Fehler beim Beenden des Satzes: $e');
    }
  }

  // Show reset confirmation dialog
  void _showResetConfirmationDialog(GameState gameState, bool resetFullGame) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber,
              color: Colors.red.shade600,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              resetFullGame ? 'Gesamtes Spiel zurücksetzen?' : 'Aktuellen Satz zurücksetzen?',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              resetFullGame 
                  ? 'Alle Punkte, Ereignisse, Sätze und Spielzeit werden dauerhaft gelöscht!'
                  : 'Alle Punkte und Ereignisse des aktuellen Satzes werden gelöscht!',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.red.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Diese Aktion kann nicht rückgängig gemacht werden!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (resetFullGame) {
                _resetFullGame(gameState);
    } else {
                _resetCurrentSet(gameState);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: Text(resetFullGame ? 'Gesamtes Spiel zurücksetzen' : 'Satz zurücksetzen'),
          ),
        ],
      ),
    );
  }

  // Show red card confirmation dialog
  void _showRedCardConfirmationDialog({
    required GameState gameState,
    required String teamId,
    required String teamName,
    required Player player,
    required bool isAutomatic,
    required String reason,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false, // Force user to make a choice
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.cancel,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rote Karte bestätigen',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    reason,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Player Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        player.jerseyNumber ?? '?',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          player.fullName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          teamName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Explanation
            if (isAutomatic) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nach zwei Hinausstellungen folgt automatisch eine Rote Karte.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Text(
                'Möchten Sie eine direkte Rote Karte für diesen Spieler vergeben?',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (isAutomatic) {
                // Add the suspension first, then the automatic red card
                _executePlayerEvent(gameState, teamId, teamName, player, GameEventType.suspension);
                // Add a small delay to ensure the suspension is processed first
                Future.delayed(const Duration(milliseconds: 500), () {
                  _executePlayerEvent(gameState, teamId, teamName, player, GameEventType.redCard);
                });
              } else {
                // Direct red card
                _executePlayerEvent(gameState, teamId, teamName, player, GameEventType.redCard);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Rote Karte bestätigen'),
          ),
        ],
      ),
    );
  }

  // Reset the entire game
  Future<void> _resetFullGame(GameState gameState) async {
    try {
      // Delete all game events
      await _liveScoringService.clearAllGameData(_selectedGame!.id);
      
      _showSuccessToast('Gesamtes Spiel wurde erfolgreich zurückgesetzt');
      
      // Clear local overlay state
      setState(() {
        _showSetCompletionOverlay = false;
        _completedSet = null;
        _lastProcessedSetCount = 0;
      });
      
    } catch (e) {
      print('❌ Error resetting full game: $e');
      _showErrorToast('Fehler beim Zurücksetzen des Spiels: $e');
    }
  }

  // Reset only the current set
  Future<void> _resetCurrentSet(GameState gameState) async {
    try {
      // Delete events from current set only
      await _liveScoringService.clearCurrentSetData(_selectedGame!.id, gameState.currentSet);
      
      _showSuccessToast('Aktueller Satz wurde erfolgreich zurückgesetzt');
      
    } catch (e) {
      print('❌ Error resetting current set: $e');
      _showErrorToast('Fehler beim Zurücksetzen des Satzes: $e');
    }
  }

  Widget _buildPlayerActions(GameState gameState, String teamId, String teamName, Team? team) {
    // Show loading if squads are still being loaded
    if (_squadsLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Lade Kader-Daten...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    // Get the squad for this team
    final squad = _gameSquads[teamId];
    
    // If no squad selected, show message
    if (squad == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Kein Kader ausgewählt',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Der Trainer muss noch den Kader für dieses Spiel auswählen.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                setState(() => _squadsLoading = true);
                await _loadGameSquads();
                setState(() => _squadsLoading = false);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Neu laden'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    // Get squad players
    final squadPlayers = squad.selectedPlayers;
    
    if (squadPlayers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Leerer Kader',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Für dieses Spiel wurden noch keine Spieler ausgewählt.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Sort squad players: red-carded players at bottom, others by jersey number
    final sortedPlayers = List<SquadPlayer>.from(squadPlayers);
    sortedPlayers.sort((a, b) {
      final aHasRedCard = _hasRedCard(gameState, a.playerId);
      final bHasRedCard = _hasRedCard(gameState, b.playerId);
      
      // Red-carded players go to the bottom
      if (aHasRedCard && !bHasRedCard) return 1;
      if (!aHasRedCard && bHasRedCard) return -1;
      
      // Within the same category (red card or not), sort by jersey number
      final jerseyA = int.tryParse(a.jerseyNumber ?? '999') ?? 999;
      final jerseyB = int.tryParse(b.jerseyNumber ?? '999') ?? 999;
      return jerseyA.compareTo(jerseyB);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedPlayers.length,
      itemBuilder: (context, index) {
        final squadPlayer = sortedPlayers[index];
        return _buildSquadPlayerCard(gameState, teamId, teamName, squadPlayer);
      },
    );
  }

  Widget _buildPlayerCard(GameState gameState, String teamId, String teamName, Player player) {
    final bool isSelected = _selectedPlayer?.id == player.id;
    final bool isTeamA = teamId == _selectedGame?.teamAId;
    
    // Get player type and color
    final isShooter = _playerTypes[player.id] ?? false;
    final playerColor = isShooter 
        ? (isTeamA ? _teamAShooterColor : _teamBShooterColor)
        : (isTeamA ? _teamASpielerColor : _teamBSpielerColor);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              // Deselect if already selected
              _selectedPlayer = null;
              _selectedPlayerTeamId = null;
            } else {
              // Select this player
              _selectedPlayer = player;
              _selectedPlayerTeamId = teamId;
            }
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected 
                ? playerColor.withOpacity(0.2)
                : playerColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected 
                  ? playerColor
                  : playerColor.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Jersey Number Square
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: playerColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    player.jerseyNumber ?? '?',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Player Name
              Expanded(
                child: Text(
                  player.fullName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
              
              // Player type indicator
              Icon(
                isShooter ? Icons.sports_basketball : Icons.person,
                size: 16,
                color: playerColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSquadPlayerCard(GameState gameState, String teamId, String teamName, SquadPlayer squadPlayer) {
    final bool isSelected = _selectedPlayer?.id == squadPlayer.playerId;
    final bool isTeamA = teamId == _selectedGame?.teamAId;
    final bool hasRedCard = _hasRedCard(gameState, squadPlayer.playerId);
    final int suspensionCount = _getPlayerSuspensionCount(gameState, squadPlayer.playerId);
    final bool hasSuspensions = suspensionCount > 0;
    
    // Get player type and color
    final isShooter = _playerTypes[squadPlayer.playerId] ?? false;
    final basePlayerColor = isShooter 
        ? (isTeamA ? _teamAShooterColor : _teamBShooterColor)
        : (isTeamA ? _teamASpielerColor : _teamBSpielerColor);
    
    // If player has red card, use muted colors
    final playerColor = hasRedCard ? Colors.grey.shade400 : basePlayerColor;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: hasRedCard ? null : () {
          setState(() {
            if (isSelected) {
              // Deselect if already selected
              _selectedPlayer = null;
              _selectedPlayerTeamId = null;
            } else {
              // Select this player - create a minimal Player object for compatibility
              _selectedPlayer = Player(
                id: squadPlayer.playerId,
                firstName: squadPlayer.firstName,
                lastName: squadPlayer.lastName,
                email: '${squadPlayer.playerId}@team.com', // Placeholder
                jerseyNumber: squadPlayer.jerseyNumber,
                gender: 'unknown', // We don't have this info in SquadPlayer
                createdAt: DateTime.now(),
              );
              _selectedPlayerTeamId = teamId;
            }
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: hasRedCard 
                ? Colors.red.shade50.withOpacity(0.5)
                : (isSelected 
                    ? playerColor.withOpacity(0.2)
                    : playerColor.withOpacity(0.05)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasRedCard 
                  ? Colors.red.shade300
                  : (isSelected 
                      ? playerColor
                      : playerColor.withOpacity(0.3)),
              width: hasRedCard ? 2 : (isSelected ? 2 : 1),
            ),
          ),
          child: Row(
            children: [
              // Jersey Number Square
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: hasRedCard ? Colors.grey.shade400 : playerColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    squadPlayer.jerseyNumber ?? '?',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Player Name and Position
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                                         Text.rich(
                       TextSpan(
                         children: [
                           TextSpan(
                             text: squadPlayer.firstName,
                             style: TextStyle(
                               fontSize: 15,
                               fontStyle: FontStyle.italic,
                               color: hasRedCard ? Colors.grey.shade500 : Colors.black87,
                               decoration: hasRedCard ? TextDecoration.lineThrough : null,
                             ),
                           ),
                           const TextSpan(text: ' '),
                           TextSpan(
                             text: squadPlayer.lastName,
                             style: TextStyle(
                               fontSize: 15,
                               fontWeight: FontWeight.bold,
                               color: hasRedCard ? Colors.grey.shade500 : Colors.black87,
                               decoration: hasRedCard ? TextDecoration.lineThrough : null,
                             ),
                           ),
                         ],
                       ),
                     ),
                                         if (squadPlayer.position != null) ...[
                       const SizedBox(height: 2),
                       Text(
                         squadPlayer.position!,
                         style: TextStyle(
                           fontSize: 12,
                           color: hasRedCard ? Colors.grey.shade400 : Colors.grey.shade600,
                           fontStyle: FontStyle.italic,
                           decoration: hasRedCard ? TextDecoration.lineThrough : null,
                         ),
                       ),
                     ],
                  ],
                ),
              ),
              
              // Starter indicator
              if (squadPlayer.isStarter) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Text(
                    'START',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                             ],
               
               // Suspension warning indicator
               if (hasSuspensions && !hasRedCard) ...[
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                   decoration: BoxDecoration(
                     color: Colors.orange.shade600,
                     borderRadius: BorderRadius.circular(8),
                   ),
                   child: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       const Icon(
                         Icons.warning,
                         color: Colors.white,
                         size: 12,
                       ),
                       const SizedBox(width: 4),
                       Text(
                         '$suspensionCount HINAUSSTELLUNG${suspensionCount > 1 ? 'EN' : ''}',
                         style: const TextStyle(
                           fontSize: 9,
                           fontWeight: FontWeight.bold,
                           color: Colors.white,
                         ),
                       ),
                     ],
                   ),
                 ),
                 const SizedBox(width: 8),
               ],
               
               // Red card indicator
               if (hasRedCard) ...[
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                   decoration: BoxDecoration(
                     color: Colors.red.shade600,
                     borderRadius: BorderRadius.circular(8),
                   ),
                   child: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       const Icon(
                         Icons.cancel,
                         color: Colors.white,
                         size: 12,
                       ),
                       const SizedBox(width: 4),
                       const Text(
                         'ROTE KARTE',
                         style: TextStyle(
                           fontSize: 9,
                           fontWeight: FontWeight.bold,
                           color: Colors.white,
                         ),
                       ),
                     ],
                   ),
                 ),
                 const SizedBox(width: 8),
               ],
               
               // Player type indicator (grayed out if red card)
               Icon(
                 isShooter ? Icons.sports_basketball : Icons.person,
                 size: 16,
                 color: hasRedCard ? Colors.grey.shade400 : playerColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(80, 36),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildCenterActionButton({
    required String label,
    required Color color,
    required IconData icon,
    required GameEventType eventType,
    required GameState gameState,
  }) {
    final bool isEnabled = _selectedPlayer != null && 
                       _selectedPlayerTeamId != null && 
                       !_hasRedCard(gameState, _selectedPlayer!.id);
    
    return ElevatedButton.icon(
      onPressed: isEnabled
          ? () => _addPlayerEvent(
                gameState,
                _selectedPlayerTeamId!,
                _selectedPlayerTeamId == _selectedGame!.teamAId ? _selectedGame!.teamAName : _selectedGame!.teamBName,
                _selectedPlayer!,
                eventType,
              )
          : null,
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isEnabled ? color : Colors.grey.shade300,
        foregroundColor: isEnabled ? Colors.white : Colors.grey.shade600,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minimumSize: const Size(120, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildCenterControlPanel(GameState gameState) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.touch_app, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedPlayer != null 
                      ? (_hasRedCard(gameState, _selectedPlayer!.id)
                          ? 'Spieler ${_selectedPlayer!.jerseyNumber} (${_selectedPlayer!.fullName}) - ROTE KARTE (nicht spielberechtigt)'
                          : 'Spieler ${_selectedPlayer!.jerseyNumber} (${_selectedPlayer!.fullName}) ausgewählt')
                        : 'Wählen Sie zuerst einen Spieler aus',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: _selectedPlayer != null ? FontWeight.bold : FontWeight.normal,
                    color: _selectedPlayer != null 
                        ? (_hasRedCard(gameState, _selectedPlayer!.id) 
                            ? Colors.red.shade700 
                            : Colors.green.shade700)
                        : Colors.grey.shade600,
                    ),
                  ),
                ),
                if (_selectedPlayer != null)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedPlayer = null;
                        _selectedPlayerTeamId = null;
                      });
                    },
                    icon: const Icon(Icons.clear, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      padding: const EdgeInsets.all(4),
                    ),
                    tooltip: 'Auswahl aufheben',
                  ),
              ],
            ),
          ),
          
          // Action Buttons
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildCenterActionButton(
                  label: '1 Punkt',
                  color: Colors.green,
                  icon: Icons.add_circle,
                  eventType: GameEventType.onePoint,
                  gameState: gameState,
                ),
                const SizedBox(height: 12),
                _buildCenterActionButton(
                  label: '2 Punkte',
                  color: Colors.blue,
                  icon: Icons.add_circle_outline,
                  eventType: GameEventType.twoPoints,
                  gameState: gameState,
                ),
                const SizedBox(height: 12),
                _buildCenterActionButton(
                  label: '6m Treffer',
                  color: Colors.indigo,
                  icon: Icons.sports_handball,
                  eventType: GameEventType.sixMeterHit,
                  gameState: gameState,
                ),
                const SizedBox(height: 12),
                _buildCenterActionButton(
                  label: '6m Verfehlt',
                  color: Colors.grey,
                  icon: Icons.sports_handball_outlined,
                  eventType: GameEventType.sixMeterMiss,
                  gameState: gameState,
                ),
                const SizedBox(height: 12),
                _buildCenterActionButton(
                  label: 'Hinausstellung',
                  color: Colors.orange,
                  icon: Icons.access_time,
                  eventType: GameEventType.suspension,
                  gameState: gameState,
                ),
                const SizedBox(height: 12),
                _buildCenterActionButton(
                  label: 'Rote Karte',
                  color: Colors.red,
                  icon: Icons.cancel,
                  eventType: GameEventType.redCard,
                  gameState: gameState,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventItem(GameEvent event) {
    Color eventColor;
    IconData eventIcon;
    
    switch (event.eventType) {
      case GameEventType.onePoint:
        eventColor = Colors.green;
        eventIcon = Icons.add_circle;
        break;
      case GameEventType.twoPoints:
        eventColor = Colors.blue;
        eventIcon = Icons.add_circle_outline;
        break;
      case GameEventType.sixMeterHit:
        eventColor = Colors.indigo;
        eventIcon = Icons.sports_handball;
        break;
      case GameEventType.sixMeterMiss:
        eventColor = Colors.grey;
        eventIcon = Icons.sports_handball_outlined;
        break;
      case GameEventType.suspension:
        eventColor = Colors.orange;
        eventIcon = Icons.access_time;
        break;
      case GameEventType.redCard:
        eventColor = Colors.red;
        eventIcon = Icons.cancel;
        break;
      case GameEventType.timeout:
        eventColor = Colors.purple;
        eventIcon = Icons.timer;
        break;
      case GameEventType.substitution:
        eventColor = Colors.teal;
        eventIcon = Icons.swap_horiz;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: eventColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: eventColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(eventIcon, color: eventColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${event.playerName} - ${event.displayName}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${event.gameMinute}\' - ${event.teamName}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addPlayerEvent(
    GameState gameState,
    String teamId,
    String teamName,
    Player player,
    GameEventType eventType,
  ) {
    // Check if this is a suspension that would trigger automatic red card
    if (eventType == GameEventType.suspension) {
      final currentSuspensions = _getPlayerSuspensionCount(gameState, player.id);
      if (currentSuspensions >= 1) {
        // This would be the second suspension - trigger automatic red card
        _showRedCardConfirmationDialog(
          gameState: gameState,
          teamId: teamId,
          teamName: teamName,
          player: player,
          isAutomatic: true,
          reason: 'Zweite Hinausstellung',
        );
        return;
      }
    }
    
    // Check if this is a direct red card
    if (eventType == GameEventType.redCard) {
      _showRedCardConfirmationDialog(
        gameState: gameState,
        teamId: teamId,
        teamName: teamName,
        player: player,
        isAutomatic: false,
        reason: 'Direkte Rote Karte',
      );
      return;
    }
    
    // For all other events, add directly
    _executePlayerEvent(gameState, teamId, teamName, player, eventType);
  }

  void _executePlayerEvent(
    GameState gameState,
    String teamId,
    String teamName,
    Player player,
    GameEventType eventType,
  ) {
    _liveScoringService.addGameEvent(
      gameId: gameState.gameId,
      playerId: player.id,
      playerName: player.fullName,
      teamId: teamId,
      teamName: teamName,
      eventType: eventType,
    ).then((_) {
      // Clear selection after successful action
      setState(() {
        _selectedPlayer = null;
        _selectedPlayerTeamId = null;
      });
      
      _showSuccessToast('${_getEventTypeDisplayName(eventType)} für ${player.fullName} hinzugefügt');
    }).catchError((error) {
      _showErrorToast('Fehler beim Hinzufügen des Ereignisses: $error');
    });
  }

  void _undoLastAction(String teamId) {
    _liveScoringService.removeLastEvent(_selectedGame!.id, teamId).then((_) {
      _showSuccessToast('Letzte Aktion rückgängig gemacht');
    }).catchError((error) {
      _showErrorToast('Fehler beim Rückgängigmachen: $error');
    });
  }

  String _getEventTypeDisplayName(GameEventType eventType) {
    switch (eventType) {
      case GameEventType.onePoint:
        return '1 Punkt';
      case GameEventType.twoPoints:
        return '2 Punkte';
      case GameEventType.suspension:
        return 'Hinausstellung';
      case GameEventType.redCard:
        return 'Rote Karte';
      case GameEventType.timeout:
        return 'Auszeit';
      case GameEventType.substitution:
        return 'Wechsel';
      case GameEventType.sixMeterHit:
        return '6m Treffer';
      case GameEventType.sixMeterMiss:
        return '6m Verfehlt';
    }
  }

  // Build shooter position widget
  Widget _buildShooterPosition() {
    return Expanded(
      child: Column(
        children: [
          const Text(
            'Shooter',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: DragTarget<SquadPlayer>(
              onAccept: (player) {
                setState(() {
                  _assignedShooter = player;
                });
                _showSuccessToast('${player.firstName} ${player.lastName} als Shooter zugewiesen');
              },
              builder: (context, accepted, rejected) => Container(
                decoration: BoxDecoration(
                  color: _assignedShooter != null ? Colors.orange.shade200 : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _assignedShooter != null ? Colors.orange.shade600 : Colors.orange.shade300,
                    width: _assignedShooter != null ? 2 : 1,
                  ),
                ),
                child: _assignedShooter != null
                  ? Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _assignedShooter!.jerseyNumber ?? '?',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${_assignedShooter!.firstName?.substring(0, 1)}. ${_assignedShooter!.lastName}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _assignedShooter = null;
                              });
                            },
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.red.shade600,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : const Center(
                      child: Text(
                        'SHOOTER\nPlayer hierher ziehen',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build werfer position widget
  Widget _buildWerferPosition() {
    return Expanded(
      child: Column(
        children: [
          const Text(
            'Werfer',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: DragTarget<SquadPlayer>(
              onAccept: (player) {
                // Check if player was already used as Werfer
                if (_usedPlayerIds.contains(player.playerId)) {
                  _showErrorToast('${player.firstName} ${player.lastName} war bereits Werfer - wähle einen anderen Spieler');
                  return;
                }
                setState(() {
                  _assignedPlayer = player;
                });
                _showSuccessToast('${player.firstName} ${player.lastName} als Werfer zugewiesen');
              },
              builder: (context, accepted, rejected) => Container(
                decoration: BoxDecoration(
                  color: _assignedPlayer != null ? Colors.blue.shade200 : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _assignedPlayer != null ? Colors.blue.shade600 : Colors.blue.shade300,
                    width: _assignedPlayer != null ? 2 : 1,
                  ),
                ),
                child: _assignedPlayer != null
                  ? Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _assignedPlayer!.jerseyNumber ?? '?',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${_assignedPlayer!.firstName?.substring(0, 1)}. ${_assignedPlayer!.lastName}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _assignedPlayer = null;
                              });
                            },
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.red.shade600,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : const Center(
                      child: Text(
                        'WERFER\nPlayer hierher ziehen',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 