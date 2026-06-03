import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/tournament.dart';
import '../models/court.dart';
import '../models/game.dart';
// import '../models/tablet_status.dart'; // Disabled to prevent null errors
import '../services/court_service.dart';
import '../services/game_service.dart';
import '../services/managed_account_service.dart';
import '../utils/app_colors.dart';
import 'game_edit_screen.dart';
import 'graphics_control_screen.dart';

class TOSoftwareScreen extends StatefulWidget {
  final Tournament tournament;

  const TOSoftwareScreen({
    super.key,
    required this.tournament,
  });

  @override
  State<TOSoftwareScreen> createState() => _TOSoftwareScreenState();
}

class _TOSoftwareScreenState extends State<TOSoftwareScreen> {
  final CourtService _courtService = CourtService();
  final GameService _gameService = GameService();
  final ManagedAccountService _managedAccountService = ManagedAccountService();
  
  List<Court> courts = [];
  List<Game> games = [];
  // Map<String, TabletStatus> tabletStatuses = {}; // Disabled to prevent null errors
  bool isLoading = true;
  String selectedSection = 'court_view';
  
  // Schedule view variables (same as tournament editor)
  TimeOfDay _scheduleStartTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _scheduleEndTime = const TimeOfDay(hour: 21, minute: 0);
  int _timeSlotDuration = 30; // minutes
  int _selectedDayIndex = 0;
  
  // Game scheduling storage
  Map<String, Game> _scheduledGames = {};
  List<Game> _unscheduledGames = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _startAutoRefresh();
    
    // Immediately load games for this tournament
    _initializeGames();
  }

  void _startAutoRefresh() {
    // Refresh tablet statuses every 30 seconds (disabled temporarily)
    // Timer.periodic(const Duration(seconds: 30), (timer) {
    //   if (mounted) {
    //     _loadTabletStatuses();
    //   }
    // });
  }

  Future<void> _initializeGames() async {
    try {
      // Load all games for this tournament immediately
      final gamesList = await _gameService.getGamesForTournament(widget.tournament.id).first;
      setState(() {
        games = gamesList;
        _loadScheduledGames();
      });
      debugPrint('Ã°Å¸Å½Â® TO Software: Loaded ${games.length} games for tournament ${widget.tournament.name}');
    } catch (e) {
      debugPrint('Error initializing games: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    
    try {
      // Load courts and games for this tournament
      final courtsStream = _courtService.getCourts();
      final gamesStream = _gameService.getGamesForTournament(widget.tournament.id);
      
      // Listen to both streams and update state
      courtsStream.listen((courtsList) {
        setState(() {
          courts = courtsList;
        });
        // Load tablet statuses when courts are loaded (disabled temporarily)
        // _loadTabletStatuses();
      });
      
      gamesStream.listen((gamesList) {
        setState(() {
          games = gamesList;
          _loadScheduledGames();
        });
      });
    } catch (e) {
      debugPrint('Error loading TO Software data: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Future<void> _loadTabletStatuses() async {
  //   try {
  //     final statuses = await _managedAccountService.getTabletStatusForTournament(widget.tournament.id);
  //     setState(() {
  //       tabletStatuses = statuses;
  //     });
  //   } catch (e) {
  //     debugPrint('Error loading tablet statuses: $e');
  //   }
  // } // Disabled to prevent null errors

  void _onSectionChanged(String section) {
    setState(() {
      selectedSection = section;
    });
    
    // If switching to schedule view, ensure games are loaded
    if (section == 'schedule_view') {
      debugPrint('Ã°Å¸â€â€ž Switching to Schedule View - triggering game reload');
      _loadScheduledGames();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Row(
        children: [
          // Left Sidebar Navigation (Tournament Editor Style)
          Container(
            width: 280,
            decoration: const BoxDecoration(
              color: AppColors.textGrey,
            ),
            child: Column(
              children: [
                // Tournament Info Header
                Container(
                  height: 160,
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: AppColors.textGrey,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.computer, color: Colors.white, size: 32),
                      const SizedBox(height: 8),
                      const Text(
                        'TO SOFTWARE',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.tournament.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.tournament.location,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // Navigation Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _buildNavItem(
                        title: 'Court View',
                        icon: Icons.sports_handball,
                        section: 'court_view',
                        isSelected: selectedSection == 'court_view',
                      ),
                      _buildNavItem(
                        title: 'Schedule View',
                        icon: Icons.schedule,
                        section: 'schedule_view',
                        isSelected: selectedSection == 'schedule_view',
                      ),
                      const SizedBox(height: 8),
                      _buildActionNavItem(
                        title: 'OBS Graphics',
                        icon: Icons.monitor,
                        onTap: () => _openGraphicsControl(),
                      ),
                      // Future navigation items can be added here
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Main Content Area
          Expanded(
            child: Container(
              color: Colors.grey[100],
              child: Column(
                children: [
                  // Top Bar with Back Button
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.black87),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'TO Software',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Expanded(
                    child: _buildMainContent(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required String title,
    required IconData icon,
    required String section,
    required bool isSelected,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.rhdBlack : Colors.transparent,
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
        onTap: () => _onSectionChanged(section),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildActionNavItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.blue.shade600.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade600.withOpacity(0.3)),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          color: Colors.blue.shade600,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.blue.shade600,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        trailing: Icon(
          Icons.open_in_new,
          size: 16,
          color: Colors.blue.shade600,
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildMainContent() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    switch (selectedSection) {
      case 'court_view':
        return _buildCourtView();
      case 'schedule_view':
        return _buildScheduleView();
      default:
        return const Center(
          child: Text('Screen not found'),
        );
    }
  }

  Widget _buildCourtView() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.sports_handball,
                color: AppColors.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Court View',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const Spacer(),
              Text(
                '${courts.length} Courts Ã¢â‚¬Â¢ ${games.length} Games',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Courts Layout
          Expanded(
            child: courts.isEmpty
                ? _buildEmptyState()
                : _buildCourtsGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildCourtsGrid() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), // Reduced top padding
      child: Column(
        children: [
          // All courts in a single row with full height
          if (courts.isNotEmpty) ...[
            Expanded(
              child: Row(
                children: courts.map((court) {
                  // Get real games assigned to this court.
                  // Direct id match is the canonical case; fall back to
                  // matching by court name so historical games scheduled
                  // before the court-id format was stabilised still render.
                  final courtGames = games.where((game) {
                    if (game.courtId == null) return false;
                    if (game.courtId == court.id) return true;

                    // Name fallback: only when the game's courtId does not
                    // match ANY current court (would otherwise duplicate games
                    // across courts when ids overlap).
                    final allCourtIds = courts.map((c) => c.id).toSet();
                    if (allCourtIds.contains(game.courtId)) return false;

                    final fallbackName = _courtNameFor(game.courtId!);
                    if (fallbackName != null &&
                        fallbackName.toLowerCase() == court.name.toLowerCase()) {
                      return true;
                    }

                    return false;
                  }).toList();
                  
                  debugPrint('Ã°Å¸ÂÂ TO Software: Court "${court.name}" (${court.id}): ${courtGames.length} games found');
                  if (courtGames.isNotEmpty) {
                    for (final game in courtGames) {
                      debugPrint('  Ã°Å¸â€œÂ Game: ${game.teamAName} vs ${game.teamBName} (${game.id})');
                    }
                  }
                  
                  // Debug output (only for first court to avoid spam)
                  if (courts.indexOf(court) == 0) {
                    debugPrint('Ã°Å¸Å½Â® Total games loaded: ${games.length}');
                    if (games.isNotEmpty) {
                      debugPrint('Ã°Å¸â€Â All game court IDs: ${games.map((g) => g.courtId).toSet()}');
                      debugPrint('Ã°Å¸â€Â Available court IDs: ${courts.map((c) => c.id).toSet()}');
                    }
                  }
                  return Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _buildCourtCard(court, courtGames),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCourtCard(Court court, List<Game> courtGames) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Court Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.sports_handball,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    court.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Tablet Status Indicator (temporarily disabled)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.tablet_android,
                    size: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${courtGames.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Games List
          Expanded(
            child: courtGames.isEmpty
                ? Center(
                    child: Text(
                      'No games assigned',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: courtGames.length,
                    itemBuilder: (context, index) {
                      final game = courtGames[index];
                      return _buildGameCard(game);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard(Game game) {
    // Get actual scheduled time or current time
    final now = DateTime.now();
    final startTime = game.scheduledTime != null 
        ? '${game.scheduledTime!.hour.toString().padLeft(2, '0')}:${game.scheduledTime!.minute.toString().padLeft(2, '0')}'
        : '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    // Calculate elapsed time or time until start
    String currentTime = '0:00';
    if (game.scheduledTime != null) {
      final diff = now.difference(game.scheduledTime!);
      if (diff.isNegative) {
        // Game hasn't started yet - show countdown
        final minutesUntil = diff.inMinutes.abs();
        currentTime = '-${(minutesUntil ~/ 60).toString().padLeft(1, '0')}:${(minutesUntil % 60).toString().padLeft(2, '0')}';
      } else {
        // Game in progress - show elapsed time
        final minutesElapsed = diff.inMinutes;
        currentTime = '${(minutesElapsed ~/ 60).toString().padLeft(1, '0')}:${(minutesElapsed % 60).toString().padLeft(2, '0')}';
      }
    }
    
    final gameLabel = _getGameLabel(game);
    
    // Get actual scores from game result if available
    final teamAScore = game.result?.teamAScore ?? 0;
    final teamBScore = game.result?.teamBScore ?? 0;
    final teamAName = game.teamAName;
    final teamBName = game.teamBName;
    
    // Get score from game result
    final scoreDisplay = '${game.result?.teamAScore ?? 0}:${game.result?.teamBScore ?? 0}';
    
    // Team colors based on game status and scores
    final teamAColor = teamAScore > teamBScore ? Colors.green.shade600 : Colors.blue.shade600;
    final teamBColor = teamBScore > teamAScore ? Colors.green.shade600 : Colors.red.shade600;
    
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (details) {
        _showGameContextMenu(context, game, details.globalPosition);
      },
      onLongPress: () => _showGameContextMenu(context, game, null),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _getGameStatusColor(game),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                    // Header with time and league
          Row(
            children: [
              Text(
                startTime,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                currentTime,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.green.shade400,
                ),
              ),
              const Spacer(),
              Text(
                gameLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // White card for teams
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              children: [
                                 // Team A with colored score
                 Row(
                   children: [
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                       decoration: BoxDecoration(
                         color: teamAColor,
                         borderRadius: BorderRadius.circular(4),
                       ),
                       child: Text(
                         '$teamAScore',
                         style: const TextStyle(
                           fontWeight: FontWeight.bold,
                           fontSize: 12,
                           color: Colors.white,
                         ),
                       ),
                     ),
                     const SizedBox(width: 8),
                     Expanded(
                       child: Text(
                         teamAName,
                         style: const TextStyle(
                           fontSize: 12,
                           color: Colors.black87,
                           fontWeight: FontWeight.w500,
                         ),
                         overflow: TextOverflow.ellipsis,
                       ),
                     ),
                   ],
                 ),
                 
                 // Horizontal divider between teams
                 Container(
                   height: 1,
                   margin: const EdgeInsets.symmetric(vertical: 4),
                   color: Colors.grey.shade300,
                 ),
                 
                 // Team B with colored score
                 Row(
                   children: [
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                       decoration: BoxDecoration(
                         color: teamBColor,
                         borderRadius: BorderRadius.circular(4),
                       ),
                       child: Text(
                         '$teamBScore',
                         style: const TextStyle(
                           fontWeight: FontWeight.bold,
                           fontSize: 12,
                           color: Colors.white,
                         ),
                       ),
                     ),
                     const SizedBox(width: 8),
                     Expanded(
                       child: Text(
                         teamBName,
                         style: const TextStyle(
                           fontSize: 12,
                           color: Colors.black87,
                           fontWeight: FontWeight.w500,
                         ),
                         overflow: TextOverflow.ellipsis,
                       ),
                     ),
                   ],
                 ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Score display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                scoreDisplay,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }



  // Widget _buildTabletStatusIndicator(String courtId) {
  //   // DISABLED: Tablet status tracking disabled to prevent null errors
  //   return Container(
  //     width: 24,
  //     height: 24,
  //     decoration: BoxDecoration(
  //       color: Colors.grey.withOpacity(0.3),
  //       borderRadius: BorderRadius.circular(4),
  //     ),
  //     child: const Icon(
  //       Icons.tablet_android,
  //       size: 16,
  //       color: Colors.white70,
  //     ),
  //   );
  // } // Disabled to prevent null errors

  // String _getTabletTooltipMessage(TabletStatus tabletStatus) {
  //   final connectionText = tabletStatus.isConnected ? 'Verbunden' : 'Getrennt';
  //   final batteryText = tabletStatus.batteryPercentage != null 
  //       ? 'Akku: ${tabletStatus.batteryPercentage}%'
  //       : 'Akku: Unbekannt';
  //   final lastSeenText = 'Zuletzt gesehen: ${_formatLastSeen(tabletStatus.lastSeen)}';
  //   
  //   return '$connectionText\n$batteryText\n$lastSeenText';
  // } // Disabled to prevent null errors

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);
    
    if (difference.inMinutes < 1) {
      return 'Jetzt';
    } else if (difference.inMinutes < 60) {
      return 'vor ${difference.inMinutes} Min';
    } else if (difference.inHours < 24) {
      return 'vor ${difference.inHours} Std';
    } else {
      return 'vor ${difference.inDays} Tagen';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sports_handball_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Courts Available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Courts will appear here once they are added to the tournament.',
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

  // ===== SCHEDULE VIEW IMPLEMENTATION =====
  Widget _buildScheduleView() {
    // Ensure games are loaded when building schedule view
    if (games.isNotEmpty && (_scheduledGames.isEmpty && _unscheduledGames.isEmpty)) {
      debugPrint('Ã°Å¸â€â€ž Schedule View: No categorized games found, triggering reload');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadScheduledGames();
      });
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.schedule,
                color: AppColors.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Schedule View',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const Spacer(),
              Text(
                '${courts.length} Courts Ã¢â‚¬Â¢ ${_scheduledGames.length} Scheduled Ã¢â‚¬Â¢ ${_unscheduledGames.length} Unscheduled',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Schedule controls
          _buildScheduleControls(),
          
          const SizedBox(height: 16),
          
          // Main content area with schedule grid and unscheduled games
          Expanded(
            child: Row(
              children: [
                // Schedule grid (75% width)
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: _buildScheduleGridWithOverlay(),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Unscheduled games sidebar (25% width)
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: _buildUnscheduledGamesSidebar(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          // Start time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Start Time',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: _selectStartTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          '${_scheduleStartTime.hour.toString().padLeft(2, '0')}:${_scheduleStartTime.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // End time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'End Time',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: _selectEndTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          '${_scheduleEndTime.hour.toString().padLeft(2, '0')}:${_scheduleEndTime.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Time slot duration
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Time Scale',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _timeSlotDuration,
                      isDense: true,
                      items: [30, 40].map((duration) => DropdownMenuItem(
                        value: duration,
                        child: Text('${duration}min'),
                      )).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _timeSlotDuration = value;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Day selection
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tournament Day',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedDayIndex,
                      isDense: true,
                      items: _getTournamentDays().asMap().entries.map((entry) {
                        final index = entry.key;
                        final day = entry.value;
                        return DropdownMenuItem(
                          value: index,
                          child: Text(
                            'Tag ${index + 1} (${day.day}.${day.month}.${day.year})',
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedDayIndex = value;
                            _loadScheduledGames(); // Reload games for selected day
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleGridWithOverlay() {
    final timeSlots = _generateTimeSlots();
    final tournamentCourts = courts.where((court) => court.name.isNotEmpty).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header with court names
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                // Time column header
                Container(
                  width: 110,
                  padding: const EdgeInsets.all(8),
                  child: const Text(
                    'Zeit',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Court headers
                ...tournamentCourts.map((court) => Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border(left: BorderSide(color: Colors.grey.shade300)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          court.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )),
              ],
            ),
          ),
          // Scrollable schedule area
          Expanded(
            child: _buildSimpleScheduleGrid(timeSlots, tournamentCourts),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleScheduleGrid(List<String> timeSlots, List<Court> tournamentCourts) {
    return SingleChildScrollView(
      child: Column(
        children: timeSlots.asMap().entries.map((entry) {
          final index = entry.key;
          final timeSlot = entry.value;
          return Container(
            height: 80.0, // Fixed height per time slot
            child: Row(
              children: [
                // Time label
                Container(
                  width: 110,
                  height: 80.0,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                      right: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      timeSlot,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                // Court columns with fixed game slots
                ...tournamentCourts.map((court) => Expanded(
                  child: _buildGameSlot(court, timeSlot, index),
                )),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGameSlot(Court court, String timeSlot, int timeSlotIndex) {
    // Find if there's a game scheduled for this court and time slot
    final slotKey = "${court.id}_${timeSlot}_$_selectedDayIndex";
    final scheduledGame = _scheduledGames[slotKey];

    return DragTarget<Game>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        final game = details.data;
        _handleFixedGameDrop(game, court, timeSlot, timeSlotIndex);
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          height: 80.0,
          decoration: BoxDecoration(
            color: candidateData.isNotEmpty 
                ? Colors.blue.shade50 
                : (scheduledGame != null ? _getGameColor(scheduledGame) : Colors.white),
            border: Border(
              left: BorderSide(color: Colors.grey.shade200),
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: scheduledGame != null 
            ? _buildScheduledGameCard(scheduledGame)
            : (candidateData.isNotEmpty
                ? Center(
                    child: Icon(
                      Icons.add_circle_outline,
                      color: Colors.blue,
                      size: 24,
                    ),
                  )
                : null),
        );
      },
    );
  }

  Widget _buildScheduledGameCard(Game game) {
    final gameColor = _getGameColor(game);
    
    return Draggable<Game>(
      data: game,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 180,
          height: 50,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                gameColor,
                gameColor.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: _buildGameCardContent(game),
        ),
      ),
      childWhenDragging: Container(
        margin: const EdgeInsets.all(1),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: _buildGameCardContent(game, isPlaceholder: true),
      ),
      child: GestureDetector(
        onLongPress: () => _showUnscheduleGameMenu(context, game),
        onSecondaryTap: () => _showUnscheduleGameMenu(context, game),
        child: Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                gameColor,
                gameColor.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Stack(
            children: [
              _buildModernGameCardContent(game),
              // Unschedule button (top-left)
              Positioned(
                top: 2,
                left: 2,
                child: Tooltip(
                  message: 'Remove from schedule',
                  child: GestureDetector(
                    onTap: () => _showUnscheduleGameMenu(context, game),
                    child: Container(
                      padding: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              // Drag indicator
              Positioned(
                bottom: 2,
                right: 2,
                child: Icon(
                  Icons.drag_indicator,
                  size: 8,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernGameCardContent(Game game) {
    // Game label: RHBL
    
    // Use team names directly from game object
    String teamAName = game.teamAName.isNotEmpty ? game.teamAName : 'Team A';
    String teamBName = game.teamBName.isNotEmpty ? game.teamBName : 'Team B';
    
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Liga badge (top-right)
          Align(
            alignment: Alignment.topRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _getGameLabel(game),
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          
          // Team names
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  teamAName,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'vs',
                  style: const TextStyle(
                    fontSize: 7,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  teamBName,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCardContent(Game game, {bool isPlaceholder = false}) {
    final opacity = isPlaceholder ? 0.5 : 1.0;
    final teamAName = game.teamAName.isNotEmpty ? game.teamAName : 'Team A';
    final teamBName = game.teamBName.isNotEmpty ? game.teamBName : 'Team B';
    
    return Opacity(
      opacity: opacity,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              teamAName,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'vs',
              style: const TextStyle(
                fontSize: 7,
                color: Colors.white70,
              ),
            ),
            Text(
              teamBName,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnscheduledGamesSidebar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                'Unscheduled Games',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_unscheduledGames.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Games list
        Expanded(
          child: _unscheduledGames.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 48,
                        color: Colors.green.shade300,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'All games scheduled!',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _unscheduledGames.length,
                  itemBuilder: (context, index) {
                    final game = _unscheduledGames[index];
                    return _buildDraggableGameCard(game);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDraggableGameCard(Game game) {
    final gameColor = _getGameColor(game);
    
    return Draggable<Game>(
      data: game,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 200,
          height: 60,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                gameColor,
                gameColor.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: _buildUnscheduledGameContent(game),
        ),
      ),
      childWhenDragging: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
        ),
        child: _buildUnscheduledGameContent(game, isPlaceholder: true),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              gameColor,
              gameColor.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: _buildUnscheduledGameContent(game),
      ),
    );
  }

  Widget _buildUnscheduledGameContent(Game game, {bool isPlaceholder = false}) {
    final opacity = isPlaceholder ? 0.5 : 1.0;
    // Game label: RHBL
    final teamAName = game.teamAName.isNotEmpty ? game.teamAName : 'Team A';
    final teamBName = game.teamBName.isNotEmpty ? game.teamBName : 'Team B';
    
    return Opacity(
      opacity: opacity,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    teamAName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'vs',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    teamBName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getGameLabel(game),
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  Icons.drag_indicator,
                  size: 12,
                  color: Colors.white.withOpacity(0.7),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===== SCHEDULING LOGIC METHODS =====
  
  void _loadScheduledGames() {
    _scheduledGames.clear();
    _unscheduledGames.clear();
    
    debugPrint('Ã°Å¸â€œâ€¦ TO Software: Loading scheduled games for ${games.length} total games');
    debugPrint('Ã°Å¸â€œâ€¦ Selected day index: $_selectedDayIndex');
    
    final tournamentDays = _getTournamentDays();
    debugPrint('Ã°Å¸â€œâ€¦ Tournament days: ${tournamentDays.map((d) => '${d.day}.${d.month}.${d.year}').join(', ')}');
    
    for (final game in games) {
      debugPrint('Ã°Å¸â€œâ€¦ Processing game: ${game.teamAName} vs ${game.teamBName}');
      debugPrint('    - scheduledTime: ${game.scheduledTime}');
      debugPrint('    - courtId: ${game.courtId}');
      debugPrint('    - status: ${game.status}');
      
      if (game.scheduledTime != null && game.courtId != null) {
        // Find which court this game should be assigned to
        // Handle court ID mismatches by finding the closest matching court
        String? matchedCourtId = game.courtId;
        
        // Check if the game's court ID matches any existing court
        final courtIds = courts.map((c) => c.id).toSet();
        if (!courtIds.contains(game.courtId)) {
          debugPrint('    - Court ID mismatch: ${game.courtId} not in $courtIds');
          // Try to match by court name or just assign to first court
          if (courts.isNotEmpty) {
            matchedCourtId = courts.first.id;
            debugPrint('    - Reassigning to first court: $matchedCourtId');
          }
        }
        
        // Find which day this game belongs to
        final gameDate = game.scheduledTime!;
        debugPrint('    - Game date: ${gameDate.day}.${gameDate.month}.${gameDate.year}');
        
        int dayIndex = -1;
        for (int i = 0; i < tournamentDays.length; i++) {
          final day = tournamentDays[i];
          if (gameDate.year == day.year && 
              gameDate.month == day.month && 
              gameDate.day == day.day) {
            dayIndex = i;
            break;
          }
        }
        
        debugPrint('    - Day index found: $dayIndex');
        
        if (dayIndex >= 0) {
          // Create time slot in the new format (start-end)
          final startTime = '${game.scheduledTime!.hour.toString().padLeft(2, '0')}:${game.scheduledTime!.minute.toString().padLeft(2, '0')}';
          final endTime = game.scheduledTime!.add(Duration(minutes: _timeSlotDuration));
          final endTimeStr = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
          final timeSlot = '$startTime-$endTimeStr';
          final key = "${matchedCourtId}_${timeSlot}_$dayIndex";
          _scheduledGames[key] = game;
          debugPrint('Ã°Å¸â€œâ€¦ Ã¢Å“â€¦ Scheduled game: ${game.teamAName} vs ${game.teamBName} on day $dayIndex at $timeSlot (court: $matchedCourtId)');
        } else {
          // No matching tournament day. Skip the game and surface a warning —
          // the previous behaviour silently dropped it onto the selected day,
          // which masked stale or mis-scheduled data.
          debugPrint(
            '⚠️ to-software: game ${game.id} (${game.teamAName} vs ${game.teamBName}) '
            'has scheduledTime ${gameDate.toIso8601String()} which falls outside '
            'the tournament day range — skipping.',
          );
          _unscheduledGames.add(game);
        }
      } else {
        _unscheduledGames.add(game);
        debugPrint('Ã°Å¸â€œâ€¦ Ã¢Å¾â€¢ Unscheduled game: ${game.teamAName} vs ${game.teamBName} (missing scheduledTime or courtId)');
      }
    }
    
    debugPrint('Ã°Å¸â€œâ€¦ Final result: ${_scheduledGames.length} scheduled games, ${_unscheduledGames.length} unscheduled games');
  }

  /// Best-effort recovery for legacy court ids whose embedded label still
  /// matches a current court name (e.g. ids like "court_<ts>_A" or
  /// "<tournamentId>_court_<ts>"). Returns null when no hint can be derived.
  String? _courtNameFor(String courtId) {
    final lastSegment = courtId.split('_').last.trim();
    if (lastSegment.isEmpty || RegExp(r'^[0-9]+$').hasMatch(lastSegment)) {
      return null;
    }
    return lastSegment;
  }

  List<DateTime> _getTournamentDays() {
    // For TO Software, we'll use the tournament's date range
    final startDate = widget.tournament.startDate ?? DateTime.now();
    final endDate = widget.tournament.endDate ?? DateTime.now();
    
    final days = <DateTime>[];
    DateTime current = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    
    while (!current.isAfter(end)) {
      days.add(current);
      current = current.add(const Duration(days: 1));
    }
    
    return days;
  }

  List<String> _generateTimeSlots() {
    final List<String> slots = [];
    DateTime start = DateTime(2025, 1, 1, _scheduleStartTime.hour, _scheduleStartTime.minute);
    DateTime end = DateTime(2025, 1, 1, _scheduleEndTime.hour, _scheduleEndTime.minute);
    
    // Generate slots based on time scale duration with start-end times
    while (start.isBefore(end)) {
      final slotEnd = start.add(Duration(minutes: _timeSlotDuration));
      final startTime = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
      final endTime = '${slotEnd.hour.toString().padLeft(2, '0')}:${slotEnd.minute.toString().padLeft(2, '0')}';
      slots.add('$startTime-$endTime');
      start = start.add(Duration(minutes: _timeSlotDuration));
    }
    
    return slots;
  }

  void _handleFixedGameDrop(Game game, Court court, String timeSlot, int timeSlotIndex) {
    // Parse the time slot to create exact scheduled time (format: "18:00-18:30")
    final timeRange = timeSlot.split('-');
    final startTimeParts = timeRange[0].split(':');
    final finalHour = int.parse(startTimeParts[0]);
    final finalMinutes = int.parse(startTimeParts[1]);
    
    // Create scheduled date time
    final tournamentDays = _getTournamentDays();
    if (_selectedDayIndex < tournamentDays.length) {
      final selectedDay = tournamentDays[_selectedDayIndex];
      final scheduledDateTime = DateTime(
        selectedDay.year,
        selectedDay.month,
        selectedDay.day,
        finalHour,
        finalMinutes,
      );
      
      // Remove game from any previous slot
      _scheduledGames.removeWhere((key, scheduledGame) => scheduledGame.id == game.id);
      
      // Update game with new time and court
      final updatedGame = Game(
        id: game.id,
        tournamentId: game.tournamentId,
        teamAId: game.teamAId,
        teamBId: game.teamBId,
        teamAName: game.teamAName,
        teamBName: game.teamBName,
        gameType: game.gameType,
        poolId: game.poolId,
        scheduledTime: scheduledDateTime,
        courtId: court.id,
        status: game.status,
        result: game.result,
        createdAt: game.createdAt,
        updatedAt: DateTime.now(),
      );
      
      // Store in local scheduling map
      final key = "${court.id}_${timeSlot}_$_selectedDayIndex";
      _scheduledGames[key] = updatedGame;
      
      // Update unscheduled games list
      _unscheduledGames.removeWhere((g) => g.id == game.id);
      
      // Update in database and refresh UI
      _gameService.updateGame(updatedGame).then((_) {
        setState(() {
          _loadScheduledGames();
        });
      });
    }
  }

  void _showUnscheduleGameMenu(BuildContext context, Game game) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unschedule Game'),
        content: Text('Remove "${game.teamAName} vs ${game.teamBName}" from the schedule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _unscheduleGame(game);
              Navigator.of(context).pop();
            },
            child: const Text('Unschedule'),
          ),
        ],
      ),
    );
  }

  void _unscheduleGame(Game game) {
    // Remove from scheduled games
    _scheduledGames.removeWhere((key, scheduledGame) => scheduledGame.id == game.id);
    
    // Create updated game without scheduling info
    final updatedGame = Game(
      id: game.id,
      tournamentId: game.tournamentId,
      teamAId: game.teamAId,
      teamBId: game.teamBId,
      teamAName: game.teamAName,
      teamBName: game.teamBName,
      gameType: game.gameType,
      poolId: game.poolId,
      scheduledTime: null,
      courtId: null,
      status: game.status,
      result: game.result,
      createdAt: game.createdAt,
      updatedAt: DateTime.now(),
    );
    
    // Add back to unscheduled games
    _unscheduledGames.add(updatedGame);
    
    // Update in database
    _gameService.updateGame(updatedGame).then((_) {
      setState(() {
        _loadScheduledGames();
      });
    });
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _scheduleStartTime,
    );
    if (picked != null && picked != _scheduleStartTime) {
      setState(() {
        _scheduleStartTime = picked;
      });
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _scheduleEndTime,
    );
    if (picked != null && picked != _scheduleEndTime) {
      setState(() {
        _scheduleEndTime = picked;
      });
    }
  }

  // ===== HELPER METHODS =====
  
  Color _getGameColor(Game game) {
    return Colors.blue.shade700; // Single league (RHBL)
  }

  String _getGameLabel(Game game) {
    return 'RHBL';
  }

  // ===== COURT VIEW HELPER METHODS =====

  Color _getGameStatusColor(Game game) {
    switch (game.status) {
      case GameStatus.scheduled:
        return AppColors.textGrey; // Default dark gray
      case GameStatus.inProgress:
        return const Color(0xFF2D5016); // Dark green
      case GameStatus.completed:
        return AppColors.rhdBlack; // Very dark gray
      case GameStatus.cancelled:
        return const Color(0xFF742A2A); // Dark red
      default:
        return AppColors.textGrey;
    }
  }

  void _showGameContextMenu(BuildContext context, Game game, Offset? position) {
    // Prevent default browser context menu by stopping event propagation
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset menuPosition = position ?? const Offset(100, 100);

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        menuPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 18, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              const Text('Edit Game'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'score',
          child: Row(
            children: [
              Icon(Icons.sports_score, size: 18, color: Colors.green.shade600),
              const SizedBox(width: 8),
              const Text('Set Score'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'reschedule',
          child: Row(
            children: [
              Icon(Icons.schedule, size: 18, color: Colors.orange.shade600),
              const SizedBox(width: 8),
              const Text('Reschedule'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'status',
          child: Row(
            children: [
              Icon(_getStatusIcon(game.status), size: 18, color: Colors.purple.shade600),
              const SizedBox(width: 8),
              Text('Change Status (${_getStatusText(game.status)})'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'details',
          child: Row(
            children: [
              Icon(Icons.info, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              const Text('Game Details'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 18, color: Colors.red.shade600),
              const SizedBox(width: 8),
              const Text('Delete Game'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value != null) {
        _handleGameContextMenuAction(value, game);
      }
    });
  }

  IconData _getStatusIcon(GameStatus status) {
    switch (status) {
      case GameStatus.scheduled:
        return Icons.schedule;
      case GameStatus.inProgress:
        return Icons.play_circle;
      case GameStatus.completed:
        return Icons.check_circle;
      case GameStatus.cancelled:
        return Icons.cancel;
    }
  }

  Color _getStatusColor(GameStatus status) {
    switch (status) {
      case GameStatus.scheduled:
        return Colors.blue.shade600;
      case GameStatus.inProgress:
        return Colors.green.shade600;
      case GameStatus.completed:
        return Colors.grey.shade600;
      case GameStatus.cancelled:
        return Colors.red.shade600;
    }
  }

  String _getStatusText(GameStatus status) {
    switch (status) {
      case GameStatus.scheduled:
        return 'Scheduled';
      case GameStatus.inProgress:
        return 'In Progress';
      case GameStatus.completed:
        return 'Completed';
      case GameStatus.cancelled:
        return 'Cancelled';
    }
  }

  void _handleGameContextMenuAction(String action, Game game) {
    switch (action) {
      case 'edit':
        _editGame(game);
        break;
      case 'score':
        _setGameScore(game);
        break;
      case 'reschedule':
        _rescheduleGame(game);
        break;
      case 'status':
        _changeGameStatus(game);
        break;
      case 'details':
        _showGameDetails(game);
        break;
      case 'delete':
        _deleteGame(game);
        break;
    }
  }

  void _editGame(Game game) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GameEditScreen(game: game),
      ),
    );
    
    // If the game was updated, refresh the data
    if (result == true) {
      _loadData();
      _loadScheduledGames();
    }
  }

  void _setGameScore(Game game) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Score'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${game.teamAName} vs ${game.teamBName}'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Text(game.teamAName, style: const TextStyle(fontWeight: FontWeight.bold))),
                  const SizedBox(width: 16),
                  Expanded(child: Text(game.teamBName, style: const TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
              const SizedBox(height: 8),
              // Score
              Row(
                children: [
                  const Text('Score:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      initialValue: game.result?.teamAScore.toString() ?? '0',
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(':', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: game.result?.teamBScore.toString() ?? '0',
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Score will be saved')),
              );
            },
            child: const Text('Save Score'),
          ),
        ],
      ),
    );
  }

  void _rescheduleGame(Game game) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reschedule Game'),
        content: Text('Reschedule "${game.teamAName} vs ${game.teamBName}" to a different time/court.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                selectedSection = 'schedule_view';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Use Schedule View to reschedule the game')),
              );
            },
            child: const Text('Open Schedule'),
          ),
        ],
      ),
    );
  }

  void _changeGameStatus(Game game) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Change Game Status'),
            const SizedBox(height: 4),
            Text(
              '${game.teamAName} vs ${game.teamBName}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getStatusColor(game.status).withOpacity(0.1),
                border: Border.all(color: _getStatusColor(game.status).withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(_getStatusIcon(game.status), color: _getStatusColor(game.status), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Current: ${_getStatusText(game.status)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(game.status),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select new status:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 8),
            ...GameStatus.values.map((status) {
              final isSelected = game.status == status;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: SizedBox(
                  width: double.infinity,
                  child: InkWell(
                    onTap: isSelected ? null : () {
                      Navigator.of(context).pop();
                      _updateGameStatus(game, status);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? _getStatusColor(status).withOpacity(0.2)
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected 
                              ? _getStatusColor(status)
                              : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getStatusIcon(status), 
                            color: _getStatusColor(status), 
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _getStatusText(status),
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? _getStatusColor(status) : Colors.black87,
                            ),
                          ),
                          const Spacer(),
                          if (isSelected)
                            Icon(
                              Icons.check,
                              color: _getStatusColor(status),
                              size: 18,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateGameStatus(Game game, GameStatus newStatus) async {
    if (game.status == newStatus) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Game is already ${_getStatusText(newStatus).toLowerCase()}')),
      );
      return;
    }

    try {
      // Create updated game with new status
      final updatedGame = Game(
        id: game.id,
        tournamentId: game.tournamentId,
        teamAId: game.teamAId,
        teamBId: game.teamBId,
        teamAName: game.teamAName,
        teamBName: game.teamBName,
        gameType: game.gameType,
        poolId: game.poolId,
        bracketRound: game.bracketRound,
        bracketPosition: game.bracketPosition,
        scheduledTime: game.scheduledTime,
        courtId: game.courtId,
        refereeGespannId: game.refereeGespannId,
        delegateId: game.delegateId,
        status: newStatus,
        result: game.result,
        createdAt: game.createdAt,
        updatedAt: DateTime.now(),
      );

      await _gameService.updateGame(updatedGame);
      
      // Refresh the data to show the updated status
      _loadData();
      _loadScheduledGames();
      
      // Show success message with status-specific color
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(_getStatusIcon(newStatus), color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('${game.teamAName} vs ${game.teamBName} Ã¢â€ â€™ ${_getStatusText(newStatus)}'),
            ],
          ),
          backgroundColor: _getStatusColor(newStatus),
          duration: const Duration(seconds: 3),
        ),
      );
      
      debugPrint('Ã¢Å“â€¦ Game status updated: ${game.teamAName} vs ${game.teamBName} Ã¢â€ â€™ ${_getStatusText(newStatus)}');
    } catch (e) {
      debugPrint('Ã¢ÂÅ’ Error updating game status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Error updating game status: $e')),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showGameDetails(Game game) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Game Details'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Teams', '${game.teamAName} vs ${game.teamBName}'),
              _buildDetailRow('Status', _getStatusText(game.status)),
              _buildDetailRow('Scheduled Time', game.scheduledTime?.toString() ?? 'Not scheduled'),
              _buildDetailRow('Court ID', game.courtId ?? 'Not assigned'),
              _buildDetailRow('Game Type', game.gameType.toString().split('.').last),
              if (game.poolId != null) _buildDetailRow('Pool', game.poolId!),
              _buildDetailRow('Created', game.createdAt.toString()),
              if (game.updatedAt != null) _buildDetailRow('Updated', game.updatedAt.toString()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _deleteGame(Game game) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Game'),
        content: Text('Are you sure you want to delete "${game.teamAName} vs ${game.teamBName}"?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Game deletion will be implemented')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openGraphicsControl() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GraphicsControlScreen(tournament: widget.tournament),
      ),
    );
  }
} 
