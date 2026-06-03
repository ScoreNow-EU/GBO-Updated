import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_colors.dart';
import '../models/tournament.dart';
import '../models/tournament_link.dart';
import '../models/team.dart';
import '../models/referee.dart';
import '../models/delegate.dart';
import '../models/kampfgericht_member.dart';
import '../models/player.dart';
import '../models/court.dart';
import '../models/game.dart';
import '../models/user.dart' as app_user;
import '../services/tournament_service.dart';
import '../services/team_service.dart';
import '../services/referee_service.dart';
import '../services/delegate_service.dart';
import '../services/kampfgericht_service.dart';
import '../services/court_service.dart';
import '../services/game_service.dart';
import '../services/auth_service.dart';
import '../services/player_service.dart';
import '../data/german_cities.dart';
import 'dart:math' as math;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:toastification/toastification.dart';
import 'tournament_games_screen.dart';
import '../services/game_scheduler.dart';
import '../widgets/advanced_scheduling_dialog.dart';
import 'tournament_assignment_screen.dart';
import 'dart:async';
import '../utils/responsive_helper.dart';
import 'new_category_pools_screen.dart';
import 'tournament_link_editor_screen.dart';
import 'game_report_screen.dart';
import 'tournament_stats_screen.dart';
import '../widgets/livestream_embed.dart';
import '../services/livestream_service.dart';
import '../models/livestream_credentials.dart';
import '../models/game_event.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Add this class at the top of the file after imports
class GamePosition {
  final double left;
  final double top;
  final double width;
  final double height;

  GamePosition({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
}

/// Lightweight local event entry used in the Spielbericht dialog.
class _GameEventEntry {
  final int minute;
  final int half;
  final GameEventType type;
  final bool isTeamA;
  final String playerName;
  const _GameEventEntry({
    required this.minute,
    required this.half,
    required this.type,
    required this.isTeamA,
    required this.playerName,
  });
}

class TournamentEditScreen extends StatefulWidget {
  final Tournament? tournament; // null for creating new tournament
  final bool isWizardMode; // true for new tournament creation wizard

  const TournamentEditScreen({
    super.key,
    this.tournament,
    this.isWizardMode = false,
  });

  @override
  State<TournamentEditScreen> createState() => _TournamentEditScreenState();
}

class _TournamentEditScreenState extends State<TournamentEditScreen> {
  final TournamentService _tournamentService = TournamentService();
  final TeamService _teamService = TeamService();
  final RefereeService _refereeService = RefereeService();
  final DelegateService _delegateService = DelegateService();
  final KampfgerichtService _kampfgerichtService = KampfgerichtService();
  final CourtService _courtService = CourtService();
  final GameService _gameService = GameService();
  final AuthService _authService = AuthService();
  final PlayerService _playerService = PlayerService();
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  
  // Tournament data
  DateTime? _startDate;
  DateTime? _endDate;
  String _status = 'upcoming';
  String _approvalStatus = 'pending_approval';
  GermanCity? _selectedLocation;
  TextEditingController _locationController = TextEditingController(); // Initialize immediately
  
  // Venue address
  final _venueStreetController = TextEditingController();
  final _venueHouseNumberController = TextEditingController();
  final _venuePlzController = TextEditingController();
  
  // Available categories - removed
  
  final List<String> _statusOptions = [
    'upcoming',
    'ongoing',
    'completed',
  ];

  // Navigation state
  String _selectedTab = 'basic'; // basic, teams, games, scheduling, courts, referees, delegates, settings
  bool _isRegistrationOpen = true;
  DateTime? _registrationDeadline;
  
  // Referee management
  List<Referee> _allReferees = [];
  /// Maps refereeId â†’ RefereeInvitation (replaces simple _selectedRefereeIds list)
  Map<String, RefereeInvitation> _refereeInvitations = {};
  String _refereeSearchQuery = '';
  final _refereeSearchController = TextEditingController();
  String _refereeSubTab = 'selection'; // selection, gespanne, planner
  
  // Kampfgericht management
  List<KampfgerichtMember> _allKampfgerichtMembers = [];
  List<String> _selectedKampfgerichtIds = [];
  String _kampfgerichtSearchQuery = '';
  final _kampfgerichtSearchController = TextEditingController();
  
  // Delegate management
  List<Delegate> _allDelegates = [];
  List<String> _selectedDelegateIds = [];
  String _delegateSearchQuery = '';
  final _delegateSearchController = TextEditingController();
  String _delegateSubTab = 'selection'; // selection, planner
  Key _delegatePlannerKey = UniqueKey(); // For forcing FutureBuilder rebuilds
  
  // Referee Gespann management
  List<Map<String, dynamic>> _refereeGespanne = [];
  final _gespannNameController = TextEditingController();
  Key _refereePlannerKey = UniqueKey(); // For forcing FutureBuilder rebuilds

  // Tournament Links (Ausschreibungen/AGBs and Social Media)
  List<TournamentLink> _links = [];

  // Tournament Organizer assignment
  List<app_user.User> _allUsers = [];
  String? _selectedTournamentOrganizerId;
  String _userSearchQuery = '';
  final _userSearchController = TextEditingController();

  // Ausrichterverein (host club) — gets +3 Ligapunkte
  String? _hostClubTeamId;

  // Sponsor logos (download URLs from Firebase Storage)
  List<String> _sponsorLogos = [];
  bool _isUploadingSponsor = false;

  // Livestream (t42 / t43)
  bool _livestreamEnabled = false;
  final _livestreamUrlController = TextEditingController();
  String? _livestreamYoutubeBroadcastId;
  bool _isCreatingBroadcast = false;
  LivestreamCredentials? _lastBroadcastCreds;

  // Team management
  List<Team> _allTeams = [];
  List<String> _selectedTeamIds = [];
  String _teamSearchQuery = '';
  final _teamSearchController = TextEditingController();

  // Pool management variables
  Map<String, List<String>> _categoryPools = {};
  Map<String, List<String>> _poolTeams = {};
  Map<String, bool> _poolIsFunBracket = {};
  Map<String, List<BracketRound>> _categoryBrackets = {};

  // Custom bracket state
  Map<String, List<CustomBracketNode>> _categoryCustomBrackets = {}; // bracket key -> custom bracket nodes

  // Court management
  List<Court> _allCourts = [];
  List<String> _selectedCourtIds = [];
  List<Court> _tournamentCourts = [];
  final MapController _mapController = MapController();
  LatLng _mapCenter = const LatLng(51.1657, 10.4515); // Germany center
  double _mapZoom = 6.0;
  bool _isPlacingCourt = false; // New state for court placement mode
  bool _isEditingCourt = false; // State for editing mode
  Court? _selectedCourtForEditing;
  final _courtNameController = TextEditingController();
  String _courtLabel = 'A'; // Default label for new courts

  bool _isLoading = false;
  bool _isSaving = false;

  // Scheduled games for match planner
  Map<String, Game> _scheduledGames = {};
  int _timeSlotDuration = 30;
  int _selectedDayIndex = 0;
  TimeOfDay _scheduleStartTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _scheduleEndTime = const TimeOfDay(hour: 18, minute: 0);

  // Auto-save functionality
  Timer? _scheduleAutoSaveTimer;
  bool _isScheduleAutoSaving = false;
  String? _scheduleAutoSaveStatus;
  
  // Auto-refresh functionality
  Timer? _autoRefreshTimer;
  bool _isAutoRefreshing = false;
  DateTime? _lastRefreshTime;

  // ? ADD: Stream subscriptions to prevent memory leaks
  StreamSubscription? _teamsSubscription;
  StreamSubscription? _refereesSubscription;
  StreamSubscription? _delegatesSubscription;
  StreamSubscription? _courtsSubscription;

  // Games schedule table: cached with fingerprint to avoid unnecessary rebuilds
  List<Game> _scheduleTableGames = [];
  String _scheduleTableFingerprint = '';
  StreamSubscription? _scheduleTableSubscription;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _loadTeams();
    _loadReferees();
    _loadDelegates();
    _loadKampfgerichtMembers();
    _loadCourts();
    _loadScheduledGames();
    _preloadGames(); // Preload games for match planner
    _startAutoRefresh();
    
    _teamSearchController.addListener(() {
      setState(() {
        _teamSearchQuery = _teamSearchController.text.toLowerCase();
      });
    });
    
    _refereeSearchController.addListener(() {
      setState(() {
        _refereeSearchQuery = _refereeSearchController.text.toLowerCase();
      });
    });
    
    _delegateSearchController.addListener(() {
      setState(() {
        _delegateSearchQuery = _delegateSearchController.text.toLowerCase();
      });
    });

    _kampfgerichtSearchController.addListener(() {
      setState(() {
        _kampfgerichtSearchQuery = _kampfgerichtSearchController.text.toLowerCase();
      });
    });
  }

  void _startAutoRefresh() {
    // Auto-refresh every 30 seconds when editing existing tournament
    if (widget.tournament != null) {
      _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        _performAutoRefresh();
      });
    }
  }

  Future<void> _performAutoRefresh() async {
    if (_isAutoRefreshing) return; // Prevent multiple simultaneous refreshes
    if (!mounted) return;
    
    setState(() {
      _isAutoRefreshing = true;
      _lastRefreshTime = DateTime.now();
    });
    
    try {
      // Refresh scheduled games data
      _loadScheduledGames();
      
      // Optional: Also refresh teams and referees data
      // _loadTeams();
      // _loadReferees();
      
      // Wait a moment to show the refresh indicator
      await Future.delayed(const Duration(milliseconds: 500));
      
    } catch (e) {
      debugPrint('Error during auto-refresh: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isAutoRefreshing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _scheduleTableSubscription?.cancel();
    _teamsSubscription?.cancel();
    _refereesSubscription?.cancel();
    _delegatesSubscription?.cancel();
    _courtsSubscription?.cancel();
    _teamSearchController.dispose();
    _refereeSearchController.dispose();
    _delegateSearchController.dispose();
    _kampfgerichtSearchController.dispose();
    _livestreamUrlController.dispose();
    super.dispose();
  }

  void _initializeData() {
    if (widget.tournament != null) {
      final tournament = widget.tournament!;
      _nameController.text = tournament.name;
      _descriptionController.text = tournament.description ?? '';
      _imageUrlController.text = tournament.imageUrl ?? '';
      _startDate = tournament.startDate;
      _endDate = tournament.endDate;
      _status = tournament.status;
      _approvalStatus = tournament.approvalStatus;
      _selectedTeamIds = List<String>.from(tournament.teamIds); // Explicit type
      // Build referee invitations map from existing invitations
      _refereeInvitations = { for (final inv in tournament.refereeInvitations) inv.refereeId: inv };
      _selectedDelegateIds = List<String>.from(tournament.delegateIds); // Explicit type
      _selectedKampfgerichtIds = tournament.kampfgerichtInvitations.map((k) => k.memberId).toList();
      _refereeGespanne = List<Map<String, dynamic>>.from(tournament.refereeGespanne); // Load existing referee pairs
      
      // Venue address
      _venueStreetController.text = tournament.venueStreet ?? '';
      _venueHouseNumberController.text = tournament.venueHouseNumber ?? '';
      _venuePlzController.text = tournament.venuePlz ?? '';
      
      // Try to find location in German cities
      _selectedLocation = GermanCities.findByDisplayName(tournament.location);
      
      // Set location controller text
      _locationController.text = tournament.location;
      
      // Set map location if we have coordinates - removed automatic coordinate lookup
      // The map will stay centered on Germany for now
      
      // Load custom brackets if they exist
      for (String category in tournament.customBrackets.keys) {
        final customBracket = tournament.customBrackets[category]!;
        _categoryCustomBrackets[category] = List<CustomBracketNode>.from(customBracket.nodes);
      }
      
      // Load tournament courts
      _tournamentCourts = List<Court>.from(tournament.courts);
      
      // Load category registration settings
      _isRegistrationOpen = tournament.isRegistrationOpen;
      _registrationDeadline = tournament.registrationDeadline;
      
      // Load Tournament Organizer assignment
      _selectedTournamentOrganizerId = tournament.tournamentOrganizerId;
      
      // Load Ausrichterverein
      _hostClubTeamId = tournament.hostClubTeamId;
      
      // Load sponsor logos
      _sponsorLogos = List<String>.from(tournament.sponsorLogos);

      // Load livestream settings
      _livestreamEnabled = tournament.livestreamEnabled;
      _livestreamUrlController.text = tournament.livestreamUrl ?? '';
      _livestreamYoutubeBroadcastId = tournament.livestreamYoutubeBroadcastId;
      
      // Load tournament links
      _links = List<TournamentLink>.from(tournament.links);
      debugPrint('Loaded ${_links.length} links from tournament');
      debugPrint('Links: ${_links.map((l) => '${l.label} (${l.type})').join(', ')}');
    } else {
      // Default values for new tournament
      _selectedTeamIds = []; // Start with no teams selected
      _locationController.text = ''; // Start with empty location
      _selectedCourtIds = []; // Start with no courts selected
      
      _isRegistrationOpen = true;
      _registrationDeadline = null;
    }
  }

  void _loadTeams() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    
    try {
      _teamsSubscription?.cancel(); // Cancel existing subscription
      _teamsSubscription = _teamService.getTeamsWithCache().listen((teams) {
        if (mounted) {
          setState(() {
            _allTeams = teams;
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _loadReferees() async {
    try {
      _refereesSubscription?.cancel(); // Cancel existing subscription
      _refereesSubscription = _refereeService.getReferees().listen((referees) {
        if (mounted) {
          setState(() {
            _allReferees = referees;
          });
        }
      });
    } catch (e) {
      debugPrint('Error loading referees: $e');
    }
  }

  void _loadDelegates() async {
    try {
      _delegatesSubscription?.cancel(); // Cancel existing subscription
      _delegatesSubscription = _delegateService.getDelegates().listen((delegates) {
        if (mounted) {
          setState(() {
            _allDelegates = delegates;
          });
        }
      });
    } catch (e) {
      debugPrint('Error loading delegates: $e');
    }
  }

  void _loadKampfgerichtMembers() async {
    try {
      _kampfgerichtService.getMembers().listen((members) {
        if (mounted) {
          setState(() {
            _allKampfgerichtMembers = members;
          });
        }
      });
    } catch (e) {
      debugPrint('Error loading kampfgericht members: $e');
    }
  }

  Future<List<app_user.User>> _loadUsers() async {
    try {
      // Get all users from the auth service
      debugPrint('Loading users...');
      
      // Create a fresh AuthService instance
      final authService = AuthService();
      final users = await authService.getAllUsers();
      debugPrint('Loaded ${users.length} users');
      return users;
    } catch (e) {
      debugPrint('Error loading users: $e');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error details: $e');
      return [];
    }
  }

  Future<String?> _getOrganizerName(String organizerId) async {
    try {
      final authService = AuthService();
      final users = await authService.getAllUsers();
      final organizer = users.firstWhere(
        (user) => user.id == organizerId,
        orElse: () => app_user.User(
          id: organizerId,
          email: '',
          firstName: 'Unknown',
          lastName: 'Organizer',
          roles: [],
          createdAt: DateTime.now(),
        ),
      );
      return organizer.fullName;
    } catch (e) {
      debugPrint('Error getting organizer name: $e');
      return null;
    }
  }

  void _preloadGames() async {
    if (widget.tournament != null) {
      try {
        await _gameService.preloadGames(widget.tournament!.id);
        debugPrint('?? Tournament Edit: Games preloaded for tournament ${widget.tournament!.id}');
      } catch (e) {
        debugPrint('? Error preloading games: $e');
      }
    }
  }

  void _loadCourts() async {
    try {
      _courtsSubscription?.cancel(); // Cancel existing subscription
      _courtsSubscription = _courtService.getCourts().listen((courts) {
        if (mounted) {
          setState(() {
            _allCourts = courts;
            // Auto-position map when courts are loaded
            _autoPositionMap();
          });
        }
      });
    } catch (e) {
      debugPrint('Error loading courts: $e');
    }
  }

  void _loadScheduledGames() async {
    if (widget.tournament == null) return;
    try {
      final games = _gameService.getGamesForTournamentSync(widget.tournament!.id);
      final Map<String, Game> newScheduledGames = {};
      final tournamentDays = _getTournamentDays();

      for (final game in games) {
        if (game.scheduledTime != null && game.courtId != null) {
          for (int dayIndex = 0; dayIndex < tournamentDays.length; dayIndex++) {
            final day = tournamentDays[dayIndex];
            if (game.scheduledTime!.year == day.year &&
                game.scheduledTime!.month == day.month &&
                game.scheduledTime!.day == day.day) {
              final hour = game.scheduledTime!.hour.toString().padLeft(2, '0');
              final minute = game.scheduledTime!.minute.toString().padLeft(2, '0');
              final endTime = game.scheduledTime!.add(Duration(minutes: _timeSlotDuration));
              final endHour = endTime.hour.toString().padLeft(2, '0');
              final endMinute = endTime.minute.toString().padLeft(2, '0');
              final timeSlot = '$hour:$minute-$endHour:$endMinute';
              final slotKey = '${game.courtId}_${timeSlot}_$dayIndex';
              newScheduledGames[slotKey] = game;
              break;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _scheduledGames = newScheduledGames;
        });
      }
    } catch (e) {
      debugPrint('Error loading scheduled games: $e');
    }
  }

  void _autoPositionMap() {
    LatLng? targetPosition;
    double targetZoom = 15.0;

    // Priority 1: Use tournament location if we have coordinates
    if (_selectedLocation != null) {
      // We would need coordinates for the selected location
      // For now, try to get coordinates from tournament location string
      final locationCoords = _getLocationCoordinates(_locationController.text);
      if (locationCoords != null) {
        targetPosition = locationCoords;
        targetZoom = 12.0; // City level zoom
      }
    }

    // Priority 2: Use a default specific location (e.g., Berlin) instead of all of Germany
    if (targetPosition == null) {
      targetPosition = const LatLng(52.5200, 13.4050); // Berlin center
      targetZoom = 10.0;
    }

    // Update map center and zoom
    if (mounted) {
      setState(() {
        _mapCenter = targetPosition!;
        _mapZoom = targetZoom;
      });
    }

    // Move the map controller if it's initialized and widget is mounted
    try {
      if (mounted && _mapController.camera.center != targetPosition) {
      _mapController.move(targetPosition, targetZoom);
      }
    } catch (e) {
      // Map controller not ready yet, ignore error
    }
  }

  LatLng? _getLocationCoordinates(String locationName) {
    // Common German cities coordinates - you can expand this
    final cityCoordinates = <String, LatLng>{
      'berlin': const LatLng(52.5200, 13.4050),
      'hamburg': const LatLng(53.5511, 9.9937),
      'münchen': const LatLng(48.1351, 11.5820),
      'munich': const LatLng(48.1351, 11.5820),
      'köln': const LatLng(50.9375, 6.9603),
      'cologne': const LatLng(50.9375, 6.9603),
      'frankfurt': const LatLng(50.1109, 8.6821),
      'stuttgart': const LatLng(48.7758, 9.1829),
      'düsseldorf': const LatLng(51.2277, 6.7735),
      'dortmund': const LatLng(51.5136, 7.4653),
      'essen': const LatLng(51.4556, 7.0116),
      'bremen': const LatLng(53.0793, 8.8017),
      'dresden': const LatLng(51.0504, 13.7373),
      'leipzig': const LatLng(51.3397, 12.3731),
      'hannover': const LatLng(52.3759, 9.7320),
      'nürnberg': const LatLng(49.4521, 11.0767),
      'nuremberg': const LatLng(49.4521, 11.0767),
    };

    final normalizedLocation = locationName.toLowerCase().trim();
    
    // Try direct match first
    if (cityCoordinates.containsKey(normalizedLocation)) {
      return cityCoordinates[normalizedLocation];
    }

    // Try partial matches
    for (String city in cityCoordinates.keys) {
      if (normalizedLocation.contains(city) || city.contains(normalizedLocation)) {
        return cityCoordinates[city];
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        
        if (ResponsiveHelper.shouldUseDrawer(screenWidth)) {
          // Mobile layout - show tournament navigation as overlay
          return Scaffold(
            drawer: _buildTournamentNavigationDrawer(screenWidth),
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              toolbarHeight: 0, // Hide the actual AppBar but keep the status bar styling
              systemOverlayStyle: const SystemUiOverlayStyle(
                statusBarColor: Colors.white,
                statusBarIconBrightness: Brightness.dark,
              ),
            ),
            body: SafeArea(
              top: false, // Don't add extra SafeArea since we're using AppBar
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
                _buildTournamentNavigation(),
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

  Widget _buildTournamentNavigationDrawer(double screenWidth) {
    return Drawer(
      child: Container(
        color: AppColors.textGrey,
        child: Column(
          children: [
            // Header
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
                                  const Icon(Icons.edit, color: Colors.white, size: 32),
                const SizedBox(height: 8),
                Text(
                  widget.tournament == null ? 'NEUES TURNIER' : 'TURNIER BEARBEITEN',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12 * ResponsiveHelper.getFontScale(screenWidth),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (widget.tournament != null && widget.tournament!.name.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.tournament!.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14 * ResponsiveHelper.getFontScale(screenWidth),
                      fontWeight: FontWeight.bold,
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
                  _buildDrawerNavItem('basic', 'Grunddaten', Icons.info_outline, screenWidth),
                  _buildDrawerNavItem('teams', 'Team Auswahl', Icons.group, screenWidth),
                  _buildDrawerNavItem('pools', 'Pools', Icons.workspaces, screenWidth),
                  _buildDrawerNavItem('links', 'Links & Social Media', Icons.link, screenWidth),
                  _buildDrawerNavItem('games', 'Spiele', Icons.sports_handball, screenWidth),
                  _buildDrawerNavItem('courts', 'Plätze', Icons.place, screenWidth),
                  _buildDrawerNavItem('referees', 'Schiedsrichter', Icons.sports_hockey, screenWidth),
                  _buildDrawerNavItem('kampfgericht', 'Kampfgericht', Icons.gavel, screenWidth),
                  _buildDrawerNavItem('delegates', 'Delegierte', Icons.person_outline, screenWidth),
                  // Zuordnung tab hidden per ticket 1777589051169
                  _buildDrawerNavItem('stats', 'Statistiken', Icons.bar_chart, screenWidth),
                  _buildDrawerNavItem('sponsors', 'Sponsoren', Icons.handshake, screenWidth),
                  _buildDrawerNavItem('livestream', 'Livestream', Icons.live_tv, screenWidth),
                  _buildDrawerNavItem('settings', 'Einstellungen', Icons.settings, screenWidth),
                ],
              ),
            ),
            // Save and Back Buttons
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveTournament,
                      icon: _isSaving 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save),
                      label: Text(widget.tournament == null ? 'Erstellen' : 'Speichern'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white70),
                      label: const Text('Zurück', style: TextStyle(color: Colors.white70)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTournamentNavigation() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppColors.textGrey,
        border: Border(
          right: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Header
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
                const Icon(Icons.edit, color: Colors.white, size: 32),
                const SizedBox(height: 8),
                Text(
                  widget.tournament == null ? 'NEUES TURNIER' : 'TURNIER BEARBEITEN',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12 * ResponsiveHelper.getFontScale(MediaQuery.of(context).size.width),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (widget.tournament != null && widget.tournament!.name.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.tournament!.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14 * ResponsiveHelper.getFontScale(MediaQuery.of(context).size.width),
                      fontWeight: FontWeight.bold,
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
                _buildNavItem('basic', 'Grunddaten', Icons.info_outline),
                _buildNavItem('teams', 'Team Auswahl', Icons.group),
                _buildNavItem('pools', 'Pools', Icons.workspaces),
                _buildNavItem('links', 'Links & Social Media', Icons.link),
                _buildNavItem('games', 'Spiele', Icons.sports_handball),
                _buildNavItem('courts', 'Plätze', Icons.place),
                _buildNavItem('referees', 'Schiedsrichter', Icons.sports_hockey),
                _buildNavItem('kampfgericht', 'Kampfgericht', Icons.gavel),
                _buildNavItem('delegates', 'Delegierte', Icons.person_outline),
                // Zuordnung tab hidden per ticket 1777589051169
                _buildNavItem('stats', 'Statistiken', Icons.bar_chart),
                _buildNavItem('sponsors', 'Sponsoren', Icons.handshake),
                _buildNavItem('livestream', 'Livestream', Icons.live_tv),
                _buildNavItem('settings', 'Einstellungen', Icons.settings),
              ],
            ),
          ),
          // Save and Back Buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveTournament,
                    icon: _isSaving 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save),
                    label: Text(widget.tournament == null ? 'Erstellen' : 'Speichern'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                    label: const Text('Zurück', style: TextStyle(color: Colors.white70)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
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

  String _getTabTitle() {
    switch (_selectedTab) {
      case 'basic':
        return 'Grunddaten';
      case 'teams':
        return 'Team Auswahl';
      case 'pools':
        return '';
      case 'links':
        return 'Links & Social Media';
      case 'games':
        return 'Spiele';
      case 'courts':
        return 'Plätze';
      case 'referees':
        return 'Schiedsrichter';
      case 'kampfgericht':
        return 'Kampfgericht';
      case 'delegates':
        return 'Delegierte';
      case 'stats':
        return 'Statistiken';
      case 'sponsors':
        return 'Sponsoren';
      case 'livestream':
        return 'Livestream';
      case 'settings':
        return 'Einstellungen';
      default:
        return 'Grunddaten';
    }
  }

  /// Short code for special scenarios: WH, WG, NH, NG, X
  String _scenarioShortCode(String scenario) {
    switch (scenario) {
      case 'Wertung gegen Heim':   return 'WH';
      case 'Wertung gegen Gast':   return 'WG';
      case 'Heim nicht angetreten': return 'NH';
      case 'Gast nicht angetreten': return 'NG';
      case 'Spielabbruch':          return 'X';
      default: return scenario;
    }
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 'basic':
        return _buildBasicDataTab();
      case 'teams':
        return _buildTeamsTab();
      case 'pools':
        return NewCategoryPoolsScreen(tournament: widget.tournament!);
      case 'links':
        return _buildLinksTab();
      case 'games':
        return _buildGamesTab();
      case 'courts':
        return _buildCourtsTab();
      case 'referees':
        return _buildRefereesTab();
      case 'kampfgericht':
        return _buildKampfgerichtTab();
      case 'delegates':
        return _buildDelegatesTab();
      // 'assignment' tab hidden per ticket 1777589051169
      case 'stats':
        if (widget.tournament == null) {
          return Center(
            child: Text(
              'Bitte speichern Sie das Turnier zuerst.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }
        return TournamentStatsScreen(key: UniqueKey(), tournament: widget.tournament!);
      case 'settings':
        return _buildSettingsTab();
      case 'sponsors':
        return _buildSponsorsTab();
      case 'livestream':
        return _buildLivestreamTab();
      default:
        return _buildBasicDataTab();
    }
  }

  Widget _buildNavItem(String tabId, String title, IconData icon) {
    final isSelected = _selectedTab == tabId;
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
        onTap: () {
          setState(() {
            _selectedTab = tabId;
          });
          
          // Auto-position map when courts tab is selected
          if (tabId == 'courts') {
            // Small delay to ensure the map is rendered
            Future.delayed(const Duration(milliseconds: 100), () {
              _autoPositionMap();
            });
          }
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
        color: isSelected ? AppColors.rhdBlack : Colors.transparent,
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
              fontSize: 14 * ResponsiveHelper.getFontScale(screenWidth),
            ),
          ),
          onTap: () {
            setState(() {
              _selectedTab = tabId;
            });
            Navigator.of(context).pop(); // Close drawer
            
            // Auto-position map when courts tab is selected
            if (tabId == 'courts') {
              Future.delayed(const Duration(milliseconds: 100), () {
                _autoPositionMap();
              });
            }
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
      ),
    );
  }

  Widget _buildMobileHeader(double screenWidth) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Row(
        children: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.black),
              onPressed: () => Scaffold.of(context).openDrawer(),
              tooltip: 'Menü öffnen',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.tournament != null && widget.tournament!.name.isNotEmpty) ...[
                  Text(
                    widget.tournament!.name,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16 * ResponsiveHelper.getFontScale(screenWidth),
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _getTabTitle(),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14 * ResponsiveHelper.getFontScale(screenWidth),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ] else ...[
                  Text(
                    _getTabTitle(),
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18 * ResponsiveHelper.getFontScale(screenWidth),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_selectedTab == 'teams')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_selectedTeamIds.length}',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 12 * ResponsiveHelper.getFontScale(screenWidth),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          // Add back button
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Zurück',
          ),
        ],
      ),
    );
  }

 
  Widget _buildTabNavigation() {
    // Remove this method as navigation is now in the sidebar
    return const SizedBox.shrink();
  }

  Widget _buildMainContent() {
    switch (_selectedTab) {
      case 'basic':
        return _buildBasicDataTab();
      case 'teams':
        return _buildTeamsTab();
      case 'pools':
        if (widget.tournament == null) {
          return Center(
            child: Text(
              'Bitte speichern Sie das Turnier zuerst, um Pools zu verwalten.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }
        return Container(
          color: Colors.white,
          child: NewCategoryPoolsScreen(tournament: widget.tournament!),
        );
      case 'games':
        return _buildGamesTab();
      case 'courts':
        return _buildCourtsTab();
      case 'referees':
        return _buildRefereesTab();
      case 'kampfgericht':
        return _buildKampfgerichtTab();
      case 'delegates':
        return _buildDelegatesTab();
      // 'assignment' tab hidden per ticket 1777589051169
      case 'stats':
        if (widget.tournament == null) {
          return Center(
            child: Text(
              'Bitte speichern Sie das Turnier zuerst.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }
        return TournamentStatsScreen(key: UniqueKey(), tournament: widget.tournament!);
      case 'settings':
        return _buildSettingsTab();
      case 'sponsors':
        return _buildSponsorsTab();
      case 'livestream':
        return _buildLivestreamTab();
      default:
        return _buildBasicDataTab();
    }
  }

  Widget _buildBasicDataTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tournament Basic Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.event, color: Colors.blue),
                        const SizedBox(width: 12),
                        Text(
                          'Turnier Grunddaten',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Tournament Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Turnier Name *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Bitte geben Sie einen Turnier Namen ein';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Beschreibung (optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Tournament Image URL
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _imageUrlController,
                          decoration: const InputDecoration(
                            labelText: 'Turnier Bild URL (optional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.image),
                            hintText: 'https://example.com/image.jpg',
                          ),
                          onChanged: (value) {
                            setState(() {
                              // Trigger rebuild to update image preview
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        // Image Preview
                        if (_imageUrlController.text.isNotEmpty) ...[
                          if (_isValidUrl(_imageUrlController.text))
                            Container(
                              height: 200,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  _imageUrlController.text,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          CircularProgressIndicator(
                                            value: loadingProgress.expectedTotalBytes != null
                                                ? loadingProgress.cumulativeBytesLoaded / 
                                                  loadingProgress.expectedTotalBytes!
                                                : null,
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Bild wird geladen...',
                                            style: TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey.shade100,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.broken_image,
                                            size: 48,
                                            color: Colors.grey.shade400,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Bild konnte nicht geladen werden',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Überprüfen Sie die URL',
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            )
                          else
                            Container(
                              height: 100,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                border: Border.all(color: Colors.orange.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.warning_amber,
                                    size: 32,
                                    color: Colors.orange.shade600,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Ungültige URL',
                                    style: TextStyle(
                                      color: Colors.orange.shade700,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'URL muss mit http:// oder https:// beginnen',
                                    style: TextStyle(
                                      color: Colors.orange.shade600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Tournament Organizer Assignment
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Turnier Organisator',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Search field
                              TextFormField(
                                controller: _userSearchController,
                                decoration: InputDecoration(
                                  labelText: 'Benutzer suchen',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.search),
                                  hintText: 'Name oder E-Mail eingeben...',
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _userSearchQuery = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              
                              // User list
                              Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: FutureBuilder<List<app_user.User>>(
                                  future: _loadUsers(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return Center(child: CircularProgressIndicator());
                                    }
                                    
                                    if (snapshot.hasError) {
                                      return Center(
                                        child: Text(
                                          'Fehler beim Laden der Benutzer: ${snapshot.error}',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      );
                                    }
                                    
                                    final users = snapshot.data ?? [];
                                    final filteredUsers = users.where((user) {
                                      if (_userSearchQuery.isEmpty) return true;
                                      return user.fullName.toLowerCase().contains(_userSearchQuery.toLowerCase()) ||
                                             user.email.toLowerCase().contains(_userSearchQuery.toLowerCase());
                                    }).toList();
                                    
                                    if (filteredUsers.isEmpty) {
                                      return Center(
                                        child: Text(
                                          'Keine Benutzer gefunden',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      );
                                    }
                                    
                                    return ListView.builder(
                                      itemCount: filteredUsers.length,
                                      itemBuilder: (context, index) {
                                        final user = filteredUsers[index];
                                        final isSelected = _selectedTournamentOrganizerId == user.id;
                                        
                                        return ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: isSelected ? Colors.blue : Colors.grey.shade300,
                                            child: Text(
                                              user.fullName.substring(0, 1).toUpperCase(),
                                              style: TextStyle(
                                                color: isSelected ? Colors.white : Colors.black87,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          title: Text(
                                            user.fullName,
                                            style: TextStyle(
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                          subtitle: Text(user.email),
                                          trailing: isSelected 
                                            ? Icon(Icons.check_circle, color: Colors.blue)
                                            : null,
                                          onTap: () {
                                            setState(() {
                                              _selectedTournamentOrganizerId = user.id;
                                            });
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                              
                              if (_selectedTournamentOrganizerId != null) ...[
                                const SizedBox(height: 8),
                                FutureBuilder<String?>(
                                  future: _getOrganizerName(_selectedTournamentOrganizerId!),
                                  builder: (context, snapshot) {
                                    final organizerName = snapshot.data ?? 'Organisator';
                                    return Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.blue.shade200),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.check_circle, color: Colors.blue, size: 16),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '$organizerName als Turnier Organisator zugewiesen',
                                              style: TextStyle(
                                                color: Colors.blue.shade700,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              setState(() {
                                                _selectedTournamentOrganizerId = null;
                                              });
                                            },
                                            child: Text('Entfernen'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Location with autocomplete
                    Autocomplete<GermanCity>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        return GermanCities.searchCities(textEditingValue.text).take(10);
                      },
                      displayStringForOption: (GermanCity option) => option.displayName,
                      onSelected: (GermanCity selection) {
                        setState(() {
                          _selectedLocation = selection;
                          _locationController.text = selection.displayName;
                        });
                      },
                      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                        // Use our own controller instead of the provided one
                        
                        // Set initial value if location is selected
                        if (_selectedLocation != null && _locationController.text != _selectedLocation!.displayName) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _locationController.text = _selectedLocation!.displayName;
                          });
                        }
                        
                        return TextFormField(
                          controller: _locationController, // Use our own controller
                          focusNode: focusNode,
                          onEditingComplete: onEditingComplete,
                          decoration: InputDecoration(
                            labelText: 'Austragungsort *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.location_on),
                            hintText: 'Deutsche Stadt eingeben (z.B. Berlin, München)...',
                            helperText: 'Tippen Sie um deutsche Städte zu durchsuchen',
                            suffixIcon: _selectedLocation != null 
                                ? Tooltip(
                                    message: 'Stadt ausgewählt: ${_selectedLocation!.displayName}',
                                    child: Icon(Icons.check_circle, color: Colors.green, size: 20),
                                  )
                                : Icon(Icons.search, color: Colors.grey, size: 20),
                          ),
                          onChanged: (value) {
                            if (_selectedLocation != null && value != _selectedLocation!.displayName) {
                              setState(() {
                                _selectedLocation = null;
                              });
                            }
                          },
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Bitte geben Sie einen Austragungsort ein';
                            }
                            return null;
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Venue Address Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.home, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Hallenadresse',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Adresse der Sporthalle für automatische Entfernungsberechnung',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _venueStreetController,
                            decoration: const InputDecoration(
                              labelText: 'Straße',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _venueHouseNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Nr.',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 150,
                      child: TextFormField(
                        controller: _venuePlzController,
                        decoration: const InputDecoration(
                          labelText: 'PLZ',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Date and Points Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule, color: Colors.green),
                        const SizedBox(width: 12),
                        Text(
                          'Termine & Punkte',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Date selection
                    Column(
                        children: [
                          // Start Date
                          TextFormField(
                            controller: TextEditingController(
                              text: _startDate != null 
                                ? '${_startDate!.day.toString().padLeft(2, '0')}.${_startDate!.month.toString().padLeft(2, '0')}.${_startDate!.year}'
                                : ''
                            ),
                            decoration: InputDecoration(
                              labelText: 'Startdatum * (DD.MM.YYYY)',
                              border: OutlineInputBorder(),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isDateInPast(_startDate))
                                    Tooltip(
                                      message: 'Vergangenes Datum - Status wird automatisch gesetzt',
                                      child: Icon(Icons.history, color: Colors.orange, size: 20),
                                    ),
                                  IconButton(
                                    icon: Icon(Icons.calendar_today),
                                    onPressed: () => _selectStartDate(),
                                  ),
                                ],
                              ),
                            ),
                            onChanged: (value) {
                              if (value.length == 10) {
                                try {
                                  final parts = value.split('.');
                                  if (parts.length == 3) {
                                    final day = int.parse(parts[0]);
                                    final month = int.parse(parts[1]);
                                    final year = int.parse(parts[2]);
                                    final date = DateTime(year, month, day);
                                    setState(() {
                                      _startDate = date;
                                    });
                                  }
                                } catch (e) {
                                  // Invalid date format, ignore
                                }
                              }
                            },
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                              LengthLimitingTextInputFormatter(10),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // End Date
                          TextFormField(
                            controller: TextEditingController(
                              text: _endDate != null 
                                ? '${_endDate!.day.toString().padLeft(2, '0')}.${_endDate!.month.toString().padLeft(2, '0')}.${_endDate!.year}'
                                : ''
                            ),
                            decoration: InputDecoration(
                              labelText: 'Enddatum (optional) (DD.MM.YYYY)',
                              border: OutlineInputBorder(),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isDateInPast(_endDate))
                                    Tooltip(
                                      message: 'Vergangenes Datum - Status wird automatisch gesetzt',
                                      child: Icon(Icons.history, color: Colors.orange, size: 20),
                                    ),
                                  IconButton(
                                    icon: Icon(Icons.calendar_today),
                                    onPressed: () => _selectEndDate(),
                                  ),
                                ],
                              ),
                            ),
                            onChanged: (value) {
                              if (value.isEmpty) {
                                setState(() {
                                  _endDate = null;
                                });
                                return;
                              }
                              if (value.length == 10) {
                                try {
                                  final parts = value.split('.');
                                  if (parts.length == 3) {
                                    final day = int.parse(parts[0]);
                                    final month = int.parse(parts[1]);
                                    final year = int.parse(parts[2]);
                                    final date = DateTime(year, month, day);
                                    setState(() {
                                      _endDate = date;
                                    });
                                  }
                                } catch (e) {
                                  // Invalid date format, ignore
                                }
                              }
                            },
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                              LengthLimitingTextInputFormatter(10),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Playing days info
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Column(
                                  children: [
                                    Text(
                                      '${_getPlayingDays()}',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                    Text(
                                      'Spieltage',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.green.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_getPlayingDays() > 1) ...[
                                  const SizedBox(width: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '+20 Pts',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    
                    // Information banner for past tournaments
                    if (_isDateInPast(_startDate) || _isDateInPast(_endDate))
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Das Turnier liegt in der Vergangenheit. Der Status wird automatisch auf "Abgeschlossen" gesetzt.',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Column(
                      children: [
                        // Status
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                          value: _status,
                              decoration: InputDecoration(
                            labelText: 'Status *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.flag),
                                suffixIcon: _isStatusAutomaticallySet() 
                                    ? Tooltip(
                                        message: 'Status wurde automatisch basierend auf dem Datum gesetzt',
                                        child: Icon(Icons.auto_awesome, color: Colors.blue, size: 20),
                                      )
                                    : null,
                          ),
                          items: _statusOptions.map((String status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(_getStatusDisplayName(status)),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _status = newValue;
                              });
                            }
                          },
                            ),
                            if (_isStatusAutomaticallySet())
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Status automatisch gesetzt basierend auf Datum',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                        ),
                      ),
                    ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamsTab() {
    List<Team> filteredTeams = _allTeams.where((team) {
      // Filter by search query
      if (_teamSearchQuery.isNotEmpty) {
        return team.name.toLowerCase().contains(_teamSearchQuery) ||
               (team.teamManager?.toLowerCase().contains(_teamSearchQuery) ?? false) ||
               team.city.toLowerCase().contains(_teamSearchQuery);
      }
      
      return true;
    }).toList();

    return Column(
      children: [
        // Team management header and filters
        Container(
          padding: const EdgeInsets.all(24),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.group, color: Colors.blue),
                  const SizedBox(width: 12),
                  Text(
                    'Team Auswahl',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  // Demo Team Button
                  ElevatedButton.icon(
                    onPressed: _createDemoTeams,
                    icon: Icon(Icons.auto_awesome, color: Colors.white),
                    label: Text('Demo Teams erstellen', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${_selectedTeamIds.length} Teams ausgewählt',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              LayoutBuilder(
                builder: (context, constraints) {
                  // Use vertical layout on small screens to prevent overflow
                  if (constraints.maxWidth < 600) {
                    return Column(
                      children: [
                        // Search box
                        TextField(
                          controller: _teamSearchController,
                          decoration: InputDecoration(
                            hintText: 'Teams suchen...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                        ),
                      ],
                    );
                  } else {
                    // Horizontal layout for larger screens
                    return Row(
                      children: [
                        // Search box
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _teamSearchController,
                            decoration: InputDecoration(
                              hintText: 'Teams suchen...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        ),
        
        // Teams list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredTeams.isEmpty
                  ? Center(
                      child: Text(
                        _teamSearchQuery.isNotEmpty 
                            ? 'Keine Teams gefunden für "$_teamSearchQuery"'
                            : 'Keine Teams verfügbar',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: filteredTeams.length,
                      itemBuilder: (context, index) {
                        final team = filteredTeams[index];
                        final isSelected = _selectedTeamIds.contains(team.id);
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: CheckboxListTile(
                            value: isSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  _selectedTeamIds.add(team.id);
                                } else {
                                  _selectedTeamIds.remove(team.id);
                                }
                              });
                            },
                            title: Text(
                              team.name,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${team.city} â€¢ ${team.bundesland}'),
                                if (team.teamManager != null)
                                  Text('Manager: ${team.teamManager}'),
                              ],
                            ),
                            secondary: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Center(
                                child: Text(
                                  team.name.substring(0, 2).toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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

  // Category-related methods removed (single league)


  Widget _buildCourtsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.place, color: Colors.blue),
                      const SizedBox(width: 12),
                      const Text(
                        'Turnier-Plätze',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _showAddCourtDialog,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Feld / Halle hinzufügen'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Plätze, Felder und Hallen die für dieses Turnier genutzt werden.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_tournamentCourts.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.place_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Noch keine Plätze konfiguriert',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Klicken Sie auf "Feld / Halle hinzufügen" um einen Platz hinzuzufügen.',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 44),
                        const Expanded(child: Text('Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ...List.generate(_tournamentCourts.length, (index) {
                    final court = _tournamentCourts[index];
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            children: [
                              // Avatar
                              CircleAvatar(
                                backgroundColor: Colors.blue.shade100,
                                radius: 18,
                                child: Text(
                                  court.name.isNotEmpty ? court.name[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Name
                              Expanded(
                                child: Text(
                                  court.name,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                              ),
                              // Delete
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
                                tooltip: 'Entfernen',
                                onPressed: () => _removeTournamentCourt(index),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              ),
                            ],
                          ),
                        ),
                        if (index < _tournamentCourts.length - 1) const Divider(height: 1, indent: 16, endIndent: 16),
                      ],
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCourtIconOverlay() {
    if (_isEditingCourt && _selectedCourtForEditing != null) {
      // Show the court being edited
      return Center(
        child: _buildCourtIcon(
          _selectedCourtForEditing!.name,
          Colors.blue,
          isEditing: true,
        ),
      );
    } else {
      // Show preview for new court
      return Center(
        child: _buildCourtIcon(
          _courtLabel,
          Colors.green.withValues(alpha: 0.8),
          isPreview: true,
        ),
      );
    }
  }

  Widget _buildCourtIcon(String label, Color color, {bool isPreview = false, bool isEditing = false}) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              label.isNotEmpty ? label[0].toUpperCase() : 'A',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (isPreview)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 10,
                ),
              ),
            ),
          if (isEditing)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Icon(
                  Icons.edit,
                  color: Colors.white,
                  size: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Court management methods (simplified — courts are just labels now)

  void _startEditingCourt(Court court) {
    setState(() {
      _selectedCourtForEditing = court;
      _isEditingCourt = true;
      _courtNameController.text = court.name;
      _courtLabel = court.name;
    });
  }

  void _saveCourtPosition() {
    // Generate next available label
    _generateNextCourtLabel();
    _showCourtDetailsDialog();
  }

  void _updateCourtPosition() {
    if (_selectedCourtForEditing != null) {
      _showCourtUpdateDialog();
    }
  }

  void _generateNextCourtLabel() {
    Set<String> existingLabels = _allCourts.map((court) => court.name.isNotEmpty ? court.name[0].toUpperCase() : 'A').toSet();
    
    // Try letters A-Z first
    for (int i = 0; i < 26; i++) {
      String letter = String.fromCharCode(65 + i); // A=65, B=66, etc.
      if (!existingLabels.contains(letter)) {
        _courtLabel = letter;
        return;
      }
    }
    
    // If all letters used, try numbers 1-99
    for (int i = 1; i <= 99; i++) {
      String number = i.toString();
      if (!existingLabels.contains(number)) {
        _courtLabel = number;
        return;
      }
    }
    
    // Fallback to A if everything is used (unlikely)
    _courtLabel = 'A';
  }

  void _showCourtUpdateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Platz "${_selectedCourtForEditing!.name}" bearbeiten'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Name
              TextFormField(
                controller: _courtNameController,
                decoration: const InputDecoration(
                  labelText: 'Platz Name *',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _cancelCourtEditing();
            },
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () async {
              if (_courtNameController.text.trim().isEmpty) {
                toastification.show(
                  context: context,
                  type: ToastificationType.error,
                  style: ToastificationStyle.fillColored,
                  title: const Text('Fehler'),
                  description: const Text('Bitte geben Sie einen Namen ein'),
                  alignment: Alignment.topRight,
                  autoCloseDuration: const Duration(seconds: 4),
                  showProgressBar: false,
                );
                return;
              }
              
              final updatedCourt = _selectedCourtForEditing!.copyWith(
                name: _courtNameController.text.trim(),
              );
              
              final success = await _courtService.updateCourt(updatedCourt);
              
              Navigator.of(context).pop();
              _cancelCourtEditing();
              
              if (success) {
                toastification.show(
                  context: context,
                  type: ToastificationType.success,
                  style: ToastificationStyle.fillColored,
                  title: const Text('Erfolg'),
                  description: const Text('Platz erfolgreich aktualisiert'),
                  alignment: Alignment.topRight,
                  autoCloseDuration: const Duration(seconds: 3),
                  showProgressBar: false,
                );
              } else {
                toastification.show(
                  context: context,
                  type: ToastificationType.error,
                  style: ToastificationStyle.fillColored,
                  title: const Text('Fehler'),
                  description: const Text('Fehler beim Aktualisieren des Platzes'),
                  alignment: Alignment.topRight,
                  autoCloseDuration: const Duration(seconds: 4),
                  showProgressBar: false,
                );
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  void _cancelCourtEditing() {
    // Reset form
    _courtNameController.clear();
    setState(() {
      _isEditingCourt = false;
    });
  }

  void _showCourtDetailsDialog() {
    // Reset form for new court
    _courtNameController.text = _courtLabel;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Neuen Platz erstellen'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Name
              TextFormField(
                controller: _courtNameController,
                decoration: const InputDecoration(
                  labelText: 'Platz Name *',
                  border: OutlineInputBorder(),
                  hintText: 'z.B. A, B, 1, 2, etc.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_courtNameController.text.trim().isEmpty) {
                toastification.show(
                  context: context,
                  type: ToastificationType.error,
                  style: ToastificationStyle.fillColored,
                  title: const Text('Fehler'),
                  description: const Text('Bitte geben Sie einen Namen ein'),
                  alignment: Alignment.topRight,
                  autoCloseDuration: const Duration(seconds: 4),
                  showProgressBar: false,
                );
                return;
              }
              
              final court = Court(
                id: '',
                name: _courtNameController.text.trim(),
              );
              
              final courtId = await _courtService.createCourt(court);
              
              Navigator.of(context).pop();
              
              if (courtId != null) {
                toastification.show(
                  context: context,
                  type: ToastificationType.success,
                  style: ToastificationStyle.fillColored,
                  title: const Text('Erfolg'),
                  description: const Text('Platz erfolgreich erstellt'),
                  alignment: Alignment.topRight,
                  autoCloseDuration: const Duration(seconds: 3),
                  showProgressBar: false,
                );
              } else {
                toastification.show(
                  context: context,
                  type: ToastificationType.error,
                  style: ToastificationStyle.fillColored,
                  title: const Text('Fehler'),
                  description: const Text('Fehler beim Erstellen des Platzes'),
                  alignment: Alignment.topRight,
                  autoCloseDuration: const Duration(seconds: 4),
                  showProgressBar: false,
                );
              }
            },
            child: const Text('Erstellen'),
          ),
        ],
      ),
    );
  }

  Future<void> _autoSaveTournament() async {
    // Simplified save function for auto-saving gespanne and other changes
    if (widget.tournament == null) return; // Only auto-save existing tournaments
    
    try {
      // Create category brackets from current state  
      Map<String, TournamentBracket> categoryBracketsMap = {};
      
      for (String category in _categoryPools.keys) {
        final poolNames = _categoryPools[category] ?? [];
        Map<String, List<String>> pools = {};
        Map<String, bool> poolIsFunBracket = {};
        
        // Convert pool data to the format expected by TournamentBracket
        for (String poolName in poolNames) {
          final poolId = '${category}_$poolName';
          pools[poolId] = _poolTeams[poolId] ?? [];
          poolIsFunBracket[poolId] = _poolIsFunBracket[poolId] ?? false;
        }
        
        categoryBracketsMap[category] = TournamentBracket(
          pools: pools,
          poolIsFunBracket: poolIsFunBracket,
          knockoutRounds: _categoryBrackets[category] ?? [],
        );
      }
      
      // Create custom brackets from current state
      Map<String, CustomBracketStructure> customBrackets = {};
      for (String category in _categoryCustomBrackets.keys) {
        final now = DateTime.now();
        customBrackets[category] = CustomBracketStructure(
          nodes: _categoryCustomBrackets[category] ?? [],
          divisionName: category,
          createdAt: now,
          updatedAt: now,
        );
      }
      
      // Update tournament with current data
      final tournament = Tournament(
        id: widget.tournament!.id,
        name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : widget.tournament!.name,
        description: _descriptionController.text.trim(),
        imageUrl: _imageUrlController.text.trim().isNotEmpty ? _imageUrlController.text.trim() : null,
        location: _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : widget.tournament!.location,
        startDate: _startDate ?? widget.tournament!.startDate,
        endDate: _endDate ?? widget.tournament!.endDate,
        status: _status,
        teamIds: _selectedTeamIds,
        refereeInvitations: _refereeInvitations.values.toList(),
        delegateIds: _selectedDelegateIds,
        refereeGespanne: _refereeGespanne,
        divisionBrackets: categoryBracketsMap,
        customBrackets: customBrackets,
        courts: _tournamentCourts,
        isRegistrationOpen: _isRegistrationOpen,
        registrationDeadline: _registrationDeadline,
        tournamentOrganizerId: _selectedTournamentOrganizerId,
        results: widget.tournament!.results,
        pools: widget.tournament!.pools,
        poolMetadata: widget.tournament!.poolMetadata,
        approvalStatus: _approvalStatus,
        approvedBy: _approvalStatus == 'pending_approval' ? null : widget.tournament!.approvedBy,
        approvedAt: _approvalStatus == 'pending_approval' ? null : widget.tournament!.approvedAt,
        rejectionReason: widget.tournament!.rejectionReason,
        hostClubTeamId: _hostClubTeamId,
        sponsorLogos: _sponsorLogos,
        livestreamEnabled: _livestreamEnabled,
        livestreamUrl: _livestreamUrlController.text.trim().isNotEmpty
            ? _livestreamUrlController.text.trim()
            : null,
        livestreamYoutubeBroadcastId: _livestreamYoutubeBroadcastId,
        venueStreet: _venueStreetController.text.trim().isNotEmpty ? _venueStreetController.text.trim() : null,
        venueHouseNumber: _venueHouseNumberController.text.trim().isNotEmpty ? _venueHouseNumberController.text.trim() : null,
        venuePlz: _venuePlzController.text.trim().isNotEmpty ? _venuePlzController.text.trim() : null,
        venueLatitude: widget.tournament!.venueLatitude,
        venueLongitude: widget.tournament!.venueLongitude,
        kampfgerichtInvitations: _selectedKampfgerichtIds.map((memberId) {
          KampfgerichtInvitation? existing;
          try {
            existing = widget.tournament!.kampfgerichtInvitations
                .firstWhere((inv) => inv.memberId == memberId);
          } catch (e) {}
          return KampfgerichtInvitation(
            memberId: memberId,
            status: existing?.status ?? 'pending',
            respondedAt: existing?.respondedAt,
            notes: existing?.notes,
            availableFrom: existing?.availableFrom,
            availableUntil: existing?.availableUntil,
            isFullDay: existing?.isFullDay ?? true,
          );
        }).toList(),
      );
      
      // Update existing tournament
      await _tournamentService.updateTournament(tournament);
      
    } catch (e) {
      debugPrint('Error auto-saving tournament: $e');
      // Don't show error to user for auto-save failures
    }
  }

  void _saveTournament() async {
    debugPrint('Save tournament called');
    
    // Only validate form if we're currently on the basic tab or if it's not valid
    // This prevents unnecessary navigation to basic tab when saving from other tabs
    bool isBasicDataValid = true;
    
    // Check if basic required fields are filled
    if (_nameController.text.trim().isEmpty) {
      isBasicDataValid = false;
    }
    
    // If basic data is not valid, navigate to basic tab and validate
    if (!isBasicDataValid) {
      debugPrint('Basic data validation failed');
      setState(() {
        _selectedTab = 'basic';
      });
      
      // Wait for tab to switch and then validate the form
      await Future.delayed(const Duration(milliseconds: 100));
      
      if (_formKey.currentState?.validate() != true) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          title: const Text('Validierungsfehler'),
          description: const Text('Bitte füllen Sie alle Pflichtfelder in den Grunddaten aus'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 4),
          showProgressBar: false,
        );
        return;
      }
    } else {
      // If we're on basic tab, validate the form
      if (_selectedTab == 'basic' && _formKey.currentState?.validate() != true) {
        debugPrint('Form validation failed on basic tab');
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          title: const Text('Validierungsfehler'),
          description: const Text('Bitte füllen Sie alle Pflichtfelder in den Grunddaten aus'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 4),
          showProgressBar: false,
        );
        return;
      }
    }

    if (_startDate == null) {
      debugPrint('No start date selected');
      // Navigate to basic data tab to show date selection
      setState(() {
        _selectedTab = 'basic';
      });
      toastification.show(
        context: context,
        type: ToastificationType.warning,
        style: ToastificationStyle.fillColored,
        title: const Text('Warnung'),
        description: const Text('Bitte wählen Sie ein Startdatum aus'),
        alignment: Alignment.topRight,
        autoCloseDuration: const Duration(seconds: 4),
        showProgressBar: false,
      );
      return;
    }

    debugPrint('Validation passed, starting save process');

    setState(() {
      _isSaving = true;
    });

    debugPrint('Starting save operation');

    try {
      debugPrint('Building category brackets...');
      // Create custom brackets from current state
      Map<String, CustomBracketStructure> customBrackets = {};
      for (String category in _categoryCustomBrackets.keys) {
        final now = DateTime.now();
        customBrackets[category] = CustomBracketStructure(
          nodes: _categoryCustomBrackets[category] ?? [],
          divisionName: category,
          createdAt: now,
          updatedAt: now,
        );
      }
      
      debugPrint('Custom brackets created');
      
      // Create or update tournament
      final tournament = Tournament(
        id: widget.tournament?.id ?? '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrl: _imageUrlController.text.trim().isNotEmpty ? _imageUrlController.text.trim() : null,
        location: _locationController.text.trim(),
        startDate: _startDate!,
        endDate: _endDate,
        status: _status,
        teamIds: _selectedTeamIds,
        refereeInvitations: _refereeInvitations.values.toList(),
        delegateIds: _selectedDelegateIds,
        refereeGespanne: _refereeGespanne,
        divisionBrackets: widget.tournament?.divisionBrackets ?? {},
        customBrackets: customBrackets,
        courts: _tournamentCourts,
        isRegistrationOpen: _isRegistrationOpen,
        registrationDeadline: _registrationDeadline,
        tournamentOrganizerId: _selectedTournamentOrganizerId,
        links: _links,
        approvalStatus: _approvalStatus,
        approvedBy: _approvalStatus == 'pending_approval' ? null : widget.tournament?.approvedBy,
        approvedAt: _approvalStatus == 'pending_approval' ? null : widget.tournament?.approvedAt,
        rejectionReason: widget.tournament?.rejectionReason,
        hostClubTeamId: _hostClubTeamId,
        sponsorLogos: _sponsorLogos,
        livestreamEnabled: _livestreamEnabled,
        livestreamUrl: _livestreamUrlController.text.trim().isNotEmpty
            ? _livestreamUrlController.text.trim()
            : null,
        livestreamYoutubeBroadcastId: _livestreamYoutubeBroadcastId,
        venueStreet: _venueStreetController.text.trim().isNotEmpty ? _venueStreetController.text.trim() : null,
        venueHouseNumber: _venueHouseNumberController.text.trim().isNotEmpty ? _venueHouseNumberController.text.trim() : null,
        venuePlz: _venuePlzController.text.trim().isNotEmpty ? _venuePlzController.text.trim() : null,
        venueLatitude: widget.tournament?.venueLatitude,
        venueLongitude: widget.tournament?.venueLongitude,
        kampfgerichtInvitations: _selectedKampfgerichtIds.map((memberId) {
          KampfgerichtInvitation? existing;
          if (widget.tournament != null) {
            try {
              existing = widget.tournament!.kampfgerichtInvitations
                  .firstWhere((inv) => inv.memberId == memberId);
            } catch (e) {}
          }
          return KampfgerichtInvitation(
            memberId: memberId,
            status: existing?.status ?? 'pending',
            respondedAt: existing?.respondedAt,
            notes: existing?.notes,
            availableFrom: existing?.availableFrom,
            availableUntil: existing?.availableUntil,
            isFullDay: existing?.isFullDay ?? true,
          );
        }).toList(),
      );
      
      debugPrint('Tournament object created with ${tournament.links.length} links');
      debugPrint('Links: ${tournament.links.map((l) => '${l.label} (${l.type})').join(', ')}');
      
      // Save using tournament service
      if (widget.tournament == null) {
        debugPrint('Creating new tournament...');
        // Creating new tournament
        await _tournamentService.addTournament(tournament);
        debugPrint('New tournament created');
      } else {
        debugPrint('Updating existing tournament...');
        // Updating existing tournament
        await _tournamentService.updateTournament(tournament);
        debugPrint('Tournament updated');
      }
      
      setState(() {
        _isSaving = false;
      });
      
      debugPrint('Save operation completed successfully');
      
      if (widget.tournament == null) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          title: const Text('Erfolg'),
          description: const Text('Turnier erfolgreich erstellt'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 3),
          showProgressBar: false,
        );
      } else {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          title: const Text('Erfolg'),
          description: const Text('Turnier erfolgreich gespeichert'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 3),
          showProgressBar: false,
        );
      }
      
      // Auto-write Ligapunkte when tournament is completed
      if (_status == 'completed' && widget.tournament != null) {
        await _autoWriteLigapunkte(widget.tournament!.id, _nameController.text.trim(), _hostClubTeamId);
      }

      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Error during save: $e');
      setState(() {
        _isSaving = false;
      });
      
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        title: const Text('Fehler'),
        description: Text('Fehler beim Speichern: $e'),
        alignment: Alignment.topRight,
        autoCloseDuration: const Duration(seconds: 5),
        showProgressBar: false,
      );
    }
  }

  /// Compute ranking from completed games and write Ligapunkte to each team's pointsHistory.
  Future<void> _autoWriteLigapunkte(String tournamentId, String tournamentName, [String? hostClubTeamId]) async {
    try {
      // Load games
      await _gameService.preloadGames(tournamentId);
      final games = _gameService.getGamesForTournamentSync(tournamentId);
      if (games.isEmpty) return;

      // Build stats map identical to _buildTeamsRankingTable in detail screen
      final Map<String, _LPTeamStats> statsMap = {};

      for (final game in games) {
        if (game.teamAId != null && game.teamAId!.isNotEmpty) {
          statsMap.putIfAbsent(game.teamAId!, () => _LPTeamStats(id: game.teamAId!, name: game.teamAName));
        }
        if (game.teamBId != null && game.teamBId!.isNotEmpty) {
          statsMap.putIfAbsent(game.teamBId!, () => _LPTeamStats(id: game.teamBId!, name: game.teamBName));
        }

        if (game.result == null || game.status != GameStatus.completed) continue;
        final r = game.result!;
        final aId = game.teamAId;
        final bId = game.teamBId;
        if (aId == null || bId == null) continue;

        final sA = statsMap[aId];
        final sB = statsMap[bId];
        if (sA == null || sB == null) continue;

        sA.played++;
        sB.played++;
        sA.goalsFor += r.teamAScore;
        sA.goalsAgainst += r.teamBScore;
        sB.goalsFor += r.teamBScore;
        sB.goalsAgainst += r.teamAScore;

        if (r.winnerId != null && r.winnerId!.isNotEmpty) {
          if (r.winnerId == aId) { sA.wins++; sB.losses++; }
          else if (r.winnerId == bId) { sB.wins++; sA.losses++; }
          else { sA.draws++; sB.draws++; }
        } else if (r.teamAScore > r.teamBScore) {
          sA.wins++; sB.losses++;
        } else if (r.teamBScore > r.teamAScore) {
          sB.wins++; sA.losses++;
        } else {
          sA.draws++; sB.draws++;
        }
      }

      if (statsMap.isEmpty) return;

      // Head-to-head helper
      int h2h(String idA, String idB) {
        int winsA = 0, winsB = 0;
        for (final g in games) {
          if (g.result == null || g.status != GameStatus.completed) continue;
          final isMatch = (g.teamAId == idA && g.teamBId == idB) || (g.teamAId == idB && g.teamBId == idA);
          if (!isMatch) continue;
          final r = g.result!;
          String? winner;
          if (r.winnerId != null && r.winnerId!.isNotEmpty) {
            winner = r.winnerId;
          } else if (r.teamAScore > r.teamBScore) {
            winner = g.teamAId;
          } else if (r.teamBScore > r.teamAScore) {
            winner = g.teamBId;
          }
          if (winner == idA) winsA++;
          if (winner == idB) winsB++;
        }
        if (winsA > winsB) return -1;
        if (winsB > winsA) return 1;
        return 0;
      }

      bool anyTiebreaker = false;

      final sorted = statsMap.values.toList()
        ..sort((a, b) {
          final pCmp = b.points.compareTo(a.points);
          if (pCmp != 0) return pCmp;
          final h2hCmp = h2h(a.id, b.id);
          if (h2hCmp != 0) return h2hCmp;
          final dCmp = b.goalDiff.compareTo(a.goalDiff);
          if (dCmp != 0) return dCmp;
          anyTiebreaker = true;
          return a.name.compareTo(b.name);
        });

      if (anyTiebreaker) {
        debugPrint('Ligapunkte NOT written — Entscheidungsspiel required');
        return;
      }

      final totalTeams = sorted.length;

      // Write Ligapunkte to each team
      for (int i = 0; i < sorted.length; i++) {
        final placement = i + 1;
        final isHostClub = hostClubTeamId != null && sorted[i].id == hostClubTeamId;
        final ligaPunkte = (totalTeams - placement + 1) + (isHostClub ? 3 : 0);
        final teamId = sorted[i].id;

        // Fetch fresh team data
        final team = await _teamService.getTeamById(teamId);
        if (team == null) continue;

        final pointsEntry = {
          'tournamentId': tournamentId,
          'tournamentName': tournamentName,
          'placement': placement,
          'points': ligaPunkte,
          'date': DateTime.now().toIso8601String(),
          if (isHostClub) 'hostClubBonus': 3,
        };

        final updatedHistory = List<Map<String, dynamic>>.from(team.pointsHistory);
        updatedHistory.removeWhere((e) => e['tournamentId'] == tournamentId);
        updatedHistory.add(pointsEntry);

        // Best 3 total
        final sortedPts = List<Map<String, dynamic>>.from(updatedHistory)
          ..sort((a, b) => ((b['points'] as int?) ?? 0).compareTo((a['points'] as int?) ?? 0));
        final best3 = sortedPts.take(3).fold<int>(0, (sum, e) => sum + ((e['points'] as int?) ?? 0));

        final updatedTeam = Team(
          id: team.id,
          name: team.name,
          clubName: team.clubName,
          teamManager: team.teamManager,
          logoUrl: team.logoUrl,
          city: team.city,
          bundesland: team.bundesland,
          coachName: team.coachName,
          coachEmail: team.coachEmail,
          rosterPlayerIds: team.rosterPlayerIds,
          totalPoints: best3,
          pointsHistory: updatedHistory,
          createdAt: team.createdAt,
        );

        await _teamService.updateTeam(team.id, updatedTeam);
      }

      debugPrint('Ligapunkte written for $totalTeams teams');
    } catch (e) {
      debugPrint('Error writing Ligapunkte: $e');
      // Non-fatal — tournament was already saved successfully
    }
  }

  // Missing methods
  void _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('de'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        _startDate = date;
        _updateStatusBasedOnDate();
      });
    }
  }

  void _selectEndDate() async {
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte wählen Sie zuerst ein Startdatum'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate!,
      firstDate: _startDate!,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('de'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        _endDate = date;
        _updateStatusBasedOnDate();
      });
    }
  }

  void _updateStatusBasedOnDate() {
    final now = DateTime.now();
    final currentDate = DateTime(now.year, now.month, now.day); // Remove time component
    
    if (_startDate != null) {
      final startDateOnly = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      final endDateOnly = _endDate != null 
          ? DateTime(_endDate!.year, _endDate!.month, _endDate!.day)
          : startDateOnly;
      
      if (endDateOnly.isBefore(currentDate)) {
        // Tournament is completely in the past
        _status = 'completed';
      } else if (startDateOnly.isAtSameMomentAs(currentDate) || 
                 (startDateOnly.isBefore(currentDate) && endDateOnly.isAfter(currentDate.subtract(const Duration(days: 1))))) {
        // Tournament is happening now
        _status = 'ongoing';
      } else if (startDateOnly.isAfter(currentDate)) {
        // Tournament is in the future
        _status = 'upcoming';
      }
    }
  }

  Future<void> _revertToDraft() async {
    if (widget.tournament == null) return;
    setState(() {
      _approvalStatus = 'pending_approval';
    });
    try {
      final updated = widget.tournament!.copyWith(
        approvalStatus: 'pending_approval',
        approvedBy: null,
        approvedAt: null,
      );
      await _tournamentService.updateTournament(updated);
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          title: const Text('Turnier zurückgesetzt'),
          description: const Text('Das Turnier wurde zurück in den Entwurf-Status versetzt'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          title: const Text('Fehler'),
          description: Text('Fehler beim Zurücksetzen: $e'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    }
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'upcoming':
        return 'Bevorstehend';
      case 'ongoing':
        return 'Laufend';
      case 'completed':
        return 'Abgeschlossen';
      default:
        return status;
    }
  }

  Color _getLeagueColor() {
    return Colors.blue;
  }

  Widget _buildRefereesTab() {
    return Column(
      children: [
        // Sub-navigation
        Container(
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _refereeSubTab = 'selection'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    decoration: BoxDecoration(
                      color: _refereeSubTab == 'selection' ? Colors.purple : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sports_hockey,
                          color: _refereeSubTab == 'selection' ? Colors.white : Colors.grey.shade600,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Auswählen (${_refereeInvitations.length})',
                            style: TextStyle(
                              color: _refereeSubTab == 'selection' ? Colors.white : Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _refereeSubTab = 'gespanne'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    decoration: BoxDecoration(
                      color: _refereeSubTab == 'gespanne' ? Colors.indigo : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.group,
                          color: _refereeSubTab == 'gespanne' ? Colors.white : Colors.grey.shade600,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Gespanne (${_refereeGespanne.length})',
                            style: TextStyle(
                              color: _refereeSubTab == 'gespanne' ? Colors.white : Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _refereeSubTab = 'planner'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    decoration: BoxDecoration(
                      color: _refereeSubTab == 'planner' ? Colors.deepPurple : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.drag_handle,
                          color: _refereeSubTab == 'planner' ? Colors.white : Colors.grey.shade600,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Planer',
                            style: TextStyle(
                              color: _refereeSubTab == 'planner' ? Colors.white : Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Content based on selected sub-tab
        Expanded(
          child: _refereeSubTab == 'selection' 
            ? _buildRefereeSelectionContent()
            : _refereeSubTab == 'gespanne'
              ? _buildRefereeGespanneContent()
              : _buildRefereePlannerContent(),
        ),
      ],
    );
  }

  Widget _buildRefereeSelectionContent() {
    final filteredReferees = _allReferees.where((referee) {
      if (_refereeSearchQuery.isEmpty) return true;
      final query = _refereeSearchQuery.toLowerCase();
      return referee.firstName.toLowerCase().contains(query) ||
             referee.lastName.toLowerCase().contains(query) ||
             referee.email.toLowerCase().contains(query) ||
             referee.licenseType.toLowerCase().contains(query) ||
             (referee.city?.toLowerCase().contains(query) ?? false);
    }).toList();

    // Sort: invited referees first, then by name
    filteredReferees.sort((a, b) {
      final aInvited = _refereeInvitations.containsKey(a.id);
      final bInvited = _refereeInvitations.containsKey(b.id);
      if (aInvited != bInvited) return aInvited ? -1 : 1;
      return a.fullName.compareTo(b.fullName);
    });

    // Status summary counts
    final notContactedCount = _refereeInvitations.values.where((i) => i.isNotContacted).length;
    final contactedCount = _refereeInvitations.values.where((i) => i.isContacted).length;
    final acceptedCount = _refereeInvitations.values.where((i) => i.isAccepted).length;
    final declinedCount = _refereeInvitations.values.where((i) => i.isDeclined).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.sports, color: Colors.purple, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Schiedsrichter verwalten',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Klicken Sie auf einen Schiedsrichter um den Status zu ändern',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  // Search field
                  TextField(
                    controller: _refereeSearchController,
                    decoration: const InputDecoration(
                      labelText: 'Schiedsrichter suchen',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Status summary chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildStatusChip('Nicht kontaktiert', notContactedCount, RefereeInvitation.statusColor('not_contacted')),
                      _buildStatusChip('Kontaktiert', contactedCount, RefereeInvitation.statusColor('contacted')),
                      _buildStatusChip('Zugesagt', acceptedCount, RefereeInvitation.statusColor('accepted')),
                      _buildStatusChip('Abgesagt', declinedCount, RefereeInvitation.statusColor('declined')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Referees list
          if (filteredReferees.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Keine Schiedsrichter gefunden',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ...filteredReferees.map((referee) {
              final invitation = _refereeInvitations[referee.id];
              final isInvited = invitation != null;
              final currentStatus = invitation?.status ?? 'not_contacted';
              final statusColor = RefereeInvitation.statusColor(currentStatus);

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isInvited
                    ? BorderSide(color: statusColor, width: 2)
                    : BorderSide.none,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showRefereeStatusDialog(referee),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Status indicator
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isInvited
                              ? RefereeInvitation.statusIcon(currentStatus)
                              : Icons.person_add_alt_1,
                            color: isInvited ? statusColor : Colors.grey,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Name, email, license
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                referee.fullName,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                referee.email,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  // License badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      referee.licenseType,
                                      style: TextStyle(fontSize: 11, color: Colors.purple[700], fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  if (referee.city != null && referee.city!.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Icon(Icons.location_on, size: 13, color: Colors.grey.shade500),
                                    const SizedBox(width: 2),
                                    Flexible(
                                      child: Text(
                                        referee.city!,
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Distance + status badge column
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (isInvited)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  RefereeInvitation.statusLabel(currentStatus),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
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
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _showRefereeStatusDialog(Referee referee) {
    final currentInvitation = _refereeInvitations[referee.id];
    final isCurrentlyInvited = currentInvitation != null;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(referee.fullName),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status options
              ...RefereeInvitation.statusValues.map((status) {
                final color = RefereeInvitation.statusColor(status);
                final isSelected = currentInvitation?.status == status;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          _refereeInvitations[referee.id] = RefereeInvitation(
                            refereeId: referee.id,
                            status: status,
                            respondedAt: DateTime.now(),
                            notes: currentInvitation?.notes,
                            availableFrom: currentInvitation?.availableFrom,
                            availableUntil: currentInvitation?.availableUntil,
                            isFullDay: currentInvitation?.isFullDay ?? true,
                          );
                        });
                        Navigator.of(ctx).pop();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Icon(RefereeInvitation.statusIcon(status), color: color, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                RefereeInvitation.statusLabel(status),
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: color,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check, color: color, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const Divider(),
              // Remove option
              if (isCurrentlyInvited)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() {
                        _refereeInvitations.remove(referee.id);
                      });
                      Navigator.of(ctx).pop();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.remove_circle_outline, color: Colors.red.shade400, size: 22),
                          const SizedBox(width: 12),
                          Text(
                            'Vom Turnier entfernen',
                            style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w500, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Schließen'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDelegateSelectionContent() {
    final filteredDelegates = _allDelegates.where((delegate) {
      if (_delegateSearchQuery.isEmpty) return true;
      final query = _delegateSearchQuery.toLowerCase();
      return delegate.firstName.toLowerCase().contains(query) ||
             delegate.lastName.toLowerCase().contains(query) ||
             delegate.email.toLowerCase().contains(query) ||
             delegate.licenseType.toLowerCase().contains(query);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_pin, color: Colors.orange, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Delegierte verwalten',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Wählen Sie Delegierte für dieses Turnier aus',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Search field
                  TextField(
                    controller: _delegateSearchController,
                    decoration: const InputDecoration(
                      labelText: 'Delegierte suchen',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Selected count
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Ausgewählte Delegierte: ${_selectedDelegateIds.length}',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Delegates list
          if (filteredDelegates.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Keine Delegierte gefunden',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ...filteredDelegates.map((delegate) {
              final isSelected = _selectedDelegateIds.contains(delegate.id);
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: CheckboxListTile(
                  title: Text(
                    delegate.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        delegate.email,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          delegate.licenseType,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  value: isSelected,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedDelegateIds.add(delegate.id);
                      } else {
                        _selectedDelegateIds.remove(delegate.id);
                      }
                    });
                  },
                  contentPadding: const EdgeInsets.all(16),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildRefereeGespanneContent() {
    // Get available referees (those selected for the tournament)
    final availableReferees = _allReferees.where((referee) => 
      _refereeInvitations.containsKey(referee.id)
    ).toList();

    // Get referees that are already in gespanne
    final assignedRefereeIds = <String>{};
    for (final gespann in _refereeGespanne) {
      assignedRefereeIds.add(gespann['referee1Id'] as String);
      assignedRefereeIds.add(gespann['referee2Id'] as String);
    }

    final unassignedReferees = availableReferees.where((referee) => 
      !assignedRefereeIds.contains(referee.id)
    ).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.group, color: Colors.indigo, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Schiedsrichter Gespanne verwalten',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Erstellen Sie Schiedsrichter-Gespanne für Handball-Spiele',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Create new gespann button
                  if (unassignedReferees.length >= 2)
                    ElevatedButton.icon(
                      onPressed: () => _showCreateGespannDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Neues Gespann erstellen'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade600, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Mindestens 2 verfügbare Schiedsrichter benötigt. Wählen Sie zuerst Schiedsrichter im "Schiedsrichter" Tab aus.',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Statistics
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Gespanne: ${_refereeGespanne.length}',
                          style: TextStyle(
                            color: Colors.indigo.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Zugewiesene: ${assignedRefereeIds.length}',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Verfügbare: ${unassignedReferees.length}',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Existing gespanne
          if (_refereeGespanne.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.group_off,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Keine Schiedsrichter-Gespanne erstellt',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Erstellen Sie Ihr erstes Gespann für das Turnier',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ...List.generate(_refereeGespanne.length, (index) {
              final gespann = _refereeGespanne[index];
              final referee1 = _allReferees.firstWhere(
                (r) => r.id == gespann['referee1Id'], 
                orElse: () => Referee(
                  id: '', 
                  firstName: 'Unbekannt', 
                  lastName: '', 
                  email: '', 
                  licenseType: '', 
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now()
                ),
              );
              final referee2 = _allReferees.firstWhere(
                (r) => r.id == gespann['referee2Id'], 
                orElse: () => Referee(
                  id: '', 
                  firstName: 'Unbekannt', 
                  lastName: '', 
                  email: '', 
                  licenseType: '', 
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now()
                ),
              );

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Gespann icon
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.group,
                          color: Colors.indigo.shade600,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Gespann details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              gespann['name'] as String,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                // Referee 1
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.blue.shade200),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Schiedsrichter 1',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.blue.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          referee1.fullName,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          referee1.licenseType,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Referee 2
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.green.shade200),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Schiedsrichter 2',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.green.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          referee2.fullName,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          referee2.licenseType,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
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
                      
                      // Actions
                      Column(
                        children: [
                          IconButton(
                            onPressed: () => _editGespann(index),
                            icon: Icon(Icons.edit, color: Colors.blue.shade600),
                            tooltip: 'Gespann bearbeiten',
                          ),
                          IconButton(
                            onPressed: () => _deleteGespann(index),
                            icon: Icon(Icons.delete, color: Colors.red.shade600),
                            tooltip: 'Gespann löschen',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRefereeAllocationContent() {
    return FutureBuilder<List<Game>>(
      key: _refereePlannerKey, // Use key to force rebuilds
      future: _loadGamesForAllocation(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Fehler beim Laden der Spiele: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final games = snapshot.data ?? [];
        
        return SingleChildScrollView(
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.assignment, color: Colors.teal),
                          const SizedBox(width: 12),
                          Text(
                            'Gespanne zu Spielen zuordnen',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ordnen Sie Schiedsrichter-Gespanne den Spielen zu',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Statistics
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Spiele gesamt: ${games.length}',
                              style: TextStyle(
                                color: Colors.teal.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Zugeordnet: ${games.where((g) => g.refereeGespannId != null).length}',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Offen: ${games.where((g) => g.refereeGespannId == null).length}',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Games table
              if (games.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.sports_soccer,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Keine Spiele vorhanden',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Erstellen Sie zuerst Spiele im "Spiele" Tab',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                _buildGamesAllocationTable(games),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGamesAllocationTable(List<Game> games) {
    // Group games by type like in tournament games screen
    final poolGames = games.where((g) => g.gameType == GameType.pool).toList();
    final eliminationGames = games.where((g) => g.gameType == GameType.elimination).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pool Games
        if (poolGames.isNotEmpty) ...[
          Text(
            'Gruppenphase',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...poolGames.map((game) => _buildGameAllocationCard(game)),
          const SizedBox(height: 32),
        ],

        // Elimination Games
        if (eliminationGames.isNotEmpty) ...[
          Text(
            'K.O.-Phase',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...eliminationGames.map((game) => _buildGameAllocationCard(game)),
        ],
      ],
    );
  }

  Widget _buildGameAllocationCard(Game game) {
    final assignedGespann = _refereeGespanne.firstWhere(
      (g) => g['referee1Id'] + '_' + g['referee2Id'] == game.refereeGespannId,
      orElse: () => <String, dynamic>{},
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: assignedGespann.isNotEmpty 
            ? Colors.green.withValues(alpha: 0.3)
            : Colors.orange.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Game Header
            Row(
              children: [
                // Game Type Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: game.gameType == GameType.pool 
                        ? Colors.blue.withValues(alpha: 0.2)
                        : Colors.purple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    game.gameType == GameType.pool 
                        ? 'Gruppe ${game.poolId?.toUpperCase() ?? ''}' 
                        : 'K.O.-Phase',
                    style: TextStyle(
                      color: game.gameType == GameType.pool 
                          ? Colors.blue.shade700 
                          : Colors.purple.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                // Assignment Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: assignedGespann.isNotEmpty
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        assignedGespann.isNotEmpty ? Icons.check_circle : Icons.warning,
                        size: 14,
                        color: assignedGespann.isNotEmpty 
                          ? Colors.green.shade600 
                          : Colors.orange.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        assignedGespann.isNotEmpty 
                          ? assignedGespann['name'] ?? 'Gespann'
                          : 'Nicht zugeordnet',
                        style: TextStyle(
                          color: assignedGespann.isNotEmpty 
                            ? Colors.green.shade700 
                            : Colors.orange.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Teams
            Row(
              children: [
                // Team A
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatTeamName(game.teamAName),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (game.isPlaceholder) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Wird automatisch bestimmt',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // VS
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'vs',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),

                // Team B
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatTeamName(game.teamBName),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (game.isPlaceholder) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Wird automatisch bestimmt',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Assignment Controls
            Row(
              children: [
                // Schedule info
                if (game.scheduledTime != null) ...[
                  Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${game.scheduledTime!.day}.${game.scheduledTime!.month}.${game.scheduledTime!.year} ${game.scheduledTime!.hour.toString().padLeft(2, '0')}:${game.scheduledTime!.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                
                // Assignment dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: game.refereeGespannId,
                    decoration: InputDecoration(
                      labelText: 'Gespann zuordnen',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Kein Gespann'),
                      ),
                      ..._refereeGespanne.map((gespann) {
                        final gespannId = gespann['referee1Id'] + '_' + gespann['referee2Id'];
                        return DropdownMenuItem<String>(
                          value: gespannId,
                          child: Text(gespann['name'] ?? 'Gespann'),
                        );
                      }).toList(),
                    ],
                    onChanged: (String? newGespannId) {
                      _assignGespannToGame(game, newGespannId);
                    },
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Clear button
                if (assignedGespann.isNotEmpty)
                  IconButton(
                    onPressed: () => _assignGespannToGame(game, null),
                    icon: const Icon(Icons.clear),
                    tooltip: 'Zuordnung entfernen',
                    color: Colors.red,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTeamName(String teamName) {
    // Format team names similar to tournament games screen
    return teamName;
  }

  Future<List<Game>> _loadGamesForAllocation() async {
    // Load games for the current tournament using the new subcollection structure
    final tournamentId = widget.tournament?.id ?? '';
    if (tournamentId.isEmpty) return [];
    
    // Preload games to ensure cache is populated
    await _gameService.preloadGames(tournamentId);
    
    // Get games from cache first, then fall back to stream
    final cachedGames = _gameService.getGamesForTournamentSync(tournamentId);
    if (cachedGames.isNotEmpty) {
      return cachedGames;
    }
    
    // If cache is empty, wait for stream data
    final gamesStream = _gameService.getGamesForTournament(tournamentId);
    return gamesStream.first; // Get the first emission from the stream
  }

  void _assignGespannToGame(Game game, String? gespannId) async {
    try {
      // Update the game with the new gespann assignment
      final updatedGame = game.copyWith(
        refereeGespannId: gespannId,
        updatedAt: DateTime.now(),
      );
      
      // Update the game in the service
      await _gameService.updateGame(updatedGame);
      
      // Clear the game cache to force fresh data
      _gameService.clearCache();
      
      // Auto-save the tournament with updated gespann assignments  
      await _autoSaveTournament();
      
      // Force refresh the UI by triggering a rebuild
      setState(() {
        // This will cause the FutureBuilder to rebuild with fresh data
        _refereePlannerKey = UniqueKey();
      });
      
      // Show feedback with toastification
      final gespannName = gespannId != null 
        ? _refereeGespanne.firstWhere(
            (g) => g['referee1Id'] + '_' + g['referee2Id'] == gespannId,
            orElse: () => {'name': 'Unbekanntes Gespann'},
          )['name']
        : null;
      
      toastification.show(
        context: context,
        type: gespannId != null ? ToastificationType.success : ToastificationType.warning,
        style: ToastificationStyle.fillColored,
        title: Text(gespannId != null ? 'Gespann zugeordnet' : 'Gespann entfernt'),
        description: Text(
          gespannId != null 
            ? 'Gespann "$gespannName" zu "${game.displayName}" zugeordnet'
            : 'Gespann-Zuordnung für "${game.displayName}" entfernt',
        ),
        alignment: Alignment.topRight,
        autoCloseDuration: const Duration(seconds: 3),
        showProgressBar: false,
      );
    } catch (e) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        title: const Text('Fehler'),
        description: Text('Fehler beim Zuordnen: $e'),
        alignment: Alignment.topRight,
        autoCloseDuration: const Duration(seconds: 4),
        showProgressBar: false,
      );
    }
  }

  Widget _buildRefereePlannerContent() {
    return FutureBuilder<List<Game>>(
      key: _refereePlannerKey, // Use key to force rebuilds
      future: _loadGamesForAllocation(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Fehler beim Laden der Spiele: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final games = snapshot.data ?? [];
        
        return SingleChildScrollView(
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.drag_handle, color: Colors.deepPurple),
                          const SizedBox(width: 12),
                          Text(
                            'Schiedsrichter-Planer',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ziehen Sie Gespanne per Drag & Drop auf die Spiele',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Statistics
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Spiele gesamt: ${games.length}',
                              style: TextStyle(
                                color: Colors.deepPurple.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Zugeordnet: ${games.where((g) => g.refereeGespannId != null).length}',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Offen: ${games.where((g) => g.refereeGespannId == null).length}',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Main planner layout
              if (games.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.sports_soccer,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Keine Spiele vorhanden',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Erstellen Sie zuerst Spiele im "Spiele" Tab',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                _buildRefereePlannerLayout(games),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRefereePlannerLayout(List<Game> games) {
    return SizedBox(
      height: 800, // Provide a fixed height to avoid unbounded constraints
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Available referee pairs on the left
          SizedBox(
            width: 300, // Fixed width for the referee pairs panel
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Verfügbare Gespanne',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_refereeGespanne.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.group_off,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Keine Gespanne vorhanden',
                                style: TextStyle(color: Colors.grey.shade600),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Erstellen Sie Gespanne im "Gespanne" Tab',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _refereeGespanne.map((gespann) => _buildDraggableGespann(gespann)).toList(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Main scheduling table on the right
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Schiedsrichter-Zuordnung',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _buildRefereeSchedulingTable(games),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableGespann(Map<String, dynamic> gespann) {
    final gespannId = gespann['referee1Id'] + '_' + gespann['referee2Id'];
    final gespannName = gespann['name'] ?? 'Gespann';
    
    // Get referee names
    final referee1 = _allReferees.firstWhere(
      (r) => r.id == gespann['referee1Id'],
      orElse: () => Referee(
        id: '',
        firstName: 'Unbekannt',
        lastName: '',
        email: '',
        licenseType: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    
    final referee2 = _allReferees.firstWhere(
      (r) => r.id == gespann['referee2Id'],
      orElse: () => Referee(
        id: '',
        firstName: 'Unbekannt',
        lastName: '',
        email: '',
        licenseType: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    return Draggable<String>(
      data: gespannId,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.deepPurple.shade700],
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gespannName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${referee1.firstName} ${referee1.lastName}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              Text(
                '${referee2.firstName} ${referee2.lastName}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              gespannName,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${referee1.firstName} ${referee1.lastName}',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 12,
              ),
            ),
            Text(
              '${referee2.firstName} ${referee2.lastName}',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade50, Colors.deepPurple.shade100],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.deepPurple.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    gespannName,
                    style: TextStyle(
                      color: Colors.deepPurple.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  Icons.drag_indicator,
                  color: Colors.deepPurple.shade400,
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${referee1.firstName} ${referee1.lastName}',
              style: TextStyle(
                color: Colors.deepPurple.shade600,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${referee2.firstName} ${referee2.lastName}',
              style: TextStyle(
                color: Colors.deepPurple.shade600,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefereeSchedulingTable(List<Game> games) {
    if (widget.tournament == null || widget.tournament!.courts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_tennis,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Keine Plätze konfiguriert',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Konfigurieren Sie zuerst Plätze im "Plätze" Tab',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    // Get scheduled games only
    final scheduledGames = games.where((g) => g.scheduledTime != null && g.courtId != null).toList();
    
    if (scheduledGames.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.schedule_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Keine Spiele eingeplant',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Planen Sie zuerst Spiele im "Spielplan" Tab',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    final courts = widget.tournament!.courts;
    
    // Group games by date and time
    final gamesByDateTime = <String, Map<String, Game>>{};
    
    for (final game in scheduledGames) {
      if (game.scheduledTime != null && game.courtId != null) {
        final dateKey = '${game.scheduledTime!.year}-${game.scheduledTime!.month.toString().padLeft(2, '0')}-${game.scheduledTime!.day.toString().padLeft(2, '0')}';
        final timeKey = '${game.scheduledTime!.hour.toString().padLeft(2, '0')}:${game.scheduledTime!.minute.toString().padLeft(2, '0')}';
        final slotKey = '${dateKey}_${timeKey}';
        
        if (!gamesByDateTime.containsKey(slotKey)) {
          gamesByDateTime[slotKey] = {};
        }
        gamesByDateTime[slotKey]![game.courtId!] = game;
      }
    }

    final sortedTimeSlots = gamesByDateTime.keys.toList()..sort();

    return SingleChildScrollView(
      child: Column(
        children: [
          // Header row with court names
          Container(
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              border: Border.all(color: Colors.deepPurple.shade200),
            ),
            child: Row(
              children: [
                // Time column header
                Container(
                  width: 120,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Colors.deepPurple.shade200)),
                  ),
                  child: Text(
                    'Zeit',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple.shade700,
                    ),
                  ),
                ),
                // Court headers
                ...courts.map((court) => Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: Colors.deepPurple.shade200)),
                    ),
                    child: Text(
                      court.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )),
              ],
            ),
          ),
          
          // Time slot rows
          ...sortedTimeSlots.map((timeSlot) {
            final gamesInSlot = gamesByDateTime[timeSlot]!;
            final parts = timeSlot.split('_');
            final dateStr = parts[0];
            final timeStr = parts[1];
            
            return Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                  left: BorderSide(color: Colors.deepPurple.shade200),
                  right: BorderSide(color: Colors.deepPurple.shade200),
                ),
              ),
              child: Row(
                children: [
                  // Time column
                  Container(
                    width: 120,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(right: BorderSide(color: Colors.deepPurple.shade200)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          timeStr,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Court columns
                  ...courts.map((court) {
                    final game = gamesInSlot[court.id];
                    return Expanded(
                      child: _buildRefereeGameSlot(game, court),
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRefereeGameSlot(Game? game, Court court) {
    if (game == null) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Center(
          child: Text(
            'Kein Spiel',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    final hasAssignment = game.refereeGespannId != null;
    final assignedGespann = hasAssignment
        ? _refereeGespanne.firstWhere(
            (g) => g['referee1Id'] + '_' + g['referee2Id'] == game.refereeGespannId,
            orElse: () => <String, dynamic>{},
          )
        : <String, dynamic>{};

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        final gespannId = details.data;
        _assignGespannToGameDragDrop(game, gespannId);
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          height: 80,
          decoration: BoxDecoration(
            color: candidateData.isNotEmpty
                ? Colors.deepPurple.shade50
                : (hasAssignment ? Colors.green.shade50 : Colors.white),
            border: Border(
              right: BorderSide(color: Colors.grey.shade200),
              bottom: candidateData.isNotEmpty 
                  ? BorderSide(color: Colors.deepPurple.shade300, width: 2)
                  : BorderSide.none,
              top: candidateData.isNotEmpty 
                  ? BorderSide(color: Colors.deepPurple.shade300, width: 2)
                  : BorderSide.none,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Game teams (compact)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_formatTeamNameShort(game.teamAName)} vs ${_formatTeamNameShort(game.teamBName)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: game.gameType == GameType.pool 
                              ? Colors.blue.withValues(alpha: 0.2)
                              : Colors.purple.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          game.gameType == GameType.pool 
                              ? 'Gr. ${game.poolId?.toUpperCase() ?? ''}' 
                              : 'K.O.',
                          style: TextStyle(
                            color: game.gameType == GameType.pool 
                                ? Colors.blue.shade700 
                                : Colors.purple.shade700,
                            fontSize: 8,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Referee assignment area
                Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: candidateData.isNotEmpty
                        ? Colors.deepPurple.withValues(alpha: 0.2)
                        : (hasAssignment 
                            ? Colors.green.withValues(alpha: 0.1) 
                            : Colors.grey.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(4),
                    border: candidateData.isNotEmpty
                        ? Border.all(color: Colors.deepPurple.shade300)
                        : Border.all(color: Colors.transparent),
                  ),
                  child: candidateData.isNotEmpty
                      ? Center(
                          child: Icon(
                            Icons.add_circle_outline,
                            color: Colors.deepPurple,
                            size: 16,
                          ),
                        )
                      : hasAssignment
                          ? Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    assignedGespann['name'] ?? 'Gespann',
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 9,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _assignGespannToGameDragDrop(game, null),
                                  child: Icon(
                                    Icons.clear,
                                    color: Colors.red.shade400,
                                    size: 12,
                                  ),
                                ),
                              ],
                            )
                          : Center(
                              child: Text(
                                'Gespann ablegen',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 8,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTeamNameShort(String teamName) {
    // Shorten team names for compact display
    if (teamName.length > 15) {
      return teamName.substring(0, 12) + '...';
    }
    return teamName;
  }

  void _assignGespannToGameDragDrop(Game game, String? gespannId) async {
    try {
      // Update the game with the new gespann assignment
      final updatedGame = game.copyWith(
        refereeGespannId: gespannId,
        updatedAt: DateTime.now(),
      );
      
      // Update the game in the service
      await _gameService.updateGame(updatedGame);
      
      // Clear the game cache to force fresh data
      _gameService.clearCache();
      
      // Auto-save the tournament with updated gespann assignments  
      await _autoSaveTournament();
      
      // Force refresh the UI by triggering a rebuild
      setState(() {
        // This will cause the FutureBuilder to rebuild with fresh data
        _refereePlannerKey = UniqueKey();
      });
      
      // Show feedback with toastification
      final gespannName = gespannId != null 
        ? _refereeGespanne.firstWhere(
            (g) => g['referee1Id'] + '_' + g['referee2Id'] == gespannId,
            orElse: () => {'name': 'Unbekanntes Gespann'},
          )['name']
        : null;
      
      toastification.show(
        context: context,
        type: gespannId != null ? ToastificationType.success : ToastificationType.warning,
        style: ToastificationStyle.fillColored,
        title: Text(gespannId != null ? 'Gespann zugeordnet' : 'Gespann entfernt'),
        description: Text(
          gespannId != null 
            ? 'Gespann "$gespannName" zu "${game.displayName}" zugeordnet'
            : 'Gespann-Zuordnung für "${game.displayName}" entfernt',
        ),
        alignment: Alignment.topRight,
        autoCloseDuration: const Duration(seconds: 3),
        showProgressBar: false,
      );
    } catch (e) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        title: const Text('Fehler'),
        description: Text('Fehler beim Zuordnen: $e'),
        alignment: Alignment.topRight,
        autoCloseDuration: const Duration(seconds: 4),
        showProgressBar: false,
      );
    }
  }

  void _showCreateGespannDialog() {
    final availableReferees = _allReferees.where((referee) => 
      _refereeInvitations.containsKey(referee.id)
    ).toList();

    final assignedRefereeIds = <String>{};
    for (final gespann in _refereeGespanne) {
      assignedRefereeIds.add(gespann['referee1Id'] as String);
      assignedRefereeIds.add(gespann['referee2Id'] as String);
    }

    final unassignedReferees = availableReferees.where((referee) => 
      !assignedRefereeIds.contains(referee.id)
    ).toList();

    String? selectedReferee1Id;
    String? selectedReferee2Id;
    _gespannNameController.clear();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Neues Schiedsrichter-Gespann erstellen'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Gespann name
                    TextField(
                      controller: _gespannNameController,
                      decoration: const InputDecoration(
                        labelText: 'Gespann Name (optional)',
                        hintText: 'z.B. "Gespann A" oder "Müller/Schmidt"',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Referee 1 selection
                    DropdownButtonFormField<String>(
                      value: selectedReferee1Id,
                      decoration: const InputDecoration(
                        labelText: 'Schiedsrichter 1 *',
                        border: OutlineInputBorder(),
                      ),
                      items: unassignedReferees.map((referee) {
                        return DropdownMenuItem<String>(
                          value: referee.id,
                          child: Text('${referee.fullName} (${referee.licenseType})'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedReferee1Id = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Referee 2 selection
                    DropdownButtonFormField<String>(
                      value: selectedReferee2Id,
                      decoration: const InputDecoration(
                        labelText: 'Schiedsrichter 2 *',
                        border: OutlineInputBorder(),
                      ),
                      items: unassignedReferees.where((referee) => 
                        referee.id != selectedReferee1Id
                      ).map((referee) {
                        return DropdownMenuItem<String>(
                          value: referee.id,
                          child: Text('${referee.fullName} (${referee.licenseType})'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedReferee2Id = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Abbrechen'),
                ),
                ElevatedButton(
                  onPressed: selectedReferee1Id != null && selectedReferee2Id != null
                    ? () => _createGespann(selectedReferee1Id!, selectedReferee2Id!)
                    : null,
                  child: const Text('Erstellen'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _createGespann(String referee1Id, String referee2Id) async {
    final referee1 = _allReferees.firstWhere((r) => r.id == referee1Id);
    final referee2 = _allReferees.firstWhere((r) => r.id == referee2Id);
    
    final gespannName = _gespannNameController.text.trim().isEmpty
      ? '${referee1.lastName}/${referee2.lastName}'
      : _gespannNameController.text.trim();

    final newGespann = {
      'referee1Id': referee1Id,
      'referee2Id': referee2Id,
      'name': gespannName,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };

    setState(() {
      _refereeGespanne.add(newGespann);
    });

    // Auto-save the tournament with the new gespann
    await _autoSaveTournament();

    Navigator.of(context).pop();
    
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.fillColored,
      title: const Text('Gespann erstellt'),
      description: Text('Gespann "$gespannName" erfolgreich erstellt und gespeichert'),
      alignment: Alignment.topRight,
      autoCloseDuration: const Duration(seconds: 3),
      showProgressBar: false,
    );
  }

  void _editGespann(int index) {
    // Implementation for editing gespann
    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.fillColored,
      title: const Text('Info'),
      description: const Text('Gespann bearbeiten wird in einer zukünftigen Version implementiert'),
      alignment: Alignment.topRight,
      autoCloseDuration: const Duration(seconds: 3),
      showProgressBar: false,
    );
  }

  void _deleteGespann(int index) {
    final gespann = _refereeGespanne[index];
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Gespann löschen'),
          content: Text('Möchten Sie das Gespann "${gespann['name']}" wirklich löschen?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
                          ElevatedButton(
                onPressed: () async {
                  setState(() {
                    _refereeGespanne.removeAt(index);
                  });
                  
                  // Auto-save the tournament after deletion
                  await _autoSaveTournament();
                  
                  Navigator.of(context).pop();
                  toastification.show(
                    context: context,
                    type: ToastificationType.error,
                    style: ToastificationStyle.fillColored,
                    title: const Text('Gespann gelöscht'),
                    description: Text('Gespann "${gespann['name']}" gelöscht und gespeichert'),
                    alignment: Alignment.topRight,
                    autoCloseDuration: const Duration(seconds: 3),
                    showProgressBar: false,
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Löschen', style: TextStyle(color: Colors.white)),
              ),
          ],
        );
      },
    );
  }

  // ─── SPONSORS TAB ─────────────────────────────────────────────────────

  Widget _buildSponsorsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.handshake, color: Colors.teal, size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Sponsor-Logos',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _isUploadingSponsor ? null : _uploadSponsorLogo,
                        icon: _isUploadingSponsor
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.upload, color: Colors.white, size: 18),
                        label: Text(
                          _isUploadingSponsor ? 'Lädt hoch...' : 'Logo hochladen',
                          style: const TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Logos werden im Kiosk-Modus in einer Sponsoren-Ansicht angezeigt.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  if (_sponsorLogos.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade50,
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.image_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'Noch keine Sponsor-Logos hochgeladen',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 200,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1,
                      ),
                      itemCount: _sponsorLogos.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Image.network(
                                    _sponsorLogos[index],
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.broken_image,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: IconButton(
                                onPressed: () => _deleteSponsorLogo(index),
                                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.red.withValues(alpha: 0.8),
                                  padding: const EdgeInsets.all(4),
                                  minimumSize: const Size(28, 28),
                                ),
                                tooltip: 'Logo entfernen',
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadSponsorLogo() async {
    if (widget.tournament == null) {
      toastification.show(
        context: context,
        type: ToastificationType.warning,
        style: ToastificationStyle.fillColored,
        title: const Text('Hinweis'),
        description: const Text('Bitte speichern Sie das Turnier zuerst.'),
        alignment: Alignment.topRight,
        autoCloseDuration: const Duration(seconds: 3),
        showProgressBar: false,
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      setState(() => _isUploadingSponsor = true);

      final storage = FirebaseStorage.instance;
      final tournamentId = widget.tournament!.id;

      for (final file in result.files) {
        if (file.bytes == null) continue;
        final sanitizedName = (file.name).replaceAll(RegExp(r'[^\w\.\-]'), '_');
        final storagePath = 'sponsors/$tournamentId/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName';
        final ref = storage.ref().child(storagePath);
        final metadata = SettableMetadata(contentType: 'image/${file.extension ?? 'png'}');
        await ref.putData(file.bytes!, metadata);
        final downloadUrl = await ref.getDownloadURL();
        _sponsorLogos.add(downloadUrl);
      }

      // Auto-save after upload
      await _autoSaveTournament();

      if (mounted) {
        setState(() => _isUploadingSponsor = false);
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          title: const Text('Erfolg'),
          description: Text('${result.files.length} Logo(s) hochgeladen'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 3),
          showProgressBar: false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingSponsor = false);
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          title: const Text('Fehler'),
          description: Text('Upload fehlgeschlagen: $e'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 4),
          showProgressBar: false,
        );
      }
    }
  }

  Future<void> _deleteSponsorLogo(int index) async {
    final url = _sponsorLogos[index];
    try {
      // Delete from Firebase Storage
      final ref = FirebaseStorage.instance.refFromURL(url);
      await ref.delete();
    } catch (e) {
      debugPrint('Could not delete sponsor logo from storage: $e');
    }
    setState(() => _sponsorLogos.removeAt(index));
    // Auto-save after deletion
    await _autoSaveTournament();
  }

  /// Calls the `createYoutubeBroadcast` cloud function and reflects the
  /// result in the form (URL field + broadcast-id chip). Shows a dialog
  /// with RTMP-URL + Stream-Key for the streaming setup.
  Future<void> _createYoutubeBroadcast() async {
    if (widget.tournament == null) return;
    final service = LivestreamService();
    final connected = await service.isYoutubeConnected();
    if (!connected) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('YouTube nicht verbunden'),
          content: const Text(
              'Bitte zuerst im Admin-Bereich unter "YouTube-Verbindung" '
              'den zentralen RHBL-Kanal verbinden.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final defaultTitle =
        '${widget.tournament!.name} – ${widget.tournament!.startDate.toLocal().toIso8601String().split('T').first}';
    String chosenPrivacy = 'unlisted';
    final titleController = TextEditingController(text: defaultTitle);

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('YouTube-Stream erstellen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Titel',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: chosenPrivacy,
                decoration: const InputDecoration(
                  labelText: 'Sichtbarkeit',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'unlisted', child: Text('Nicht gelistet')),
                  DropdownMenuItem(
                      value: 'public', child: Text('Öffentlich')),
                  DropdownMenuItem(
                      value: 'private', child: Text('Privat')),
                ],
                onChanged: (v) => setLocal(() {
                  if (v != null) chosenPrivacy = v;
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Erstellen'),
            ),
          ],
        ),
      ),
    );

    if (shouldCreate != true) {
      titleController.dispose();
      return;
    }
    final title = titleController.text.trim();
    titleController.dispose();

    setState(() => _isCreatingBroadcast = true);
    try {
      final now = DateTime.now().toUtc();
      final tournamentStart = widget.tournament!.startDate.toUtc();
      // YouTube requires the start time to be in the future. If the tournament
      // date is in the past (or within the next minute), fall back to +5 min.
      final scheduledStart = tournamentStart.isAfter(now.add(const Duration(minutes: 1)))
          ? tournamentStart
          : now.add(const Duration(minutes: 5));
      final creds = await service.createBroadcast(
        tournamentId: widget.tournament!.id,
        title: title.isEmpty ? null : title,
        scheduledStartTime: scheduledStart,
        privacyStatus: chosenPrivacy,
      );
      if (!mounted) return;
      setState(() {
        _livestreamEnabled = true;
        _livestreamUrlController.text = creds.watchUrl;
        _livestreamYoutubeBroadcastId = creds.broadcastId;
        _lastBroadcastCreds = creds;
        _isCreatingBroadcast = false;
      });
      await _showBroadcastResultDialog(creds);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreatingBroadcast = false);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Fehler'),
          content: Text('Stream konnte nicht erstellt werden:\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showBroadcastResultDialog(LivestreamCredentials c) async {
    bool revealKey = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Stream erstellt ✓'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _credRow(context, 'Watch-URL', c.watchUrl),
                _credRow(context, 'RTMP-URL', c.rtmpUrl),
                Row(
                  children: [
                    Expanded(
                      child: _credRow(
                        context,
                        'Stream-Key',
                        revealKey
                            ? c.streamKey
                            : '•' * c.streamKey.length.clamp(8, 32),
                      ),
                    ),
                    IconButton(
                      tooltip: revealKey ? 'Verbergen' : 'Anzeigen',
                      icon: Icon(revealKey
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setLocal(() => revealKey = !revealKey),
                    ),
                    IconButton(
                      tooltip: 'Kopieren',
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: c.streamKey));
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Stream-Key kopiert')),
                        );
                      },
                    ),
                  ],
                ),
                const Divider(height: 28),
                const Text(
                  'OBS einrichten',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                const Text(
                  '1.  OBS öffnen → Einstellungen → Stream\n'
                  '2.  Dienst: „YouTube – RTMPS" (oder „Benutzerdefiniert")\n'
                  '3.  Server: RTMP-URL von oben einfügen\n'
                  '4.  Stream-Key: Stream-Key von oben einfügen\n'
                  '5.  OK → Streaming starten\n\n'
                  'Wichtig: Starte den Stream erst kurz vor Spielbeginn. '
                  'Starte NICHT einen neuen Broadcast – der Broadcast ist '
                  'bereits auf YouTube angelegt. OBS verbindet sich '
                  'automatisch mit dem bestehenden Broadcast.',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Die Zugangsdaten bleiben im Livestream-Tab sichtbar '
                  'solange dieses Fenster offen ist.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fertig'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _credRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  value,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
              IconButton(
                tooltip: 'Kopieren',
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: value));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$label kopiert')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLivestreamTab() {
    final urlText = _livestreamUrlController.text.trim();
    final hasValidUrl = urlText.isNotEmpty &&
        (urlText.contains('youtube.com/watch') ||
            urlText.contains('youtu.be/') ||
            urlText.contains('youtube.com/live/') ||
            urlText.contains('youtube.com/embed/'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.live_tv, color: Colors.red, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Livestream',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Binde einen YouTube-Livestream in die Turnier-Detailseite ein.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Livestream aktivieren'),
                    subtitle: const Text(
                        'Wenn aktiv, wird der Stream auf der Turnierseite angezeigt.'),
                    value: _livestreamEnabled,
                    onChanged: (v) => setState(() => _livestreamEnabled = v),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _livestreamUrlController,
                    decoration: const InputDecoration(
                      labelText: 'YouTube-Livestream-URL',
                      hintText: 'https://www.youtube.com/watch?v=...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                    ),
                    keyboardType: TextInputType.url,
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      if (!_livestreamEnabled) return null;
                      final v = value?.trim() ?? '';
                      if (v.isEmpty) return 'Bitte eine URL angeben';
                      if (!(v.contains('youtube.com/watch') ||
                          v.contains('youtu.be/') ||
                          v.contains('youtube.com/live/') ||
                          v.contains('youtube.com/embed/'))) {
                        return 'Bitte eine gültige YouTube-URL angeben';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isCreatingBroadcast
                            ? null
                            : _createYoutubeBroadcast,
                        icon: _isCreatingBroadcast
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome),
                        label: const Text(
                            'YouTube-Stream automatisch erstellen'),
                      ),
                      if (_livestreamYoutubeBroadcastId != null) ...[
                        const SizedBox(width: 12),
                        Chip(
                          avatar: const Icon(Icons.check_circle,
                              color: Colors.green, size: 18),
                          label: Text(
                              'Broadcast-ID: ${_livestreamYoutubeBroadcastId!}'),
                        ),
                      ],
                    ],
                  ),
                  if (_lastBroadcastCreds != null) ...[
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.settings_input_antenna,
                            size: 18, color: Colors.red),
                        const SizedBox(width: 8),
                        const Text(
                          'OBS-Zugangsdaten',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('Anleitung'),
                          onPressed: () =>
                              _showBroadcastResultDialog(_lastBroadcastCreds!),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _credRow(context, 'RTMP-URL', _lastBroadcastCreds!.rtmpUrl),
                    _StreamKeyRow(
                      streamKey: _lastBroadcastCreds!.streamKey,
                      credRowBuilder: _credRow,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_livestreamEnabled && hasValidUrl) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vorschau',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    LivestreamEmbed(url: urlText),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Game Management Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.sports_basketball, color: Colors.red, size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Spiel Verwaltung',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Verwalten Sie alle Spiele dieses Turniers.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Remove All Games Button
                  Container(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: widget.tournament != null ? _showRemoveAllGamesDialog : null,
                      icon: const Icon(Icons.delete_forever, color: Colors.white),
                      label: const Text(
                        'Alle Spiele löschen',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '?? Diese Aktion löscht alle Spiele und Planungen unwiderruflich!',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Team Management Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.group, color: Colors.orange, size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Team Verwaltung',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Verwalten Sie alle Teams dieses Turniers.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Remove All Teams Button
                  Container(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: widget.tournament != null ? _showRemoveAllTeamsDialog : null,
                      icon: const Icon(Icons.group_remove, color: Colors.white),
                      label: const Text(
                        'Alle Teams entfernen',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '?? Diese Aktion entfernt alle Teams aus diesem Turnier!',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Ligapunkte Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.emoji_events, color: Colors.purple, size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Ligapunkte Verwaltung',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Berechnet die Platzierung und schreibt Ligapunkte in die Rangliste. '
                    'Vorhandene Einträge für dieses Turnier werden ersetzt.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Ausrichterverein selection
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ausrichterverein',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Der Ausrichterverein erhält +3 Ligapunkte zusätzlich zu den Spielpunkten.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _hostClubTeamId,
                        decoration: const InputDecoration(
                          labelText: 'Ausrichterverein auswählen',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.home_work_outlined),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('— Kein Ausrichterverein —'),
                          ),
                          ..._allTeams
                              .where((t) => _selectedTeamIds.contains(t.id))
                              .map((t) => DropdownMenuItem<String>(
                                    value: t.id,
                                    child: Text(t.name),
                                  ))
                              .toList(),
                        ],
                        onChanged: (val) => setState(() => _hostClubTeamId = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: widget.tournament != null
                          ? () async {
                              try {
                                setState(() => _isLoading = true);
                                await _autoWriteLigapunkte(
                                  widget.tournament!.id,
                                  _nameController.text.trim(),
                                  _hostClubTeamId,
                                );
                                if (mounted) {
                                  setState(() => _isLoading = false);
                                  toastification.show(
                                    context: context,
                                    type: ToastificationType.success,
                                    style: ToastificationStyle.fillColored,
                                    title: const Text('Erfolg'),
                                    description: const Text('Ligapunkte wurden vergeben!'),
                                    alignment: Alignment.topRight,
                                    autoCloseDuration: const Duration(seconds: 3),
                                    showProgressBar: false,
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  setState(() => _isLoading = false);
                                  toastification.show(
                                    context: context,
                                    type: ToastificationType.error,
                                    style: ToastificationStyle.fillColored,
                                    title: const Text('Fehler'),
                                    description: Text('Fehler: $e'),
                                    alignment: Alignment.topRight,
                                    autoCloseDuration: const Duration(seconds: 5),
                                    showProgressBar: false,
                                  );
                                }
                              }
                            }
                          : null,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.emoji_events, color: Colors.white),
                      label: Text(
                        widget.tournament != null
                            ? 'Ligapunkte vergeben'
                            : 'Bitte Turnier zuerst speichern',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Hinweis: Bei einem Entscheidungsspiel-Gleichstand werden keine LP vergeben.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.purple,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Revert to Draft Card
          if (widget.tournament != null && _approvalStatus != 'pending_approval')
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.undo, color: Colors.orange, size: 24),
                        const SizedBox(width: 12),
                        const Text(
                          'Genehmigung zurücksetzen',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Setzt das Turnier zurück in den Entwurf-Status. '
                      'Das Turnier muss dann erneut genehmigt werden, bevor es öffentlich sichtbar ist.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _revertToDraft,
                        icon: const Icon(Icons.undo, color: Colors.orange),
                        label: const Text(
                          'Zurück zu Entwurf',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.orange),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          if (widget.tournament != null && _approvalStatus != 'pending_approval')
            const SizedBox(height: 16),
          
          // Statistiken Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bar_chart, color: Colors.teal, size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Turnierstatistiken',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Liest alle Spielereignisse (Tore, Karten, Zeitstrafen) erneut aus '
                    'den Spielberichten und aktualisiert die Statistik-Ansicht.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: widget.tournament != null
                          ? () {
                              // Switch to the stats tab, which triggers a fresh _loadStats()
                              setState(() {
                                _selectedTab = 'stats';
                              });
                              toastification.show(
                                context: context,
                                type: ToastificationType.info,
                                style: ToastificationStyle.fillColored,
                                title: const Text('Statistiken'),
                                description: const Text('Statistiken werden geladenâ€¦'),
                                alignment: Alignment.topRight,
                                autoCloseDuration: const Duration(seconds: 2),
                                showProgressBar: false,
                              );
                            }
                          : null,
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: Text(
                        widget.tournament != null
                            ? 'Statistiken neu berechnen'
                            : 'Bitte Turnier zuerst speichern',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Show confirmation dialog for removing all games
  void _showRemoveAllGamesDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              const Text('Alle Spiele löschen'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sind Sie sicher, dass Sie alle Spiele dieses Turniers löschen möchten?',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dies wird folgende Daten unwiderruflich löschen:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('â€¢ Alle Gruppen- und Eliminationsspiele', style: TextStyle(color: Colors.red.shade700)),
                    Text('â€¢ Alle Zeitpläne und Platzplanungen', style: TextStyle(color: Colors.red.shade700)),
                    Text('â€¢ Alle Spielergebnisse', style: TextStyle(color: Colors.red.shade700)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _removeAllGames();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Alle Spiele löschen'),
            ),
          ],
        );
      },
    );
  }

  // Show confirmation dialog for removing all teams
  void _showRemoveAllTeamsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 28),
              const SizedBox(width: 12),
              const Text('Alle Teams entfernen'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sind Sie sicher, dass Sie alle Teams aus diesem Turnier entfernen möchten?',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dies wird folgende Aktionen ausführen:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('â€¢ Alle Teams werden vom Turnier abgemeldet', style: TextStyle(color: Colors.orange.shade700)),
                    Text('â€¢ Die Teams bleiben im System bestehen', style: TextStyle(color: Colors.orange.shade700)),
                    Text('â€¢ Turnierplätze werden für neue Anmeldungen frei', style: TextStyle(color: Colors.orange.shade700)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _removeAllTeams();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Alle Teams entfernen'),
            ),
          ],
        );
      },
    );
  }

  // Remove all teams from the tournament
  Future<void> _removeAllGames() async {
    if (widget.tournament == null) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Lösche alle Spiele...'),
              ],
            ),
          );
        },
      );

      // Delete all games from database
      await _gameService.deleteAllGamesForTournament(widget.tournament!.id);

      // Clear local scheduling data
      setState(() {
        _scheduledGames.clear();
      });

      // Force refresh of scheduled games
      _loadScheduledGames();

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Alle Spiele wurden erfolgreich gelöscht'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Text('Fehler beim Löschen der Spiele: $e'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Remove all teams from the tournament
  Future<void> _removeAllTeams() async {
    if (widget.tournament == null) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Entferne alle Teams...'),
              ],
            ),
          );
        },
      );

      // Clear the team IDs from the tournament
      final updatedTournament = widget.tournament!.copyWith(
        teamIds: [],
      );

      // Update tournament in database
      await _tournamentService.updateTournament(updatedTournament);

      // Update local state
      setState(() {
        _selectedTeamIds.clear();
      });

      // Reload teams data
      _loadTeams();

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Alle Teams wurden erfolgreich entfernt'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Text('Fehler beim Entfernen der Teams: $e'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Show context menu for unscheduling a game
  void _showUnscheduleGameMenu(BuildContext context, Game game) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.schedule, color: Colors.orange, size: 24),
              const SizedBox(width: 12),
              const Text('Spiel aus Plan entfernen'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Möchten Sie dieses Spiel aus dem Zeitplan entfernen?',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getGameColor(game).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _getGameColor(game).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGameTitle(game),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (game.scheduledTime != null)
                      Text(
                        'Geplant: ${_formatDateTime(game.scheduledTime!)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    if (game.courtId != null)
                      Text(
                        'Platz: ${_getCourtNameForUnschedule(game.courtId!)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Das Spiel wird zurück in die Liste der nicht geplanten Spiele verschoben.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _unscheduleGame(game);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Aus Plan entfernen'),
            ),
          ],
        );
      },
    );
  }

  // Unschedule a game and move it back to unassigned list
  Future<void> _unscheduleGame(Game game) async {
    try {
      // Remove from local scheduled games map
      _scheduledGames.removeWhere((key, scheduledGame) => scheduledGame.id == game.id);

      // Create updated game with no schedule
      final unscheduledGame = Game(
        id: game.id,
        tournamentId: game.tournamentId,
        teamAId: game.teamAId,
        teamBId: game.teamBId,
        teamAName: game.teamAName,
        teamBName: game.teamBName,
        gameType: game.gameType,
        poolId: game.poolId,
        scheduledTime: null, // Remove scheduled time
        courtId: null, // Remove court assignment
        status: game.status,
        result: game.result,
        createdAt: game.createdAt,
        updatedAt: DateTime.now(),
      );

      // Update in database
      await _gameService.updateGame(unscheduledGame);

      // Refresh UI
      setState(() {
        _loadScheduledGames();
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Spiel "${_getGameTitle(game)}" aus dem Plan entfernt'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }

    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Text('Fehler beim Entfernen: $e'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Helper method to get court name by ID for unscheduling
  String _getCourtNameForUnschedule(String courtId) {
    final court = _tournamentCourts.firstWhere(
      (court) => court.id == courtId,
      orElse: () => Court(
        id: '',
        name: 'Unbekannt',
      ),
    );
    return court.name;
  }

  // Helper method to format date and time
  String _formatDateTime(DateTime dateTime) {
    final dayNames = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    final dayName = dayNames[dateTime.weekday - 1];
    return '$dayName ${dateTime.day}.${dateTime.month}.${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildLinksTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ausschreibung / AGBs',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          _buildLinksList('agb'),
          const SizedBox(height: 32),

          // Social Media Section
          Text(
            'Social Media',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          _buildLinksList('social'),
          const SizedBox(height: 32),

          // Save Button
          ElevatedButton.icon(
            onPressed: _saveTournament,
            icon: const Icon(Icons.save),
            label: const Text('Änderungen speichern'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinksList(String linkType) {
    final links = _links.where((link) => link.type == linkType).toList();
    debugPrint('Building links list for type $linkType: found ${links.length} links');
    
    return Column(
      children: [
        if (links.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade50,
            ),
            child: Center(
              child: Text(
                'Keine ${linkType == 'agb' ? 'Ausschreibungen/AGBs' : 'Social Media Links'} hinzugefügt',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: links.length,
            itemBuilder: (context, index) {
              final link = links[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(link.colorValue),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      _getIconFromName(link.iconName),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(link.label),
                  subtitle: Text(
                    link.url,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: SizedBox(
                    width: 100,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () => _editLink(link),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                          onPressed: () => _deleteLink(link),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => _addLink(linkType),
          icon: const Icon(Icons.add),
          label: Text(linkType == 'agb' ? 'Ausschreibung hinzufügen' : 'Social Media Link hinzufügen'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Future<void> _addLink(String linkType) async {
    final newLink = await Navigator.of(context).push<TournamentLink>(
      MaterialPageRoute(
        builder: (context) => TournamentLinkEditorScreen(
          linkType: linkType,
        ),
      ),
    );

    if (newLink != null) {
      setState(() {
        _links.add(newLink);
      });
    }
  }

  Future<void> _editLink(TournamentLink link) async {
    final updatedLink = await Navigator.of(context).push<TournamentLink>(
      MaterialPageRoute(
        builder: (context) => TournamentLinkEditorScreen(
          link: link,
          linkType: link.type,
        ),
      ),
    );

    if (updatedLink != null) {
      setState(() {
        final index = _links.indexWhere((l) => l.id == link.id);
        if (index >= 0) {
          _links[index] = updatedLink;
        }
      });
    }
  }

  void _deleteLink(TournamentLink link) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Link löschen?'),
        content: Text('Möchten Sie "${link.label}" wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _links.removeWhere((l) => l.id == link.id);
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }

  IconData _getIconFromName(String iconName) {
    switch (iconName) {
      case 'facebook':
        return Icons.facebook;
      case 'instagram':
        return Icons.camera_alt;
      case 'twitter':
        return Icons.share;
      case 'linkedin':
        return Icons.business;
      case 'youtube':
        return Icons.play_circle;
      case 'web':
      case 'language':
        return Icons.language;
      case 'download':
        return Icons.download;
      case 'document':
      case 'description':
        return Icons.description;
      case 'link':
        return Icons.link;
      case 'email':
        return Icons.email;
      case 'phone':
        return Icons.phone;
      case 'location':
        return Icons.location_on;
      default:
        return Icons.link;
    }
  }

  Widget _buildGamesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Games Management Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.sports_handball, color: Colors.blue),
                      const SizedBox(width: 12),
                      const Text(
                        'Spiele & Turnierplan',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      if (widget.tournament != null) ...[
                        ElevatedButton.icon(
                          onPressed: _showManualGameCreationDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Spiel hinzufügen'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _showBulkGameEntryDialog,
                          icon: const Icon(Icons.table_rows),
                          label: const Text('Spielplan-Tabelle'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => TournamentGamesScreen(
                                  tournament: widget.tournament!,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.visibility),
                          label: const Text('Alle Spiele anzeigen'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  if (widget.tournament == null) ...[
                    // New tournament message
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.orange.shade700),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Speichern Sie zuerst das Turnier, um Spiele zu erstellen.',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Pool games generation
                    const Text(
                      'Gruppenphase',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildPoolGamesSection(),
                    
                    const SizedBox(height: 24),
                    
                    // Elimination bracket generation
                    const Text(
                      'K.O.-System',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildEliminationBracketSection(),
                    
                    const SizedBox(height: 24),
                    
                    // Current games overview
                    const Text(
                      'Übersicht',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildGamesOverview(),

                    const SizedBox(height: 24),

                    // Spielplan table
                    const Text(
                      'Spielplan-Tabelle',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildGamesScheduleTable(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGamesScheduleTable() {
    // Lazy-init stream listener: only rebuilds UI when data actually changes
    _scheduleTableSubscription ??= _gameService
        .getGamesForTournament(widget.tournament!.id)
        .listen((games) {
      final fp = games.map((g) =>
        '${g.id}|${g.status}|${g.result?.teamAScore}:${g.result?.teamBScore}|${g.result?.specialScenario}|${g.scheduledTime}|${g.courtId}|${g.teamAName}|${g.teamBName}'
      ).toList()..sort();
      final fpStr = fp.join(';');
      if (fpStr != _scheduleTableFingerprint) {
        _scheduleTableFingerprint = fpStr;
        if (mounted) setState(() => _scheduleTableGames = games);
      }
    });

    final games = _scheduleTableGames;
    if (games.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Center(
          child: Text(
            'Noch keine Spiele vorhanden.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    // Sort by scheduledTime, then by type
    final sorted = [...games]..sort((a, b) {
      if (a.scheduledTime != null && b.scheduledTime != null) {
        return a.scheduledTime!.compareTo(b.scheduledTime!);
      }
      if (a.scheduledTime != null) return -1;
      if (b.scheduledTime != null) return 1;
      return 0;
    });

    return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              // Header row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 36, child: Text('#', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                    const Expanded(flex: 3, child: Text('Spiel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                    const SizedBox(width: 120, child: Text('Zeit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                    const SizedBox(width: 120, child: Text('Halle', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                    const SizedBox(width: 80, child: Text('Ergebnis', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.center)),
                    const SizedBox(width: 110, child: Text('Aktionen', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.center)),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Game rows
              ...sorted.asMap().entries.map((entry) {
                final idx = entry.key;
                final game = entry.value;
                final courtName = game.courtId != null
                    ? (_tournamentCourts.where((c) => c.id == game.courtId).isNotEmpty
                        ? _tournamentCourts.firstWhere((c) => c.id == game.courtId).name
                        : null)
                    : null;
                final timeStr = game.scheduledTime != null
                    ? '${game.scheduledTime!.day.toString().padLeft(2,'0')}.${game.scheduledTime!.month.toString().padLeft(2,'0')} ${game.scheduledTime!.hour.toString().padLeft(2,'0')}:${game.scheduledTime!.minute.toString().padLeft(2,'0')}'
                    : '—';
                final isCompleted = game.status == GameStatus.completed;
                final resultStr = isCompleted && game.result != null ? game.result!.finalScore : '—';

                return Column(
                  children: [
                    Container(
                      color: idx.isOdd ? Colors.grey.shade50 : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
                            child: Text('${idx + 1}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          ),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${game.teamAName} — ${game.teamBName}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  game.gameType == GameType.pool ? 'Pool${game.poolId != null ? ' ${game.poolId}' : ''}' : 'K.O.',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                          // Zeit (tappable)
                          InkWell(
                            onTap: () => _showEditGameTimeDialog(game),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              width: 120,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: game.scheduledTime != null ? Colors.blue.shade50 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: game.scheduledTime != null ? Colors.blue.shade200 : Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.schedule, size: 12, color: Colors.blue.shade600),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      timeStr,
                                      style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Halle (tappable)
                          InkWell(
                            onTap: () => _showEditGameHallDialog(game),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              width: 116,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: courtName != null ? Colors.green.shade50 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: courtName != null ? Colors.green.shade300 : Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.place, size: 12, color: Colors.green.shade600),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      courtName ?? '—',
                                      style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Ergebnis
                          SizedBox(
                            width: 80,
                            child: Center(
                              child: isCompleted && game.result?.specialScenario != null
                                  // Sonderszenario: nur Badge, kein Score
                                  ? Tooltip(
                                      message: game.result?.resultComment?.isNotEmpty == true
                                          ? game.result!.resultComment!
                                          : game.result!.specialScenario!,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.orange.shade300),
                                        ),
                                        child: Text(
                                          _scenarioShortCode(game.result!.specialScenario!),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange.shade900,
                                          ),
                                        ),
                                      ),
                                    )
                                  // Normales Ergebnis
                                  : Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isCompleted ? Colors.green.shade100 : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        resultStr,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isCompleted ? Colors.green.shade800 : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          // Aktionen
                          SizedBox(
                            width: 110,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Tooltip(
                                  message: 'Spielbericht eintragen',
                                  child: IconButton(
                                    icon: Icon(Icons.edit_note, color: Colors.deepPurple.shade600, size: 20),
                                    onPressed: () => _showManualSpielberichtDialog(game),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  ),
                                ),
                                Tooltip(
                                  message: 'Zeit & Halle bearbeiten',
                                  child: IconButton(
                                    icon: Icon(Icons.edit_calendar, color: Colors.blue.shade600, size: 20),
                                    onPressed: () => _showEditGameTimeDialog(game),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (idx < sorted.length - 1) const Divider(height: 1),
                  ],
                );
              }),
            ],
          ),
        );
  }

  Future<void> _showEditGameTimeDialog(Game game) async {
    DateTime? selectedDate = game.scheduledTime;
    TimeOfDay? selectedTime = game.scheduledTime != null
        ? TimeOfDay.fromDateTime(game.scheduledTime!)
        : null;
    String? selectedCourtId = game.courtId;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('Zeit & Halle — ${game.teamAName} vs ${game.teamBName}'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date picker
                const Text('Datum', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text(selectedDate != null
                      ? '${selectedDate!.day.toString().padLeft(2,'0')}.${selectedDate!.month.toString().padLeft(2,'0')}.${selectedDate!.year}'
                      : 'Datum wählen'),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setDlgState(() => selectedDate = picked);
                  },
                ),
                const SizedBox(height: 16),
                // Time picker
                const Text('Uhrzeit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: Text(selectedTime != null
                      ? '${selectedTime!.hour.toString().padLeft(2,'0')}:${selectedTime!.minute.toString().padLeft(2,'0')}'
                      : 'Uhrzeit wählen'),
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: selectedTime ?? const TimeOfDay(hour: 10, minute: 0),
                    );
                    if (picked != null) setDlgState(() => selectedTime = picked);
                  },
                ),
                const SizedBox(height: 16),
                // Court/Hall picker
                const Text('Halle / Feld', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedCourtId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    hintText: 'Keine Halle',
                  ),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('— Keine Halle —')),
                    ..._tournamentCourts.map((c) => DropdownMenuItem<String>(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (val) => setDlgState(() => selectedCourtId = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Abbrechen')),
            ElevatedButton(
              onPressed: () async {
                DateTime? newTime;
                if (selectedDate != null && selectedTime != null) {
                  newTime = DateTime(
                    selectedDate!.year, selectedDate!.month, selectedDate!.day,
                    selectedTime!.hour, selectedTime!.minute,
                  );
                } else if (selectedDate != null) {
                  newTime = selectedDate;
                }
                final updated = game.copyWith(
                  scheduledTime: newTime ?? game.scheduledTime,
                  courtId: selectedCourtId,
                  updatedAt: DateTime.now(),
                );
                await _gameService.updateGame(updated);
                if (mounted) {
                  Navigator.of(ctx).pop();
                  toastification.show(
                    context: context,
                    type: ToastificationType.success,
                    style: ToastificationStyle.flat,
                    title: const Text('Gespeichert'),
                    description: const Text('Zeit und Halle wurden aktualisiert.'),
                    alignment: Alignment.topRight,
                    autoCloseDuration: const Duration(seconds: 3),
                    showProgressBar: false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditGameHallDialog(Game game) => _showEditGameTimeDialog(game);

  Future<void> _showManualSpielberichtDialog(Game game) async {
    final teamAScoreCtrl = TextEditingController(text: game.result?.teamAScore.toString() ?? '');
    final teamBScoreCtrl = TextEditingController(text: game.result?.teamBScore.toString() ?? '');
    final htACtrl = TextEditingController(text: game.result?.halfTimeScoreA?.toString() ?? '');
    final htBCtrl = TextEditingController(text: game.result?.halfTimeScoreB?.toString() ?? '');
    final entryPlayerCtrl = TextEditingController();
    final entryPlayerFocus = FocusNode();
    final formKey = GlobalKey<FormState>();

    // Mutable event state — captured by ref in StatefulBuilder
    final List<_GameEventEntry> events = [];
    int entryMinute = 1;
    int entryHalf = 1;
    GameEventType? entryType;
    bool entryIsTeamA = true;
    String? selectedScenario = game.result?.specialScenario;
    final commentCtrl = TextEditingController(text: game.result?.resultComment ?? '');

    // Load rosters from already-fetched _allTeams
    final teamAPlayerNames = <String>[];
    final teamBPlayerNames = <String>[];
    final teamAMatches = _allTeams.where((t) => t.id == game.teamAId);
    if (teamAMatches.isNotEmpty && teamAMatches.first.rosterPlayerIds.isNotEmpty) {
      try {
        final players = await _playerService.getPlayersByIds(teamAMatches.first.rosterPlayerIds);
        for (final p in players) teamAPlayerNames.add('${p.firstName} ${p.lastName}');
      } catch (e) {
        debugPrint('⚠️ tournament edit: load team A roster failed: $e');
      }
    }
    final teamBMatches = _allTeams.where((t) => t.id == game.teamBId);
    if (teamBMatches.isNotEmpty && teamBMatches.first.rosterPlayerIds.isNotEmpty) {
      try {
        final players = await _playerService.getPlayersByIds(teamBMatches.first.rosterPlayerIds);
        for (final p in players) teamBPlayerNames.add('${p.firstName} ${p.lastName}');
      } catch (e) {
        debugPrint('⚠️ tournament edit: load team B roster failed: $e');
      }
    }

    // Load existing events from Firestore
    if (game.id.isNotEmpty) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('gameEvents')
            .where('gameId', isEqualTo: game.id)
            .get();
        for (final doc in snap.docs) {
          final d = doc.data();
          events.add(_GameEventEntry(
            minute: (d['gameMinute'] as int?) ?? 0,
            half: (d['half'] as int?) ?? 1,
            type: GameEventType.values.firstWhere(
              (e) => e.name == (d['eventType'] ?? ''),
              orElse: () => GameEventType.goal,
            ),
            isTeamA: (d['teamId'] ?? '') == (game.teamAId ?? ''),
            playerName: (d['playerName'] as String?) ?? '',
          ));
        }
        events.sort((a, b) => a.minute.compareTo(b.minute));
      } catch (e) {
        debugPrint('⚠️ tournament edit: load existing game events failed: $e');
      }
    }

    if (!mounted) return;

    String eventLabel(GameEventType t) {
      switch (t) {
        case GameEventType.goal: return 'Tor';
        case GameEventType.sevenMeterHit: return '7m âœ“';
        case GameEventType.sevenMeterMiss: return '7m âœ—';
        case GameEventType.yellowCard: return 'Verw.';
        case GameEventType.twoMinuteSuspension: return '2 Min';
        case GameEventType.redCard: return 'Disq.';
        case GameEventType.blueCard: return 'Disq.!';
        default: return t.name;
      }
    }

    Color eventColor(GameEventType t) {
      switch (t) {
        case GameEventType.goal:
        case GameEventType.sevenMeterHit: return Colors.green.shade700;
        case GameEventType.sevenMeterMiss: return Colors.orange.shade700;
        case GameEventType.yellowCard: return Colors.amber.shade800;
        case GameEventType.twoMinuteSuspension: return Colors.orange.shade800;
        case GameEventType.redCard: return Colors.red.shade700;
        case GameEventType.blueCard: return Colors.blue.shade700;
        default: return Colors.grey.shade700;
      }
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final currentPlayerNames = entryIsTeamA ? teamAPlayerNames : teamBPlayerNames;
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
              child: Column(
                children: [
                  // â”€â”€ Header â”€â”€
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade700,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_note, color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Spielbericht — ${game.teamAName} vs ${game.teamBName}',
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.of(ctx).pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                  // â”€â”€ Body â”€â”€
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Score
                            const Text('Ergebnis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(children: [
                                    Text(game.teamAName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      controller: teamAScoreCtrl,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(vertical: 8)),
                                      validator: (v) => v == null || v.isEmpty || int.tryParse(v) == null ? '' : null,
                                    ),
                                  ]),
                                ),
                                const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: Text(':', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold))),
                                Expanded(
                                  child: Column(children: [
                                    Text(game.teamBName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      controller: teamBScoreCtrl,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(vertical: 8)),
                                      validator: (v) => v == null || v.isEmpty || int.tryParse(v) == null ? '' : null,
                                    ),
                                  ]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Halbzeit
                            Text('Halbzeit (optional)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            const SizedBox(height: 6),
                            Row(children: [
                              Expanded(child: TextFormField(
                                controller: htACtrl,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  isDense: true, border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                  hintText: 'HZ ${game.teamAName}', hintStyle: const TextStyle(fontSize: 11),
                                ),
                              )),
                              const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text(':', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                              Expanded(child: TextFormField(
                                controller: htBCtrl,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  isDense: true, border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                  hintText: 'HZ ${game.teamBName}', hintStyle: const TextStyle(fontSize: 11),
                                ),
                              )),
                            ]),

                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),

                            // â”€â”€ Ereignisse â”€â”€
                            Row(children: [
                              const Text('Ereignisse', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 8),
                              Text('(${events.length})', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                            ]),
                            if (events.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              // â”€â”€ Column headers â”€â”€
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(children: [
                                  SizedBox(width: 56, child: Text('Team', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600))),
                                  SizedBox(width: 48, child: Text('Zeit', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600), textAlign: TextAlign.center)),
                                  SizedBox(width: 52, child: Text('Stand', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600), textAlign: TextAlign.center)),
                                  Expanded(child: Text('Ereignis', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600))),
                                  Expanded(child: Text('Person', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600))),
                                  const SizedBox(width: 30),
                                ]),
                              ),
                              const SizedBox(height: 4),
                              // â”€â”€ Event rows with running score â”€â”€
                              ...() {
                                // sort events for display
                                final sorted = List<MapEntry<int, _GameEventEntry>>.from(
                                  events.asMap().entries,
                                )..sort((a, b) {
                                  final h = a.value.half.compareTo(b.value.half);
                                  return h != 0 ? h : a.value.minute.compareTo(b.value.minute);
                                });
                                int runA = 0, runB = 0;
                                return sorted.map((entry) {
                                  final idx = entry.key;
                                  final ev = entry.value;
                                  final col = eventColor(ev.type);
                                  // running score
                                  if (ev.type == GameEventType.goal || ev.type == GameEventType.sevenMeterHit) {
                                    if (ev.isTeamA) runA++; else runB++;
                                  }
                                  final showScore = ev.type == GameEventType.goal || ev.type == GameEventType.sevenMeterHit;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 3),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: ev.isTeamA ? Colors.blue.withOpacity(0.04) : Colors.red.withOpacity(0.04),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: Row(children: [
                                      // Team badge
                                      SizedBox(
                                        width: 56,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: (ev.isTeamA ? Colors.blue : Colors.red).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            ev.isTeamA ? 'Heim' : 'Gast',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ev.isTeamA ? Colors.blue.shade700 : Colors.red.shade700),
                                          ),
                                        ),
                                      ),
                                      // Zeit
                                      SizedBox(
                                        width: 48,
                                        child: Text(
                                          "${ev.half}. ${ev.minute.toString().padLeft(2, '0')}'",
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      // Spielstand
                                      SizedBox(
                                        width: 52,
                                        child: showScore
                                            ? Text('$runA:$runB', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))
                                            : Text('—', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                                      ),
                                      // Ereignis
                                      Expanded(
                                        child: Row(children: [
                                          Container(
                                            width: 8, height: 8,
                                            decoration: BoxDecoration(color: col, shape: BoxShape.circle),
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(child: Text(eventLabel(ev.type), style: TextStyle(fontSize: 11, color: col, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                        ]),
                                      ),
                                      // Person
                                      Expanded(
                                        child: Text(
                                          ev.playerName.isNotEmpty ? ev.playerName : '—',
                                          style: const TextStyle(fontSize: 11),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      // Delete
                                      SizedBox(
                                        width: 30,
                                        child: IconButton(
                                          icon: Icon(Icons.close, size: 14, color: Colors.red.shade400),
                                          onPressed: () => setDlgState(() {
                                            events.removeAt(idx);
                                            // Auto-recalc scores
                                            _recalcScoresFromEvents(events, teamAScoreCtrl, teamBScoreCtrl, htACtrl, htBCtrl);
                                          }),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          tooltip: 'Löschen',
                                        ),
                                      ),
                                    ]),
                                  );
                                }).toList();
                              }(),
                            ],
                            const SizedBox(height: 12),

                            // â”€â”€ Ereignis-Eingabe â”€â”€
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Row 1: Minute + Halbzeit + Ereignis-Typ
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 70,
                                        child: TextField(
                                          keyboardType: TextInputType.number,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 13),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            labelText: 'Min.',
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                          ),
                                          onChanged: (v) => entryMinute = int.tryParse(v) ?? entryMinute,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildToggle2(
                                        label1: 'HZ 1',
                                        label2: 'HZ 2',
                                        value: entryHalf == 1,
                                        onChanged: (b) => setDlgState(() => entryHalf = b ? 1 : 2),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Wrap(
                                          spacing: 4,
                                          runSpacing: 4,
                                          children: [
                                            GameEventType.goal,
                                            GameEventType.sevenMeterHit,
                                            GameEventType.sevenMeterMiss,
                                            GameEventType.yellowCard,
                                            GameEventType.twoMinuteSuspension,
                                            GameEventType.redCard,
                                            GameEventType.blueCard,
                                          ].map((t) {
                                            final sel = entryType == t;
                                            final col = eventColor(t);
                                            return GestureDetector(
                                              onTap: () => setDlgState(() => entryType = sel ? null : t),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: sel ? col : col.withOpacity(0.08),
                                                  border: Border.all(color: col.withOpacity(sel ? 1 : 0.5)),
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                                child: Text(eventLabel(t),
                                                    style: TextStyle(fontSize: 11, color: sel ? Colors.white : col, fontWeight: FontWeight.w600)),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  // Row 2: Team toggle + Spieler autocomplete + Hinzufügen
                                  Row(
                                    children: [
                                      _buildToggle2(
                                        label1: game.teamAName.length > 12 ? '${game.teamAName.substring(0, 12)}â€¦' : game.teamAName,
                                        label2: game.teamBName.length > 12 ? '${game.teamBName.substring(0, 12)}â€¦' : game.teamBName,
                                        value: entryIsTeamA,
                                        onChanged: (b) => setDlgState(() { entryIsTeamA = b; entryPlayerCtrl.clear(); }),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _buildTeamAutocomplete(
                                          controller: entryPlayerCtrl,
                                          focusNode: entryPlayerFocus,
                                          hint: 'Spieler (optional)',
                                          teamNames: currentPlayerNames,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      ElevatedButton.icon(
                                        onPressed: entryType == null
                                            ? null
                                            : () => setDlgState(() {
                                                  events.add(_GameEventEntry(
                                                    minute: entryMinute,
                                                    half: entryHalf,
                                                    type: entryType!,
                                                    isTeamA: entryIsTeamA,
                                                    playerName: entryPlayerCtrl.text.trim(),
                                                  ));
                                                  entryPlayerCtrl.clear();
                                                  entryType = null;
                                                  // Auto-recalculate score from events
                                                  _recalcScoresFromEvents(events, teamAScoreCtrl, teamBScoreCtrl, htACtrl, htBCtrl);
                                                }),
                                        icon: const Icon(Icons.add, size: 18),
                                        label: const Text('Hinzufügen'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.deepPurple,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // â”€â”€ Footer â”€â”€
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      children: [
                        Text('${events.length} Ereignis${events.length != 1 ? 'se' : ''}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        const SizedBox(width: 8),
                        // Badge when a scenario is active
                        if (selectedScenario != null) ...[
                          GestureDetector(
                            onTap: () async {
                              await _showSonderszenarioDialog(
                                ctx, selectedScenario, commentCtrl,
                                (s) => setDlgState(() => selectedScenario = s),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.orange.shade300),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.warning_amber_rounded, size: 13, color: Colors.orange.shade800),
                                const SizedBox(width: 4),
                                Text(selectedScenario!, style: TextStyle(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        TextButton.icon(
                          icon: Icon(Icons.warning_amber_rounded, size: 16, color: selectedScenario != null ? Colors.orange.shade700 : null),
                          label: const Text('Sonderszenario'),
                          style: TextButton.styleFrom(foregroundColor: selectedScenario != null ? Colors.orange.shade700 : Colors.grey.shade600),
                          onPressed: () async {
                            await _showSonderszenarioDialog(
                              ctx, selectedScenario, commentCtrl,
                              (s) => setDlgState(() => selectedScenario = s),
                            );
                          },
                        ),
                        const SizedBox(width: 4),
                        TextButton.icon(
                          icon: const Icon(Icons.upload_file, size: 16),
                          label: const Text('nuLiga Import'),
                          style: TextButton.styleFrom(foregroundColor: Colors.deepPurple),
                          onPressed: () async {
                            final pasteCtrl = TextEditingController();
                            final parsed = await showDialog<List<_GameEventEntry>>(
                              context: ctx,
                              builder: (dCtx) => AlertDialog(
                                title: const Row(
                                  children: [
                                    Icon(Icons.upload_file, color: Colors.deepPurple),
                                    SizedBox(width: 8),
                                    Text('nuLiga Spielverlauf importieren'),
                                  ],
                                ),
                                content: SizedBox(
                                  width: 520,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Spielverlauf-Abschnitt aus der nuLiga-PDF kopieren und hier einfügen:',
                                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                      ),
                                      const SizedBox(height: 10),
                                      TextField(
                                        controller: pasteCtrl,
                                        maxLines: 18,
                                        decoration: const InputDecoration(
                                          hintText:
                                              'Spielverlauf\nTeam Zeit Stand Ereignis Person\n'
                                              'Heim 02:26 1:0 Tor 2 Mustermann, Max\n'
                                              'Gast 14:54 2 Minuten 57 Bogacki, Henrike\n...',
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.all(10),
                                        ),
                                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                                      ),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(dCtx).pop(null),
                                    child: const Text('Abbrechen'),
                                  ),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.check, size: 16),
                                    label: const Text('Importieren'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => Navigator.of(dCtx).pop(
                                      _parseNuLigaText(pasteCtrl.text),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (parsed != null && parsed.isNotEmpty) {
                              setDlgState(() {
                                events.addAll(parsed);
                                _recalcScoresFromEvents(
                                    events, teamAScoreCtrl, teamBScoreCtrl, htACtrl, htBCtrl);
                              });
                            }
                          },
                        ),
                        const Spacer(),
                        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Abbrechen')),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text('Spielbericht speichern'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final scoreA = int.parse(teamAScoreCtrl.text.trim());
                            final scoreB = int.parse(teamBScoreCtrl.text.trim());
                            final htA = htACtrl.text.trim().isNotEmpty ? int.tryParse(htACtrl.text.trim()) : null;
                            final htB = htBCtrl.text.trim().isNotEmpty ? int.tryParse(htBCtrl.text.trim()) : null;
                            String winnerId = '';
                            String winnerName = '';

                            // Scenario-based winner determination
                            if (selectedScenario == 'Wertung gegen Heim' || selectedScenario == 'Heim nicht angetreten') {
                              // Gast gewinnt
                              winnerId = game.teamBId ?? '';
                              winnerName = game.teamBName;
                            } else if (selectedScenario == 'Wertung gegen Gast' || selectedScenario == 'Gast nicht angetreten') {
                              // Heim gewinnt
                              winnerId = game.teamAId ?? '';
                              winnerName = game.teamAName;
                            } else if (selectedScenario == 'Spielabbruch') {
                              // Kein Sieger
                              winnerName = 'Spielabbruch';
                            } else {
                              // Normal: per Ergebnis
                              if (scoreA > scoreB) { winnerId = game.teamAId ?? ''; winnerName = game.teamAName; }
                              else if (scoreB > scoreA) { winnerId = game.teamBId ?? ''; winnerName = game.teamBName; }
                              else { winnerName = 'Unentschieden'; }
                            }
                            final result = GameResult(
                              teamAScore: scoreA, teamBScore: scoreB,
                              winnerId: winnerId.isNotEmpty ? winnerId : null,
                              winnerName: winnerName,
                              halfTimeScoreA: htA, halfTimeScoreB: htB,
                              specialScenario: selectedScenario,
                              resultComment: commentCtrl.text.trim().isEmpty ? null : commentCtrl.text.trim(),
                            );
                            await _gameService.updateGame(
                                game.copyWith(result: result, status: GameStatus.completed, updatedAt: DateTime.now()));
                            // Save events to Firestore (replace all)
                            if (game.id.isNotEmpty) {
                              try {
                                final existing = await FirebaseFirestore.instance
                                    .collection('gameEvents').where('gameId', isEqualTo: game.id).get();
                                final batch = FirebaseFirestore.instance.batch();
                                for (final doc in existing.docs) batch.delete(doc.reference);
                                for (final ev in events) {
                                  final ref = FirebaseFirestore.instance.collection('gameEvents').doc();
                                  batch.set(ref, {
                                    'gameId': game.id,
                                    'gameMinute': ev.minute,
                                    'half': ev.half,
                                    'eventType': ev.type.toString(),
                                    'teamId': ev.isTeamA ? (game.teamAId ?? '') : (game.teamBId ?? ''),
                                    'teamName': ev.isTeamA ? game.teamAName : game.teamBName,
                                    'playerId': '',
                                    'playerName': ev.playerName,
                                    'timestamp': DateTime.now().toIso8601String(),
                                  });
                                }
                                await batch.commit();
                              } catch (e) {
                                debugPrint('âŒ Event save error: $e');
                              }
                            }
                            if (mounted) {
                              Navigator.of(ctx).pop();
                              toastification.show(
                                context: context,
                                type: ToastificationType.success,
                                style: ToastificationStyle.flat,
                                title: const Text('Spielbericht gespeichert'),
                                description: Text('$scoreA:$scoreB Â· ${events.length} Ereignisse'),
                                alignment: Alignment.topRight,
                                autoCloseDuration: const Duration(seconds: 4),
                                showProgressBar: false,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    teamAScoreCtrl.dispose();
    teamBScoreCtrl.dispose();
    htACtrl.dispose();
    htBCtrl.dispose();
    entryPlayerCtrl.dispose();
    entryPlayerFocus.dispose();
  }

  Widget _buildGamesOverview() {
    final stats = _gameService.getTournamentStats(widget.tournament!.id);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildStatBox('Gesamt', stats['total'].toString(), Colors.blue),
              const SizedBox(width: 16),
              _buildStatBox('Beendet', stats['completed'].toString(), Colors.green),
              const SizedBox(width: 16),
              _buildStatBox('Geplant', stats['scheduled'].toString(), Colors.orange),
              const SizedBox(width: 16),
              _buildStatBox('Laufend', stats['inProgress'].toString(), Colors.red),
            ],
          ),
          if (stats['total']! > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => TournamentGamesScreen(
                        tournament: widget.tournament!,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.sports_handball),
                label: const Text('Zur Spieleverwaltung'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _deleteAllGames(),
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text('Alle Spiele löschen'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPoolGamesInfo() {
    int totalPoolGames = 0;
    for (String category in _categoryPools.keys) {
      for (String pool in _categoryPools[category]!) {
        String poolId = '${category}_${pool}';
        List<String> teams = _poolTeams[poolId] ?? [];
        if (teams.length > 1) {
          // n*(n-1)/2 games for n teams
          totalPoolGames += (teams.length * (teams.length - 1)) ~/ 2;
        }
      }
    }
    return '$totalPoolGames Spiele möglich';
  }

  String _getEliminationGamesInfo() {
    // Count total teams that would advance from pools
    int totalAdvancingTeams = 0;
    for (String category in _categoryPools.keys) {
      int poolCount = _categoryPools[category]!.length;
      // Assuming top 2 from each pool advance
      totalAdvancingTeams += poolCount * 2;
    }
    
    if (totalAdvancingTeams > 1) {
      int eliminationGames = totalAdvancingTeams - 1; // n-1 games for n teams
      return '$eliminationGames Spiele für $totalAdvancingTeams Teams';
    }
    return 'Keine Teams definiert';
  }

  void _showBulkGameEntryDialog() {
    final List<Map<String, dynamic>> rows = [_emptyBulkRow()];
    final formKey = GlobalKey<FormState>();
    final tournamentTeamNames = _allTeams
        .where((t) => _selectedTeamIds.contains(t.id))
        .map((t) => t.name)
        .toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          void addRow() => setDlgState(() => rows.add(_emptyBulkRow()));
          void removeRow(int i) => setDlgState(() { if (rows.length > 1) rows.removeAt(i); });

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.table_rows, color: Colors.white),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Spielplan-Tabelle — Mehrere Spiele eintragen',
                            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),

                  // Column headers
                  Container(
                    color: Colors.grey.shade100,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const SizedBox(width: 36, child: Text('#', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                        const SizedBox(width: 110, child: Text('Datum', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                        const SizedBox(width: 80, child: Text('Zeit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                        const SizedBox(width: 130, child: Text('Halle', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                        const Expanded(child: Text('Team A', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                        const SizedBox(width: 20, child: Text('vs', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.center)),
                        const Expanded(child: Text('Team B', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                        const SizedBox(width: 130, child: Text('Bezeichnung', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                        const SizedBox(width: 36),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Scrollable rows
                  Flexible(
                    child: Form(
                      key: formKey,
                      child: ListView.builder(
                        itemCount: rows.length,
                        itemExtent: 57.0,
                        itemBuilder: (_, i) {
                          final row = rows[i];
                          InputDecoration _cell(String hint) => InputDecoration(
                            isDense: true,
                            hintText: hint,
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          );
                          return Container(
                            decoration: BoxDecoration(
                              color: i.isOdd ? Colors.grey.shade50 : Colors.white,
                              border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.5)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                      // Row number
                                      SizedBox(
                                        width: 36,
                                        child: Text('${i + 1}',
                                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                                      ),

                                      // Datum — free text TT.MM.JJJJ
                                      SizedBox(
                                        width: 110,
                                        child: Container(
                                          margin: const EdgeInsets.only(right: 8),
                                          child: TextFormField(
                                            controller: row['dateCtrl'] as TextEditingController,
                                            style: const TextStyle(fontSize: 12),
                                            decoration: _cell('TT.MM.JJJJ'),
                                          ),
                                        ),
                                      ),

                                      // Zeit — free text HH:MM
                                      SizedBox(
                                        width: 80,
                                        child: Container(
                                          margin: const EdgeInsets.only(right: 8),
                                          child: TextFormField(
                                            controller: row['timeCtrl'] as TextEditingController,
                                            style: const TextStyle(fontSize: 12),
                                            decoration: _cell('HH:MM'),
                                          ),
                                        ),
                                      ),

                                      // Halle — Autocomplete
                                      SizedBox(
                                        width: 130,
                                        child: Container(
                                          margin: const EdgeInsets.only(right: 8),
                                          child: _buildTeamAutocomplete(
                                            controller: row['halleCtrl'] as TextEditingController,
                                            focusNode: row['halleFocus'] as FocusNode,
                                            hint: 'Halle',
                                            teamNames: _tournamentCourts.map((c) => c.name).toList(),
                                          ),
                                        ),
                                      ),

                                      // Team A — Autocomplete
                                      Expanded(
                                        child: Container(
                                          margin: const EdgeInsets.only(right: 8),
                                          child: _buildTeamAutocomplete(
                                            controller: row['teamACtrl'] as TextEditingController,
                                            focusNode: row['teamAFocus'] as FocusNode,
                                            hint: 'Team A',
                                            teamNames: tournamentTeamNames,
                                          ),
                                        ),
                                      ),

                                      // vs
                                      const SizedBox(
                                        width: 20,
                                        child: Center(
                                          child: Text(':', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        ),
                                      ),

                                      // Team B — Autocomplete
                                      Expanded(
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(horizontal: 8),
                                          child: _buildTeamAutocomplete(
                                            controller: row['teamBCtrl'] as TextEditingController,
                                            focusNode: row['teamBFocus'] as FocusNode,
                                            hint: 'Team B',
                                            teamNames: tournamentTeamNames,
                                          ),
                                        ),
                                      ),

                                      // Bezeichnung
                                      SizedBox(
                                        width: 130,
                                        child: Container(
                                          margin: const EdgeInsets.only(right: 8),
                                          child: TextFormField(
                                            controller: row['labelCtrl'] as TextEditingController,
                                            style: const TextStyle(fontSize: 12),
                                            decoration: _cell('z.B. Finale'),
                                          ),
                                        ),
                                      ),

                                      // Delete row
                                      SizedBox(
                                        width: 36,
                                        child: IconButton(
                                          icon: Icon(Icons.remove_circle_outline,
                                              color: Colors.red.shade300, size: 20),
                                          onPressed: rows.length > 1 ? () => removeRow(i) : null,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                        },
                      ),
                    ),
                  ),

                  // Footer: add row + save
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: addRow,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Zeile hinzufügen'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.deepPurple),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${rows.length} Spiel${rows.length != 1 ? 'e' : ''}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Abbrechen'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: Text('${rows.length} Spiel${rows.length != 1 ? 'e' : ''} speichern'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            // Validate: every row must have teamA and teamB
                            bool valid = true;
                            for (final row in rows) {
                              final a = (row['teamACtrl'] as TextEditingController).text.trim();
                              final b = (row['teamBCtrl'] as TextEditingController).text.trim();
                              if (a.isEmpty || b.isEmpty) { valid = false; break; }
                            }
                            if (!valid) {
                              toastification.show(
                                context: context,
                                type: ToastificationType.error,
                                style: ToastificationStyle.fillColored,
                                title: const Text('Fehler'),
                                description: const Text('Bitte Team A und Team B in jeder Zeile ausfüllen.'),
                                alignment: Alignment.topRight,
                                autoCloseDuration: const Duration(seconds: 3),
                                showProgressBar: false,
                              );
                              return;
                            }

                            int created = 0;
                            final now = DateTime.now();
                            for (final row in rows) {
                              final teamAName = (row['teamACtrl'] as TextEditingController).text.trim();
                              final teamBName = (row['teamBCtrl'] as TextEditingController).text.trim();
                              final label = (row['labelCtrl'] as TextEditingController).text.trim();

                              // Resolve halle name â†’ courtId
                              final halleName = (row['halleCtrl'] as TextEditingController).text.trim();
                              final courtId = halleName.isEmpty
                                  ? null
                                  : _tournamentCourts
                                      .where((c) => c.name.toLowerCase() == halleName.toLowerCase())
                                      .map((c) => c.id)
                                      .firstOrNull;

                              final date = _parseBulkDate((row['dateCtrl'] as TextEditingController).text);
                              final time = _parseBulkTime((row['timeCtrl'] as TextEditingController).text);

                              DateTime? scheduledTime;
                              if (date != null && time != null) {
                                scheduledTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                              } else if (date != null) {
                                scheduledTime = date;
                              }

                              // Try to match to tournament teams by name
                              final tournamentTeams = _allTeams.where((t) => _selectedTeamIds.contains(t.id)).toList();
                              String? teamAId;
                              String? teamBId;
                              try { teamAId = tournamentTeams.firstWhere((t) => t.name.toLowerCase() == teamAName.toLowerCase()).id; } catch (e) { debugPrint('⚠️ tournament edit: no team match for "$teamAName": $e'); }
                              try { teamBId = tournamentTeams.firstWhere((t) => t.name.toLowerCase() == teamBName.toLowerCase()).id; } catch (e) { debugPrint('⚠️ tournament edit: no team match for "$teamBName": $e'); }

                              final game = Game(
                                id: '',
                                tournamentId: widget.tournament!.id,
                                teamAId: teamAId,
                                teamBId: teamBId,
                                teamAName: teamAName,
                                teamBName: teamBName,
                                gameType: GameType.friendly,
                                poolId: label.isNotEmpty ? label : null,
                                scheduledTime: scheduledTime,
                                status: GameStatus.scheduled,
                                createdAt: now,
                                updatedAt: now,
                                courtId: courtId,
                              );
                              try {
                                await _gameService.addGame(game);
                                created++;
                              } catch (e) {
                                debugPrint('âŒ addGame failed: $e');
                                toastification.show(
                                  context: context,
                                  type: ToastificationType.error,
                                  style: ToastificationStyle.fillColored,
                                  title: const Text('Fehler beim Speichern'),
                                  description: Text('$e'),
                                  alignment: Alignment.topRight,
                                  autoCloseDuration: const Duration(seconds: 5),
                                  showProgressBar: false,
                                );
                              }
                            }

                            Navigator.of(ctx).pop();
                            setState(() {});
                            toastification.show(
                              context: context,
                              type: ToastificationType.success,
                              style: ToastificationStyle.fillColored,
                              title: Text('$created Spiel${created != 1 ? 'e' : ''} erstellt'),
                              description: const Text('Der Spielplan wurde gespeichert.'),
                              alignment: Alignment.topRight,
                              autoCloseDuration: const Duration(seconds: 3),
                              showProgressBar: false,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Map<String, dynamic> _emptyBulkRow() {
    final d = _startDate;
    return {
      'dateCtrl': TextEditingController(
        text: d != null
            ? '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year}'
            : '',
      ),
      'timeCtrl': TextEditingController(),
      'courtId': null as String?,
      'halleCtrl': TextEditingController(),
      'halleFocus': FocusNode(),
      'teamACtrl': TextEditingController(),
      'teamAFocus': FocusNode(),
      'teamBCtrl': TextEditingController(),
      'teamBFocus': FocusNode(),
      'labelCtrl': TextEditingController(),
    };
  }

  DateTime? _parseBulkDate(String s) {
    final parts = s.trim().split('.');
    if (parts.length >= 2) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = parts.length >= 3 ? int.tryParse(parts[2]) : DateTime.now().year;
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  TimeOfDay? _parseBulkTime(String s) {
    final clean = s.trim().replaceAll(' ', '');
    final parts = clean.split(':');
    if (parts.length == 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null && h < 24 && m < 60) {
        return TimeOfDay(hour: h, minute: m);
      }
    }
    return null;
  }

  /// Recalculate score TextEditingControllers from the current list of events.
  void _recalcScoresFromEvents(
    List<_GameEventEntry> events,
    TextEditingController teamAScoreCtrl,
    TextEditingController teamBScoreCtrl,
    TextEditingController htACtrl,
    TextEditingController htBCtrl,
  ) {
    int sA = 0, sB = 0, htA = 0, htB = 0;
    for (final ev in events) {
      if (ev.type == GameEventType.goal || ev.type == GameEventType.sevenMeterHit) {
        if (ev.isTeamA) {
          sA++;
          if (ev.half == 1) htA++;
        } else {
          sB++;
          if (ev.half == 1) htB++;
        }
      }
    }
    teamAScoreCtrl.text = sA.toString();
    teamBScoreCtrl.text = sB.toString();
    htACtrl.text = htA.toString();
    htBCtrl.text = htB.toString();
  }

  /// Parses a copy-pasted nuLiga Spielverlauf text into [_GameEventEntry] objects.
  /// Halbzeit: Minute < 15 â†’ HZ 1, Minute â‰¥ 15 â†’ HZ 2.
  ///
  /// nuLiga-Ereignisse:
  ///   Tor               â†’ goal
  ///   7m mit Tor        â†’ sevenMeterHit
  ///   7m ohne Tor       â†’ sevenMeterMiss
  ///   2 Minuten         â†’ twoMinuteSuspension
  ///   Verwarnung        â†’ yellowCard
  ///   ohne Bericht      â†’ redCard  (Disqualifikation ohne schriftlichen Bericht)
  ///   mit Bericht       â†’ blueCard (Disqualifikation mit schriftlichem Bericht)
  ///   Auszeit           â†’ timeout
  List<_GameEventEntry> _parseNuLigaText(String rawText) {
    // Zeilenweise einlesen; Folgezeilen die auf "," enden zusammenführen
    final rawLines = rawText.split('\n');
    final lines = <String>[];
    for (final raw in rawLines) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      if (lines.isNotEmpty && lines.last.endsWith(',')) {
        lines[lines.length - 1] = '${lines.last} $trimmed';
      } else {
        lines.add(trimmed);
      }
    }

    final entries = <_GameEventEntry>[];
    final headerRe = RegExp(r'^(Spielverlauf|Team\s+Zeit)', caseSensitive: false);

    for (final line in lines) {
      if (headerRe.hasMatch(line)) continue;
      if (line == 'Team Zeit Stand Ereignis Person') continue;

      // â”€â”€ Sonderformat Auszeit: MM:SS Auszeit Heim/Gast â”€â”€
      final timeoutMatch =
          RegExp(r'^(\d+):(\d+)\s+Auszeit\s+(Heim|Gast)\s*$').firstMatch(line);
      if (timeoutMatch != null) {
        final minute = int.parse(timeoutMatch.group(1)!);
        entries.add(_GameEventEntry(
          minute: minute,
          half: minute < 15 ? 1 : 2,
          type: GameEventType.timeout,
          isTeamA: timeoutMatch.group(3) == 'Heim',
          playerName: '',
        ));
        continue;
      }

      // â”€â”€ Standardzeile: Heim/Gast MM:SS [Spielstand] Ereignis [Nr] [Name] â”€â”€
      final mainMatch =
          RegExp(r'^(Heim|Gast)\s+(\d+):(\d+)\s+(.+)$').firstMatch(line);
      if (mainMatch == null) continue;

      final isTeamA = mainMatch.group(1) == 'Heim';
      final minute = int.parse(mainMatch.group(2)!);
      final half = minute < 15 ? 1 : 2;

      // Optionalen Spielstand "X:Y " am Anfang entfernen
      String rest = mainMatch.group(4)!.trimLeft();
      rest = rest.replaceFirst(RegExp(r'^\d+:\d+\s+'), '');

      GameEventType? type;

      // Reihenfolge: spezifischere Begriffe zuerst
      if (rest.startsWith('7m mit Tor') || rest.startsWith('7-Meter mit Tor')) {
        type = GameEventType.sevenMeterHit;
        rest = rest.replaceFirst(RegExp(r'^7-?[Mm]eter mit Tor|^7m mit Tor'), '').trimLeft();
      } else if (rest.startsWith('7m ohne Tor') || rest.startsWith('7-Meter ohne Tor')) {
        type = GameEventType.sevenMeterMiss;
        rest = rest.replaceFirst(RegExp(r'^7-?[Mm]eter ohne Tor|^7m ohne Tor'), '').trimLeft();
      } else if (rest.startsWith('7m') || rest.startsWith('7-Meter')) {
        // Fallback: unklares 7m â†’ Treffer
        type = GameEventType.sevenMeterHit;
        rest = rest.replaceFirst(RegExp(r'^7-?[Mm]eter|^7m'), '').trimLeft();
      } else if (rest.startsWith('Tor')) {
        type = GameEventType.goal;
        rest = rest.substring(3).trimLeft();
      } else if (rest.startsWith('2 Minuten')) {
        type = GameEventType.twoMinuteSuspension;
        rest = rest.substring(9).trimLeft();
      } else if (rest.startsWith('Verwarnung')) {
        type = GameEventType.yellowCard;
        rest = rest.substring(10).trimLeft();
      } else if (rest.startsWith('ohne Bericht')) {
        type = GameEventType.redCard;
        rest = rest.substring(12).trimLeft();
      } else if (rest.startsWith('mit Bericht')) {
        type = GameEventType.blueCard;
        rest = rest.substring(11).trimLeft();
      } else if (rest.startsWith('Auszeit')) {
        type = GameEventType.timeout;
        rest = '';
      }

      if (type == null) continue; // unbekannter Ereignistyp â†’ überspringen

      // Führende Trikotnummer entfernen (z. B. "12 Kunert, Heiko" â†’ "Kunert, Heiko")
      rest = rest.replaceFirst(RegExp(r'^\d+\s*'), '').trim();

      entries.add(_GameEventEntry(
        minute: minute,
        half: half,
        type: type,
        isTeamA: isTeamA,
        playerName: rest,
      ));
    }

    return entries;
  }

  /// Opens the Sonderszenario sub-dialog. [onChanged] is called with the
  /// selected scenario (or null to clear) so the parent can call setDlgState.
  Future<void> _showSonderszenarioDialog(
    BuildContext ctx,
    String? currentScenario,
    TextEditingController commentCtrl,
    void Function(String?) onChanged,
  ) async {
    String? localScenario = currentScenario;

    await showDialog<void>(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setSS) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Sonderszenario'),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Szenario auswählen:', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final scenario in const [
                      'Wertung gegen Heim',
                      'Wertung gegen Gast',
                      'Heim nicht angetreten',
                      'Gast nicht angetreten',
                      'Spielabbruch',
                    ])
                      ChoiceChip(
                        label: Text(scenario, style: const TextStyle(fontSize: 12)),
                        selected: localScenario == scenario,
                        selectedColor: Colors.orange.shade100,
                        checkmarkColor: Colors.orange.shade800,
                        onSelected: (sel) => setSS(() {
                          localScenario = sel ? scenario : null;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: commentCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Kommentar / Begründung (optional)',
                    hintText: 'z. B. â€žGastmannschaft frühzeitig abgereist"',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (localScenario != null)
              TextButton.icon(
                icon: const Icon(Icons.clear, size: 14),
                label: const Text('Zurücksetzen'),
                style: TextButton.styleFrom(foregroundColor: Colors.grey),
                onPressed: () {
                  setSS(() => localScenario = null);
                  commentCtrl.clear();
                },
              ),
            TextButton(
              onPressed: () => Navigator.of(dCtx).pop(),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white),
              onPressed: () {
                onChanged(localScenario);
                Navigator.of(dCtx).pop();
              },
              child: const Text('Übernehmen'),
            ),
          ],
        ),
      ),
    );
  }

  /// Two-option segmented toggle (e.g. HZ 1 | HZ 2 or Team A | Team B).
  Widget _buildToggle2({
    required String label1,
    required String label2,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    Widget btn(String label, bool active, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? Colors.deepPurple : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : Colors.grey.shade700)),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(6)),
      clipBehavior: Clip.hardEdge,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(label1, value, () => onChanged(true)),
          Container(width: 1, height: 30, color: Colors.grey.shade400),
          btn(label2, !value, () => onChanged(false)),
        ],
      ),
    );
  }

  /// Keyboard-navigable autocomplete field for team name entry.
  /// - Typing filters options (case-insensitive contains)
  /// - Arrow keys navigate, Enter selects
  /// - Tab selects the only visible option (if exactly 1 remains) and moves focus
  Widget _buildTeamAutocomplete({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required List<String> teamNames,
    ValueChanged<String>? onChanged,
  }) {
    // Closure variable so Tab handler can see current options without state
    final List<String> currentOptions = [];

    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: (TextEditingValue textValue) {
        final List<String> opts;
        if (textValue.text.isEmpty) {
          opts = teamNames;
        } else {
          final q = textValue.text.toLowerCase();
          opts = teamNames.where((n) => n.toLowerCase().contains(q)).toList();
        }
        currentOptions
          ..clear()
          ..addAll(opts);
        return opts;
      },
      onSelected: (String value) {
        controller.text = value;
        onChanged?.call(value);
      },
      fieldViewBuilder: (context, textController, fieldFocusNode, onFieldSubmitted) {
        return Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.tab &&
                currentOptions.length == 1) {
              textController.text = currentOptions.first;
              onChanged?.call(currentOptions.first);
              // Let Tab propagate so focus moves to next field
              return KeyEventResult.ignored;
            }
            return KeyEventResult.ignored;
          },
          child: TextFormField(
            controller: textController,
            focusNode: fieldFocusNode,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            onChanged: onChanged,
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 260),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text(option, style: const TextStyle(fontSize: 12)),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showManualGameCreationDialog() {
    // Mode toggle: true = free text, false = select from tournament teams
    bool freeTextMode = false;

    String? selectedTeamAId;
    String? selectedTeamBId;
    final teamANameCtrl = TextEditingController();
    final teamBNameCtrl = TextEditingController();
    final gameNameCtrl = TextEditingController(); // e.g. "Finale", "Halbfinale"

    GameType selectedGameType = GameType.friendly;
    String? selectedPoolId;
    DateTime? selectedDate = _startDate;
    TimeOfDay? selectedTime;
    String? selectedCourtId;
    String? selectedRefereeGespannId;

    // Get tournament teams
    final tournamentTeams = _allTeams.where((t) => _selectedTeamIds.contains(t.id)).toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            title: const Text('Spiel manuell erstellen'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mode toggle
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setDlgState(() => freeTextMode = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: !freeTextMode ? Colors.blue : Colors.transparent,
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                ),
                                child: Center(
                                  child: Text(
                                    'Turnierteams',
                                    style: TextStyle(
                                      color: !freeTextMode ? Colors.white : Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setDlgState(() => freeTextMode = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: freeTextMode ? Colors.blue : Colors.transparent,
                                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                ),
                                child: Center(
                                  child: Text(
                                    'Freie Eingabe',
                                    style: TextStyle(
                                      color: freeTextMode ? Colors.white : Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Game Type
                    DropdownButtonFormField<GameType>(
                      value: selectedGameType,
                      decoration: const InputDecoration(
                        labelText: 'Spieltyp',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: const [
                        DropdownMenuItem(value: GameType.friendly, child: Text('Manuell / Einzelspiel')),
                        DropdownMenuItem(value: GameType.pool, child: Text('Gruppenspiel (Pool)')),
                        DropdownMenuItem(value: GameType.elimination, child: Text('K.O.-Spiel')),
                      ],
                      onChanged: (v) => setDlgState(() => selectedGameType = v!),
                    ),
                    const SizedBox(height: 16),

                    // Optional game label (e.g. "Finale", "Halbfinale")
                    TextFormField(
                      controller: gameNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Spielbezeichnung (optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label_outline),
                        hintText: 'z.B. Finale, Halbfinale, Spiel um Platz 3',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Pool ID — only for pool games
                    if (selectedGameType == GameType.pool) ...[
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Pool-Bezeichnung (optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.workspaces),
                          hintText: 'z.B. A, B, C',
                        ),
                        onChanged: (v) => selectedPoolId = v.isNotEmpty ? v : null,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // â”€â”€ Team selection â”€â”€
                    if (!freeTextMode) ...[
                      // Dropdown from registered teams
                      DropdownButtonFormField<String>(
                        value: selectedTeamAId,
                        decoration: const InputDecoration(
                          labelText: 'Team A (Heim) *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.groups),
                        ),
                        items: tournamentTeams.map((team) => DropdownMenuItem(
                          value: team.id,
                          child: Text(team.name),
                        )).toList(),
                        onChanged: (v) => setDlgState(() {
                          selectedTeamAId = v;
                          if (selectedTeamBId == v) selectedTeamBId = null;
                        }),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedTeamBId,
                        decoration: const InputDecoration(
                          labelText: 'Team B (Gast) *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.groups),
                        ),
                        items: tournamentTeams
                            .where((t) => t.id != selectedTeamAId)
                            .map((team) => DropdownMenuItem(
                              value: team.id,
                              child: Text(team.name),
                            ))
                            .toList(),
                        onChanged: (v) => setDlgState(() => selectedTeamBId = v),
                      ),
                    ] else ...[
                      // Free-text team names
                      TextFormField(
                        controller: teamANameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Team A Name *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.groups),
                          hintText: 'z.B. TSV München',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: teamBNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Team B Name *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.groups),
                          hintText: 'z.B. HSC Hamburg',
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Date
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today, color: Colors.blue),
                      title: Text(selectedDate != null
                          ? '${selectedDate!.day.toString().padLeft(2, '0')}.${selectedDate!.month.toString().padLeft(2, '0')}.${selectedDate!.year}'
                          : 'Datum auswählen'),
                      subtitle: const Text('Spieltag'),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (date != null) setDlgState(() => selectedDate = date);
                      },
                    ),

                    // Time
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.access_time, color: Colors.blue),
                      title: Text(selectedTime != null
                          ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                          : 'Uhrzeit auswählen'),
                      subtitle: const Text('Anstoßzeit'),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: ctx,
                          initialTime: selectedTime ?? const TimeOfDay(hour: 10, minute: 0),
                        );
                        if (time != null) setDlgState(() => selectedTime = time);
                      },
                    ),

                    // Court
                    if (_tournamentCourts.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: selectedCourtId,
                        decoration: const InputDecoration(
                          labelText: 'Feld / Halle (optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.stadium),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Kein Feld zugewiesen')),
                          ..._tournamentCourts.map((court) => DropdownMenuItem(
                            value: court.id,
                            child: Text(court.name),
                          )),
                        ],
                        onChanged: (v) => setDlgState(() => selectedCourtId = v),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Referee Gespann
                    if (_refereeGespanne.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: selectedRefereeGespannId,
                        decoration: const InputDecoration(
                          labelText: 'Schiedsrichter-Gespann (optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.sports),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Kein Gespann zugewiesen')),
                          ..._refereeGespanne.map((g) => DropdownMenuItem(
                            value: g['id'] as String,
                            child: Text(g['name'] as String? ?? 'Gespann'),
                          )),
                        ],
                        onChanged: (v) => setDlgState(() => selectedRefereeGespannId = v),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  teamANameCtrl.dispose();
                  teamBNameCtrl.dispose();
                  gameNameCtrl.dispose();
                  Navigator.of(ctx).pop();
                },
                child: const Text('Abbrechen'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: () async {
                  // Validate teams
                  final String teamAName;
                  final String teamBName;
                  final String? teamAId;
                  final String? teamBId;

                  if (freeTextMode) {
                    teamAName = teamANameCtrl.text.trim();
                    teamBName = teamBNameCtrl.text.trim();
                    teamAId = null;
                    teamBId = null;
                    if (teamAName.isEmpty || teamBName.isEmpty) {
                      toastification.show(
                        context: context,
                        type: ToastificationType.error,
                        style: ToastificationStyle.fillColored,
                        title: const Text('Fehler'),
                        description: const Text('Bitte beide Teamnamen eingeben'),
                        alignment: Alignment.topRight,
                        autoCloseDuration: const Duration(seconds: 3),
                        showProgressBar: false,
                      );
                      return;
                    }
                    if (teamAName == teamBName) {
                      toastification.show(
                        context: context,
                        type: ToastificationType.error,
                        style: ToastificationStyle.fillColored,
                        title: const Text('Fehler'),
                        description: const Text('Beide Teams haben denselben Namen'),
                        alignment: Alignment.topRight,
                        autoCloseDuration: const Duration(seconds: 3),
                        showProgressBar: false,
                      );
                      return;
                    }
                  } else {
                    if (selectedTeamAId == null || selectedTeamBId == null) {
                      toastification.show(
                        context: context,
                        type: ToastificationType.error,
                        style: ToastificationStyle.fillColored,
                        title: const Text('Fehler'),
                        description: const Text('Bitte zwei Teams auswählen'),
                        alignment: Alignment.topRight,
                        autoCloseDuration: const Duration(seconds: 3),
                        showProgressBar: false,
                      );
                      return;
                    }
                    final ta = tournamentTeams.firstWhere((t) => t.id == selectedTeamAId);
                    final tb = tournamentTeams.firstWhere((t) => t.id == selectedTeamBId);
                    teamAName = ta.name;
                    teamBName = tb.name;
                    teamAId = selectedTeamAId;
                    teamBId = selectedTeamBId;
                  }

                  DateTime? scheduledTime;
                  if (selectedDate != null && selectedTime != null) {
                    scheduledTime = DateTime(
                      selectedDate!.year, selectedDate!.month, selectedDate!.day,
                      selectedTime!.hour, selectedTime!.minute,
                    );
                  } else if (selectedDate != null) {
                    scheduledTime = selectedDate;
                  }

                  // Append game name label to pool ID if provided
                  final labelValue = gameNameCtrl.text.trim();
                  final poolIdValue = selectedGameType == GameType.pool
                      ? (selectedPoolId ?? (labelValue.isNotEmpty ? labelValue : null))
                      : (labelValue.isNotEmpty ? labelValue : null);

                  final now = DateTime.now();
                  final game = Game(
                    id: '',
                    tournamentId: widget.tournament!.id,
                    teamAId: teamAId,
                    teamBId: teamBId,
                    teamAName: teamAName,
                    teamBName: teamBName,
                    gameType: selectedGameType,
                    poolId: poolIdValue,
                    scheduledTime: scheduledTime,
                    status: GameStatus.scheduled,
                    createdAt: now,
                    updatedAt: now,
                    courtId: selectedCourtId,
                    refereeGespannId: selectedRefereeGespannId,
                  );

                  try {
                    await _gameService.addGame(game);
                    teamANameCtrl.dispose();
                    teamBNameCtrl.dispose();
                    gameNameCtrl.dispose();
                    Navigator.of(ctx).pop();
                    setState(() {});
                    toastification.show(
                      context: context,
                      type: ToastificationType.success,
                      style: ToastificationStyle.fillColored,
                      title: const Text('Spiel erstellt'),
                      description: Text('$teamAName vs $teamBName${labelValue.isNotEmpty ? ' ($labelValue)' : ''}'),
                      alignment: Alignment.topRight,
                      autoCloseDuration: const Duration(seconds: 3),
                      showProgressBar: false,
                    );
                  } catch (e) {
                    toastification.show(
                      context: context,
                      type: ToastificationType.error,
                      style: ToastificationStyle.fillColored,
                      title: const Text('Fehler'),
                      description: Text('Fehler beim Erstellen: $e'),
                      alignment: Alignment.topRight,
                      autoCloseDuration: const Duration(seconds: 4),
                      showProgressBar: false,
                    );
                  }
                },
                child: const Text('Spiel erstellen'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _generatePoolGames() async {
    try {
      int generatedGames = 0;
      for (String category in _categoryPools.keys) {
        for (String pool in _categoryPools[category]!) {
          String poolId = '${category}_${pool}';
          List<String> teamIds = _poolTeams[poolId] ?? [];
          
          if (teamIds.length > 1) {
            // Get actual team objects
            List<Team> teams = teamIds
                .map((id) => _allTeams.firstWhere((team) => team.id == id, orElse: () => Team(
                  id: id,
                  name: 'Unknown Team',
                  city: '',
                  bundesland: '',
                  createdAt: DateTime.now(),
                )))
                .toList();
            
            await _gameService.generatePoolGames(widget.tournament!.id, pool, teams);
            generatedGames += (teams.length * (teams.length - 1)) ~/ 2;
          }
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$generatedGames Pool-Spiele erfolgreich generiert!'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Generieren der Spiele: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getGameTitle(Game game) {
    if (game.gameType == GameType.pool) {
      final poolId = game.poolId?.toUpperCase() ?? '';
      
      // Get all pool games for this pool and sort them to get consistent numbering
      final allPoolGames = _gameService.getPoolGames(widget.tournament!.id, game.poolId ?? '');
      allPoolGames.sort((a, b) => a.id.compareTo(b.id)); // Sort by ID for consistency
      
      // Find the index of this game in the sorted list
      final gameIndex = allPoolGames.indexWhere((g) => g.id == game.id);
      final gameNumber = gameIndex >= 0 ? gameIndex + 1 : 1;
      
      return 'Pool $poolId - Spiel $gameNumber';
    } else {
      // Extract node title from game ID for elimination games
      final parts = game.id.split('_match_');
      if (parts.length > 1) {
        final titleParts = parts[1].split('_');
        if (titleParts.length >= 3) {
          return titleParts.sublist(0, titleParts.length - 2).join(' ');
        }
      }
      return 'K.O. Spiel';
    }
  }

  String _getSimpleGameTitle(Game game) {
    if (game.gameType == GameType.pool) {
      final poolId = game.poolId?.toUpperCase() ?? '';
      final allPoolGames = _gameService.getPoolGames(widget.tournament!.id, game.poolId ?? '');
      allPoolGames.sort((a, b) => a.id.compareTo(b.id));
      final gameIndex = allPoolGames.indexWhere((g) => g.id == game.id);
      final gameNumber = gameIndex >= 0 ? gameIndex + 1 : 1;
      return '$poolId-$gameNumber';
    } else {
      return 'K.O.';
    }
  }

  bool _checkTeamConflicts(Game game) {
    if (game.scheduledTime == null || game.courtId == null) return false;
    
    final gameStart = game.scheduledTime!;
    final gameEnd = gameStart.add(Duration(minutes: _timeSlotDuration));
    
    // Check all other scheduled games
    for (final entry in _scheduledGames.entries) {
      final otherGame = entry.value;
      if (otherGame.id == game.id || otherGame.scheduledTime == null) continue;
      
      final otherStart = otherGame.scheduledTime!;
      final otherEnd = otherStart.add(Duration(minutes: _timeSlotDuration));
      
      // Check if same team is involved
      final hasCommonTeam = (game.teamAId != null && (game.teamAId == otherGame.teamAId || game.teamAId == otherGame.teamBId)) ||
                           (game.teamBId != null && (game.teamBId == otherGame.teamAId || game.teamBId == otherGame.teamBId));
      
      if (hasCommonTeam) {
        // Check for time overlap (same time)
        if ((gameStart.isBefore(otherEnd) && gameEnd.isAfter(otherStart))) {
          return true;
        }
        
        // Check for back-to-back (less than 15 minutes between games)
        final timeBetween = gameStart.difference(otherEnd).inMinutes.abs();
        if (timeBetween < 15 && timeBetween >= 0) {
          return true;
        }
      }
    }
    
    return false;
  }

  List<String> _getTeamConflictDetails(Game game) {
    final conflicts = <String>[];
    if (game.scheduledTime == null || game.courtId == null) return conflicts;
    
    final gameStart = game.scheduledTime!;
    final gameEnd = gameStart.add(Duration(minutes: _timeSlotDuration));
    
    // Check all other scheduled games for detailed conflict info
    for (final entry in _scheduledGames.entries) {
      final otherGame = entry.value;
      if (otherGame.id == game.id || otherGame.scheduledTime == null) continue;
      
      final otherStart = otherGame.scheduledTime!;
      final otherEnd = otherStart.add(Duration(minutes: _timeSlotDuration));
      
      // Find which teams are in conflict
      final conflictingTeams = <String>[];
      if (game.teamAId != null && (game.teamAId == otherGame.teamAId || game.teamAId == otherGame.teamBId)) {
        conflictingTeams.add(game.teamAName);
      }
      if (game.teamBId != null && (game.teamBId == otherGame.teamAId || game.teamBId == otherGame.teamBId)) {
        conflictingTeams.add(game.teamBName);
      }
      
      if (conflictingTeams.isNotEmpty) {
        // Check for time overlap (same time)
        if ((gameStart.isBefore(otherEnd) && gameEnd.isAfter(otherStart))) {
          conflicts.add('${conflictingTeams.join(', ')} spielt gleichzeitig');
        } else {
          // Check for back-to-back (less than 15 minutes between games)
          final timeBetween = gameStart.difference(otherEnd).inMinutes.abs();
          if (timeBetween < 15 && timeBetween >= 0) {
            conflicts.add('${conflictingTeams.join(', ')} spielt direkt hintereinander');
          }
        }
      }
    }
    
    return conflicts;
  }

  Color _getGameColor(Game game) {
    return _getLeagueColor();
  }

  String _getGameLabel(Game game) {
    return 'RHBL';
  }

  Widget _buildScheduleGridWithOverlay() {
    final timeSlots = _generateTimeSlots();
    final courts = widget.tournament!.courts;

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
                ...courts.map((court) => Expanded(
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
          // Scrollable schedule area - Simple Grid
          Expanded(
            child: _buildSimpleScheduleGrid(timeSlots, courts),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleScheduleGrid(List<String> timeSlots, List<Court> courts) {
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
                ...courts.map((court) => Expanded(
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
    final hasConflict = _checkTeamConflicts(game);
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
            border: hasConflict ? Border.all(color: Colors.red, width: 2) : null,
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
            border: hasConflict ? Border.all(color: Colors.red, width: 2) : null,
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
              // Conflict indicator
              if (hasConflict)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.warning,
                      size: 8,
                      color: Colors.white,
                    ),
                  ),
                ),
              // Unschedule button (top-left)
              Positioned(
                top: 2,
                left: 2,
                child: Tooltip(
                  message: 'Spiel aus Plan entfernen',
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
    final gameLabel = _getGameLabel(game);
    final color = _getGameColor(game);
    
    // Use team names directly from game object first, then try lookup
    String teamAName = game.teamAName.isNotEmpty ? game.teamAName : 'Team A';
    String teamBName = game.teamBName.isNotEmpty ? game.teamBName : 'Team B';
    
    // If still default names, try to get from team IDs
    if (teamAName == 'Team A' && game.teamAId != null) {
      final teamA = _allTeams.firstWhere(
        (team) => team.id == game.teamAId,
        orElse: () => Team(
          id: '',
          name: 'Team A',
          city: '',
          bundesland: '',
          createdAt: DateTime.now(),
        ),
      );
      if (teamA.id.isNotEmpty) teamAName = teamA.name;
    }
    
    if (teamBName == 'Team B' && game.teamBId != null) {
      final teamB = _allTeams.firstWhere(
        (team) => team.id == game.teamBId,
        orElse: () => Team(
          id: '',
          name: 'Team B',
          city: '',
          bundesland: '',
          createdAt: DateTime.now(),
        ),
      );
      if (teamB.id.isNotEmpty) teamBName = teamB.name;
    }
    
    // Create abbreviations from team names (first 3 characters for better readability)
    String getAbbreviation(String teamName) {
      if (teamName.length <= 3) return teamName.toUpperCase();
      
      // Try to get meaningful abbreviation
      final words = teamName.split(' ');
      if (words.length > 1) {
        // Use first letter of each word (up to 3)
        String abbrev = '';
        for (int i = 0; i < words.length && abbrev.length < 3; i++) {
          if (words[i].isNotEmpty) {
            abbrev += words[i][0].toUpperCase();
          }
        }
        return abbrev.isNotEmpty ? abbrev : teamName.substring(0, 3).toUpperCase();
      } else {
        // Single word - take first 3 characters
        return teamName.substring(0, 3).toUpperCase();
      }
    }
    

    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with gradient background
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                color,
                color.withOpacity(0.8),
              ],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Text(
            _getLeagueShort(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        // Main content with light background
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Show team names if available, otherwise show game info
                if (teamAName != 'Team A' && teamBName != 'Team B') ...[
                  Text(
                    teamAName,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'vs',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 7,
                      fontWeight: FontWeight.w500,
                      height: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    teamBName,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ] else ...[
                  // Fallback to game title if no team names
                  Text(
                    _getSimpleGameTitle(game),
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGameCardContent(Game game, {bool isPlaceholder = false}) {
    final opacity = isPlaceholder ? 0.5 : 1.0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Simple game title
          Text(
            _getSimpleGameTitle(game),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.black87.withOpacity(opacity),
              height: 1.0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 1),
          
          // Team matchup in single line
          if (game.teamAName.isNotEmpty && game.teamBName.isNotEmpty)
            Text(
              '${_formatTeamNameShort(game.teamAName)} vs ${_formatTeamNameShort(game.teamBName)}',
              style: TextStyle(
                fontSize: 8,
                color: Colors.black54.withOpacity(opacity),
                height: 1.0,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _buildScheduleGrid(List<String> timeSlots, List<Court> courts) {
    return Column(
      children: timeSlots.asMap().entries.map((entry) {
        final index = entry.key;
        final timeSlot = entry.value;
        return Container(
          height: 80.0, // Fixed 80px height per time slot
          child: Row(
            children: [
                              // Time label
                Container(
                  width: 80,
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
                  alignment: Alignment.centerLeft,
                  child: Text(
                    timeSlot,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              // Court columns
              ...courts.map((court) => Expanded(
                                 child: DragTarget<Game>(
                   onWillAcceptWithDetails: (details) => true,
                   onAcceptWithDetails: (details) {
                     final game = details.data;
                     final courtIndex = courts.indexOf(court);
                     final dropPosition = details.offset;
                     _handleGameDrop(game, courtIndex, index, dropPosition, timeSlot);
                   },
                   onMove: (details) {
                     // Optional: Could add visual feedback here for snap preview
                   },
                  builder: (context, candidateData, rejectedData) {
                    return Container(
                      height: 80.0,
                      decoration: BoxDecoration(
                        color: candidateData.isNotEmpty 
                            ? Colors.blue.shade50 
                            : Colors.white,
                        border: Border(
                          left: BorderSide(color: Colors.grey.shade200),
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: candidateData.isNotEmpty
                          ? Center(
                              child: Icon(
                                Icons.add_circle_outline,
                                color: Colors.blue,
                                size: 24,
                              ),
                            )
                          : null,
                    );
                  },
                ),
              )),
            ],
          ),
        );
      }).toList(),
    );
  }

  List<Widget> _buildPositionedGames(List<Court> courts) {
    final List<Widget> positionedGames = [];
    
    for (var entry in _scheduledGames.entries) {
      final game = entry.value;
      if (game.scheduledTime != null && game.courtId != null) {
        final court = courts.firstWhere((c) => c.id == game.courtId);
        final courtIndex = courts.indexOf(court);
        
        // Calculate position
        final gamePosition = _calculateGamePosition(game, courtIndex, courts.length);
        if (gamePosition != null) {
          positionedGames.add(
            Positioned(
              left: gamePosition.left,
              top: gamePosition.top,
              width: gamePosition.width,
              height: gamePosition.height,
              child: _buildGameWidget(game),
            ),
          );
        }
      }
    }
    
    return positionedGames;
  }

  GamePosition? _calculateGamePosition(Game game, int courtIndex, int totalCourts) {
    if (game.scheduledTime == null) return null;
    
    final gameTime = game.scheduledTime!;
    final scheduleStart = DateTime(gameTime.year, gameTime.month, gameTime.day, 
                                  _scheduleStartTime.hour, _scheduleStartTime.minute);
    
    // Calculate total minutes from schedule start
    final totalMinutesFromStart = gameTime.difference(scheduleStart).inMinutes;
    
    // Calculate which time slot this belongs to and position within that slot
    final slotIndex = totalMinutesFromStart ~/ _timeSlotDuration;
    final minutesIntoSlot = totalMinutesFromStart % _timeSlotDuration;
    
    // Each time slot is 60px high, position proportionally within the slot
    final pixelsPerMinute = 60.0 / _timeSlotDuration;
    final top = (slotIndex * 60.0) + (minutesIntoSlot * pixelsPerMinute);
    
    // Calculate horizontal position
    final screenWidth = MediaQuery.of(context).size.width;
    final courtWidth = (screenWidth - 80) / totalCourts;
    final left = 80 + (courtIndex * courtWidth);
    
    // Game height: exactly 30 minutes worth of pixels
    final gameHeight = (30.0 / _timeSlotDuration) * 60.0;
    
    return GamePosition(
      left: left + 2, // Small margin
      top: top,
      width: (courtWidth - 4) * 0.71, // Reduce width to 71% for better visual proportion
      height: gameHeight,
    );
  }

  Widget _buildGameWidget(Game game) {
    return Draggable<Game>(
      data: game,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 200,
          height: 30,
          decoration: BoxDecoration(
            color: _getGameColor(game),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: _buildGameContent(game),
        ),
      ),
      childWhenDragging: Container(
        decoration: BoxDecoration(
          color: _getGameColor(game).withOpacity(0.3),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: _buildGameContent(game, isDragging: true),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _getGameColor(game),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: _buildGameContent(game),
      ),
    );
  }

  Widget _buildGameContent(Game game, {bool isDragging = false}) {
    final gameColor = _getGameColor(game);
    final backgroundColor = isDragging ? gameColor.withOpacity(0.3) : gameColor;
    final textColor = isDragging ? Colors.grey.shade600 : Colors.white;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            backgroundColor,
            backgroundColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Game title with category indicator
            Row(
              children: [
                Expanded(
                  child: Text(
                  _getGameTitle(game),
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 9,
                    color: textColor,
                      letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: textColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getLeagueShort(),
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            // Team matchup
                Text(
              '${_formatTeamNameShort(game.teamAName)} - ${_formatTeamNameShort(game.teamBName)}',
                  style: TextStyle(
                    fontSize: 8,
                fontWeight: FontWeight.w500,
                color: textColor.withOpacity(0.95),
                letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
    );
  }

  String _getLeagueShort() {
    return 'RHBL';
  }

  void _handleFixedGameDrop(Game game, Court court, String timeSlot, int timeSlotIndex) {
    // Parse the time slot to create exact scheduled time (format: "18:00-18:30")
    final timeRange = timeSlot.split('-');
    final startTimeParts = timeRange[0].split(':');
    final hour = int.parse(startTimeParts[0]);
    final minute = int.parse(startTimeParts[1]);
    
    // Create scheduled date time
    final tournamentDays = _getTournamentDays();
    if (_selectedDayIndex < tournamentDays.length) {
      final selectedDay = tournamentDays[_selectedDayIndex];
      final scheduledDateTime = DateTime(
        selectedDay.year,
        selectedDay.month,
        selectedDay.day,
        hour,
        minute,
      );
      
      // Check for conflicts - simple check if slot is already occupied by a different game
      final slotKey = "${court.id}_${timeSlot}_$_selectedDayIndex";
      final existingGame = _scheduledGames[slotKey];
      if (existingGame != null && existingGame.id != game.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dieser Zeitslot ist bereits belegt von "${_getGameTitle(existingGame)}"'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
      
      // Remove game from any previous slot (including the current one if it's the same game)
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
      _scheduledGames[slotKey] = updatedGame;
      
      // Update in database and refresh UI
      _gameService.updateGame(updatedGame).then((_) {
        setState(() {
          _loadScheduledGames();
        });
        
        // Trigger auto-save for schedule changes
        _triggerScheduleAutoSave();
        
        final timeRange = timeSlot.split('-');
        // Check for conflicts after scheduling
        final conflicts = _getTeamConflictDetails(updatedGame);
        
        toastification.show(
          context: context,
          title: Text(conflicts.isNotEmpty ? 'Spiel verschoben - Konflikt!' : 'Spiel verschoben'),
          description: Text(conflicts.isNotEmpty 
            ? '${_getGameTitle(game)} verschoben\n?? ${conflicts.join(', ')}'
            : '${_getGameTitle(game)} zu ${timeRange[0]} auf Feld ${court.name} verschoben'),
          type: conflicts.isNotEmpty ? ToastificationType.warning : ToastificationType.success,
          style: ToastificationStyle.flat,
          autoCloseDuration: Duration(seconds: conflicts.isNotEmpty ? 6 : 3),
        );
      });
    }
  }

  void _handleGameDrop(Game game, int courtIndex, int timeSlotIndex, Offset dropPosition, String timeSlot) {
    final courts = widget.tournament!.courts;
    final court = courts[courtIndex];
    
    // Calculate which time slot to snap to based on drop position
    final totalDropY = dropPosition.dy;
    final pixelsPerMinute = 60.0 / _timeSlotDuration;
    final minutesFromScheduleStart = (totalDropY / pixelsPerMinute).round();
    
    // Snap to nearest time slot boundary
    final snappedMinutes = (minutesFromScheduleStart ~/ _timeSlotDuration) * _timeSlotDuration;
    
    // Calculate final time from schedule start
    final scheduleStartMinutes = _scheduleStartTime.hour * 60 + _scheduleStartTime.minute;
    final finalTotalMinutes = scheduleStartMinutes + snappedMinutes;
    final finalHour = finalTotalMinutes ~/ 60;
    final finalMinutes = finalTotalMinutes % 60;
    
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
      
      // Check for conflicts
      if (_hasTimeConflict(scheduledDateTime, court.id, game.id)) {
        _showConflictDialog();
        return;
      }
      
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
      final key = "${court.id}_${scheduledDateTime.millisecondsSinceEpoch}_$_selectedDayIndex";
      _scheduledGames[key] = updatedGame;
      
      // Update in database and refresh UI
      _gameService.updateGame(updatedGame).then((_) {
        setState(() {
          _loadScheduledGames();
        });
        
        toastification.show(
          context: context,
          title: Text('Spiel zugewiesen'),
          description: Text('Spiel "${_getGameTitle(game)}" zu ${finalHour.toString().padLeft(2, '0')}:${finalMinutes.toString().padLeft(2, '0')} auf ${court.name} zugewiesen (${_timeSlotDuration}min Raster)'),
          type: ToastificationType.success,
          style: ToastificationStyle.flat,
          autoCloseDuration: const Duration(seconds: 5),
        );
      });
    }
  }

  bool _hasTimeConflict(DateTime scheduledTime, String courtId, String gameId) {
    final gameEndTime = scheduledTime.add(const Duration(minutes: 30));
    
    for (var entry in _scheduledGames.entries) {
      final existingGame = entry.value;
      if (existingGame.id == gameId || existingGame.courtId != courtId) continue;
      
      if (existingGame.scheduledTime != null) {
        final existingStart = existingGame.scheduledTime!;
        final existingEnd = existingStart.add(const Duration(minutes: 30));
        
        // Check for overlap
        if (scheduledTime.isBefore(existingEnd) && gameEndTime.isAfter(existingStart)) {
          return true;
        }
      }
    }
    return false;
  }

  void _showConflictDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zeitkonflikt'),
        content: const Text('Ein anderes Spiel ist bereits zu dieser Zeit auf diesem Platz geplant.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeConfigHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          // Status indicators row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Auto-save status indicator
              if (_scheduleAutoSaveStatus != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _scheduleAutoSaveStatus!.contains('Fehler') ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _scheduleAutoSaveStatus!.contains('Fehler') ? Colors.red.shade200 : Colors.green.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isScheduleAutoSaving) 
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          _scheduleAutoSaveStatus!.contains('Fehler') ? Icons.error_outline : Icons.check_circle_outline,
                          size: 16,
                          color: _scheduleAutoSaveStatus!.contains('Fehler') ? Colors.red : Colors.green,
                        ),
                      const SizedBox(width: 8),
                      Text(
                        _scheduleAutoSaveStatus!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _scheduleAutoSaveStatus!.contains('Fehler') ? Colors.red : Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Auto-refresh status indicator
              if (widget.tournament != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isAutoRefreshing) 
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          Icons.refresh,
                          size: 16,
                          color: Colors.blue.shade600,
                        ),
                      const SizedBox(width: 8),
                      Text(
                        _isAutoRefreshing 
                          ? 'Aktualisiert...' 
                          : _lastRefreshTime != null 
                            ? 'Zuletzt: ${_lastRefreshTime!.hour.toString().padLeft(2, '0')}:${_lastRefreshTime!.minute.toString().padLeft(2, '0')}'
                            : 'Auto-Aktualisierung aktiv',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          
          if (_scheduleAutoSaveStatus != null || widget.tournament != null)
            const SizedBox(height: 12),
          
          Row(
            children: [
              // Start Time
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Startzeit',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () async {
                      await _selectStartTime();
                      _triggerScheduleAutoSave(); // Auto-save when schedule times change
                    },
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
              
              const SizedBox(width: 20),
              
              // End Time
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Endzeit',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () async {
                      await _selectEndTime();
                      _triggerScheduleAutoSave(); // Auto-save when schedule times change
                    },
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
              
              const SizedBox(width: 20),
              
              // Duration Selector
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zeitslot-Dauer',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                          child: Text('${duration} min', style: const TextStyle(fontSize: 14)),
                        )).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _timeSlotDuration = value;
                              // Preserve existing game schedules when changing time scale
                              final existingGames = Map<String, Game>.from(_scheduledGames);
                              _scheduledGames.clear();
                              existingGames.forEach((key, game) {
                                if (game.scheduledTime != null && game.courtId != null) {
                                  final hour = game.scheduledTime!.hour;
                                  final minute = game.scheduledTime!.minute;
                                  final timeSlot = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
                                  final newKey = "${game.courtId}_${timeSlot}_$_selectedDayIndex";
                                  _scheduledGames[newKey] = game;
                                }
                              });
                            });
                            _triggerScheduleAutoSave(); // Auto-save when time slot duration changes
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              
              const Spacer(),
              
              // Manual Refresh Button
              if (widget.tournament != null)
                ElevatedButton.icon(
                  onPressed: _isAutoRefreshing ? null : () => _performAutoRefresh(),
                  icon: Icon(
                    _isAutoRefreshing ? Icons.hourglass_empty : Icons.refresh,
                    size: 18,
                  ),
                  label: Text(_isAutoRefreshing ? 'Lädt...' : 'Aktualisieren'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              
              if (widget.tournament != null)
                const SizedBox(width: 8),
              
              // Auto Generate Button
              ElevatedButton.icon(
                onPressed: _autoGenerateSchedule,
                icon: const Icon(Icons.auto_fix_high, size: 18),
                label: const Text('Auto-Planung'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayTabs() {
    final tournamentDays = _getTournamentDays();
    
    if (tournamentDays.isEmpty) {
      return Container();
    }
    
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // Days Tabs
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: tournamentDays.length,
              itemBuilder: (context, index) {
                final day = tournamentDays[index];
                final isSelected = index == _selectedDayIndex;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedDayIndex = index;
                      });
                      // Auto-refresh games when day is changed
                      _loadScheduledGames();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue.shade600 : Colors.white,
                        border: Border.all(
                          color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: Colors.blue.shade600.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ] : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white.withOpacity(0.2) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${day.day}/${day.month}',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.grey.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _getDayName(day.weekday),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? Colors.white : Colors.black87,
                                    height: 1.0,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${day.day}.${day.month}.${day.year}',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: isSelected ? Colors.white.withOpacity(0.8) : Colors.grey.shade600,
                                    height: 1.0,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
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
      ),
    );
  }

  List<DateTime> _getTournamentDays() {
    if (widget.tournament == null) return [];
    
    final startDate = widget.tournament!.startDate;
    final endDate = widget.tournament!.endDate;
    
    if (endDate == null) {
      // If no end date, just return the start date
      return [DateTime(startDate.year, startDate.month, startDate.day)];
    }
    
    final days = <DateTime>[];
    DateTime current = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    
    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      days.add(current);
      current = current.add(const Duration(days: 1));
    }
    
    return days;
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Mo';
      case 2: return 'Di';
      case 3: return 'Mi';
      case 4: return 'Do';
      case 5: return 'Fr';
      case 6: return 'Sa';
      case 7: return 'So';
      default: return '';
    }
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

  void _showAddCourtDialog() {
    final nameController = TextEditingController(
      text: String.fromCharCode(65 + _tournamentCourts.length), // A, B, C, ...
    );
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Feld / Halle hinzufügen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name *',
                border: OutlineInputBorder(),
                hintText: 'z.B. Feld A, Halle 1, ...',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Beschreibung',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final newCourt = Court(
                id: 'court_${DateTime.now().millisecondsSinceEpoch}_${_tournamentCourts.length}',
                name: name,
                );
                setState(() {
                  _tournamentCourts.add(newCourt);
                });
                _triggerScheduleAutoSave();
                Navigator.of(ctx).pop();
              },
              child: const Text('Hinzufügen'),
            ),
          ],
        ),
    );
  }

  void _addTournamentCourt() {
    final courtName = String.fromCharCode(65 + _tournamentCourts.length); // A, B, C, etc.
    final newCourt = Court(
      id: 'court_${DateTime.now().millisecondsSinceEpoch}_${_tournamentCourts.length}',
      name: courtName,
    );
    
    setState(() {
      _tournamentCourts.add(newCourt);
    });
    
    // Trigger auto-save when courts are modified
    _triggerScheduleAutoSave();
  }

  void _removeTournamentCourt(int index) {
    setState(() {
      _tournamentCourts.removeAt(index);
    });
    
    // Trigger auto-save when courts are modified
    _triggerScheduleAutoSave();
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

   void _autoGenerateSchedule() {
    if (widget.tournament == null) {
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(
          content: Text('Turnier muss zuerst gespeichert werden'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show advanced scheduling dialog
    showDialog(
      context: context,
      builder: (context) => AdvancedSchedulingDialog(
        tournament: widget.tournament!,
        gameService: _gameService,
        teamService: _teamService,
        scheduleStartTime: _scheduleStartTime,
        scheduleEndTime: _scheduleEndTime,
        timeSlotDuration: _timeSlotDuration,
        onSchedulingComplete: _handleSchedulingResult,
      ),
    );
  }

  void _handleSchedulingResult(SchedulingResult result) {
    if (result.success) {
      setState(() {
        _loadScheduledGames();
      });
      
      toastification.show(
        context: context,
        title: const Text('Spielplanung erfolgreich'),
        description: Text(
          '${result.scheduledGames} Spiele auf ${result.fieldsUsed} Felder verteilt.\n'
          '${result.unscheduledGames} Spiele konnten nicht geplant werden.\n'
          '${result.warnings.isNotEmpty ? result.warnings.join('\n') : ''}'
        ),
        type: ToastificationType.success,
        style: ToastificationStyle.flat,
        autoCloseDuration: const Duration(seconds: 8),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler bei der Spielplanung: ${result.errorMessage}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  void _triggerScheduleAutoSave() {
    // Cancel previous timer
    _scheduleAutoSaveTimer?.cancel();
    
    // Start new timer for auto-save (debounce for 3 seconds for schedule changes)
    _scheduleAutoSaveTimer = Timer(const Duration(seconds: 3), () {
      _performScheduleAutoSave();
    });
  }

  Future<void> _performScheduleAutoSave() async {
    if (widget.tournament == null) return; // Only auto-save when editing existing tournaments
    
    setState(() {
      _isScheduleAutoSaving = true;
      _scheduleAutoSaveStatus = 'Zeitplan wird gespeichert...';
    });
    
    try {
      // Update the tournament with current court configuration
      final updatedTournament = Tournament(
        id: widget.tournament!.id,
        name: widget.tournament!.name,
        description: widget.tournament!.description,
        imageUrl: widget.tournament!.imageUrl,
        location: widget.tournament!.location,
        startDate: widget.tournament!.startDate,
        endDate: widget.tournament!.endDate,
        status: widget.tournament!.status,
        teamIds: widget.tournament!.teamIds,
        refereeInvitations: widget.tournament!.refereeInvitations,
        divisionBrackets: widget.tournament!.divisionBrackets,
        customBrackets: widget.tournament!.customBrackets,
        courts: _tournamentCourts, // Updated courts
        pools: widget.tournament!.pools, // Added pools
        approvalStatus: widget.tournament!.approvalStatus,
        approvedBy: widget.tournament!.approvedBy,
        approvedAt: widget.tournament!.approvedAt,
        rejectionReason: widget.tournament!.rejectionReason,
        hostClubTeamId: widget.tournament!.hostClubTeamId,
        venueStreet: widget.tournament!.venueStreet,
        venueHouseNumber: widget.tournament!.venueHouseNumber,
        venuePlz: widget.tournament!.venuePlz,
        venueLatitude: widget.tournament!.venueLatitude,
        venueLongitude: widget.tournament!.venueLongitude,
        kampfgerichtInvitations: widget.tournament!.kampfgerichtInvitations,
      );

      await _tournamentService.updateTournament(updatedTournament);
      
      setState(() {
        _isScheduleAutoSaving = false;
        _scheduleAutoSaveStatus = 'Zeitplan automatisch gespeichert';
      });
      
      // Clear status after 3 seconds
      Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _scheduleAutoSaveStatus = null;
          });
        }
      });
      
    } catch (e) {
      setState(() {
        _isScheduleAutoSaving = false;
        _scheduleAutoSaveStatus = 'Fehler beim Speichern des Zeitplans';
      });
      
      // Clear error after 5 seconds
      Timer(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _scheduleAutoSaveStatus = null;
          });
        }
      });
    }
  }

  Widget _buildDelegatePlannerContent() {
    return FutureBuilder<List<Game>>(
      key: _delegatePlannerKey, // Use key to force rebuilds
      future: _loadGamesForAllocation(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Fehler beim Laden der Spiele: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final games = snapshot.data ?? [];
        
        return SingleChildScrollView(
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.assignment_ind, color: Colors.deepOrange),
                          const SizedBox(width: 12),
                          Text(
                            'Delegierte-Planer',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ziehen Sie Delegierte per Drag & Drop auf die Spiele',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Statistics
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.deepOrange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Spiele gesamt: ${games.length}',
                              style: TextStyle(
                                color: Colors.deepOrange.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Zugeordnet: ${games.where((g) => g.delegateId != null).length}',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Offen: ${games.where((g) => g.delegateId == null).length}',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Main planner layout
              if (games.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.sports_soccer,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Keine Spiele vorhanden',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Erstellen Sie zuerst Spiele im "Spiele" Tab',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                _buildDelegatePlannerLayout(games),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDelegatePlannerLayout(List<Game> games) {
    // Get selected delegates for this tournament
    final availableDelegates = _allDelegates.where((delegate) => 
      _selectedDelegateIds.contains(delegate.id)
    ).toList();

    return SizedBox(
      height: 800, // Provide a fixed height to avoid unbounded constraints
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Available delegates on the left
          SizedBox(
            width: 300, // Fixed width for the delegates panel
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Verfügbare Delegierte',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (availableDelegates.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_off,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Keine Delegierte ausgewählt',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Wählen Sie Delegierte im "Auswahl" Tab aus',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: availableDelegates.map((delegate) => _buildDraggableDelegateCard(delegate)).toList(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Main scheduling table on the right
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Delegierte-Zuordnung',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _buildDelegateSchedulingTable(games),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableDelegateCard(Delegate delegate) {
    return Draggable<String>(
      data: delegate.id,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepOrange, Colors.deepOrange.shade700],
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                delegate.fullName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                delegate.licenseType,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              delegate.fullName,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              delegate.licenseType,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepOrange.shade50, Colors.deepOrange.shade100],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.deepOrange.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    delegate.fullName,
                    style: TextStyle(
                      color: Colors.deepOrange.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  Icons.drag_indicator,
                  color: Colors.deepOrange.shade400,
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              delegate.licenseType,
              style: TextStyle(
                color: Colors.deepOrange.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDelegateSchedulingTable(List<Game> games) {
    if (widget.tournament == null || widget.tournament!.courts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_tennis,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Keine Plätze konfiguriert',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Konfigurieren Sie zuerst Plätze im "Plätze" Tab',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    // Get scheduled games only
    final scheduledGames = games.where((g) => g.scheduledTime != null && g.courtId != null).toList();
    
    if (scheduledGames.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.schedule_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Keine Spiele eingeplant',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Planen Sie zuerst Spiele im "Spielplan" Tab',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    final courts = widget.tournament!.courts;
    
    // Group games by date and time
    final gamesByDateTime = <String, Map<String, Game>>{};
    
    for (final game in scheduledGames) {
      if (game.scheduledTime != null && game.courtId != null) {
        final dateKey = '${game.scheduledTime!.year}-${game.scheduledTime!.month.toString().padLeft(2, '0')}-${game.scheduledTime!.day.toString().padLeft(2, '0')}';
        final timeKey = '${game.scheduledTime!.hour.toString().padLeft(2, '0')}:${game.scheduledTime!.minute.toString().padLeft(2, '0')}';
        final slotKey = '${dateKey}_${timeKey}';
        
        if (!gamesByDateTime.containsKey(slotKey)) {
          gamesByDateTime[slotKey] = {};
        }
        gamesByDateTime[slotKey]![game.courtId!] = game;
      }
    }

    final sortedTimeSlots = gamesByDateTime.keys.toList()..sort();

    return SingleChildScrollView(
      child: Column(
        children: [
          // Header row with court names
          Container(
            decoration: BoxDecoration(
              color: Colors.deepOrange.shade50,
              border: Border.all(color: Colors.deepOrange.shade200),
            ),
            child: Row(
              children: [
                // Time column header
                Container(
                  width: 120,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Colors.deepOrange.shade200)),
                  ),
                  child: Text(
                    'Zeit',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange.shade700,
                    ),
                  ),
                ),
                // Court headers
                ...courts.map((court) => Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: Colors.deepOrange.shade200)),
                    ),
                    child: Text(
                      court.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )),
              ],
            ),
          ),
          
          // Time slot rows
          ...sortedTimeSlots.map((timeSlot) {
            final gamesInSlot = gamesByDateTime[timeSlot]!;
            final parts = timeSlot.split('_');
            final dateStr = parts[0];
            final timeStr = parts[1];
            
            return Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                  left: BorderSide(color: Colors.deepOrange.shade200),
                  right: BorderSide(color: Colors.deepOrange.shade200),
                ),
              ),
              child: Row(
                children: [
                  // Time column
                  Container(
                    width: 120,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(right: BorderSide(color: Colors.deepOrange.shade200)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          timeStr,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Court columns
                  ...courts.map((court) {
                    final game = gamesInSlot[court.id];
                    return Expanded(
                      child: _buildDelegateGameSlot(game, court),
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
    }

  Future<void> _assignDelegateToGameDragDrop(Game game, String delegateId) async {
    try {
      // Create updated game with delegate assignment
      final updatedGame = game.copyWith(delegateId: delegateId);
      
      // Update in database
      await _gameService.updateGame(updatedGame);
      
      // Clear the game cache to force fresh data
      _gameService.clearCache();
      
      // Auto-save the tournament with updated delegate assignments  
      await _autoSaveTournament();
      
      // Update local state
      setState(() {
        _delegatePlannerKey = UniqueKey(); // Force rebuild
      });
      
      final delegate = _allDelegates.firstWhere((d) => d.id == delegateId);
      
      toastification.show(
        context: context,
        type: ToastificationType.success,
        style: ToastificationStyle.fillColored,
        title: const Text('Delegierter zugeordnet'),
        description: Text('${delegate.fullName} wurde "${game.displayName}" zugeordnet'),
        alignment: Alignment.topRight,
        autoCloseDuration: const Duration(seconds: 3),
        showProgressBar: false,
      );
    } catch (e) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        title: const Text('Fehler'),
        description: Text('Fehler bei der Zuordnung: $e'),
        alignment: Alignment.topRight,
        autoCloseDuration: const Duration(seconds: 4),
        showProgressBar: false,
      );
    }
  }

  Future<void> _removeDelegateAssignment(Game game) async {
    try {
      // Create updated game with removed delegate assignment
      final updatedGame = game.copyWith(delegateId: null);
      
      // Update in database
      await _gameService.updateGame(updatedGame);
      
      // Update local state
      setState(() {
        _delegatePlannerKey = UniqueKey(); // Force rebuild
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delegierte-Zuordnung für "${game.displayName}" entfernt'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Entfernen der Zuordnung: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

    Widget _buildDelegateGameSlot(Game? game, Court court) {
    if (game == null) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Center(
          child: Text(
            'Kein Spiel',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    final hasAssignment = game.delegateId != null;
    final assignedDelegate = hasAssignment
        ? _allDelegates.where((d) => d.id == game.delegateId).isNotEmpty
            ? _allDelegates.firstWhere((d) => d.id == game.delegateId)
            : null
        : null;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        final delegateId = details.data;
        _assignDelegateToGameDragDrop(game, delegateId);
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          height: 80,
          decoration: BoxDecoration(
            color: candidateData.isNotEmpty
                ? Colors.deepOrange.shade50
                : (hasAssignment ? Colors.green.shade50 : Colors.white),
            border: Border(
              right: BorderSide(color: Colors.grey.shade200),
              bottom: candidateData.isNotEmpty 
                  ? BorderSide(color: Colors.deepOrange.shade300, width: 2)
                  : BorderSide.none,
              top: candidateData.isNotEmpty 
                  ? BorderSide(color: Colors.deepOrange.shade300, width: 2)
                  : BorderSide.none,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Game teams (compact)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_formatTeamNameShort(game.teamAName)} vs ${_formatTeamNameShort(game.teamBName)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: game.gameType == GameType.pool 
                              ? Colors.blue.withValues(alpha: 0.2)
                              : Colors.purple.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          game.gameType == GameType.pool 
                              ? 'Gr. ${game.poolId?.toUpperCase() ?? ''}' 
                              : 'K.O.',
                          style: TextStyle(
                            color: game.gameType == GameType.pool 
                                ? Colors.blue.shade700 
                                : Colors.purple.shade700,
                            fontSize: 8,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Delegate assignment area
                Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: candidateData.isNotEmpty
                        ? Colors.deepOrange.withValues(alpha: 0.2)
                        : (hasAssignment 
                            ? Colors.green.withValues(alpha: 0.1) 
                            : Colors.grey.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(4),
                    border: candidateData.isNotEmpty
                        ? Border.all(color: Colors.deepOrange.shade300)
                        : Border.all(color: Colors.transparent),
                  ),
                  child: candidateData.isNotEmpty
                      ? Center(
                          child: Icon(
                            Icons.add_circle_outline,
                            color: Colors.deepOrange,
                            size: 16,
                          ),
                        )
                      : hasAssignment && assignedDelegate != null
                          ? Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    assignedDelegate.fullName,
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 9,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                                                 GestureDetector(
                                   onTap: () => _removeDelegateAssignmentFromSlot(game),
                                   child: Icon(
                                     Icons.clear,
                                     color: Colors.red.shade400,
                                     size: 12,
                                   ),
                                 ),
                              ],
                            )
                          : Center(
                              child: Text(
                                'Delegierter ablegen',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 8,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _removeDelegateAssignmentFromSlot(Game game) async {
    try {
      // Create updated game with removed delegate assignment
      final updatedGame = game.copyWith(delegateId: null);
      
      // Update in database
      await _gameService.updateGame(updatedGame);
      
      // Clear the game cache to force fresh data
      _gameService.clearCache();
      
      // Auto-save the tournament with updated delegate assignments  
      await _autoSaveTournament();
      
      // Update local state
      setState(() {
        _delegatePlannerKey = UniqueKey(); // Force rebuild
      });
      
      toastification.show(
        context: context,
        type: ToastificationType.warning,
        style: ToastificationStyle.fillColored,
        title: const Text('Delegierter entfernt'),
        description: Text('Delegierte-Zuordnung für "${game.displayName}" entfernt'),
        alignment: Alignment.topRight,
        autoCloseDuration: const Duration(seconds: 3),
        showProgressBar: false,
      );
    } catch (e) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        title: const Text('Fehler'),
        description: Text('Fehler beim Entfernen der Zuordnung: $e'),
        alignment: Alignment.topRight,
        autoCloseDuration: const Duration(seconds: 4),
        showProgressBar: false,
      );
    }
  }

  String? _getCourtName(String? courtId) {
    if (courtId == null) return null;
    final court = _tournamentCourts.where((c) => c.id == courtId).isNotEmpty
        ? _tournamentCourts.firstWhere((c) => c.id == courtId)
        : null;
    return court?.name;
  }

  /// Create demo teams with demo players for testing the tournament
  Future<void> _createDemoTeams() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.orange),
              SizedBox(width: 12),
              Text('Demo Teams erstellen'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.orange),
              SizedBox(height: 16),
              Text('Erstelle Demo Teams mit Spielern...'),
            ],
          ),
        ),
      );

      // Create demo players first
      List<String> createdPlayerIds = [];
      
      // Define demo players
      final demoPlayersData = [
        // Team 1 Players
        {'firstName': 'Anna', 'lastName': 'Schmidt', 'email': 'anna.schmidt.demo@example.com', 'position': 'Defender', 'gender': 'female', 'jerseyNumber': '1'},
        {'firstName': 'Maria', 'lastName': 'Weber', 'email': 'maria.weber.demo@example.com', 'position': 'Blocker', 'gender': 'female', 'jerseyNumber': '2'},
        {'firstName': 'Lisa', 'lastName': 'Mueller', 'email': 'lisa.mueller.demo@example.com', 'position': 'Libero', 'gender': 'female', 'jerseyNumber': '3'},
        {'firstName': 'Sarah', 'lastName': 'Bauer', 'email': 'sarah.bauer.demo@example.com', 'position': 'Setter', 'gender': 'female', 'jerseyNumber': '4'},
        
        // Team 2 Players
        {'firstName': 'Max', 'lastName': 'Mustermann', 'email': 'max.mustermann.demo@example.com', 'position': 'Blocker', 'gender': 'male', 'jerseyNumber': '5'},
        {'firstName': 'Thomas', 'lastName': 'Wagner', 'email': 'thomas.wagner.demo@example.com', 'position': 'Defender', 'gender': 'male', 'jerseyNumber': '6'},
        {'firstName': 'Michael', 'lastName': 'Fischer', 'email': 'michael.fischer.demo@example.com', 'position': 'Setter', 'gender': 'male', 'jerseyNumber': '7'},
        {'firstName': 'Andreas', 'lastName': 'Schneider', 'email': 'andreas.schneider.demo@example.com', 'position': 'Libero', 'gender': 'male', 'jerseyNumber': '8'},
        
        // Mixed Team Players
        {'firstName': 'Julia', 'lastName': 'Hoffmann', 'email': 'julia.hoffmann.demo@example.com', 'position': 'Blocker', 'gender': 'female', 'jerseyNumber': '9'},
        {'firstName': 'Daniel', 'lastName': 'Klein', 'email': 'daniel.klein.demo@example.com', 'position': 'Defender', 'gender': 'male', 'jerseyNumber': '10'},
        {'firstName': 'Sandra', 'lastName': 'Wolf', 'email': 'sandra.wolf.demo@example.com', 'position': 'Setter', 'gender': 'female', 'jerseyNumber': '11'},
        {'firstName': 'Sebastian', 'lastName': 'Richter', 'email': 'sebastian.richter.demo@example.com', 'position': 'Libero', 'gender': 'male', 'jerseyNumber': '12'},
      ];

      // Create demo players
      for (final playerData in demoPlayersData) {
        final player = Player(
          id: '',
          firstName: playerData['firstName'] as String,
          lastName: playerData['lastName'] as String,
          email: playerData['email'] as String,
          phone: '+49 123 456789',
          classification: playerData['position'] as String,
          jerseyNumber: playerData['jerseyNumber'] as String,
          gender: playerData['gender'] as String,
          isActive: true,
          createdAt: DateTime.now(),
        );

        final playerId = await _playerService.addPlayer(player);
        if (playerId != null) {
          createdPlayerIds.add(playerId);
        }
      }

      // Create demo teams with players
      final demoTeams = [
        {
          'name': 'Demo Team 1',
          'city': 'Berlin',
          'playerIds': createdPlayerIds.take(4).toList(),
          'teamManager': 'demo.manager1@example.com',
        },
        {
          'name': 'Demo Team 2',
          'city': 'München',
          'playerIds': createdPlayerIds.skip(4).take(4).toList(),
          'teamManager': 'demo.manager2@example.com',
        },
        {
          'name': 'Demo Team 3',
          'city': 'Hamburg',
          'playerIds': createdPlayerIds.skip(8).take(4).toList(),
          'teamManager': 'demo.manager3@example.com',
        },
      ];

      List<String> createdTeamIds = [];

      // Create teams
      for (final teamData in demoTeams) {
        final team = Team(
          id: '',
          name: teamData['name'] as String,
          city: teamData['city'] as String,
          bundesland: 'Demo State',
          teamManager: teamData['teamManager'] as String,
          rosterPlayerIds: List<String>.from(teamData['playerIds'] as List),
          createdAt: DateTime.now(),
        );

        await _teamService.addTeam(team);
        
        // Get the created team to get its ID
        final allTeams = await _teamService.getAllTeams();
        final createdTeam = allTeams.firstWhere(
          (t) => t.name == team.name && t.city == team.city,
          orElse: () => team,
        );
        
        if (createdTeam.id.isNotEmpty) {
          createdTeamIds.add(createdTeam.id);
        }
      }

      // Close loading dialog
      Navigator.of(context).pop();

      // Refresh teams list
      _loadTeams();

      // Automatically select the created demo teams
      setState(() {
        _selectedTeamIds.addAll(createdTeamIds);
      });

      // Show success message
      toastification.show(
        context: context,
        type: ToastificationType.success,
        style: ToastificationStyle.fillColored,
        title: const Text('Demo Teams erstellt'),
        description: Text('${demoTeams.length} Demo Teams mit ${demoPlayersData.length} Spielern erfolgreich erstellt und ausgewählt!'),
        alignment: Alignment.topRight,
        autoCloseDuration: const Duration(seconds: 5),
        showProgressBar: false,
      );

    } catch (e) {
      // Close loading dialog if open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error message
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        title: const Text('Fehler'),
        description: Text('Fehler beim Erstellen der Demo Teams: $e'),
        alignment: Alignment.topRight,
        autoCloseDuration: const Duration(seconds: 5),
        showProgressBar: false,
      );
    }
  }

  // --- Utility methods ---

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (_) {
      return false;
    }
  }

  bool _isDateInPast(DateTime? date) {
    if (date == null) return false;
    return date.isBefore(DateTime.now());
  }

  int _getPlayingDays() {
    if (_startDate == null || _endDate == null) return 1;
    final difference = _endDate!.difference(_startDate!).inDays;
    return difference < 1 ? 1 : difference + 1;
  }

  bool _isStatusAutomaticallySet() {
    if (_startDate == null && _endDate == null) return false;
    // If end date is in the past, status should be 'completed'
    if (_endDate != null && _isDateInPast(_endDate!)) {
      return _status == 'completed';
    }
    // If start date is in the past but end date isn't, status should be 'ongoing'
    if (_startDate != null && _isDateInPast(_startDate!) && (_endDate == null || !_isDateInPast(_endDate!))) {
      return _status == 'ongoing';
    }
    return false;
  }

  // --- Tab methods ---

  Widget _buildSchedulingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_month, color: Colors.teal, size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Spielplan erstellen',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Planen Sie Spiele und weisen Sie diese Spielfeldern und Zeitfenstern zu.',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (widget.tournament == null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade700),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Speichern Sie zuerst das Turnier, um den Spielplan zu erstellen.',
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await showDialog<bool>(
                          context: context,
                          builder: (context) => AdvancedSchedulingDialog(
                            tournament: widget.tournament!,
                            gameService: _gameService,
                            teamService: _teamService,
                            scheduleStartTime: _scheduleStartTime,
                            scheduleEndTime: _scheduleEndTime,
                            timeSlotDuration: _timeSlotDuration,
                            onSchedulingComplete: (result) {
                              setState(() {});
                            },
                          ),
                        );
                        if (result == true) {
                          setState(() {});
                        }
                      },
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Erweiterte Spielplanung'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentTab() {
    if (widget.tournament == null) {
      return Center(
        child: Text(
          'Bitte speichern Sie das Turnier zuerst.',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }
    return TournamentAssignmentScreen(tournament: widget.tournament!);
  }

  Widget _buildKampfgerichtTab() {
    final filteredMembers = _allKampfgerichtMembers.where((member) {
      if (_kampfgerichtSearchQuery.isEmpty) return true;
      final query = _kampfgerichtSearchQuery.toLowerCase();
      return member.firstName.toLowerCase().contains(query) ||
             member.lastName.toLowerCase().contains(query) ||
             member.email.toLowerCase().contains(query) ||
             (member.city?.toLowerCase().contains(query) ?? false);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.gavel, color: Colors.teal, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Kampfgericht verwalten',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Wählen Sie Zeitnehmer und Sekretäre für dieses Turnier aus',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Search field
                  TextField(
                    controller: _kampfgerichtSearchController,
                    decoration: const InputDecoration(
                      labelText: 'Kampfgericht suchen',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Selected count
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Ausgewählte Kampfgericht-Mitglieder: ${_selectedKampfgerichtIds.length}',
                      style: TextStyle(
                        color: Colors.teal.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Members list
          if (filteredMembers.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _kampfgerichtSearchQuery.isEmpty
                            ? 'Keine Kampfgericht-Mitglieder vorhanden.\nBitte erstellen Sie zuerst Mitglieder in der Kampfgericht-Verwaltung.'
                            : 'Keine Kampfgericht-Mitglieder gefunden',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ...filteredMembers.map((member) {
              final isSelected = _selectedKampfgerichtIds.contains(member.id);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: CheckboxListTile(
                  title: Text(
                    member.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(member.email, overflow: TextOverflow.ellipsis),
                      if (member.city != null && member.city!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              member.city!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  value: isSelected,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedKampfgerichtIds.add(member.id);
                      } else {
                        _selectedKampfgerichtIds.remove(member.id);
                      }
                    });
                  },
                  contentPadding: const EdgeInsets.all(16),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDelegatesTab() {
    return Column(
      children: [
        // Sub-navigation
        Container(
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _delegateSubTab = 'selection'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _delegateSubTab == 'selection' ? Colors.orange : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_pin,
                          size: 18,
                          color: _delegateSubTab == 'selection' ? Colors.white : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Auswählen (${_selectedDelegateIds.length})',
                          style: TextStyle(
                            color: _delegateSubTab == 'selection' ? Colors.white : Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _delegateSubTab = 'planner'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _delegateSubTab == 'planner' ? Colors.deepOrange : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_ind,
                          size: 18,
                          color: _delegateSubTab == 'planner' ? Colors.white : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Zuordnung',
                          style: TextStyle(
                            color: _delegateSubTab == 'planner' ? Colors.white : Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: _delegateSubTab == 'planner'
              ? _buildDelegatePlannerContent()
              : _buildDelegateSelectionContent(),
        ),
      ],
    );
  }

  // --- Games tab helper methods ---

  Widget _buildPoolGamesSection() {
    final hasPools = _categoryPools.values.any((pools) => pools.isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grid_view, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Pool-Spiele generieren',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hasPools
                ? 'Generiert Hinrunden-Spiele für alle definierten Pools.'
                : 'Bitte erstellen Sie zuerst Pools im "Pools" Tab.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: hasPools ? () => _generatePoolGames() : null,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Pool-Spiele generieren'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEliminationBracketSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_tree, color: Colors.purple.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'K.O.-System',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.purple.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _getEliminationGamesInfo(),
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'K.O.-Spiele werden automatisch erstellt, wenn die Gruppenphase abgeschlossen ist.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  void _deleteAllGames() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alle Spiele löschen?'),
        content: const Text(
          'Möchten Sie wirklich alle Spiele für dieses Turnier löschen? Diese Aktion kann nicht rückgängig gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.tournament != null) {
      try {
        await _gameService.deleteAllGamesForTournament(widget.tournament!.id);
        _gameService.clearCache();
        setState(() {});
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          title: const Text('Spiele gelöscht'),
          description: const Text('Alle Spiele wurden erfolgreich gelöscht.'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 3),
          showProgressBar: false,
        );
      } catch (e) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          title: const Text('Fehler'),
          description: Text('Fehler beim Löschen der Spiele: $e'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 5),
          showProgressBar: false,
        );
      }
    }
  }
}

/// Lightweight stats class for Ligapunkte calculation in _autoWriteLigapunkte.
/// Inline stream-key row with reveal/hide toggle for the Livestream tab.
class _StreamKeyRow extends StatefulWidget {
  final String streamKey;
  final Widget Function(BuildContext, String, String) credRowBuilder;

  const _StreamKeyRow({
    required this.streamKey,
    required this.credRowBuilder,
  });

  @override
  State<_StreamKeyRow> createState() => _StreamKeyRowState();
}

class _StreamKeyRowState extends State<_StreamKeyRow> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: widget.credRowBuilder(
            context,
            'Stream-Key',
            _revealed
                ? widget.streamKey
                : '•' * widget.streamKey.length.clamp(8, 32),
          ),
        ),
        IconButton(
          tooltip: _revealed ? 'Verbergen' : 'Anzeigen',
          icon: Icon(_revealed ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _revealed = !_revealed),
        ),
        IconButton(
          tooltip: 'Kopieren',
          icon: const Icon(Icons.copy),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: widget.streamKey));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Stream-Key kopiert')),
            );
          },
        ),
      ],
    );
  }
}

class _LPTeamStats {
  final String id;
  final String name;
  int played = 0;
  int wins = 0;
  int draws = 0;
  int losses = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;

  _LPTeamStats({required this.id, required this.name});

  int get points => wins * 2 + draws;
  int get goalDiff => goalsFor - goalsAgainst;
}
