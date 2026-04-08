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

import '../models/managed_account.dart';
import '../models/game_squad.dart';
import '../models/tablet_status.dart';
import '../services/game_squad_service.dart';

import '../services/live_scoring_service.dart';
import '../models/game_event.dart';
import '../models/player.dart';
import '../services/player_service.dart';
import '../models/referee.dart';
import '../services/referee_service.dart';
import '../services/custom_notification_service.dart';
import '../services/team_manager_service.dart';
import '../utils/responsive_helper.dart';
import 'dart:math' as math;

class ScoringTabletScreen extends StatefulWidget {
  final app_user.User user;
  final String? tournamentId;
  final String? courtId;
  final bool showBackButton;
  
  const ScoringTabletScreen({
    super.key,
    required this.user,
    this.tournamentId,
    this.courtId,
    this.showBackButton = false,
  });

  @override
  State<ScoringTabletScreen> createState() => _ScoringTabletScreenState();
}

class _ScoringTabletScreenState extends State<ScoringTabletScreen> with TickerProviderStateMixin {
  final GameService _gameService = GameService();
  final TournamentService _tournamentService = TournamentService();
  final ManagedAccountService _managedAccountService = ManagedAccountService();
  final AuthService _authService = AuthService();
  final TeamService _teamService = TeamService();

  final GameSquadService _gameSquadService = GameSquadService();
  final RefereeService _refereeService = RefereeService();
  final LiveScoringService _liveScoringService = LiveScoringService();

  /// Whether we're running on a desktop/PC (compact layout) vs iPad/tablet (touch layout)
  bool get _isDesktopLayout => ResponsiveHelper.isScoringDesktop(context);

  /// Scaling factors for compact desktop layout
  double get _paddingScale => _isDesktopLayout ? 0.65 : 1.0;
  double get _fontScale => _isDesktopLayout ? 0.85 : 1.0;
  double get _iconScale => _isDesktopLayout ? 0.85 : 1.0;
  double get _buttonScale => _isDesktopLayout ? 0.8 : 1.0;
  
  // Navigation state
  String _selectedTab = 'main'; // main, squad, referees, scoring, statistics, completion
  bool _isInScoringMode = false; // Track if we're in scoring mode or games list mode
  bool _isSidebarExpanded = false; // Track sidebar expansion state
  
  // Live scoring state
  Player? _selectedPlayer;
  String? _selectedPlayerTeamId;
  GameState? _currentGameState; // Cached for keyboard handler
  
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
  
  // Half completion overlay
  bool _showSetCompletionOverlay = false;
  bool _halfCompleted = false;
  int _lastProcessedHalfCount = 0;
  
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

  // Game officials state (referees, timekeeper, scorekeeper, delegates)
  final TextEditingController _referee1Controller = TextEditingController();
  final TextEditingController _referee2Controller = TextEditingController();
  final TextEditingController _timekeeperController = TextEditingController();
  final TextEditingController _scorekeeperController = TextEditingController();
  final TextEditingController _delegate1Controller = TextEditingController();
  final TextEditingController _delegate2Controller = TextEditingController();

  // Cached referee list for autocomplete
  List<Referee> _allReferees = [];

  // All system users for the team manager autocomplete
  List<app_user.User> _allUsers = [];

  // Per-game team managers (stored in gameStates)
  String? _teamAManagerId;
  String? _teamAManagerName;
  String? _teamBManagerId;
  String? _teamBManagerName;
  bool _teamAManagerSigned = false;
  bool _teamBManagerSigned = false;

  // Track auto-send of sign-off notifications (prevent re-send on every build)
  bool _signRequestSentA = false;
  bool _signRequestSentB = false;

  // Keyboard shortcuts state
  final FocusNode _scoringFocusNode = FocusNode();
  bool _keyboardFocusTeamA = true; // Which team keyboard actions target
  bool _showShortcutsLegend = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    // Register global keyboard handler so shortcuts work regardless of focus
    HardwareKeyboard.instance.addHandler(_globalKeyHandler);
    // If tournamentId and courtId are provided directly, load them directly
    if (widget.tournamentId != null && widget.courtId != null) {
      _loadDirectTournamentData();
    } else {
      _loadManagedAccountData();
    }
    _startAutoRefresh();
  }

  /// Global hardware keyboard handler — fires even when text fields have focus.
  bool _globalKeyHandler(KeyEvent event) {
    if (!mounted || !_isInScoringMode) return false;
    final result = _handleKeyEvent(_scoringFocusNode, event);
    return result == KeyEventResult.handled;
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
      print('ðŸ”„ ScoringTablet: Starting comprehensive Firebase refresh...');
      
      // Force refresh games data from Firebase
      if (_assignedTournament != null) {
        print('ðŸ”„ Force refreshing games for tournament: ${_assignedTournament!.name}');
        await _gameService.forceRefreshGames(_assignedTournament!.id);
      }
      
      // Force refresh team data (clear cache)
      print('ðŸ”„ Clearing team cache...');
      _teamService.clearCache();
      
      // Reload games with fresh data
      await _loadGamesWithAnimation();
      
      // Refresh team data for selected game
      if (_selectedGame != null) {
        print('ðŸ”„ Refreshing team data for selected game...');
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
          print('ðŸ”„ Refreshing squad data...');
          setState(() => _squadsLoading = true);
          await _loadGameSquads();
          if (mounted) {
            setState(() => _squadsLoading = false);
          }
        }
      }
      
      setState(() => _lastRefresh = DateTime.now());
      print('âœ… ScoringTablet: Comprehensive refresh complete');
      
      // Show success feedback
      _showSuccessToast('Daten erfolgreich von Firebase aktualisiert');
      
    } catch (e) {
      print('âŒ Error during comprehensive refresh: $e');
      _showErrorToast('Fehler beim Aktualisieren der Daten: $e');
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  /// Load tournament and court directly from provided IDs (used when accessed via scoring picker)
  Future<void> _loadDirectTournamentData() async {
    try {
      print('📱 ScoringTablet: Loading directly with tournamentId: ${widget.tournamentId}, courtId: ${widget.courtId}');
      
      _assignedTournament = await _tournamentService.getTournamentById(widget.tournamentId!);
      
      if (_assignedTournament != null) {
        print('📱 Tournament loaded: ${_assignedTournament!.name}');
        
        try {
          _assignedCourt = _assignedTournament!.courts.firstWhere(
            (court) => court.id == widget.courtId,
          );
          print('📱 Court found: ${_assignedCourt!.name}');
          
          await _loadGames();
        } catch (e) {
          print('❌ Court not found: $e');
          _showErrorToast('Feld "${widget.courtId}" nicht im Turnier gefunden');
        }
      } else {
        _showErrorToast('Turnier nicht gefunden');
      }
    } catch (e) {
      print('❌ Error loading direct tournament data: $e');
      _showErrorToast('Fehler beim Laden der Turnierdaten: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadManagedAccountData() async {
    try {
      print('ðŸ” ScoringTablet: Loading managed account data for user: ${widget.user.email}');
      
      final allAccounts = await _managedAccountService.getAllManagedAccounts().first;
      print('ðŸ” Found ${allAccounts.length} managed accounts total');
      
      _managedAccount = allAccounts.firstWhere(
        (account) => account.email == widget.user.email,
        orElse: () => throw Exception('Managed account not found for email: ${widget.user.email}'),
      );

      print('ðŸ” Managed account found:');
      print('   - Email: ${_managedAccount!.email}');
      print('   - Tournament ID: ${_managedAccount!.tournamentId}');
      print('   - Court ID: ${_managedAccount!.courtId}');
      print('   - Type: ${_managedAccount!.type}');

      if (_managedAccount != null && _managedAccount!.tournamentId != null) {
        _assignedTournament = await _tournamentService.getTournamentById(_managedAccount!.tournamentId!);
        print('ðŸ” Tournament loaded: ${_assignedTournament?.name}');
        print('ðŸ” Tournament has ${_assignedTournament?.courts.length} courts');
        
        if (_assignedTournament != null && _managedAccount!.courtId != null) {
          try {
            // Debug: Show all available courts
            print('ðŸ” Available courts in tournament:');
            for (final court in _assignedTournament!.courts) {
              print('   - Court ID: "${court.id}", Name: "${court.name}"');
            }
            
            _assignedCourt = _assignedTournament!.courts.firstWhere(
              (court) => court.id == _managedAccount!.courtId,
            );
            
            print('ðŸ” Assigned court: "${_assignedCourt!.name}" (ID: "${_assignedCourt!.id}")');
            
            await _loadGames();
            
            // Update tablet status to indicate it's connected (disabled to prevent null errors)
            // _updateTabletStatus();
          } catch (e) {
            print('âŒ Court not found: $e');
            _showErrorToast('Court "${_managedAccount!.courtId}" nicht im Turnier gefunden');
          }
        }
      }
    } catch (e) {
      print('âŒ Error loading managed account data: $e');
      _showErrorToast('Fehler beim Laden der Account-Daten: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadGames() async {
    if (_assignedTournament == null || _assignedCourt == null) return;
    
    try {
      final allGames = await _gameService.getGamesForTournament(_assignedTournament!.id).first;
      
      // Debug: Show all game court IDs and assigned court ID
      print('ðŸ ScoringTablet: Debug court ID matching');
      print('ðŸ Assigned court ID: "${_assignedCourt!.id}"');
      print('ðŸ Found ${allGames.length} total games for tournament');
      
      for (final game in allGames) {
        print('ðŸ Game: ${game.teamAName} vs ${game.teamBName}');
        print('   - Game court ID: "${game.courtId}"');
        print('   - Matches assigned court: ${game.courtId == _assignedCourt!.id}');
        print('   - Game status: ${game.status}');
        print('   - Scheduled time: ${game.scheduledTime}');
      }
      
      // Try multiple matching strategies for court assignment
      var courtGames = allGames.where((game) => game.courtId == _assignedCourt!.id).toList();
      
      // If no exact matches, try matching by court name
      if (courtGames.isEmpty) {
        print('ðŸ No exact court ID matches, trying to match by court name...');
        
        // Get all courts from the tournament
        final allTournamentCourts = _assignedTournament!.courts;
        
        for (final game in allGames) {
          if (game.courtId != null) {
            // Try to find a court with this game's courtId
            final gamesCourt = allTournamentCourts.firstWhere(
              (court) => court.id == game.courtId,
              orElse: () => Court(
                id: '',
                name: '',
              ),
            );
            
            // If we found a matching court and it has the same name as our assigned court
            if (gamesCourt.id.isNotEmpty && gamesCourt.name == _assignedCourt!.name) {
              courtGames.add(game);
              print('ðŸ Matched game "${game.teamAName} vs ${game.teamBName}" by court name "${gamesCourt.name}"');
            }
          }
        }
      }
      
      // If still no matches, show ALL games for debugging (remove this in production)
      if (courtGames.isEmpty) {
        print('âš ï¸ Still no court matches found. For debugging, showing all games:');
        courtGames = allGames;
        print('âš ï¸ DEBUG MODE: Showing all ${courtGames.length} games');
      }
      
      print('ðŸ Final result: ${courtGames.length} games for court "${_assignedCourt!.name}"');
      
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
      print('âŒ Error loading games: $e');
    }
  }

  Future<void> _loadGamesWithAnimation() async {
    if (_assignedTournament == null || _assignedCourt == null) return;
    
    try {
      final allGames = await _gameService.getGamesForTournament(_assignedTournament!.id).first;
      
      // Debug: Show court ID matching (same as _loadGames)
      print('ðŸ”„ ScoringTablet: Refreshing games with animation');
      print('ðŸ”„ Assigned court ID: "${_assignedCourt!.id}"');
      print('ðŸ”„ Found ${allGames.length} total games');
      
      // Try multiple matching strategies for court assignment (same as _loadGames)
      var courtGames = allGames.where((game) => game.courtId == _assignedCourt!.id).toList();
      
      // If no exact matches, try matching by court name
      if (courtGames.isEmpty) {
        final allTournamentCourts = _assignedTournament!.courts;
        
        for (final game in allGames) {
          if (game.courtId != null) {
            final gamesCourt = allTournamentCourts.firstWhere(
              (court) => court.id == game.courtId,
              orElse: () => Court(
                id: '',
                name: '',
              ),
            );
            
            if (gamesCourt.id.isNotEmpty && gamesCourt.name == _assignedCourt!.name) {
              courtGames.add(game);
            }
          }
        }
      }
      
      // If still no matches, show ALL games for debugging
      if (courtGames.isEmpty) {
        courtGames = allGames;
      }
      
      print('ðŸ”„ Found ${courtGames.length} games for assigned court');
      
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
      print('âŒ Error loading games with animation: $e');
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
    // Mark tablet as disconnected when app is closed (disabled to prevent null errors)
    // if (_managedAccount != null && 
    //     _assignedCourt != null && 
    //     _assignedCourt!.id.isNotEmpty) {
    //   _managedAccountService.markTabletDisconnected(_assignedCourt!.id);
    // }
    
    HardwareKeyboard.instance.removeHandler(_globalKeyHandler);
    _refreshTimer?.cancel();
    _fadeController.dispose();
    _liveScoringService.dispose();
    _scoringFocusNode.dispose();
    _referee1Controller.dispose();
    _referee2Controller.dispose();
    _timekeeperController.dispose();
    _scorekeeperController.dispose();
    _delegate1Controller.dispose();
    _delegate2Controller.dispose();
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
      return Focus(
        focusNode: _scoringFocusNode,
        autofocus: true,
        // onKeyEvent removed — handled globally via HardwareKeyboard.instance
        child: Stack(
          children: [
            _buildScoringInterface(),
            if (_showShortcutsLegend) _buildShortcutsLegend(),
            // Keyboard focus indicator
            Positioned(
              right: 16,
              top: 16,
              child: GestureDetector(
                onTap: () => setState(() => _showShortcutsLegend = !_showShortcutsLegend),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.keyboard,
                        size: 14,
                        color: _keyboardFocusTeamA ? Colors.blue.shade300 : Colors.red.shade300,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _keyboardFocusTeamA ? 'Team A' : 'Team B',
                        style: TextStyle(
                          color: _keyboardFocusTeamA ? Colors.blue.shade300 : Colors.red.shade300,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text('(?)', style: TextStyle(color: Colors.white54, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
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

  /// Handle keyboard events for the scoring interface.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    
    final key = event.logicalKey;
    
    // Toggle shortcuts legend with '?'
    if (key == LogicalKeyboardKey.slash && HardwareKeyboard.instance.isShiftPressed) {
      setState(() => _showShortcutsLegend = !_showShortcutsLegend);
      return KeyEventResult.handled;
    }

    // Escape — deselect player or close legend
    if (key == LogicalKeyboardKey.escape) {
      setState(() {
        if (_showShortcutsLegend) {
          _showShortcutsLegend = false;
        } else {
          _selectedPlayer = null;
          _selectedPlayerTeamId = null;
        }
      });
      return KeyEventResult.handled;
    }
    
    // Tab — switch keyboard focus team
    if (key == LogicalKeyboardKey.tab) {
      setState(() => _keyboardFocusTeamA = !_keyboardFocusTeamA);
      return KeyEventResult.handled;
    }
    
    // F1–F6 — switch tabs
    final tabKeys = {
      LogicalKeyboardKey.f1: 'main',
      LogicalKeyboardKey.f2: 'squad',
      LogicalKeyboardKey.f3: 'referees',
      LogicalKeyboardKey.f4: 'scoring',
      LogicalKeyboardKey.f5: 'statistics',
      LogicalKeyboardKey.f6: 'completion',
    };
    if (tabKeys.containsKey(key)) {
      setState(() => _selectedTab = tabKeys[key]!);
      return KeyEventResult.handled;
    }

    // Spacebar — toggle timer (works on scoring tab)
    if (key == LogicalKeyboardKey.space && _selectedTab == 'scoring' && _selectedGame != null && _currentGameState != null) {
      if (_currentGameState!.isRunning) {
        _liveScoringService.pauseGameTimer(_selectedGame!.id);
      } else {
        _liveScoringService.startGameTimer(_selectedGame!.id);
      }
      return KeyEventResult.handled;
    }

    // Only process scoring shortcuts when on the scoring tab and a game is active
    if (_selectedTab != 'scoring' || _selectedGame == null || _currentGameState == null) {
      return KeyEventResult.ignored;
    }

    final targetTeamId = _keyboardFocusTeamA
        ? (_selectedGame!.teamAId ?? '')
        : (_selectedGame!.teamBId ?? '');

    // Number keys 0–9 — select player by jersey number
    final digitKeys = {
      LogicalKeyboardKey.digit1: '1', LogicalKeyboardKey.digit2: '2',
      LogicalKeyboardKey.digit3: '3', LogicalKeyboardKey.digit4: '4',
      LogicalKeyboardKey.digit5: '5', LogicalKeyboardKey.digit6: '6',
      LogicalKeyboardKey.digit7: '7', LogicalKeyboardKey.digit8: '8',
      LogicalKeyboardKey.digit9: '9', LogicalKeyboardKey.digit0: '0',
      LogicalKeyboardKey.numpad1: '1', LogicalKeyboardKey.numpad2: '2',
      LogicalKeyboardKey.numpad3: '3', LogicalKeyboardKey.numpad4: '4',
      LogicalKeyboardKey.numpad5: '5', LogicalKeyboardKey.numpad6: '6',
      LogicalKeyboardKey.numpad7: '7', LogicalKeyboardKey.numpad8: '8',
      LogicalKeyboardKey.numpad9: '9', LogicalKeyboardKey.numpad0: '0',
    };
    if (digitKeys.containsKey(key)) {
      final digit = digitKeys[key]!;
      final squad = _gameSquads[targetTeamId];
      if (squad != null) {
        final match = squad.selectedPlayers.where(
          (p) => p.jerseyNumber == digit,
        ).firstOrNull;
        if (match != null) {
          setState(() {
            _selectedPlayer = Player(
              id: match.playerId,
              firstName: match.firstName,
              lastName: match.lastName,
              email: '${match.playerId}@team.com',
              jerseyNumber: match.jerseyNumber,
              gender: 'unknown',
              createdAt: DateTime.now(),
            );
            _selectedPlayerTeamId = targetTeamId;
          });
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    }

    // G — goal
    if (key == LogicalKeyboardKey.keyG && _selectedPlayer != null) {
      _addPlayerEvent(
        _currentGameState!,
        _selectedPlayerTeamId!,
        _keyboardFocusTeamA ? _selectedGame!.teamAName : _selectedGame!.teamBName,
        _selectedPlayer!,
        GameEventType.goal,
      );
      return KeyEventResult.handled;
    }
    
    // S — 2-minute suspension
    if (key == LogicalKeyboardKey.keyS && _selectedPlayer != null) {
      _addPlayerEvent(
        _currentGameState!,
        _selectedPlayerTeamId!,
        _keyboardFocusTeamA ? _selectedGame!.teamAName : _selectedGame!.teamBName,
        _selectedPlayer!,
        GameEventType.twoMinuteSuspension,
      );
      return KeyEventResult.handled;
    }
    
    // Y — yellow card
    if (key == LogicalKeyboardKey.keyY && _selectedPlayer != null) {
      _addPlayerEvent(
        _currentGameState!,
        _selectedPlayerTeamId!,
        _keyboardFocusTeamA ? _selectedGame!.teamAName : _selectedGame!.teamBName,
        _selectedPlayer!,
        GameEventType.yellowCard,
      );
      return KeyEventResult.handled;
    }
    
    // R — red card
    if (key == LogicalKeyboardKey.keyR && _selectedPlayer != null) {
      _addPlayerEvent(
        _currentGameState!,
        _selectedPlayerTeamId!,
        _keyboardFocusTeamA ? _selectedGame!.teamAName : _selectedGame!.teamBName,
        _selectedPlayer!,
        GameEventType.redCard,
      );
      return KeyEventResult.handled;
    }

    // Z / Ctrl+Z — undo last action
    if (key == LogicalKeyboardKey.keyZ) {
      _undoLastAction(targetTeamId);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Widget _buildShortcutsLegend() {
    return Positioned(
      right: 16,
      bottom: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.keyboard, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Text('Tastenkürzel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _showShortcutsLegend = false),
                    child: const Icon(Icons.close, color: Colors.white54, size: 18),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 16),
              _shortcutRow('Tab', 'Team wechseln'),
              _shortcutRow('0-9', 'Spieler auswählen (Trikot)'),
              _shortcutRow('G', 'Tor'),
              _shortcutRow('S', '2-Min. Strafe'),
              _shortcutRow('Y', 'Gelbe Karte'),
              _shortcutRow('R', 'Rote Karte'),
              _shortcutRow('Z', 'Rückgängig'),
              _shortcutRow('Space', 'Timer Start/Stopp'),
              _shortcutRow('Esc', 'Auswahl aufheben'),
              _shortcutRow('F1-F6', 'Tab wechseln'),
              _shortcutRow('?', 'Hilfe ein/aus'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shortcutRow(String key, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(key, style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
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
      padding: EdgeInsets.all(20 * _paddingScale),
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
            // Back button (when accessed via scoring picker, not as managed tablet)
            if (widget.showBackButton) ...[
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, size: 24),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                  foregroundColor: Colors.black87,
                ),
                tooltip: 'Zurück',
              ),
              const SizedBox(width: 12),
            ],
            // Tournament and Court Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _assignedTournament?.name ?? 'Kein Turnier zugewiesen',
                    style: TextStyle(
                      fontSize: 24 * _fontScale,
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
      padding: EdgeInsets.all(20 * _paddingScale),
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
              Text(
                'Aktuelle Spiele',
                style: TextStyle(
                  fontSize: 20 * _fontScale,
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
      padding: EdgeInsets.all(20 * _paddingScale),
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
              Text(
                'Kommende Spiele',
                style: TextStyle(
                  fontSize: 20 * _fontScale,
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
      margin: EdgeInsets.only(bottom: 12 * _paddingScale),
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
          padding: EdgeInsets.all(16 * _paddingScale),
          child: Column(
            children: [
              // Game Header
              Row(
                children: [
                  // Time
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10 * _paddingScale, vertical: 6 * _paddingScale),
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
                    padding: EdgeInsets.symmetric(vertical: 12 * _paddingScale),
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
      // Reset sign-off notification tracking for new game
      _signRequestSentA = false;
      _signRequestSentB = false;
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
    
    // Set half duration from tournament settings
    final halfDuration = _assignedTournament?.halfDurationMinutes ?? 15;
    await _liveScoringService.setHalfDuration(game.id, halfDuration);
    
    // Load officials data
    _loadOfficials();

    // Load all referees for autocomplete
    _loadAllReferees();
    
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
        print('âœ… Loaded squad for team ${squad.teamId}: ${squad.playerCount} players');
      }
      
      print('âœ… Total squads loaded: ${_gameSquads.length}');
    } catch (e) {
      print('âŒ Error loading game squads: $e');
    }
  }

  Widget _buildNavigation() {
    final double sidebarWidth = _isSidebarExpanded ? (_isDesktopLayout ? 220 : 280) : (_isDesktopLayout ? 60 : 80);
    
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
                      label: const Text('ZurÃ¼ck zu Spielen', style: TextStyle(color: Colors.white70, fontSize: 14)),
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
                      tooltip: 'ZurÃ¼ck zu Spielen',
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
                  label: const Text('ZurÃ¼ck zu Spielen', style: TextStyle(color: Colors.white70)),
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
            tooltip: 'ZurÃ¼ck zu Spielen',
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
      _halfCompleted = false;
      _lastProcessedHalfCount = 0;
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
        padding: EdgeInsets.all(24 * _paddingScale),
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
                  
                  // Liga and Pool Information
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Liga Info
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
                              _extractCategoryFromGame(_selectedGame!),
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
            'Kein Spiel ausgewÃ¤hlt',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'WÃ¤hlen Sie ein Spiel aus der Liste aus.',
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
            label: const Text('ZurÃ¼ck zu Spielen'),
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
                      teamId: _selectedGame!.teamAId ?? '',
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
                      teamId: _selectedGame!.teamBId ?? '',
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
    if (_selectedGame == null) return _buildNoGameView();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGameHeader(),
          const SizedBox(height: 24),

          // Pre-assigned referees from database
          if (_selectedGame!.referee1Id != null || _selectedGame!.referee2Id != null)
            _buildAssignedRefereesCard(),

          if (_selectedGame!.referee1Id != null || _selectedGame!.referee2Id != null)
            const SizedBox(height: 20),

          // Editable match officials
          _buildOfficialsSection(
            'Schiedsrichter',
            Icons.sports,
            Colors.purple,
            [
              _buildOfficialField('Schiedsrichter 1', _referee1Controller),
              const SizedBox(height: 12),
              _buildOfficialField('Schiedsrichter 2', _referee2Controller),
            ],
          ),
          const SizedBox(height: 20),
          _buildOfficialsSection(
            'Zeitnehmer / Sekretär',
            Icons.timer,
            Colors.teal,
            [
              _buildOfficialField('Zeitnehmer', _timekeeperController),
              const SizedBox(height: 12),
              _buildOfficialField('Sekretär', _scorekeeperController),
            ],
          ),
          const SizedBox(height: 20),
          _buildOfficialsSection(
            'Delegierte',
            Icons.badge,
            Colors.indigo,
            [
              _buildOfficialField('Delegierter 1', _delegate1Controller),
              const SizedBox(height: 12),
              _buildOfficialField('Delegierter 2', _delegate2Controller),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: FilledButton.icon(
              onPressed: _saveOfficials,
              icon: const Icon(Icons.save),
              label: const Text('Spieloffizielle speichern'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.purple,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedRefereesCard() {
    return FutureBuilder<List<String>>(
      future: _loadAssignedRefereeNames(),
      builder: (context, snapshot) {
        final names = snapshot.data ?? [];
        if (names.isEmpty) return const SizedBox.shrink();
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.purple.shade800,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Zugewiesene Schiedsrichter (Datenbank)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: names.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(Icons.sports, size: 16, color: Colors.purple.shade400),
                        const SizedBox(width: 8),
                        Text('SR ${e.key + 1}: ', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                        Text(e.value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<String>> _loadAssignedRefereeNames() async {
    final names = <String>[];
    try {
      if (_selectedGame!.referee1Id != null) {
        final ref = await _refereeService.getRefereeById(_selectedGame!.referee1Id!);
        names.add(ref?.fullName ?? _selectedGame!.referee1Id!);
      }
      if (_selectedGame!.referee2Id != null) {
        final ref = await _refereeService.getRefereeById(_selectedGame!.referee2Id!);
        names.add(ref?.fullName ?? _selectedGame!.referee2Id!);
      }
    } catch (_) {}
    return names;
  }

  Widget _buildOfficialsSection(String title, IconData icon, Color color, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialField(String label, TextEditingController controller) {
    return Autocomplete<Referee>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return _allReferees;
        }
        final query = textEditingValue.text.toLowerCase();
        return _allReferees.where((r) =>
          r.fullName.toLowerCase().contains(query) ||
          r.email.toLowerCase().contains(query)
        );
      },
      displayStringForOption: (Referee r) => r.fullName,
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        // Sync initial value from the external controller
        if (textController.text.isEmpty && controller.text.isNotEmpty) {
          textController.text = controller.text;
        }
        // Keep controllers in sync
        textController.addListener(() {
          if (controller.text != textController.text) {
            controller.text = textController.text;
          }
        });
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            prefixIcon: const Icon(Icons.person_outline, size: 20),
            suffixIcon: textController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      textController.clear();
                      controller.clear();
                    },
                  )
                : const Icon(Icons.arrow_drop_down, size: 20),
          ),
          style: const TextStyle(fontSize: 14),
          onFieldSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250, maxWidth: 400),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final referee = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.person, size: 18),
                    title: Text(referee.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      [if (referee.licenseType.isNotEmpty) referee.licenseType, if (referee.email.isNotEmpty) referee.email].join(' · '),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    onTap: () => onSelected(referee),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (Referee referee) {
        controller.text = referee.fullName;
      },
    );
  }

  Future<void> _loadAllReferees() async {
    try {
      final results = await Future.wait([
        _refereeService.getAllReferees(),
        _authService.getAllUsers(),
      ]);
      if (mounted) {
        setState(() {
          _allReferees = results[0] as List<Referee>;
          _allUsers = (results[1] as List<app_user.User>)
              ..sort((a, b) => a.fullName.compareTo(b.fullName));
        });
      }
    } catch (_) {}
  }

  void _showAddOfficialDialog(String teamId, String teamName, bool isTeamA) {
    final nameCtrl = TextEditingController();
    String selectedRole = 'Trainer';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Offiziellen hinzufügen – $teamName', style: const TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: InputDecoration(
                  labelText: 'Rolle',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: TeamOfficial.roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) => setDialogState(() => selectedRole = v ?? 'Trainer'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                final squad = _gameSquads[teamId];
                final currentOfficials = List<TeamOfficial>.from(squad?.officials ?? []);
                if (currentOfficials.length >= 5) {
                  _showErrorToast('Maximal 5 Offizielle pro Team');
                  return;
                }
                currentOfficials.add(TeamOfficial(name: nameCtrl.text.trim(), role: selectedRole));
                
                if (squad != null) {
                  final updated = squad.copyWith(officials: currentOfficials, updatedAt: DateTime.now());
                  await _gameSquadService.updateSquadOfficials(
                    _selectedGame!.id, teamId, currentOfficials);
                  setState(() => _gameSquads[teamId] = updated);
                }
                _showSuccessToast('Offizieller hinzugefügt');
              },
              child: const Text('Hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveOfficials() async {
    if (_selectedGame == null) return;
    try {
      await FirebaseFirestore.instance.collection('gameStates').doc(_selectedGame!.id).set({
        'referee1': _referee1Controller.text.trim(),
        'referee2': _referee2Controller.text.trim(),
        'timekeeper': _timekeeperController.text.trim(),
        'scorekeeper': _scorekeeperController.text.trim(),
        'delegate1': _delegate1Controller.text.trim(),
        'delegate2': _delegate2Controller.text.trim(),
        // team managers
        'teamAManagerId': _teamAManagerId ?? '',
        'teamAManagerName': _teamAManagerName ?? '',
        'teamBManagerId': _teamBManagerId ?? '',
        'teamBManagerName': _teamBManagerName ?? '',
        'teamAManagerSigned': _teamAManagerSigned,
        'teamBManagerSigned': _teamBManagerSigned,
      }, SetOptions(merge: true));
      _showSuccessToast('Offizielle gespeichert');
    } catch (e) {
      _showErrorToast('Fehler: $e');
    }
  }

  void _loadOfficials() async {
    if (_selectedGame == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('gameStates')
          .doc(_selectedGame!.id)
          .get();

      String? teamAMgrId, teamAMgrName, teamBMgrId, teamBMgrName;
      bool teamASigned = false, teamBSigned = false;

      if (doc.exists) {
        final data = doc.data()!;
        _referee1Controller.text = data['referee1'] ?? '';
        _referee2Controller.text = data['referee2'] ?? '';
        _timekeeperController.text = data['timekeeper'] ?? '';
        _scorekeeperController.text = data['scorekeeper'] ?? '';
        _delegate1Controller.text = data['delegate1'] ?? '';
        _delegate2Controller.text = data['delegate2'] ?? '';
        teamAMgrId   = (data['teamAManagerId']   as String?)?.isNotEmpty == true ? data['teamAManagerId']   : null;
        teamAMgrName = (data['teamAManagerName'] as String?)?.isNotEmpty == true ? data['teamAManagerName'] : null;
        teamBMgrId   = (data['teamBManagerId']   as String?)?.isNotEmpty == true ? data['teamBManagerId']   : null;
        teamBMgrName = (data['teamBManagerName'] as String?)?.isNotEmpty == true ? data['teamBManagerName'] : null;
        teamASigned  = data['teamAManagerSigned'] ?? false;
        teamBSigned  = data['teamBManagerSigned'] ?? false;
      }

      // Auto-populate from team_managers if not already set
      final service = TeamManagerService();
      if (teamAMgrId == null && _selectedGame!.teamAId != null) {
        final managers = await service.getManagersForTeam(_selectedGame!.teamAId!);
        final active = managers.where((m) => m.isActive && m.userId != null).toList();
        if (active.isNotEmpty) {
          teamAMgrId   = active.first.userId;
          teamAMgrName = active.first.name;
        }
      }
      if (teamBMgrId == null && _selectedGame!.teamBId != null) {
        final managers = await service.getManagersForTeam(_selectedGame!.teamBId!);
        final active = managers.where((m) => m.isActive && m.userId != null).toList();
        if (active.isNotEmpty) {
          teamBMgrId   = active.first.userId;
          teamBMgrName = active.first.name;
        }
      }

      if (mounted) {
        setState(() {
          _teamAManagerId     = teamAMgrId;
          _teamAManagerName   = teamAMgrName;
          _teamBManagerId     = teamBMgrId;
          _teamBManagerName   = teamBMgrName;
          _teamAManagerSigned = teamASigned;
          _teamBManagerSigned = teamBSigned;
        });
        // Persist auto-populated managers so they are saved for next load
        if (teamAMgrId != null || teamBMgrId != null) {
          _saveOfficials();
        }
      }
    } catch (e) {
      print('❌ Error loading officials: $e');
    }
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

        // Cache for keyboard handler
        _currentGameState = gameState;

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
            _isDesktopLayout 
              ? _buildDesktopLiveScoring(gameState)
              : Padding(
          padding: EdgeInsets.all(16 * _paddingScale),
          child: Column(
            children: [
              // Game Header
              _buildLiveScoringHeader(gameState),
              SizedBox(height: 16 * _paddingScale),
              
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
        if (_showSetCompletionOverlay && _halfCompleted)
          _buildSetCompletionOverlay(gameState),
        
        // Shootout Setup Dialog
        if (_showShootoutSetupDialog && _halfCompleted)
          _buildShootoutSetupDialog(gameState),
      ],
        );
      },
    );
  }

  Widget _buildLiveStatistics() {
    return _buildPlaceholderScreen(
      'Live-Statistiken',
      Icons.analytics,
      'Hier kÃ¶nnen Sie Live-Statistiken und Spielanalysen einsehen.',
      Colors.blue,
    );
  }

  /// Desktop layout: Left=Event History | Right=Column[Top=Controls, Bottom=Players]
  Widget _buildDesktopLiveScoring(GameState gameState) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // LEFT: Event History Sidebar
          SizedBox(
            width: 260,
            child: _buildDesktopEventHistory(gameState),
          ),
          const SizedBox(width: 8),
          // RIGHT: Controls + Players
          Expanded(
            child: Column(
              children: [
                // TOP: Score Header + Action Buttons
                _buildDesktopControlPanel(gameState),
                const SizedBox(height: 8),
                // BOTTOM: Player Grids side by side
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildDesktopPlayerGrid(
                          gameState,
                          _selectedGame!.teamAId ?? '',
                          _selectedGame!.teamAName,
                          _teamA,
                          true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildDesktopPlayerGrid(
                          gameState,
                          _selectedGame!.teamBId ?? '',
                          _selectedGame!.teamBName,
                          _teamB,
                          false,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Desktop event history sidebar
  Widget _buildDesktopEventHistory(GameState gameState) {
    final events = List<GameEvent>.from(gameState.events)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.history, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Spielverlauf',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  '${events.length}',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: events.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox, size: 36, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Text(
                          'Noch keine Ereignisse',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: events.length,
                    itemBuilder: (context, index) => _buildEventItem(events[index]),
                  ),
          ),
        ],
      ),
    );
  }

  /// Desktop control panel: compact score header + action buttons in a horizontal row
  Widget _buildDesktopControlPanel(GameState gameState) {
    final teamAScore = gameState.getTeamScore(_selectedGame!.teamAId ?? '');
    final teamBScore = gameState.getTeamScore(_selectedGame!.teamBId ?? '');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Timer row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  gameState.gameTime.periodDisplay,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(width: 12),
                Text(
                  gameState.gameTime.displayTime,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 28,
                  child: ElevatedButton(
                    onPressed: gameState.isRunning
                        ? () => _liveScoringService.pauseGameTimer(_selectedGame!.id)
                        : () => _liveScoringService.startGameTimer(_selectedGame!.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gameState.isRunning ? Colors.orange : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: Size.zero,
                    ),
                    child: Icon(
                      gameState.isRunning ? Icons.pause : Icons.play_arrow,
                      size: 16,
                    ),
                  ),
                ),
                if (gameState.gameTime.minutes >= 10) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 28,
                    child: ElevatedButton(
                      onPressed: () => _showEndSetDialog(gameState),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: Size.zero,
                      ),
                      child: const Text('Satz beenden', style: TextStyle(fontSize: 10)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Score Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_teamASpielerColor, Colors.grey.shade800, _teamBSpielerColor],
              ),
            ),
            child: Row(
              children: [
                // Team A
                Expanded(
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => _showRosterOverrideDialog(
                          _selectedGame!.teamAId ?? '',
                          _selectedGame!.teamAName,
                          _teamA,
                        ),
                        icon: const Icon(Icons.edit_note, color: Colors.white, size: 16),
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        padding: EdgeInsets.zero,
                        tooltip: 'Kader bearbeiten',
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _selectedGame!.teamAName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Score
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$teamAScore',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                      const Text(
                        ' : ',
                        style: TextStyle(color: Colors.white70, fontSize: 20),
                      ),
                      Text(
                        '$teamBScore',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                // Team B
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          _selectedGame!.teamBName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => _showRosterOverrideDialog(
                          _selectedGame!.teamBId ?? '',
                          _selectedGame!.teamBName,
                          _teamB,
                        ),
                        icon: const Icon(Icons.edit_note, color: Colors.white, size: 16),
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        padding: EdgeInsets.zero,
                        tooltip: 'Kader bearbeiten',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Selected player indicator + Action buttons row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person,
                  size: 16,
                  color: _selectedPlayer != null ? Colors.green : Colors.grey.shade400,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _selectedPlayer != null
                        ? '#${_selectedPlayer!.jerseyNumber ?? "?"} ${_selectedPlayer!.fullName}'
                        : 'Spieler auswählen...',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _selectedPlayer != null ? FontWeight.bold : FontWeight.normal,
                      color: _selectedPlayer != null
                          ? (_hasRedCard(gameState, _selectedPlayer!.id)
                              ? Colors.red
                              : Colors.green.shade700)
                          : Colors.grey,
                    ),
                  ),
                ),
                if (_selectedPlayer != null)
                  GestureDetector(
                    onTap: () => setState(() {
                      _selectedPlayer = null;
                      _selectedPlayerTeamId = null;
                    }),
                    child: Icon(Icons.clear, size: 14, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),
          // Action buttons — compact horizontal row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildDesktopActionChip('Tor', Icons.sports_handball, Colors.green, GameEventType.goal, gameState),
                _buildDesktopActionChip('7m ✓', Icons.my_location, Colors.indigo, GameEventType.sevenMeterHit, gameState),
                _buildDesktopActionChip('7m ✗', Icons.location_off, Colors.grey, GameEventType.sevenMeterMiss, gameState),
                _buildDesktopActionChip('Gelb', Icons.square, Colors.yellow.shade700, GameEventType.yellowCard, gameState),
                _buildDesktopActionChip('2 Min', Icons.access_time, Colors.orange, GameEventType.twoMinuteSuspension, gameState),
                _buildDesktopActionChip('Rot', Icons.cancel, Colors.red, GameEventType.redCard, gameState),
                _buildDesktopActionChip('Blau', Icons.report, Colors.blue.shade800, GameEventType.blueCard, gameState),
                // Undo buttons
                ActionChip(
                  avatar: const Icon(Icons.undo, size: 14),
                  label: const Text('Undo A', style: TextStyle(fontSize: 11)),
                  onPressed: () => _undoLastAction(_selectedGame!.teamAId ?? ''),
                  backgroundColor: Colors.grey.shade200,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                ActionChip(
                  avatar: const Icon(Icons.undo, size: 14),
                  label: const Text('Undo B', style: TextStyle(fontSize: 11)),
                  onPressed: () => _undoLastAction(_selectedGame!.teamBId ?? ''),
                  backgroundColor: Colors.grey.shade200,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Desktop action chip for a scoring event
  Widget _buildDesktopActionChip(
    String label,
    IconData icon,
    Color color,
    GameEventType eventType,
    GameState gameState,
  ) {
    final isEnabled = _selectedPlayer != null &&
        _selectedPlayerTeamId != null &&
        !_hasRedCard(gameState, _selectedPlayer!.id);

    return ActionChip(
      avatar: Icon(icon, size: 14, color: isEnabled ? color : Colors.grey),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: isEnabled ? color : Colors.grey,
          fontWeight: FontWeight.w600,
        ),
      ),
      onPressed: isEnabled
          ? () => _addPlayerEvent(
                gameState,
                _selectedPlayerTeamId!,
                _selectedPlayerTeamId == _selectedGame!.teamAId
                    ? _selectedGame!.teamAName
                    : _selectedGame!.teamBName,
                _selectedPlayer!,
                eventType,
              )
          : null,
      backgroundColor: isEnabled ? color.withOpacity(0.1) : Colors.grey.shade100,
      side: BorderSide(color: isEnabled ? color.withOpacity(0.3) : Colors.grey.shade300),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  /// Desktop player grid — a compact grid of player cards for one team
  Widget _buildDesktopPlayerGrid(
    GameState gameState,
    String teamId,
    String teamName,
    Team? team,
    bool isTeamA,
  ) {
    final squad = _gameSquads[teamId];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Team header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isTeamA ? _teamASpielerColor : _teamBSpielerColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isTeamA ? _teamAShooterColor : _teamBShooterColor,
                  width: 4,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    teamName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${gameState.getTeamScore(teamId)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          // Player grid
          Expanded(
            child: squad == null || squad.selectedPlayers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.group_off, size: 28, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Text(
                          'Kein Kader',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => _showRosterOverrideDialog(teamId, teamName, team),
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('Kader erstellen', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(6),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 1.4,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: squad.selectedPlayers.length,
                    itemBuilder: (context, index) {
                      final sp = squad.selectedPlayers[index];
                      final isSelected = _selectedPlayer?.id == sp.playerId;
                      final hasRed = _hasRedCard(gameState, sp.playerId);
                      final suspensions = _getPlayerSuspensionCount(gameState, sp.playerId);
                      final goals = gameState.events
                          .where((e) =>
                              e.playerId == sp.playerId &&
                              (e.eventType == GameEventType.goal ||
                               e.eventType == GameEventType.sevenMeterHit))
                          .length;
                      final specialColors = _getPlayerBorderColors(sp);
                      final hasPinkBorder = specialColors.contains(Colors.pink);
                      final hasYellowBorder = specialColors.any((c) => c == Colors.amber.shade600);

                      // Determine desktop tile border
                      Color tileBorderColor;
                      double tileBorderWidth;
                      if (isSelected) {
                        tileBorderColor = isTeamA ? _teamAShooterColor : _teamBShooterColor;
                        tileBorderWidth = 2;
                      } else if (hasRed) {
                        tileBorderColor = Colors.red.shade300;
                        tileBorderWidth = 1.5;
                      } else if (specialColors.isNotEmpty) {
                        tileBorderColor = specialColors.first;
                        tileBorderWidth = 2;
                      } else {
                        tileBorderColor = Colors.grey.shade200;
                        tileBorderWidth = 1;
                      }

                      Widget tile = Container(
                          decoration: BoxDecoration(
                            color: hasRed
                                ? Colors.red.shade50
                                : isSelected
                                    ? (isTeamA ? _teamAShooterColor : _teamBShooterColor).withOpacity(0.15)
                                    : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: tileBorderColor, width: tileBorderWidth),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Row(
                            children: [
                              // Jersey number
                              Container(
                                width: 26,
                                height: 26,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isTeamA ? _teamAShooterColor : _teamBShooterColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  sp.jerseyNumber ?? '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sp.lastName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: hasRed ? Colors.red : null,
                                        decoration: hasRed ? TextDecoration.lineThrough : null,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Row(
                                      children: [
                                        if (goals > 0) ...[
                                          Icon(Icons.sports_handball, size: 10, color: Colors.green.shade600),
                                          Text('$goals', style: TextStyle(fontSize: 9, color: Colors.green.shade600)),
                                          const SizedBox(width: 3),
                                        ],
                                        if (suspensions > 0) ...[
                                          Icon(Icons.access_time, size: 10, color: Colors.orange.shade700),
                                          Text('$suspensions', style: TextStyle(fontSize: 9, color: Colors.orange.shade700)),
                                        ],
                                        if (hasRed) ...[
                                          const Icon(Icons.cancel, size: 10, color: Colors.red),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );

                      // Wrap with second border if both pink AND yellow
                      if (hasPinkBorder && hasYellowBorder) {
                        tile = Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade600, width: 2),
                          ),
                          child: tile,
                        );
                      }

                      return GestureDetector(
                        onTap: hasRed
                            ? null
                            : () {
                                setState(() {
                                  _selectedPlayer = Player(
                                    id: sp.playerId,
                                    firstName: sp.firstName,
                                    lastName: sp.lastName,
                                    email: '${sp.playerId}@team.com',
                                    jerseyNumber: sp.jerseyNumber,
                                    gender: sp.gender ?? 'unknown',
                                    createdAt: DateTime.now(),
                                  );
                                  _selectedPlayerTeamId = teamId;
                                });
                              },
                        child: tile,
                      );
                    },
                  ),
          ),
        ],
      ),
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

              // Manager sign-off
              _buildManagerSignOffCard(),

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
                          '${gameState.getTeamScore(_selectedGame!.teamAId ?? '')}',
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
                          '${gameState.getTeamScore(_selectedGame!.teamBId ?? '')}',
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
                        'Punkte',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${gameState.teamAScore}',
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
                        'Punkte',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${gameState.teamBScore}',
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

  Widget _buildManagerSignOffCard() {
    final teamAName = _selectedGame?.teamAName ?? 'Team A';
    final teamBName = _selectedGame?.teamBName ?? 'Team B';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF455A64),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                Icon(Icons.draw, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Unterschriften der Spielverantwortlichen',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildSignOffRow(
                  teamName: teamAName,
                  managerId: _teamAManagerId,
                  managerName: _teamAManagerName,
                  isSigned: _teamAManagerSigned,
                  accentColor: Colors.blue,
                  onSign: () => _confirmSignOff(teamAName, isTeamA: true),
                  isTeamA: true,
                  onRequestSign: () => _sendSignOffNotification(isTeamA: true),
                ),
                const Divider(height: 24),
                _buildSignOffRow(
                  teamName: teamBName,
                  managerId: _teamBManagerId,
                  managerName: _teamBManagerName,
                  isSigned: _teamBManagerSigned,
                  accentColor: Colors.red,
                  onSign: () => _confirmSignOff(teamBName, isTeamA: false),
                  isTeamA: false,
                  onRequestSign: () => _sendSignOffNotification(isTeamA: false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignOffRow({
    required String teamName,
    required String? managerId,
    required String? managerName,
    required bool isSigned,
    required MaterialColor accentColor,
    required VoidCallback onSign,
    required bool isTeamA,
    required VoidCallback onRequestSign,
  }) {
    // Auto-send sign-off notification on first build when manager is assigned but hasn't signed
    if (managerId != null && !isSigned) {
      final alreadySent = isTeamA ? _signRequestSentA : _signRequestSentB;
      if (!alreadySent) {
        // Schedule after build to avoid setState-during-build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (isTeamA) { _signRequestSentA = true; }
          else         { _signRequestSentB = true; }
          onRequestSign();
        });
      }
    }

    return Row(
      children: [
        Container(
          width: 6, height: 44,
          decoration: BoxDecoration(color: accentColor.shade400, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(teamName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: accentColor.shade700)),
              const SizedBox(height: 2),
              managerId == null
                  ? Text('Kein Spielverantwortlicher zugewiesen',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontStyle: FontStyle.italic))
                  : Text(managerName ?? managerId,
                      style: const TextStyle(fontSize: 12, color: Colors.black87)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (isSigned)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.shade300)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle, size: 14, color: Colors.green.shade600),
              const SizedBox(width: 6),
              Text('Unterschrieben', style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
            ]),
          )
        else if (managerId == null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
            child: Text('Nicht verfügbar', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          )
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: onSign,
                icon: Icon(Icons.draw_outlined, size: 14, color: accentColor.shade600),
                label: Text('Bestätigen', style: TextStyle(fontSize: 12, color: accentColor.shade700)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: accentColor.shade300),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onRequestSign,
                icon: const Icon(Icons.send, size: 16),
                tooltip: 'Unterschrift anfordern',
                style: IconButton.styleFrom(
                  foregroundColor: accentColor.shade600,
                  padding: const EdgeInsets.all(6),
                  minimumSize: const Size(32, 32),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _confirmSignOff(String teamName, {required bool isTeamA}) async {
    final managerName = isTeamA ? _teamAManagerName : _teamBManagerName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Spielprotokoll bestätigen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Spielverantwortlicher von $teamName:', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(managerName ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Ich bestätige hiermit die Richtigkeit des Spielprotokolls.',
                style: TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green.shade600),
            child: const Text('Bestätigen'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() {
        if (isTeamA) _teamAManagerSigned = true;
        else         _teamBManagerSigned = true;
      });
      await _saveOfficials();
      _showSuccessToast('${isTeamA ? _selectedGame?.teamAName : _selectedGame?.teamBName}: Protokoll bestätigt');
    }
  }

  /// Send a sign-off request notification to the team manager
  void _sendSignOffNotification({required bool isTeamA}) {
    if (_selectedGame == null) return;
    final managerId = isTeamA ? _teamAManagerId : _teamBManagerId;
    final teamName = isTeamA ? _selectedGame!.teamAName : _selectedGame!.teamBName;
    final teamId = isTeamA ? _selectedGame!.teamAId : _selectedGame!.teamBId;
    if (managerId == null || teamId == null) return;

    // Look up user email from _allUsers
    final user = _allUsers.where((u) => u.id == managerId).firstOrNull;
    final userEmail = user?.email;

    CustomNotificationService().sendGameNotification(
      title: 'Spielprotokoll unterschreiben',
      message: 'Bitte unterschreibe das Spielprotokoll für $teamName.',
      notificationType: 'sign_off_request',
      gameId: _selectedGame!.id,
      teamId: teamId,
      teamName: teamName,
      userId: managerId,
      userEmail: userEmail,
    );

    _showSuccessToast('Unterschrift-Anforderung an ${user?.fullName ?? managerId} gesendet');
  }

  Widget _buildResetOptionsCard(GameState gameState) {
    final hasData = gameState.events.isNotEmpty;
    
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
                'Spiel zurÃ¼cksetzen',
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
                ? 'Alle Punkte, Ereignisse und SÃ¤tze lÃ¶schen. Diese Aktion kann nicht rÃ¼ckgÃ¤ngig gemacht werden.'
                : 'Aktuell sind keine Daten zum ZurÃ¼cksetzen vorhanden.',
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
                      'Achtung: Alle Spielereignisse und Punkte werden dauerhaft gelÃ¶scht!',
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
                    label: const Text('Aktuellen Satz zurÃ¼cksetzen'),
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
                    label: const Text('Gesamtes Spiel zurÃ¼cksetzen'),
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
                'Diese FunktionalitÃ¤t wird in einer zukÃ¼nftigen Version implementiert.',
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
        content: const Text('MÃ¶chten Sie sich wirklich abmelden?'),
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

  String _extractCategoryFromGame(Game game) {
    // Use actual team data if available - show city info
    if (_teamA != null && _teamB != null) {
      if (_teamA!.city == _teamB!.city) {
        return _teamA!.city;
      } else {
        return '${_teamA!.city} vs ${_teamB!.city}';
      }
    } else if (_teamA != null) {
      return _teamA!.city;
    } else if (_teamB != null) {
      return _teamB!.city;
    }

    return 'RHBL'; // Single league
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
            _selectedGame?.displayName ?? 'Kein Spiel ausgewÃ¤hlt',
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
    required String teamId,
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
                      '${squad.playerCount}/16',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _showRosterOverrideDialog(teamId, teamName, team),
                  icon: const Icon(Icons.edit_note, color: Colors.white, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    padding: const EdgeInsets.all(6),
                  ),
                  tooltip: 'Kader bearbeiten',
                ),
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
          'Kein Kader ausgewÃ¤hlt',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Der Trainer muss noch den Kader fÃ¼r dieses Spiel auswÃ¤hlen.',
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
        const SizedBox(height: 16),

        // Team Officials
        _buildSquadOfficialsList(squad),
      ],
    );
  }

  Widget _buildSquadStatus(GameSquad squad) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (squad.isApproved) {
      statusColor = Colors.green;
      statusText = 'Vom Trainer bestÃ¤tigt';
      statusIcon = Icons.check_circle;
    } else if (squad.isRejected) {
      statusColor = Colors.red;
      statusText = 'Vom Trainer abgelehnt';
      statusIcon = Icons.cancel;
    } else {
      statusColor = Colors.orange;
      statusText = 'Wartet auf Trainer-BestÃ¤tigung';
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
                  'AusgewÃ¤hlt von ${squad.selectedByName}',
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
              'AusgewÃ¤hlte Spieler (${squad.playerCount})',
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

  Widget _buildSquadOfficialsList(GameSquad squad) {
    final officials = squad.officials;
    final teamId = squad.teamId;
    final isTeamA = teamId == _selectedGame?.teamAId;
    final teamName = isTeamA ? _selectedGame!.teamAName : _selectedGame!.teamBName;
    final accentColor = isTeamA ? Colors.blue : Colors.red;

    final managerId = isTeamA ? _teamAManagerId : _teamBManagerId;
    final managerName = isTeamA ? _teamAManagerName : _teamBManagerName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Spielverantwortlicher ──────────────────────────────────────
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accentColor.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: accentColor.shade600,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.manage_accounts, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Spielverantwortlicher', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    if (managerId != null)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isTeamA) { _teamAManagerId = null; _teamAManagerName = null; }
                            else         { _teamBManagerId = null; _teamBManagerName = null; }
                          });
                          _saveOfficials();
                        },
                        child: const Icon(Icons.close, color: Colors.white70, size: 16),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: managerId != null
                    ? Row(
                        children: [
                          Icon(Icons.person, size: 18, color: accentColor.shade400),
                          const SizedBox(width: 8),
                          Expanded(child: Text(managerName ?? managerId, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(20)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.check_circle, size: 12, color: Colors.green.shade700),
                              const SizedBox(width: 4),
                              Text('Zugewiesen', style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ],
                      )
                    : _buildUserAutocomplete(
                        label: 'Person suchen…',
                        accentColor: accentColor,
                        onSelected: (user) {
                          setState(() {
                            if (isTeamA) { _teamAManagerId = user.id; _teamAManagerName = user.fullName; }
                            else         { _teamBManagerId = user.id; _teamBManagerName = user.fullName; }
                          });
                          _saveOfficials();
                          // Send roster confirmation notification to the assigned manager
                          if (_selectedGame != null) {
                            CustomNotificationService().sendGameNotification(
                              title: 'Kaderbestätigung angefordert',
                              message: 'Du wurdest als Spielverantwortlicher für $teamName eingetragen. Bitte bestätige den Kader.',
                              notificationType: 'roster_confirmation',
                              gameId: _selectedGame!.id,
                              teamId: teamId,
                              teamName: teamName,
                              userId: user.id,
                              userEmail: user.email,
                            );
                          }
                        },
                      ),
              ),
            ],
          ),
        ),

        // ── Team-Offizielle ───────────────────────────────────────────
        Row(
          children: [
            Text(
              'Team-Offizielle (${officials.length}/5)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            if (officials.length < 5)
              TextButton.icon(
                onPressed: () => _showAddOfficialDialog(teamId, teamName, isTeamA),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Hinzufügen', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: isTeamA ? Colors.blue.shade700 : Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (officials.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey.shade400),
                const SizedBox(width: 8),
                Text('Keine Team-Offiziellen eingetragen',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
              ],
            ),
          )
        else
          ...officials.asMap().entries.map((entry) {
            final i = entry.key;
            final o = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.purple.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.badge, size: 16, color: Colors.purple.shade400),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(o.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(o.role, style: TextStyle(fontSize: 10, color: Colors.purple.shade700)),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () async {
                        final updated = List<TeamOfficial>.from(officials)..removeAt(i);
                        await _gameSquadService.updateSquadOfficials(
                          _selectedGame!.id, teamId, updated);
                        final sq = _gameSquads[teamId];
                        if (sq != null) {
                          setState(() => _gameSquads[teamId] = sq.copyWith(officials: updated));
                        }
                      },
                      child: Icon(Icons.close, size: 14, color: Colors.red.shade300),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  /// Generic user autocomplete picker (for team manager assignment).
  Widget _buildUserAutocomplete({
    required String label,
    required MaterialColor accentColor,
    required void Function(app_user.User) onSelected,
  }) {
    return Autocomplete<app_user.User>(
      optionsBuilder: (TextEditingValue value) {
        if (value.text.isEmpty) return _allUsers;
        final q = value.text.toLowerCase();
        return _allUsers.where((u) =>
          u.fullName.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q));
      },
      displayStringForOption: (u) => u.fullName,
      fieldViewBuilder: (ctx, textCtrl, focusNode, onSubmitted) => TextFormField(
        controller: textCtrl,
        focusNode: focusNode,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: label,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          prefixIcon: Icon(Icons.search, size: 18, color: accentColor.shade400),
          suffixIcon: textCtrl.text.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: textCtrl.clear)
              : null,
        ),
        onFieldSubmitted: (_) => onSubmitted(),
      ),
      optionsViewBuilder: (ctx, onSelect, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220, maxWidth: 380),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (_, i) {
                final u = options.elementAt(i);
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(radius: 14, backgroundColor: accentColor.shade100,
                    child: Text(u.firstName.isNotEmpty ? u.firstName[0] : '?',
                      style: TextStyle(fontSize: 12, color: accentColor.shade700, fontWeight: FontWeight.bold))),
                  title: Text(u.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(u.email, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  onTap: () => onSelect(u),
                );
              },
            ),
          ),
        ),
      ),
      onSelected: onSelected,
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
            'WÃ¤hlen Sie Farben fÃ¼r Shooter und Spieler. Diese werden in der Live-Punktevergabe verwendet.',
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
      padding: EdgeInsets.symmetric(horizontal: 20 * _paddingScale, vertical: 12 * _paddingScale),
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
            padding: EdgeInsets.symmetric(horizontal: 16 * _paddingScale, vertical: 8 * _paddingScale),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  gameState.gameTime.displayTime,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20 * _fontScale,
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
                      '${gameState.getTeamScore(_selectedGame!.teamAId ?? '')} : ${gameState.getTeamScore(_selectedGame!.teamBId ?? '')}',
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
                    '${gameState.teamAScore}',
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
                    '${gameState.teamBScore}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                if (gameState.events.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Text('Halbzeit: ${gameState.currentHalf}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18 * _fontScale,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _showRosterOverrideDialog(teamId, teamName, team),
                      icon: const Icon(Icons.edit_note, color: Colors.white, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        padding: const EdgeInsets.all(8),
                      ),
                      tooltip: 'Kader bearbeiten',
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => _undoLastAction(teamId),
                      icon: const Icon(Icons.undo, color: Colors.white, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        padding: const EdgeInsets.all(8),
                      ),
                      tooltip: 'Letzte Aktion rÃ¼ckgÃ¤ngig',
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

  // Helper method to count player 2-minute suspensions
  int _getPlayerSuspensionCount(GameState gameState, String playerId) {
    return gameState.events.where((event) => 
      event.playerId == playerId && 
      event.eventType == GameEventType.twoMinuteSuspension
    ).length;
  }

  // Helper method to check if player has any suspensions
  bool _hasPlayerSuspensions(GameState gameState, String playerId) {
    return _getPlayerSuspensionCount(gameState, playerId) > 0;
  }

  // Helper method to check for newly completed halves
  void _checkForSetCompletion(GameState gameState) {
    final currentHalf = gameState.currentHalf;
    
    if (currentHalf > _lastProcessedHalfCount) {
      // Half completed
      // Check if we need a shootout (scores tied after 2 halves)
      if (currentHalf > 2 && gameState.teamAScore == gameState.teamBScore) {
        setState(() {
          _halfCompleted = true;
          _showShootoutSetupDialog = true;
          _lastProcessedHalfCount = currentHalf;
        });
      } else if (currentHalf > 1) {
        setState(() {
          _halfCompleted = true;
          _showSetCompletionOverlay = true;
          _lastProcessedHalfCount = currentHalf;
        });
      }
    }
  }

  // Build half completion overlay
  Widget _buildSetCompletionOverlay(GameState gameState) {
    final teamAScore = gameState.teamAScore;
    final teamBScore = gameState.teamBScore;
    final winnerId = teamAScore > teamBScore 
        ? _selectedGame!.teamAId 
        : _selectedGame!.teamBId;
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
                '${(gameState.currentHalf) - 1}. Halbzeit beendet',
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
                            color: winnerId == _selectedGame!.teamAId 
                                ? Colors.green.shade600 
                                : Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '$teamAScore',
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
                            color: winnerId == _selectedGame!.teamBId 
                                ? Colors.green.shade600 
                                : Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '$teamBScore',
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
                      label: const Text('Ã„nderungen vornehmen'),
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
                      label: const Text('BestÃ¤tigen'),
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
  Widget _buildShootoutSetupDialog(GameState gameState) {
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
      _halfCompleted = false;
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
                                '${_assignedGoalkeeper!.firstName.substring(0, 1)}. ${_assignedGoalkeeper!.lastName}',
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
            'Kein Kader fÃ¼r $teamName',
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
      _showErrorToast('Alle Positionen mÃ¼ssen besetzt sein!');
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
          _showSuccessToast('Unentschieden nach 5 WÃ¼rfen - Sudden Death! Alle Spieler wieder verfÃ¼gbar.');
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
      _halfCompleted = false;
    });
    
    _showSuccessToast('Halbzeit bestÃ¤tigt und weiter');
  }

  // Handle make changes to set
  void _handleMakeChanges() {
    setState(() {
      _showSetCompletionOverlay = false;
      _halfCompleted = false;
    });
    
    // TODO: Implement score editing functionality
    _showErrorToast('Funktion "Ã„nderungen vornehmen" wird in einer zukÃ¼nftigen Version implementiert');
  }

  // Show end set dialog for beach handball
  void _showEndSetDialog(GameState gameState) {
    final teamAScore = gameState.getTeamScore(_selectedGame!.teamAId ?? '');
    final teamBScore = gameState.getTeamScore(_selectedGame!.teamBId ?? '');
    
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
                '${_selectedGame!.teamAName} fÃ¼hrt',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ] else if (teamBScore > teamAScore) ...[
              Text(
                '${_selectedGame!.teamBName} fÃ¼hrt',
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

  // End half by time (handball rules)
  Future<void> _endSetByTime(GameState gameState) async {
    try {
      await _liveScoringService.completeHalf(
        _selectedGame!.id,
      );
      
      _showSuccessToast('Halbzeit wurde erfolgreich beendet');
      
    } catch (e) {
      print('âŒ Error ending set by time: $e');
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
              resetFullGame ? 'Gesamtes Spiel zurÃ¼cksetzen?' : 'Aktuellen Satz zurÃ¼cksetzen?',
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
                  ? 'Alle Punkte, Ereignisse, SÃ¤tze und Spielzeit werden dauerhaft gelÃ¶scht!'
                  : 'Alle Punkte und Ereignisse des aktuellen Satzes werden gelÃ¶scht!',
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
                      'Diese Aktion kann nicht rÃ¼ckgÃ¤ngig gemacht werden!',
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
            child: Text(resetFullGame ? 'Gesamtes Spiel zurÃ¼cksetzen' : 'Satz zurÃ¼cksetzen'),
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
                    'Rote Karte bestÃ¤tigen',
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
                'MÃ¶chten Sie eine direkte Rote Karte fÃ¼r diesen Spieler vergeben?',
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
                // Add the 2-minute suspension first, then the automatic red card
                _executePlayerEvent(gameState, teamId, teamName, player, GameEventType.twoMinuteSuspension);
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
            child: const Text('Rote Karte bestÃ¤tigen'),
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
      
      _showSuccessToast('Gesamtes Spiel wurde erfolgreich zurÃ¼ckgesetzt');
      
      // Clear local overlay state
      setState(() {
        _showSetCompletionOverlay = false;
        _halfCompleted = false;
        _lastProcessedHalfCount = 0;
      });
      
    } catch (e) {
      print('âŒ Error resetting full game: $e');
      _showErrorToast('Fehler beim ZurÃ¼cksetzen des Spiels: $e');
    }
  }

  // Reset only the current set
  Future<void> _resetCurrentSet(GameState gameState) async {
    try {
      // Delete events from current half only
      await _liveScoringService.clearCurrentHalfData(_selectedGame!.id, gameState.currentHalf);
      
      _showSuccessToast('Aktueller Satz wurde erfolgreich zurÃ¼ckgesetzt');
      
    } catch (e) {
      print('âŒ Error resetting current set: $e');
      _showErrorToast('Fehler beim ZurÃ¼cksetzen des Satzes: $e');
    }
  }

  /// Show a dialog to manually override the roster (add/remove players from the game squad).
  Future<void> _showRosterOverrideDialog(String teamId, String teamName, Team? team) async {
    if (_selectedGame == null || team == null) return;

    // Load available players from the team roster
    final availablePlayers = await _gameSquadService.getAvailablePlayersForTeam(teamId);
    if (availablePlayers.isEmpty) {
      _showErrorToast('Keine Spieler im Kader von $teamName vorhanden');
      return;
    }

    // Get currently selected player IDs
    final currentSquad = _gameSquads[teamId];
    final selectedIds = Set<String>.from(
      currentSquad?.selectedPlayers.map((p) => p.playerId) ?? [],
    );

    if (!mounted) return;
    
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.edit_note, color: Colors.teal.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kader bearbeiten – $teamName',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: selectedIds.length > 16 ? Colors.red.shade100 : Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${selectedIds.length}/16',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: selectedIds.length > 16 ? Colors.red : Colors.teal.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                height: 400,
                child: ListView.builder(
                  itemCount: availablePlayers.length,
                  itemBuilder: (_, index) {
                    final player = availablePlayers[index];
                    final isSelected = selectedIds.contains(player.id);
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            if (selectedIds.length < 16) {
                              selectedIds.add(player.id);
                            } else {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Maximal 16 Spieler erlaubt')),
                              );
                            }
                          } else {
                            selectedIds.remove(player.id);
                          }
                        });
                      },
                      title: Text(
                        player.fullName,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        'Trikot: ${player.jerseyNumber ?? '–'}  •  ${player.classification ?? '–'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      secondary: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.teal : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            player.jerseyNumber ?? '?',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      activeColor: Colors.teal,
                      dense: true,
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Abbrechen'),
                ),
                FilledButton.icon(
                  onPressed: selectedIds.isEmpty
                      ? null
                      : () async {
                          Navigator.pop(dialogContext);
                          // Save the updated squad
                          final selectedPlayers = availablePlayers
                              .where((p) => selectedIds.contains(p.id))
                              .toList();
                          final success = await _gameSquadService.selectSquadForGame(
                            gameId: _selectedGame!.id,
                            teamId: teamId,
                            selectedPlayers: selectedPlayers,
                            selectedByUserId: widget.user.id,
                            selectedByName: widget.user.fullName,
                          );
                          if (success) {
                            _showSuccessToast('Kader für $teamName aktualisiert');
                            setState(() => _squadsLoading = true);
                            await _loadGameSquads();
                            setState(() => _squadsLoading = false);
                          } else {
                            _showErrorToast('Fehler beim Aktualisieren des Kaders');
                          }
                        },
                  icon: const Icon(Icons.save, size: 18),
                  label: Text('Speichern (${selectedIds.length})'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.teal,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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
              'Kein Kader ausgewÃ¤hlt',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Der Trainer muss noch den Kader fÃ¼r dieses Spiel auswÃ¤hlen.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showRosterOverrideDialog(teamId, teamName, team),
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Kader erstellen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
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
              'FÃ¼r dieses Spiel wurden noch keine Spieler ausgewÃ¤hlt.',
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

    return GridView.builder(
      padding: EdgeInsets.all(6 * _paddingScale),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.6,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
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

  // Determine special border colors for classification/gender
  List<Color> _getPlayerBorderColors(SquadPlayer sp) {
    final colors = <Color>[];
    if (sp.gender == 'weiblich') colors.add(Colors.pink);
    final cls = sp.classification;
    if (cls == 'Gruppe A' || cls == 'Gruppe B') colors.add(Colors.amber.shade600);
    return colors;
  }

  Widget _buildSquadPlayerCard(GameState gameState, String teamId, String teamName, SquadPlayer squadPlayer) {
    final bool isSelected = _selectedPlayer?.id == squadPlayer.playerId;
    final bool isTeamA = teamId == _selectedGame?.teamAId;
    final bool hasRedCard = _hasRedCard(gameState, squadPlayer.playerId);
    final int suspensionCount = _getPlayerSuspensionCount(gameState, squadPlayer.playerId);
    final bool hasSuspensions = suspensionCount > 0;
    final goals = gameState.events
        .where((e) => e.playerId == squadPlayer.playerId &&
            (e.eventType == GameEventType.goal || e.eventType == GameEventType.sevenMeterHit))
        .length;
    
    final isShooter = _playerTypes[squadPlayer.playerId] ?? false;
    final basePlayerColor = isShooter 
        ? (isTeamA ? _teamAShooterColor : _teamBShooterColor)
        : (isTeamA ? _teamASpielerColor : _teamBSpielerColor);
    final playerColor = hasRedCard ? Colors.grey.shade400 : basePlayerColor;

    final specialColors = _getPlayerBorderColors(squadPlayer);
    final bool hasPink = specialColors.contains(Colors.pink);
    final bool hasYellow = specialColors.any((c) => c == Colors.amber.shade600);
    
    Color borderColor;
    double borderWidth;
    if (hasRedCard) {
      borderColor = Colors.red.shade300;
      borderWidth = 2;
    } else if (isSelected) {
      borderColor = playerColor;
      borderWidth = 2.5;
    } else if (specialColors.isNotEmpty) {
      borderColor = specialColors.first;
      borderWidth = 2;
    } else {
      borderColor = playerColor.withOpacity(0.3);
      borderWidth = 1;
    }

    Widget tile = GestureDetector(
      onTap: hasRedCard ? null : () {
        setState(() {
          if (isSelected) {
            _selectedPlayer = null;
            _selectedPlayerTeamId = null;
          } else {
            _selectedPlayer = Player(
              id: squadPlayer.playerId,
              firstName: squadPlayer.firstName,
              lastName: squadPlayer.lastName,
              email: '${squadPlayer.playerId}@team.com',
              jerseyNumber: squadPlayer.jerseyNumber,
              gender: squadPlayer.gender ?? 'unknown',
              createdAt: DateTime.now(),
            );
            _selectedPlayerTeamId = teamId;
          }
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: hasRedCard
              ? Colors.red.shade50
              : isSelected
                  ? playerColor.withOpacity(0.2)
                  : playerColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Top row: jersey number + indicators
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: hasRedCard ? Colors.grey.shade400 : playerColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    squadPlayer.jerseyNumber ?? '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                const Spacer(),
                if (hasPink)
                  Container(
                    width: 8, height: 8, margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.pink, border: Border.all(color: Colors.pink.shade700, width: 1)),
                  ),
                if (hasYellow)
                  Container(
                    width: 8, height: 8, margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.amber, border: Border.all(color: Colors.amber.shade800, width: 1)),
                  ),
                if (goals > 0)
                  Text('⚽$goals', style: TextStyle(fontSize: 8, color: Colors.green.shade700)),
                if (hasSuspensions && !hasRedCard)
                  Container(
                    margin: const EdgeInsets.only(left: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(color: Colors.orange.shade600, borderRadius: BorderRadius.circular(3)),
                    child: Text('$suspensionCount', style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                if (hasRedCard)
                  const Icon(Icons.cancel, size: 12, color: Colors.red),
              ],
            ),
            const SizedBox(height: 2),
            // Name (last name bold, first name small)
            Text(
              squadPlayer.lastName,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: hasRedCard ? Colors.grey.shade500 : Colors.black87,
                decoration: hasRedCard ? TextDecoration.lineThrough : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              squadPlayer.firstName,
              style: TextStyle(
                fontSize: 8,
                color: hasRedCard ? Colors.grey.shade400 : Colors.grey.shade600,
                decoration: hasRedCard ? TextDecoration.lineThrough : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    // Wrap with second border if both pink AND yellow
    if (hasPink && hasYellow) {
      tile = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.shade600, width: 2),
        ),
        child: tile,
      );
    }

    return tile;
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
                          : 'Spieler ${_selectedPlayer!.jerseyNumber} (${_selectedPlayer!.fullName}) ausgewÃ¤hlt')
                        : 'WÃ¤hlen Sie zuerst einen Spieler aus',
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
                  label: 'Tor',
                  color: Colors.green,
                  icon: Icons.sports_handball,
                  eventType: GameEventType.goal,
                  gameState: gameState,
                ),
                const SizedBox(height: 12),
                _buildCenterActionButton(
                  label: '7m Treffer',
                  color: Colors.indigo,
                  icon: Icons.my_location,
                  eventType: GameEventType.sevenMeterHit,
                  gameState: gameState,
                ),
                const SizedBox(height: 12),
                _buildCenterActionButton(
                  label: '7m Verfehlt',
                  color: Colors.grey,
                  icon: Icons.location_off,
                  eventType: GameEventType.sevenMeterMiss,
                  gameState: gameState,
                ),
                const SizedBox(height: 12),
                _buildCenterActionButton(
                  label: 'Gelbe Karte',
                  color: Colors.yellow.shade700,
                  icon: Icons.square,
                  eventType: GameEventType.yellowCard,
                  gameState: gameState,
                ),
                const SizedBox(height: 12),
                _buildCenterActionButton(
                  label: '2 Min. Strafe',
                  color: Colors.orange,
                  icon: Icons.access_time,
                  eventType: GameEventType.twoMinuteSuspension,
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
                const SizedBox(height: 12),
                _buildCenterActionButton(
                  label: 'Blaue Karte',
                  color: Colors.blue.shade800,
                  icon: Icons.report,
                  eventType: GameEventType.blueCard,
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
      case GameEventType.goal:
        eventColor = Colors.green;
        eventIcon = Icons.sports_handball;
        break;
      case GameEventType.sevenMeterHit:
        eventColor = Colors.indigo;
        eventIcon = Icons.my_location;
        break;
      case GameEventType.sevenMeterMiss:
        eventColor = Colors.grey;
        eventIcon = Icons.location_off;
        break;
      case GameEventType.yellowCard:
        eventColor = Colors.yellow.shade700;
        eventIcon = Icons.square;
        break;
      case GameEventType.twoMinuteSuspension:
        eventColor = Colors.orange;
        eventIcon = Icons.access_time;
        break;
      case GameEventType.redCard:
        eventColor = Colors.red;
        eventIcon = Icons.cancel;
        break;
      case GameEventType.blueCard:
        eventColor = Colors.blue.shade800;
        eventIcon = Icons.report;
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
    // Check if this is a 2-minute suspension that would trigger automatic red card
    if (eventType == GameEventType.twoMinuteSuspension) {
      final currentSuspensions = _getPlayerSuspensionCount(gameState, player.id);
      if (currentSuspensions >= 1) {
        // This would be the second 2-min suspension - trigger automatic red card
        _showRedCardConfirmationDialog(
          gameState: gameState,
          teamId: teamId,
          teamName: teamName,
          player: player,
          isAutomatic: true,
          reason: 'Zweite 2-Minuten-Strafe',
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
      
      _showSuccessToast('${_getEventTypeDisplayName(eventType)} fÃ¼r ${player.fullName} hinzugefÃ¼gt');
    }).catchError((error) {
      _showErrorToast('Fehler beim HinzufÃ¼gen des Ereignisses: $error');
    });
  }

  void _undoLastAction(String teamId) {
    _liveScoringService.removeLastEvent(_selectedGame!.id, teamId).then((_) {
      _showSuccessToast('Letzte Aktion rÃ¼ckgÃ¤ngig gemacht');
    }).catchError((error) {
      _showErrorToast('Fehler beim RÃ¼ckgÃ¤ngigmachen: $error');
    });
  }

  String _getEventTypeDisplayName(GameEventType eventType) {
    switch (eventType) {
      case GameEventType.goal:
        return 'Tor';
      case GameEventType.sevenMeterHit:
        return '7m Treffer';
      case GameEventType.sevenMeterMiss:
        return '7m Verfehlt';
      case GameEventType.yellowCard:
        return 'Gelbe Karte';
      case GameEventType.twoMinuteSuspension:
        return '2 Min. Strafe';
      case GameEventType.redCard:
        return 'Rote Karte';
      case GameEventType.blueCard:
        return 'Blaue Karte';
      case GameEventType.timeout:
        return 'Auszeit';
      case GameEventType.substitution:
        return 'Wechsel';
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
                                '${_assignedShooter!.firstName.substring(0, 1)}. ${_assignedShooter!.lastName}',
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
                  _showErrorToast('${player.firstName} ${player.lastName} war bereits Werfer - wÃ¤hle einen anderen Spieler');
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
                                '${_assignedPlayer!.firstName.substring(0, 1)}. ${_assignedPlayer!.lastName}',
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

  // Update tablet status when tablet is connected
  Future<void> _updateTabletStatus() async {
    if (_managedAccount == null || _assignedCourt == null) {
      print('âš ï¸ ScoringTablet: Cannot update tablet status - missing managed account or court');
      return;
    }
    
    if (_managedAccount!.id.isEmpty || _assignedCourt!.id.isEmpty) {
      print('âš ï¸ ScoringTablet: Cannot update tablet status - empty IDs');
      return;
    }
    
    try {
      print('ðŸ“± ScoringTablet: Updating tablet status for court ${_assignedCourt!.id}');
      
      // Simulate battery level (in a real implementation, this would come from device info)
      final batteryLevel = _getBatteryLevel();
      
      final success = await _managedAccountService.updateTabletStatus(
        courtId: _assignedCourt!.id,
        tabletId: _managedAccount!.id,
        connectionStatus: TabletConnectionStatus.connected,
        batteryPercentage: batteryLevel,
        deviceName: _getDeviceName(),
      );
      
      if (success) {
        print('âœ… ScoringTablet: Tablet status updated successfully');
      } else {
        print('âŒ ScoringTablet: Failed to update tablet status');
      }
    } catch (e) {
      print('âŒ ScoringTablet: Error updating tablet status: $e');
    }
  }

  // Simulate getting battery level (replace with actual device info in production)
  int _getBatteryLevel() {
    // For demo purposes, return a random battery level between 30-100%
    // In a real app, you would use device_info_plus or battery_plus packages
    return 85; // Simulated battery level
  }

  // Get device name (replace with actual device info in production)
  String _getDeviceName() {
    // For demo purposes, return a generic name
    // In a real app, you would use device_info_plus package
    return 'Scoring Tablet';
  }

} 