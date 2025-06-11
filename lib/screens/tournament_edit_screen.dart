import 'package:flutter/material.dart';
import '../models/tournament.dart';
import '../models/team.dart';
import '../models/tournament_criteria.dart';
import '../models/court.dart';
import '../models/game.dart';
import '../services/tournament_service.dart';
import '../services/team_service.dart';
import '../services/court_service.dart';
import '../services/game_service.dart';
import '../data/german_cities.dart';
import 'dart:math' as math;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import '../widgets/custom_bracket_builder.dart';
import 'package:toastification/toastification.dart';
import 'tournament_games_screen.dart';

class TournamentEditScreen extends StatefulWidget {
  final Tournament? tournament; // null for creating new tournament

  const TournamentEditScreen({
    super.key,
    this.tournament,
  });

  @override
  State<TournamentEditScreen> createState() => _TournamentEditScreenState();
}

class _TournamentEditScreenState extends State<TournamentEditScreen> {
  final TournamentService _tournamentService = TournamentService();
  final TeamService _teamService = TeamService();
  final CourtService _courtService = CourtService();
  final GameService _gameService = GameService();
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pointsController = TextEditingController();
  final _imageUrlController = TextEditingController();
  
  // Tournament data
  DateTime? _startDate;
  DateTime? _endDate;
  // Add category-specific dates support
  Map<String, DateTime?> _categoryStartDates = {}; // category -> specific start date
  Map<String, DateTime?> _categoryEndDates = {}; // category -> specific end date
  bool _useCategorySpecificDates = false; // Toggle for using category-specific dates
  String _status = 'upcoming';
  List<String> _selectedCategories = [];
  GermanCity? _selectedLocation;
  TextEditingController _locationController = TextEditingController(); // Initialize immediately
  
  // Available categories
  final List<String> _availableCategories = [
    'GBO Juniors Cup',
    'GBO Seniors Cup',
  ];
  
  final List<String> _statusOptions = [
    'upcoming',
    'ongoing',
    'completed',
  ];

  // Navigation state
  String _selectedTab = 'basic'; // basic, teams, divisions, criteria, courts, settings
  
  // Tournament Criteria
  TournamentCriteria _criteria = TournamentCriteria();

  // Team management
  List<Team> _allTeams = [];
  List<String> _selectedTeamIds = [];
  String _teamFilterDivision = 'Alle';
  String _teamSearchQuery = '';
  final _teamSearchController = TextEditingController();

  // Available divisions for team filtering
  final List<String> _divisions = [
    'Women\'s U14',
    'Women\'s U16', 
    'Women\'s U18',
    'Women\'s Seniors',
    'Women\'s FUN',
    'Men\'s U14',
    'Men\'s U16',
    'Men\'s U18', 
    'Men\'s Seniors',
    'Men\'s FUN',
  ];

  // Add state variables for pool management
  String? _selectedDivisionForPools;
  Map<String, List<String>> _divisionPools = {}; // division -> list of pool names
  Map<String, List<String>> _poolTeams = {}; // poolId -> list of team IDs
  Map<String, List<String>> _placeholderTeams = {}; // poolId -> list of placeholder team IDs from presets
  Map<String, bool> _poolIsFunBracket = {}; // poolId -> is fun bracket (doesn't count for ranking)
  Map<String, List<BracketRound>> _divisionBrackets = {}; // division -> knockout rounds
  int _poolCounter = 1;

  // Add state variables for custom bracket management
  Map<String, List<CustomBracketNode>> _divisionCustomBrackets = {}; // division -> custom bracket nodes

  // Bracket view mode toggle (for migration from old to new system)
  bool _showOldBrackets = false;

  // Court management
  List<Court> _allCourts = [];
  List<String> _selectedCourtIds = [];
  final MapController _mapController = MapController();
  LatLng _mapCenter = const LatLng(51.1657, 10.4515); // Germany center
  double _mapZoom = 6.0;
  bool _isPlacingCourt = false; // New state for court placement mode
  bool _isEditingCourt = false; // State for editing mode
  Court? _selectedCourtForEditing;
  final _courtNameController = TextEditingController();
  final _courtDescriptionController = TextEditingController();
  String _courtType = 'outdoor';
  int _courtCapacity = 0;
  List<String> _courtAmenities = [];
  String _courtLabel = 'A'; // Default label for new courts
  
  final List<String> _courtTypes = [
    'outdoor',
    'indoor', 
    'grass',
    'sand',
    'concrete',
    'clay',
  ];
  
  final List<String> _availableAmenities = [
    'lights',
    'scoreboard',
    'parking',
    'restroom',
    'seating',
    'shelter',
    'food_service',
    'first_aid',
  ];

  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _loadTeams();
    _loadCourts();
    
    _teamSearchController.addListener(() {
      setState(() {
        _teamSearchQuery = _teamSearchController.text.toLowerCase();
      });
    });
  }

  void _initializeData() {
    if (widget.tournament != null) {
      final tournament = widget.tournament!;
      _nameController.text = tournament.name;
      _descriptionController.text = tournament.description ?? '';
      _pointsController.text = tournament.points.toString();
      _imageUrlController.text = tournament.imageUrl ?? '';
      _startDate = tournament.startDate;
      _endDate = tournament.endDate;
      _status = tournament.status;
      _selectedCategories = List<String>.from(tournament.categories); // Explicit type
      _selectedTeamIds = List<String>.from(tournament.teamIds); // Explicit type
      
      // Initialize category-specific dates
      if (tournament.categoryStartDates != null && tournament.categoryStartDates!.isNotEmpty) {
        _useCategorySpecificDates = true;
        _categoryStartDates = Map<String, DateTime?>.from(tournament.categoryStartDates!);
        _categoryEndDates = Map<String, DateTime?>.from(tournament.categoryEndDates ?? {});
      } else {
        _useCategorySpecificDates = false;
        _categoryStartDates = {};
        _categoryEndDates = {};
      }
      
      // Load criteria if it exists
      if (tournament.criteria != null) {
        _criteria = tournament.criteria!;
      }
      
      // Try to find location in German cities
      _selectedLocation = GermanCities.findByDisplayName(tournament.location);
      
      // Set location controller text
      _locationController.text = tournament.location;
      
      // Set map location if we have coordinates - removed automatic coordinate lookup
      // The map will stay centered on Germany for now
      
      // Load existing bracket data
      for (String division in tournament.divisionBrackets.keys) {
        final bracket = tournament.divisionBrackets[division]!;
        
        // Load pools
        final divisionPoolNames = <String>[];
        for (String poolId in bracket.pools.keys) {
          // Extract pool name from poolId (format: "division_poolName")
          final poolName = poolId.substring(division.length + 1);
          divisionPoolNames.add(poolName);
          
          // Load pool teams with explicit type casting
          _poolTeams[poolId] = List<String>.from(bracket.pools[poolId] ?? []);
          
          // Load fun bracket status
          _poolIsFunBracket[poolId] = bracket.poolIsFunBracket[poolId] ?? false;
        }
        _divisionPools[division] = divisionPoolNames;
        
        // Load knockout rounds
        _divisionBrackets[division] = List<BracketRound>.from(bracket.knockoutRounds);
      }
      
      // Load custom brackets if they exist
      for (String division in tournament.customBrackets.keys) {
        final customBracket = tournament.customBrackets[division]!;
        _divisionCustomBrackets[division] = List<CustomBracketNode>.from(customBracket.nodes);
      }
    } else {
      // Default values for new tournament
      _pointsController.text = '20';
      _selectedCategories = ['GBO Juniors Cup'];
      _selectedTeamIds = []; // Start with no teams selected
      _locationController.text = ''; // Start with empty location
      _divisionPools = {}; // Start with no pools
      _poolTeams = {}; // Start with no pool teams
      _poolIsFunBracket = {}; // Start with no fun brackets
      _divisionBrackets = {}; // Start with no knockout rounds
      _criteria = TournamentCriteria(); // Initialize with default criteria
      _selectedCourtIds = []; // Start with no courts selected
      _useCategorySpecificDates = false;
      _categoryStartDates = {};
      _categoryEndDates = {};
    }
  }

  void _loadTeams() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      _teamService.getTeams().listen((teams) {
        setState(() {
          _allTeams = teams;
          _isLoading = false;
        });
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loadCourts() async {
    try {
      _courtService.getCourts().listen((courts) {
        setState(() {
          _allCourts = courts;
          // Auto-position map when courts are loaded
          _autoPositionMap();
        });
      });
    } catch (e) {
      print('Error loading courts: $e');
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

    // Priority 2: Use existing courts center if no tournament location
    if (targetPosition == null && _allCourts.isNotEmpty) {
      if (_allCourts.length == 1) {
        // Single court - center on it
        final court = _allCourts.first;
        targetPosition = LatLng(court.latitude, court.longitude);
        targetZoom = 16.0;
      } else {
        // Multiple courts - find center point
        double avgLat = _allCourts.map((c) => c.latitude).reduce((a, b) => a + b) / _allCourts.length;
        double avgLng = _allCourts.map((c) => c.longitude).reduce((a, b) => a + b) / _allCourts.length;
        targetPosition = LatLng(avgLat, avgLng);
        targetZoom = 14.0;
      }
    }

    // Priority 3: Use a default specific location (e.g., Berlin) instead of all of Germany
    if (targetPosition == null) {
      targetPosition = const LatLng(52.5200, 13.4050); // Berlin center
      targetZoom = 10.0;
    }

    // Update map center and zoom
    setState(() {
      _mapCenter = targetPosition!;
      _mapZoom = targetZoom;
    });

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
    return Scaffold(
      body: Row(
        children: [
          // Custom Left Navigation Panel for Tournament Editing
          _buildTournamentNavigation(),
          // Main Content Area
          Expanded(
            child: Container(
              color: Colors.grey[100],
              child: Column(
                children: [
                  _buildHeader(),
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

  Widget _buildTournamentNavigation() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Logo/Header Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: Column(
              children: [
                Image.asset(
                  'logo.png',
                  height: 60,
                  width: 90,
                ),
                const SizedBox(height: 8),
                const Text(
                  'German Beach Open',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.edit, color: Colors.blue.shade700, size: 20),
                      const SizedBox(height: 4),
                      Text(
                        widget.tournament == null ? 'Neues Turnier' : 'Turnier bearbeiten',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (widget.tournament != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _nameController.text.isNotEmpty 
                              ? _nameController.text
                              : widget.tournament!.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildNavItem('basic', 'Grunddaten', Icons.info_outline),
                _buildNavItem('teams', 'Teams (${_selectedTeamIds.length})', Icons.group),
                _buildNavItem('divisions', 'Divisionen', Icons.category),
                if (_selectedCategories.contains('GBO Seniors Cup'))
                  _buildNavItem('criteria', 'Kriterien', Icons.assignment_turned_in),
                _buildNavItem('games', 'Spiele', Icons.sports_volleyball),
                _buildNavItem('courts', 'Plätze', Icons.location_on),
                _buildNavItem('settings', 'Einstellungen', Icons.settings),
              ],
            ),
          ),
          
          // Footer with action buttons
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
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
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Zurück'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
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

  Widget _buildNavItem(String tabId, String title, IconData icon) {
    final isSelected = _selectedTab == tabId;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.blue.shade700 : Colors.black87,
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

  Widget _buildHeader() {
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
          Expanded(
            child: Text(
              _getTabTitle(),
              style: const TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_selectedTab == 'teams')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${_selectedTeamIds.length} Teams ausgewählt',
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
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
      case 'divisions':
        return 'Divisionen';
      case 'criteria':
        return 'Turnier Kriterien';
      case 'courts':
        return 'Plätze';
      case 'settings':
        return 'Einstellungen';
      default:
        return 'Grunddaten';
    }
  }

  Widget _buildTabNavigation() {
    // Remove this method as navigation is now in the sidebar
    return const SizedBox.shrink();
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 'basic':
        return _buildBasicDataTab();
      case 'teams':
        return _buildTeamsTab();
      case 'divisions':
        return _buildDivisionsTab();
      case 'criteria':
        return _buildCriteriaTab();
      case 'games':
        return _buildGamesTab();
      case 'courts':
        return _buildCourtsTab();
      case 'settings':
        return _buildSettingsTab();
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
                    
                    // Category-specific dates toggle
                    if (_selectedCategories.length > 1) ...[
                      Container(
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
                                Icon(Icons.date_range, color: Colors.blue.shade600),
                                const SizedBox(width: 8),
                                Text(
                                  'Getrennte Termine für Kategorien',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                                const Spacer(),
                                Switch(
                                  value: _useCategorySpecificDates,
                                  onChanged: (value) {
                                    setState(() {
                                      _useCategorySpecificDates = value;
                                      if (value) {
                                        // Initialize category dates with main dates
                                        for (String category in _selectedCategories) {
                                          _categoryStartDates[category] = _categoryStartDates[category] ?? _startDate;
                                          _categoryEndDates[category] = _categoryEndDates[category] ?? _endDate;
                                        }
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Aktivieren Sie diese Option, um verschiedene Termine für Jugend- und Seniorenturniere zu verwenden.',
                              style: TextStyle(
                                color: Colors.blue.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Date selection based on category-specific toggle
                    if (_useCategorySpecificDates && _selectedCategories.length > 1) ...[
                      // Category-specific date selection
                      ...(_selectedCategories.map((category) {
                        String categoryName = category.contains('Juniors') ? 'Jugend' : 'Senioren';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$categoryName Turnier',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: category.contains('Juniors') ? Colors.orange.shade700 : Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                // Category Start Date
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _selectCategoryStartDate(category),
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'Startdatum *',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.calendar_today),
                                      ),
                                      child: Text(
                                        _categoryStartDates[category] != null 
                                            ? '${_categoryStartDates[category]!.day}.${_categoryStartDates[category]!.month}.${_categoryStartDates[category]!.year}'
                                            : 'Datum auswählen',
                                        style: TextStyle(
                                          color: _categoryStartDates[category] != null ? Colors.black : Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                
                                // Category End Date
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _selectCategoryEndDate(category),
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'Enddatum (optional)',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.event_available),
                                      ),
                                      child: Text(
                                        _categoryEndDates[category] != null 
                                            ? '${_categoryEndDates[category]!.day}.${_categoryEndDates[category]!.month}.${_categoryEndDates[category]!.year}'
                                            : 'Datum auswählen',
                                        style: TextStyle(
                                          color: _categoryEndDates[category] != null ? Colors.black : Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                
                                // Playing days info
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        '${_getPlayingDaysForCategory(category)}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                      Text(
                                        'Spieltage',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.green.shade600,
                                        ),
                                      ),
                                      if (_getPlayingDaysForCategory(category) > 1) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          '+20 Pts',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      }).toList()),
                    ] else ...[
                      // Standard date selection
                      Row(
                        children: [
                          // Start Date
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectStartDate(),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Startdatum *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.calendar_today),
                                  suffixIcon: _isDateInPast(_startDate)
                                      ? Tooltip(
                                          message: 'Vergangenes Datum - Status wird automatisch gesetzt',
                                          child: Icon(Icons.history, color: Colors.orange, size: 20),
                                        )
                                      : null,
                                ),
                                child: Text(
                                  _startDate != null 
                                      ? '${_startDate!.day}.${_startDate!.month}.${_startDate!.year}'
                                      : 'Datum auswählen',
                                  style: TextStyle(
                                    color: _startDate != null ? Colors.black : Colors.grey[600],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          
                          // End Date
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectEndDate(),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Enddatum (optional)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.event_available),
                                  suffixIcon: _isDateInPast(_endDate)
                                      ? Tooltip(
                                          message: 'Vergangenes Datum - Status wird automatisch gesetzt',
                                          child: Icon(Icons.history, color: Colors.orange, size: 20),
                                        )
                                      : null,
                                ),
                                child: Text(
                                  _endDate != null 
                                      ? '${_endDate!.day}.${_endDate!.month}.${_endDate!.year}'
                                      : 'Datum auswählen',
                                  style: TextStyle(
                                    color: _endDate != null ? Colors.black : Colors.grey[600],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          
                          // Playing days info
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '${_getPlayingDays()}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                Text(
                                  'Spieltage',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green.shade600,
                                  ),
                                ),
                                if (_getPlayingDays() > 1) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '+20 Pts',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
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
                    Row(
                      children: [
                        // Points
                        Expanded(
                          child: _selectedCategories.contains('GBO Seniors Cup') 
                              ? InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'Gesamtpunkte (inkl. Supercup Bonus)',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.star),
                                    suffixIcon: Tooltip(
                                      message: 'Punkte werden automatisch aus den Kriterien berechnet. ${_criteria.supercupBonus > 0 ? "Supercup Bonus (+150) ist enthalten!" : "Erfülle alle Supercup-Kriterien für +150 Bonus"}',
                                      child: Icon(
                                        _criteria.supercupBonus > 0 ? Icons.star : Icons.info_outline, 
                                        color: _criteria.supercupBonus > 0 ? Colors.green : Colors.blue
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        '${_criteria.totalPoints + _criteria.supercupBonus}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                      if (_criteria.supercupBonus > 0) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '+${_criteria.supercupBonus} Bonus',
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
                                )
                              : TextFormField(
                                  controller: _pointsController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Punkte *',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.star),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Bitte geben Sie Punkte ein';
                                    }
                                    if (int.tryParse(value) == null) {
                                      return 'Bitte geben Sie eine gültige Zahl ein';
                                    }
                                    return null;
                                  },
                                ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Status
                        Expanded(
                          child: Column(
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
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Categories Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.category, color: Colors.orange),
                        const SizedBox(width: 12),
                        Text(
                          'Kategorien',
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
                      'Wählen Sie die Kategorien aus, für die dieses Turnier zählt:',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: _availableCategories.map((category) {
                        final isSelected = _selectedCategories.contains(category);
                        return FilterChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedCategories.add(category);
                              } else {
                                _selectedCategories.remove(category);
                              }
                            });
                          },
                          selectedColor: Colors.blue.withValues(alpha: 0.2),
                          checkmarkColor: Colors.blue,
                        );
                      }).toList(),
                    ),
                    
                    if (_selectedCategories.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Bitte wählen Sie mindestens eine Kategorie aus',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
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

  Widget _buildTeamsTab() {
    List<Team> filteredTeams = _allTeams.where((team) {
      // Filter by division
      if (_teamFilterDivision != 'Alle' && !_isTeamCompatibleWithDivision(team, _teamFilterDivision)) {
        return false;
      }
      
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
              
              Row(
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
                  const SizedBox(width: 16),
                  
                  // Division filter
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _teamFilterDivision,
                      decoration: InputDecoration(
                        labelText: 'Division',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem(value: 'Alle', child: Text('Alle')),
                        ..._divisions.map((division) => DropdownMenuItem(
                          value: division,
                          child: Text(division),
                        )),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _teamFilterDivision = value!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Select/Deselect All button
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        if (_selectedTeamIds.length == filteredTeams.length) {
                          // Deselect all visible teams
                          for (var team in filteredTeams) {
                            _selectedTeamIds.remove(team.id);
                          }
                        } else {
                          // Select all visible teams
                          for (var team in filteredTeams) {
                            if (!_selectedTeamIds.contains(team.id)) {
                              _selectedTeamIds.add(team.id);
                            }
                          }
                        }
                      });
                    },
                    icon: Icon(_selectedTeamIds.length == filteredTeams.length && filteredTeams.isNotEmpty 
                        ? Icons.deselect 
                        : Icons.select_all),
                    label: Text(_selectedTeamIds.length == filteredTeams.length && filteredTeams.isNotEmpty 
                        ? 'Alle abwählen' 
                        : 'Alle auswählen'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                      foregroundColor: Colors.black87,
                    ),
                  ),
                ],
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
                                Text('${team.city} • ${team.division}'),
                                if (team.teamManager != null)
                                  Text('Manager: ${team.teamManager}'),
                              ],
                            ),
                            secondary: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _getDivisionColor(team.division).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Center(
                                child: Text(
                                  team.name.substring(0, 2).toUpperCase(),
                                  style: TextStyle(
                                    color: _getDivisionColor(team.division),
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

  Widget _buildDivisionsTab() {
    if (_selectedDivisionForPools == null) {
      return _buildDivisionSelectionView();
    } else {
      return _buildPoolManagementView();
    }
  }

  Widget _buildDivisionSelectionView() {
    // Group selected teams by division
    Map<String, List<Team>> teamsByDivision = {};
    
    for (String teamId in _selectedTeamIds) {
      Team? team = _allTeams.firstWhere((t) => t.id == teamId, orElse: () => Team(
        id: '', name: '', city: '', bundesland: '', division: '', createdAt: DateTime.now()
      ));
      
      if (team.id.isNotEmpty) {
        if (!teamsByDivision.containsKey(team.division)) {
          teamsByDivision[team.division] = [];
        }
        teamsByDivision[team.division]!.add(team);
      }
    }
    
    // Expand divisions with corresponding Fun tournaments for Senior divisions
    final expandedDivisions = _expandDivisionsWithFunTournaments(teamsByDivision);

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
                      Icon(Icons.category, color: Colors.purple),
                      const SizedBox(width: 12),
                      Text(
                        'Divisionen verwalten',
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
                    'Wählen Sie eine Division aus, um Pools/Gruppen zu erstellen und Teams zuzuweisen.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  
                  if (expandedDivisions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'Keine Teams ausgewählt\nWechseln Sie zum Teams-Tab um Teams auszuwählen',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    )
                  else
                    ...expandedDivisions.entries.map((entry) {
                      final division = entry.key;
                      final teams = entry.value;
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: _getDivisionColor(division).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.group,
                              color: _getDivisionColor(division),
                              size: 24,
                            ),
                          ),
                          title: Text(
                            division,
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${teams.length} Teams'),
                              Text(
                                _getDivisionDescription(division),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Pools verwalten',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.arrow_forward_ios, size: 16),
                            ],
                          ),
                          onTap: () {
                            setState(() {
                              _selectedDivisionForPools = division;
                              // Initialize pools for this division if not exists
                              if (!_divisionPools.containsKey(division)) {
                                _divisionPools[division] = [];
                              }
                            });
                          },
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoolManagementView() {
    // Get teams for selected division
    List<Team> divisionTeams = [];
    Set<String> teamsInPools = {};
    
    for (String teamId in _selectedTeamIds) {
      Team? team = _allTeams.firstWhere((t) => t.id == teamId, orElse: () => Team(
        id: '', name: '', city: '', bundesland: '', division: '', createdAt: DateTime.now()
      ));
      
      if (team.id.isNotEmpty && _isTeamCompatibleWithDivision(team, _selectedDivisionForPools!)) {
        divisionTeams.add(team);
      }
    }

    // Get teams that are already in pools (including corresponding A/B tournaments)
    for (String poolId in _poolTeams.keys) {
      if (_isPoolIdRelatedToDivision(poolId, _selectedDivisionForPools!)) {
        teamsInPools.addAll(_poolTeams[poolId] ?? []);
      }
    }

    // Available teams (not in any pool)
    List<Team> availableTeams = divisionTeams.where((team) => !teamsInPools.contains(team.id)).toList();

    return Column(
      children: [
        // Header with back button
        Container(
          padding: const EdgeInsets.all(24),
          color: Colors.white,
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.blue),
                onPressed: () {
                  setState(() {
                    _selectedDivisionForPools = null;
                  });
                },
              ),
              const SizedBox(width: 12),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getDivisionColor(_selectedDivisionForPools!).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.group,
                  color: _getDivisionColor(_selectedDivisionForPools!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedDivisionForPools!,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Pool Management - ${divisionTeams.length} Teams',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                            ),
                          ),
                          const Spacer(),
              // Toggle button for bracket view mode
                          Container(
                            decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                        child: Row(
                  mainAxisSize: MainAxisSize.min,
                          children: [
                    _buildToggleButton(
                      'New Bracket', 
                      !_showOldBrackets, 
                      () => setState(() => _showOldBrackets = false),
                    ),
                    _buildToggleButton(
                      'Migration View', 
                      _showOldBrackets, 
                      () => setState(() => _showOldBrackets = true),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        
        // Main content area - USE FULL HEIGHT
                  Expanded(
          child: _showOldBrackets 
              ? _buildOldPoolView(divisionTeams, availableTeams)
              : _buildCustomBracketView(availableTeams, divisionTeams),
        ),
      ],
    );
  }

  Widget _buildCustomBracketView(List<Team> teams, List<Team> divisionTeams) {
    final customNodes = _divisionCustomBrackets[_selectedDivisionForPools] ?? [];
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: CustomBracketBuilder(
        initialNodes: customNodes,
        divisionName: _selectedDivisionForPools!,
        availableTeams: teams,
        poolTeams: _poolTeams,
        allTeams: divisionTeams,
        tournament: Tournament(
          id: widget.tournament?.id ?? '',
          name: _nameController.text,
          categories: _divisionPools.keys.toList(),
          location: _locationController.text,
          startDate: _startDate ?? DateTime.now(),
          endDate: _endDate,
          points: 0,
          status: 'upcoming',
        ),
        onPresetTeamsLoaded: (poolId, presetTeamIds) {
          // Handle preset team loading - these become placeholders
          setState(() {
            _poolTeams[poolId] = List.from(presetTeamIds);
            // Track these as placeholder teams
            _placeholderTeams[poolId] = List.from(presetTeamIds);
          });
        },
        onTeamRemove: (poolId, teamId) {
          _removeTeamFromPool(poolId, teamId);
        },
        placeholderTeams: _placeholderTeams,
        onTeamDrop: (team, node) {
          // Handle team assignment to pool
          if (node.nodeType == 'pool') {
            setState(() {
              // Create a pool ID based on the node
              final poolId = '${_selectedDivisionForPools}_${node.title}';
              
              print('Assigning ${team.name} to pool: $poolId');
              
              // Remove team from any other pools first (including corresponding A/B tournaments)
              for (String existingPoolId in _poolTeams.keys.toList()) {
                if (_isPoolIdRelatedToDivision(existingPoolId, _selectedDivisionForPools!) && existingPoolId != poolId) {
                  if (_poolTeams[existingPoolId]!.contains(team.id)) {
                    print('Removing ${team.name} from pool: $existingPoolId (cross-tournament removal)');
                    _poolTeams[existingPoolId]!.remove(team.id);
                    
                    // Restore placeholder teams if this pool has them and now has fewer teams than placeholders
                    if (_placeholderTeams.containsKey(existingPoolId)) {
                      final placeholders = _placeholderTeams[existingPoolId]!;
                      final currentTeams = _poolTeams[existingPoolId]!;
                      
                      // If we have fewer real teams than placeholder slots, fill with placeholders
                      if (currentTeams.length < placeholders.length) {
                        final missingCount = placeholders.length - currentTeams.length;
                        final availablePlaceholders = placeholders.where((p) => !currentTeams.contains(p)).take(missingCount);
                        _poolTeams[existingPoolId]!.addAll(availablePlaceholders);
                      }
                    }
                  }
                }
              }
              
              // Initialize pool if it doesn't exist
              if (!_poolTeams.containsKey(poolId)) {
                _poolTeams[poolId] = [];
              }
              
              // If this pool has placeholders, replace one with the real team or add beyond placeholder limit
              if (_placeholderTeams.containsKey(poolId)) {
                final placeholders = _placeholderTeams[poolId]!;
                final currentTeams = _poolTeams[poolId]!;
                
                // First try to replace a placeholder
                bool replacedPlaceholder = false;
                for (String placeholder in placeholders) {
                  if (currentTeams.contains(placeholder)) {
                    // Replace placeholder with real team
                    final index = currentTeams.indexOf(placeholder);
                    currentTeams[index] = team.id;
                    print('Replaced placeholder $placeholder with ${team.name} at index $index (proceeding team)');
                    replacedPlaceholder = true;
                    break;
                  }
                }
                
                // If no placeholder to replace, add the team anyway (as non-proceeding if beyond placeholder limit)
                if (!replacedPlaceholder && !currentTeams.contains(team.id)) {
                  currentTeams.add(team.id);
                  final isProceeding = _getProceedingTeamCount(poolId) < placeholders.length;
                  print('Added ${team.name} to pool as ${isProceeding ? "proceeding" : "non-proceeding"} team');
                }
              } else {
                // No placeholders, add team normally if not already there
                if (!_poolTeams[poolId]!.contains(team.id)) {
                  _poolTeams[poolId]!.add(team.id);
                  print('Added ${team.name} to pool: $poolId');
                }
              }
              
              // Add pool name to division pools if not already there
              final poolNames = _divisionPools[_selectedDivisionForPools!] ?? [];
              if (!poolNames.contains(node.title)) {
                poolNames.add(node.title);
                _divisionPools[_selectedDivisionForPools!] = poolNames;
              }
              
              print('Current pool teams state: $_poolTeams');
              print('Placeholder teams state: $_placeholderTeams');
            });
          }
        },
        onBracketChanged: (nodes) {
      setState(() {
            _divisionCustomBrackets[_selectedDivisionForPools!] = nodes;
              });
            },
      ),
    );
  }

  int _getRefereePoints() {
    int total = 0;
    total += _criteria.ehfKaderReferees * 25;
    total += _criteria.dhbEliteKaderReferees * 20;
    total += _criteria.dhbStammKaderReferees * 15;
    total += _criteria.perspektivKaderReferees * 10;
    total += (_criteria.basisLizenzReferees * 5).clamp(0, 50);
    return total.clamp(0, 250);
  }

  String _getEbtStatusDescription() {
    final points = _criteria.ebtStatus;
    if (points >= 300) return '300+ EBT = 150 Punkte';
    if (points >= 250) return '250-299 EBT = 100 Punkte';
    if (points >= 200) return '200-249 EBT = 80 Punkte';
    if (points >= 150) return '150-199 EBT = 60 Punkte';
    if (points >= 100) return '100-149 EBT = 40 Punkte';
    if (points >= 1) return '1-99 EBT = 20 Punkte';
    return '0 EBT = 0 Punkte';
  }

  int _getPlayingDays() {
    if (_startDate == null) return 1;
    if (_endDate == null) return 1;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  int _getPlayingDaysPoints() {
    return _getPlayingDays() > 1 ? 20 : 0;
  }

  List<String> _getMissingSupercupCriteria() {
    List<String> missing = [];
    
    // Check referee points (need at least 150)
    int refereePoints = _getRefereePoints();
    if (refereePoints < 150) {
      missing.add('Schiedsrichter Punkte: ${refereePoints}/150 (${150 - refereePoints} fehlen)');
    }
    
    // Check delegate requirement (need either EBT or DHB delegate)
    bool hasDelegate = _criteria.ebtDelegate || _criteria.dhbNationalDelegate;
    if (!hasDelegate) {
      missing.add('Delegate: Entweder EBT-Delegate oder DHB National Delegate erforderlich');
    }
    
    // Check livestream requirement (need any livestream) - updated logic
    bool hasValidStream = _criteria.livestreamOption != 'none';
    if (!hasValidStream) {
      missing.add('Livestream: Jeder Typ von Live-Stream erforderlich');
    }
    
    // Check individual mandatory criteria
    if (!_criteria.zeitnehmerGestellt) {
      missing.add('Zeitnehmer werden gestellt');
    }
    
    if (!_criteria.fangneatzeZaeune) {
      missing.add('Fangnätze/Zäune hinter allen Toren und Spielfeldern');
    }
    
    if (!_criteria.waterForPlayers) {
      missing.add('Water for Players');
    }
    
    if (!_criteria.alleBeachplaetzeOffiziellesMasse) {
      missing.add('Alle Beachplätze mit offiziellen Maßen');
    }
    
    if (!_criteria.technicalMeeting) {
      missing.add('Technical Meeting');
    }
    
    // Check base points requirement (need at least 900) - calculate WITHOUT supercup bonus
    int basePoints = _calculateBasePointsWithoutSupercup();
    if (basePoints < 900) {
      missing.add('Basis Punkte: ${basePoints}/900 (${900 - basePoints} fehlen)');
    }
    
    // Check if tournament has multiple days (auto-detected)
    int playingDays = _getPlayingDays();
    if (playingDays <= 1) {
      missing.add('Turnier muss über mehrere Tage gehen (aktuell: $playingDays Tag)');
    }
    
    return missing;
  }

  // Helper method to calculate base points without supercup bonus to avoid circular dependency
  int _calculateBasePointsWithoutSupercup() {
    int total = 0;
    
    // MUST Criteria (30 pts each)
    if (_criteria.officialBeachhandballRules) total += 30;
    if (_criteria.twoRefereesPerGame) total += 30;
    if (_criteria.cleanZone) total += 30;
    if (_criteria.ausspielenPlatz1To8) total += 30;
    
    // CAN Criteria - Referees (max 250 pts)
    int refereePoints = 0;
    refereePoints += _criteria.ehfKaderReferees * 25;
    refereePoints += _criteria.dhbEliteKaderReferees * 20;
    refereePoints += _criteria.dhbStammKaderReferees * 15;
    refereePoints += _criteria.perspektivKaderReferees * 10;
    refereePoints += (_criteria.basisLizenzReferees * 5).clamp(0, 50);
    total += refereePoints.clamp(0, 250);
    
    // CAN Criteria - Officials (max 180 pts)
    int officialPoints = 0;
    if (_criteria.ebtDelegate) officialPoints += 100;
    if (_criteria.dhbNationalDelegate) officialPoints += 80;
    total += officialPoints.clamp(0, 180);
    
    // CAN Criteria - Other
    if (_criteria.technicalMeeting) total += 20;
    total += _criteria.getEbtPoints();
    total += _criteria.getLivestreamPoints();
    if (_criteria.fangneatzeZaeune) total += 30;
    if (_criteria.sanitaeterdienst) total += 20;
    if (_criteria.sitztribuene) total += 60;
    if (_criteria.spielfeldumrandung) total += 30;
    if (_criteria.alleBeachplaetzeOffiziellesMasse) total += 20;
    if (_criteria.gboOnlineSchedule) total += 100;
    if (_criteria.gboScoringSystem) total += 50;
    if (_criteria.elektronischeAnzeigetafeln) total += 40;
    if (_criteria.zeitnehmerGestellt) total += 20;
    if (_criteria.gboJuniorsCup) total += 30;
    if (_criteria.waterForPlayers) total += 20;
    if (_criteria.arenaCommentator) total += 20;
    if (_criteria.tournierauszeichnungen) total += 20;
    if (_criteria.tournamentInTownCenter) total += 250;
    
    // Add playing days points
    total += _getPlayingDaysPoints();
    
    return total;
  }

  Widget _buildCourtsTab() {
    return Column(
      children: [
        // Header with controls
        Container(
          padding: const EdgeInsets.all(24),
          color: Colors.white,
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.green),
                  const SizedBox(width: 12),
                  Text(
                    'Plätze verwalten',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  if (_isEditingCourt) ...[
                    ElevatedButton.icon(
                      onPressed: _updateCourtPosition,
                      icon: const Icon(Icons.save),
                      label: const Text('Änderungen speichern'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _cancelCourtEditing,
                      icon: const Icon(Icons.close),
                      label: const Text('Abbrechen'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ] else ...[
                    ElevatedButton.icon(
                      onPressed: _saveCourtPosition,
                      icon: const Icon(Icons.add_location),
                      label: const Text('Neuen Platz hinzufügen'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _isEditingCourt 
                    ? 'Bewegen Sie die Karte, um Platz "${_selectedCourtForEditing?.name}" zu repositionieren.'
                    : 'Bewegen Sie die Karte, um den neuen Platz zu positionieren. Klicken Sie auf bestehende Plätze zum Bearbeiten.',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        
        // Map with court overlay - takes remaining space
        Expanded(
          child: Stack(
            children: [
              // Map
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _mapCenter,
                  initialZoom: _mapZoom,
                  minZoom: 10.0,
                  maxZoom: 20.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.gbo.updated',
                    tileProvider: CancellableNetworkTileProvider(),
                  ),
                  // Existing court markers
                  MarkerLayer(
                    markers: _buildCourtMarkers(),
                  ),
                ],
              ),
              
              // Court icon overlay in center
              _buildCourtIconOverlay(),
              
              // Center crosshair
              Center(
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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

  // Court management methods
  List<Marker> _buildCourtMarkers() {
    return _allCourts.map((court) {
      return Marker(
        point: LatLng(court.latitude, court.longitude),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _startEditingCourt(court),
          child: _buildCourtIcon(
            court.name,
            _selectedCourtIds.contains(court.id) ? Colors.green : Colors.blue,
          ),
        ),
      );
    }).toList();
  }

  void _startEditingCourt(Court court) {
    setState(() {
      _selectedCourtForEditing = court;
      _isEditingCourt = true;
      _courtNameController.text = court.name;
      _courtDescriptionController.text = court.description;
      _courtType = court.type;
      _courtCapacity = court.maxCapacity;
      _courtAmenities = List.from(court.amenities);
      _courtLabel = court.name;
    });
    
    // Center map on the court
    _mapController.move(LatLng(court.latitude, court.longitude), 16.0);
  }

  void _saveCourtPosition() {
    // Generate next available label
    _generateNextCourtLabel();
    final center = _mapController.camera.center;
    _showCourtDetailsDialog(center.latitude, center.longitude);
  }

  void _updateCourtPosition() {
    if (_selectedCourtForEditing != null) {
      final center = _mapController.camera.center;
      _showCourtUpdateDialog(center.latitude, center.longitude);
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

  void _showCourtUpdateDialog(double latitude, double longitude) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Platz "${_selectedCourtForEditing!.name}" bearbeiten'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Neue Position: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 16),
              
              // Name
              TextFormField(
                controller: _courtNameController,
                decoration: const InputDecoration(
                  labelText: 'Platz Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              // Description
              TextFormField(
                controller: _courtDescriptionController,
                decoration: const InputDecoration(
                  labelText: 'Beschreibung',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              
              // Type
              DropdownButtonFormField<String>(
                value: _courtType,
                decoration: const InputDecoration(
                  labelText: 'Platz Typ',
                  border: OutlineInputBorder(),
                ),
                items: _courtTypes.map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(_getCourtTypeDisplayName(type)),
                )).toList(),
                onChanged: (value) {
                  setState(() {
                    _courtType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Capacity
              TextFormField(
                initialValue: _courtCapacity.toString(),
                decoration: const InputDecoration(
                  labelText: 'Zuschauerkapazität',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  _courtCapacity = int.tryParse(value) ?? 0;
                },
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
                description: _courtDescriptionController.text.trim(),
                latitude: latitude,
                longitude: longitude,
                type: _courtType,
                maxCapacity: _courtCapacity,
                amenities: _courtAmenities,
                updatedAt: DateTime.now(),
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
    _courtDescriptionController.clear();
    _courtType = 'outdoor';
    _courtCapacity = 0;
    _courtAmenities.clear();
    setState(() {
      _isEditingCourt = false;
    });
  }

  void _showCourtDetailsDialog(double latitude, double longitude) {
    // Reset form for new court
    _courtNameController.text = _courtLabel; // Set default name to the label
    _courtDescriptionController.clear();
    _courtType = 'outdoor';
    _courtCapacity = 0;
    _courtAmenities.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Neuen Platz erstellen'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Position: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 16),
              
              // Name
              TextFormField(
                controller: _courtNameController,
                decoration: const InputDecoration(
                  labelText: 'Platz Name *',
                  border: OutlineInputBorder(),
                  hintText: 'z.B. A, B, 1, 2, etc.',
                ),
              ),
              const SizedBox(height: 16),
              
              // Description
              TextFormField(
                controller: _courtDescriptionController,
                decoration: const InputDecoration(
                  labelText: 'Beschreibung',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              
              // Type
              DropdownButtonFormField<String>(
                value: _courtType,
                decoration: const InputDecoration(
                  labelText: 'Platz Typ',
                  border: OutlineInputBorder(),
                ),
                items: _courtTypes.map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(_getCourtTypeDisplayName(type)),
                )).toList(),
                onChanged: (value) {
                  setState(() {
                    _courtType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Capacity
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Zuschauerkapazität',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  _courtCapacity = int.tryParse(value) ?? 0;
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
                description: _courtDescriptionController.text.trim(),
                latitude: latitude,
                longitude: longitude,
                type: _courtType,
                maxCapacity: _courtCapacity,
                amenities: _courtAmenities,
                isActive: true,
                createdAt: DateTime.now(),
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

  String _getCourtTypeDisplayName(String type) {
    switch (type) {
      case 'outdoor':
        return 'Außenplatz';
      case 'indoor':
        return 'Hallenplatz';
      case 'grass':
        return 'Rasenplatz';
      case 'sand':
        return 'Sandplatz';
      case 'concrete':
        return 'Betonplatz';
      case 'clay':
        return 'Hartplatz';
      default:
        return type;
    }
  }
  
  String _getAmenityDisplayName(String amenity) {
    switch (amenity) {
      case 'lights':
        return 'Beleuchtung';
      case 'scoreboard':
        return 'Anzeigetafel';
      case 'parking':
        return 'Parkplatz';
      case 'restroom':
        return 'Toiletten';
      case 'seating':
        return 'Sitzplätze';
      case 'shelter':
        return 'Überdachung';
      case 'food_service':
        return 'Verpflegung';
      case 'first_aid':
        return 'Erste Hilfe';
      default:
        return amenity;
    }
  }

  void _saveTournament() async {
    print('Save tournament called');
    
    // Validate form
    if (_formKey.currentState?.validate() != true) {
      print('Form validation failed');
      // Navigate to basic data tab to show validation errors
      setState(() {
        _selectedTab = 'basic';
      });
      
      // Show specific error message
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

    if (_selectedCategories.isEmpty) {
      print('No categories selected');
      // Navigate to basic data tab to show category selection
      setState(() {
        _selectedTab = 'basic';
      });
      toastification.show(
        context: context,
        type: ToastificationType.warning,
        style: ToastificationStyle.fillColored,
        title: const Text('Warnung'),
        description: const Text('Bitte wählen Sie mindestens eine Kategorie aus'),
        alignment: Alignment.topRight,
        autoCloseDuration: const Duration(seconds: 4),
        showProgressBar: false,
      );
      return;
    }

    if (_startDate == null) {
      print('No start date selected');
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

    print('Validation passed, starting save process');

    setState(() {
      _isSaving = true;
    });

    print('Starting save operation');

    try {
      print('Building division brackets...');
      // Create division brackets from current state  
      Map<String, TournamentBracket> divisionBrackets = {};
      
      for (String division in _divisionPools.keys) {
        final poolNames = _divisionPools[division] ?? [];
        Map<String, List<String>> pools = {};
        Map<String, bool> poolIsFunBracket = {};
        
        // Convert pool data to the format expected by TournamentBracket
        for (String poolName in poolNames) {
          final poolId = '${division}_$poolName';
          pools[poolId] = _poolTeams[poolId] ?? [];
          poolIsFunBracket[poolId] = _poolIsFunBracket[poolId] ?? false;
        }
        
        divisionBrackets[division] = TournamentBracket(
          pools: pools,
          poolIsFunBracket: poolIsFunBracket,
          knockoutRounds: _divisionBrackets[division] ?? [],
        );
      }
      
      print('Division brackets created');
      
      // Create custom brackets from current state
      Map<String, CustomBracketStructure> customBrackets = {};
      for (String division in _divisionCustomBrackets.keys) {
        final now = DateTime.now();
        customBrackets[division] = CustomBracketStructure(
          nodes: _divisionCustomBrackets[division] ?? [],
          divisionName: division,
          createdAt: now,
          updatedAt: now,
        );
      }
      
      print('Custom brackets created');
      
      // Create or update tournament
      final tournament = Tournament(
        id: widget.tournament?.id ?? '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrl: _imageUrlController.text.trim().isNotEmpty ? _imageUrlController.text.trim() : null,
        location: _locationController.text.trim(),
        startDate: _startDate!,
        endDate: _endDate,
        // Add category-specific dates if using them
        categoryStartDates: _useCategorySpecificDates && _categoryStartDates.isNotEmpty 
            ? Map<String, DateTime>.fromEntries(
                _categoryStartDates.entries
                    .where((entry) => entry.value != null)
                    .map((entry) => MapEntry(entry.key, entry.value!))
              )
            : null,
        categoryEndDates: _useCategorySpecificDates && _categoryEndDates.isNotEmpty 
            ? Map<String, DateTime>.fromEntries(
                _categoryEndDates.entries
                    .where((entry) => entry.value != null)
                    .map((entry) => MapEntry(entry.key, entry.value!))
              )
            : null,
        status: _status,
        categories: _selectedCategories,
        points: _selectedCategories.contains('GBO Seniors Cup') 
            ? _criteria.totalPoints + _criteria.supercupBonus 
            : int.tryParse(_pointsController.text) ?? 0,
        teamIds: _selectedTeamIds,
        divisionBrackets: divisionBrackets,
        customBrackets: customBrackets,
        criteria: _selectedCategories.contains('GBO Seniors Cup') ? _criteria : null,
      );
      
      print('Tournament object created');
      
      // Save using tournament service
      if (widget.tournament == null) {
        print('Creating new tournament...');
        // Creating new tournament
        await _tournamentService.addTournament(tournament);
        print('New tournament created');
      } else {
        print('Updating existing tournament...');
        // Updating existing tournament
        await _tournamentService.updateTournament(tournament);
        print('Tournament updated');
      }
      
      setState(() {
        _isSaving = false;
      });
      
      print('Save operation completed successfully');
      
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
      
      Navigator.of(context).pop();
    } catch (e) {
      print('Error during save: $e');
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

  // Missing methods
  void _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020), // Allow dates from 2020 onwards
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _startDate = date;
        // Automatically set status to completed if tournament is in the past
        _updateStatusBasedOnDate();
      });
    }
  }

  void _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020), // Start from tournament start date or 2020
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _endDate = date;
        // Automatically set status to completed if tournament is in the past
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

  Color _getDivisionColor(String division) {
    if (division.contains('Women')) {
      if (division.contains('FUN')) return Colors.pink;
      if (division.contains('U14')) return Colors.purple;
      if (division.contains('U16')) return Colors.deepPurple;
      if (division.contains('U18')) return Colors.indigo;
      return Colors.blue; // Women's Seniors
    } else {
      if (division.contains('FUN')) return Colors.orange;
      if (division.contains('U14')) return Colors.green;
      if (division.contains('U16')) return Colors.teal;
      if (division.contains('U18')) return Colors.cyan;
      return Colors.red; // Men's Seniors
    }
  }

  Widget _buildCriteriaTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with current points
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.blue.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.assignment_turned_in, color: Colors.blue.shade700, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Turnier-Kriterien',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Konfiguriere Kriterien für GBO Seniors Cup Turniere',
                        style: TextStyle(
                          color: Colors.blue.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${_criteria.totalPoints + _criteria.supercupBonus}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'TOTAL POINTS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // MUST Criteria Section
          _buildCriteriaSection(
            'MUSS-Kriterien',
            'Erforderliche Kriterien (30 Punkte pro Kriterium)',
            Colors.red,
            [
              _buildCriteriaCheckbox(
                'Offizielle Beachhandball-Regeln',
                'Turnier folgt offiziellen IHF Beachhandball-Regeln',
                _criteria.officialBeachhandballRules,
                (value) => _updateCriteria(_criteria.copyWith(officialBeachhandballRules: value)),
                30,
              ),
              _buildCriteriaCheckbox(
                'Zwei Schiedsrichter pro Spiel',
                'Jedes Spiel hat genau zwei Schiedsrichter',
                _criteria.twoRefereesPerGame,
                (value) => _updateCriteria(_criteria.copyWith(twoRefereesPerGame: value)),
                30,
              ),
              _buildCriteriaCheckbox(
                'Clean Zone',
                'Spielbereich wird als saubere Zone geführt',
                _criteria.cleanZone,
                (value) => _updateCriteria(_criteria.copyWith(cleanZone: value)),
                30,
              ),
              _buildCriteriaCheckbox(
                'Ausspielen Platz 1-8',
                'Turnier beinhaltet Spiele um die Plätze 1-8',
                _criteria.ausspielenPlatz1To8,
                (value) => _updateCriteria(_criteria.copyWith(ausspielenPlatz1To8: value)),
                30,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Referees Section
          _buildCriteriaSection(
            'Schiedsrichter (max 250 Punkte)',
            'Qualifizierte Schiedsrichter für das Turnier',
            Colors.orange,
            [
              _buildCriteriaCounter(
                'EHF Kader Schiedsrichter',
                'Europäische Handball Föderation qualifizierte Schiedsrichter',
                _criteria.ehfKaderReferees,
                (value) => _updateCriteria(_criteria.copyWith(ehfKaderReferees: value)),
                25,
                'pro Schiedsrichter',
              ),
              _buildCriteriaCounter(
                'DHB Elite Kader Schiedsrichter',
                'Deutsche Handball Bund Elite-Schiedsrichter',
                _criteria.dhbEliteKaderReferees,
                (value) => _updateCriteria(_criteria.copyWith(dhbEliteKaderReferees: value)),
                20,
                'pro Schiedsrichter',
              ),
              _buildCriteriaCounter(
                'DHB Stamm Kader Schiedsrichter',
                'Deutsche Handball Bund Standard-Schiedsrichter',
                _criteria.dhbStammKaderReferees,
                (value) => _updateCriteria(_criteria.copyWith(dhbStammKaderReferees: value)),
                15,
                'pro Schiedsrichter',
              ),
              _buildCriteriaCounter(
                'Perspektiv Kader Schiedsrichter',
                'Nachwuchs-/Entwicklungs-Schiedsrichter',
                _criteria.perspektivKaderReferees,
                (value) => _updateCriteria(_criteria.copyWith(perspektivKaderReferees: value)),
                10,
                'pro Schiedsrichter',
              ),
              _buildCriteriaCounter(
                'Basis Lizenz Schiedsrichter',
                'Basis-Lizenz Schiedsrichter (max 50 Punkte gesamt)',
                _criteria.basisLizenzReferees,
                (value) => _updateCriteria(_criteria.copyWith(basisLizenzReferees: value)),
                5,
                'pro Schiedsrichter (max 10)',
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Officials Section
          _buildCriteriaSection(
            'Offizielle (max 180 Punkte)',
            'Turnier-Offizielle und Delegierte',
            Colors.purple,
            [
              _buildCriteriaCheckbox(
                'EBT Delegierter',
                'European Beach Tour Delegierter anwesend',
                _criteria.ebtDelegate,
                (value) => _updateCriteria(_criteria.copyWith(ebtDelegate: value)),
                100,
              ),
              _buildCriteriaCheckbox(
                'DHB National-Delegierter',
                'Deutsche Handball Bund National-Delegierter',
                _criteria.dhbNationalDelegate,
                (value) => _updateCriteria(_criteria.copyWith(dhbNationalDelegate: value)),
                80,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Infrastructure Section
          _buildCriteriaSection(
            'Infrastruktur & Ausstattung',
            'Turnier-Einrichtungen und Ausrüstung',
            Colors.green,
            [
              _buildCriteriaCheckbox(
                'Fangnetze/Zäune',
                'Sicherheitsnetze und Absperrungen um die Plätze',
                _criteria.fangneatzeZaeune,
                (value) => _updateCriteria(_criteria.copyWith(fangneatzeZaeune: value)),
                30,
              ),
              _buildCriteriaCheckbox(
                'Offizielle Beachplatz-Maße',
                'All beach courts have official dimensions',
                _criteria.alleBeachplaetzeOffiziellesMasse,
                (value) => _updateCriteria(_criteria.copyWith(alleBeachplaetzeOffiziellesMasse: value)),
                20,
              ),
              _buildCriteriaCheckbox(
                'Sitztribüne',
                'Seating tribune for spectators',
                _criteria.sitztribuene,
                (value) => _updateCriteria(_criteria.copyWith(sitztribuene: value)),
                60,
              ),
              _buildCriteriaCheckbox(
                'Spielfeld-Umrandung',
                'Court perimeter markings/barriers',
                _criteria.spielfeldumrandung,
                (value) => _updateCriteria(_criteria.copyWith(spielfeldumrandung: value)),
                30,
              ),
              _buildCriteriaCheckbox(
                'Elektronische Anzeigetafeln',
                'Electronic scoreboards',
                _criteria.elektronischeAnzeigetafeln,
                (value) => _updateCriteria(_criteria.copyWith(elektronischeAnzeigetafeln: value)),
                40,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Services Section
          _buildCriteriaSection(
            'Services & Support',
            'Additional tournament services',
            Colors.teal,
            [
              _buildCriteriaCheckbox(
                'Technical Meeting',
                'Official technical meeting held (required for Supercup)',
                _criteria.technicalMeeting,
                (value) => _updateCriteria(_criteria.copyWith(technicalMeeting: value)),
                20,
              ),
              _buildCriteriaCheckbox(
                'Zeitnehmer gestellt',
                'Official timekeepers provided (required for Supercup)',
                _criteria.zeitnehmerGestellt,
                (value) => _updateCriteria(_criteria.copyWith(zeitnehmerGestellt: value)),
                20,
              ),
              _buildCriteriaCheckbox(
                'Sanitäterdienst',
                'Medical services available',
                _criteria.sanitaeterdienst,
                (value) => _updateCriteria(_criteria.copyWith(sanitaeterdienst: value)),
                20,
              ),
              _buildCriteriaCheckbox(
                'Water for Players',
                'Free water provided for players (required for Supercup)',
                _criteria.waterForPlayers,
                (value) => _updateCriteria(_criteria.copyWith(waterForPlayers: value)),
                20,
              ),
              _buildCriteriaCheckbox(
                'Arena Commentator',
                'Professional arena commentary',
                _criteria.arenaCommentator,
                (value) => _updateCriteria(_criteria.copyWith(arenaCommentator: value)),
                20,
              ),
              _buildCriteriaCheckbox(
                'Turnier-Auszeichnungen',
                'Tournament awards and trophies',
                _criteria.tournierauszeichnungen,
                (value) => _updateCriteria(_criteria.copyWith(tournierauszeichnungen: value)),
                20,
              ),
              _buildTournamentDaysWidget(),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // GBO Systems Section
          _buildCriteriaSection(
            'GBO Systems',
            'Integration with GBO platform',
            Colors.indigo,
            [
              _buildCriteriaCheckbox(
                'GBO Online Schedule',
                'Tournament uses GBO online scheduling system',
                _criteria.gboOnlineSchedule,
                (value) => _updateCriteria(_criteria.copyWith(gboOnlineSchedule: value)),
                100,
              ),
              _buildCriteriaCheckbox(
                'GBO Scoring System',
                'Tournament uses GBO live scoring system',
                _criteria.gboScoringSystem,
                (value) => _updateCriteria(_criteria.copyWith(gboScoringSystem: value)),
                50,
              ),
              _buildCriteriaCheckbox(
                'GBO Juniors Cup',
                'Tournament includes GBO Juniors Cup (automatically awarded)',
                _criteria.gboJuniorsCup,
                (value) => _updateCriteria(_criteria.copyWith(gboJuniorsCup: value)),
                30,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Special Criteria Section
          _buildCriteriaSection(
            'Special Criteria',
            'High-value tournament enhancements',
            Colors.amber,
            [
              _buildEbtStatusDropdown(),
              _buildLivestreamDropdown(),
              _buildCriteriaCheckbox(
                'Tournament in Town Center',
                'Tournament located in city/town center',
                _criteria.tournamentInTownCenter,
                (value) => _updateCriteria(_criteria.copyWith(tournamentInTownCenter: value)),
                250,
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Supercup Eligibility
          _buildSupercupStatus(),
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.settings, color: Colors.blue, size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Turnier Einstellungen',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Weitere Einstellungen für dieses Turnier werden hier hinzugefügt.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
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

  Widget _buildToggleButton(String label, bool isSelected, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.blue : Colors.grey,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildOldPoolView(List<Team> divisionTeams, List<Team> availableTeams) {
    final division = _selectedDivisionForPools!;
    final poolNames = _divisionPools[division] ?? [];
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Migration View: Here you can see your existing pools and remove teams to make them available for the new bracket builder.',
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
          
          // Available teams section
          if (availableTeams.isNotEmpty) ...[
            Text(
              'Available Teams (${availableTeams.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: availableTeams.length,
                itemBuilder: (context, index) {
                  final team = availableTeams[index];
                  return Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 8),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              team.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              team.city,
                              style: TextStyle(color: Colors.grey[600], fontSize: 10),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Existing pools section
          Text(
            'Existing Pools (${poolNames.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          
          if (poolNames.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  'No pools created yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                ),
                itemCount: poolNames.length,
                itemBuilder: (context, index) {
                  final poolName = poolNames[index];
                  final poolId = '${division}_$poolName';
                  final teamsInPool = _poolTeams[poolId] ?? [];
                  final isFunBracket = _poolIsFunBracket[poolId] ?? false;
                  
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Pool $poolName',
                                  style: TextStyle(
                                    color: Colors.blue.shade800,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (isFunBracket)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'FUN',
                                    style: TextStyle(
                                      color: Colors.orange.shade800,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${teamsInPool.length} Teams',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: teamsInPool.isEmpty
                                ? Center(
                                    child: Text(
                                      'No teams',
                                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: teamsInPool.length,
                                    itemBuilder: (context, teamIndex) {
                                      final teamId = teamsInPool[teamIndex];
                                      final team = divisionTeams.firstWhere(
                                        (t) => t.id == teamId,
                                        orElse: () => Team(
                                          id: teamId,
                                          name: 'Unknown Team',
                                          city: '',
                                          bundesland: '',
                                          division: '',
                                          createdAt: DateTime.now(),
                                        ),
                                      );
                                      
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                team.name,
                                                style: const TextStyle(fontSize: 11),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.remove_circle_outline, 
                                                  color: Colors.red, size: 16),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(
                                                minWidth: 24,
                                                minHeight: 24,
                                              ),
                                              onPressed: () => _removeTeamFromPool(poolId, teamId),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
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

  bool _isTeamCompatibleWithDivision(Team team, String tournamentDivision) {
    // Teams are compatible if:
    // 1. Their division exactly matches the tournament division
    // 2. Women's Fun can access Women's Senior teams
    // 3. Men's Fun can access Men's Senior teams
    if (team.division == tournamentDivision) {
      return true;
    }
    
    // Allow Fun tournaments to access Senior teams
    if (tournamentDivision.contains('FUN') && team.division.contains('Seniors')) {
      // Check if they're the same gender
      if ((tournamentDivision.contains('Women') && team.division.contains('Women')) ||
          (tournamentDivision.contains('Men') && team.division.contains('Men'))) {
        return true;
      }
    }
    
    return false;
  }

  Map<String, List<Team>> _expandDivisionsWithFunTournaments(Map<String, List<Team>> originalDivisions) {
    Map<String, List<Team>> expandedDivisions = Map.from(originalDivisions);
    
    // For each Senior division, add a corresponding Fun division
    for (String division in originalDivisions.keys) {
      if (division.contains('Seniors')) {
        String funDivision = division.replaceAll('Seniors', 'FUN');
        // Add the Fun division with the same teams (they can participate in both)
        expandedDivisions[funDivision] = List.from(originalDivisions[division]!);
      }
    }
    
    return expandedDivisions;
  }

  String _getDivisionDescription(String division) {
    if (division.contains('Seniors')) {
      return 'A-Turnier - Zählt zur Rangliste der Deutschen Meisterschaft';
    } else if (division.contains('FUN')) {
      return 'B-Turnier - Just for Fun';
    } else {
      return 'Jugendturnier';
    }
  }

  bool _isPoolIdRelatedToDivision(String poolId, String currentDivision) {
    // Check if pool belongs to current division
    if (poolId.startsWith('${currentDivision}_')) {
      return true;
    }
    
    // Check if pool belongs to corresponding A/B tournament
    String correspondingDivision = _getCorrespondingDivision(currentDivision);
    if (correspondingDivision != currentDivision && poolId.startsWith('${correspondingDivision}_')) {
      return true;
    }
    
    return false;
  }

  String _getCorrespondingDivision(String division) {
    // If it's a Senior division, return the Fun division
    if (division.contains('Seniors')) {
      return division.replaceAll('Seniors', 'FUN');
    }
    // If it's a Fun division, return the Senior division
    else if (division.contains('FUN')) {
      return division.replaceAll('FUN', 'Seniors');
    }
    // For youth divisions, return the same division
    else {
      return division;
    }
  }

  int _getProceedingTeamCount(String poolId) {
    // Count how many real teams (non-placeholder) are in the pool
    final currentTeams = _poolTeams[poolId] ?? [];
    final placeholders = _placeholderTeams[poolId] ?? [];
    
    return currentTeams.where((teamId) => !placeholders.contains(teamId)).length;
  }

  void _removeTeamFromPool(String poolId, String teamId) {
    setState(() {
      _poolTeams[poolId]?.remove(teamId);
      
      // If this pool has placeholders, restore them to maintain minimum structure
      if (_placeholderTeams.containsKey(poolId)) {
        final placeholders = _placeholderTeams[poolId]!;
        final currentTeams = _poolTeams[poolId] ?? [];
        
        // If we have fewer real teams than placeholder slots, fill with placeholders
        if (currentTeams.length < placeholders.length) {
          final missingCount = placeholders.length - currentTeams.length;
          final availablePlaceholders = placeholders.where((p) => !currentTeams.contains(p)).take(missingCount);
          _poolTeams[poolId] ??= [];
          _poolTeams[poolId]!.addAll(availablePlaceholders);
        }
      }
      
      // Clean up empty lists only if there are no placeholders
      if ((_poolTeams[poolId]?.isEmpty ?? false) && !_placeholderTeams.containsKey(poolId)) {
        _poolTeams.remove(poolId);
      }
    });
    
    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.fillColored,
      title: const Text('Info'),
      description: const Text('Team aus Pool entfernt'),
      alignment: Alignment.topRight,
      autoCloseDuration: const Duration(seconds: 2),
      showProgressBar: false,
    );
  }

  void _updateCriteria(TournamentCriteria newCriteria) {
    setState(() {
      _criteria = newCriteria;
    });
  }

  Widget _buildCriteriaSection(String title, String subtitle, MaterialColor color, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color.shade700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children.map((child) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: child,
          )),
        ],
      ),
    );
  }

  Widget _buildCriteriaCheckbox(
    String title,
    String description,
    bool value,
    Function(bool) onChanged,
    int points,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: value ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value ? Colors.green.shade300 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: (newValue) => onChanged(newValue ?? false),
            activeColor: Colors.green,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: value ? Colors.green : Colors.grey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '+$points',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriteriaCounter(
    String title,
    String description,
    int value,
    Function(int) onChanged,
    int pointsPerUnit,
    String unit,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: value > 0 ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value > 0 ? Colors.green.shade300 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: value > 0 ? Colors.green : Colors.grey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+${value * pointsPerUnit}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: value > 0 ? () => onChanged(value - 1) : null,
                icon: const Icon(Icons.remove),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.shade100,
                  foregroundColor: Colors.red.shade700,
                  minimumSize: const Size(32, 32),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => onChanged(value + 1),
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.green.shade100,
                  foregroundColor: Colors.green.shade700,
                  minimumSize: const Size(32, 32),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$pointsPerUnit pts $unit',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEbtStatusDropdown() {
    final ebtOptions = [
      {'value': 0, 'label': 'Nicht betroffen (0 Punkte)', 'points': 0},
      {'value': 100, 'label': '100-149 (40 Punkte)', 'points': 40},
      {'value': 150, 'label': '150-199 (60 Punkte)', 'points': 60},
      {'value': 200, 'label': '200-249 (80 Punkte)', 'points': 80},
      {'value': 250, 'label': '250-299 (100 Punkte)', 'points': 100},
      {'value': 300, 'label': '300+ (150 Punkte)', 'points': 150},
    ];

    // Ensure the current value exists in the options, otherwise use 0 as default
    final validValues = ebtOptions.map((option) => option['value'] as int).toSet();
    final currentValue = validValues.contains(_criteria.ebtStatus) ? _criteria.ebtStatus : 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: currentValue > 0 ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: currentValue > 0 ? Colors.green.shade300 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'EBT Status',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'European Beach Tour tournament status',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: currentValue > 0 ? Colors.green : Colors.grey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+${_criteria.getEbtPoints()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: currentValue,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: ebtOptions.map((option) {
              return DropdownMenuItem<int>(
                value: option['value'] as int,
                child: Text(option['label'] as String),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                _updateCriteria(_criteria.copyWith(ebtStatus: value));
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLivestreamDropdown() {
    final livestreamOptions = [
      {'value': 'none', 'label': 'Kein Livestream (0 Punkte)', 'points': 0},
      {'value': 'own_stream', 'label': 'Eigener Stream (50 Punkte)', 'points': 50},
      {'value': 'swtv_twitch', 'label': 'SWTV Twitch Stream (150 Punkte)', 'points': 150},
      {'value': 'swtv_remote', 'label': 'SWTV Remote Stream (250 Punkte)', 'points': 250},
      {'value': 'swtv_crew', 'label': 'SWTV Crew vor Ort (250 Punkte)', 'points': 250},
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _criteria.livestreamOption != 'none' ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _criteria.livestreamOption != 'none' ? Colors.green.shade300 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Livestream',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Live-Streaming Optionen (jeder Stream benötigt für Supercup)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _criteria.livestreamOption != 'none' ? Colors.green : Colors.grey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+${_criteria.getLivestreamPoints()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _criteria.livestreamOption,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: livestreamOptions.map((option) {
              return DropdownMenuItem<String>(
                value: option['value'] as String,
                child: Text(option['label'] as String),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                _updateCriteria(_criteria.copyWith(livestreamOption: value));
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSupercupStatus() {
    final isEligible = _criteria.checkSupercupEligibility();
    final missingCriteria = _getMissingSupercupCriteria();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isEligible 
              ? [Colors.green.shade50, Colors.green.shade100]
              : [Colors.orange.shade50, Colors.orange.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEligible ? Colors.green.shade300 : Colors.orange.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isEligible ? Icons.star : Icons.star_border,
                color: isEligible ? Colors.green.shade700 : Colors.orange.shade700,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GBO Supercup Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isEligible ? Colors.green.shade700 : Colors.orange.shade700,
                      ),
                    ),
                    Text(
                      isEligible 
                          ? 'Alle Supercup-Bedingungen erfüllt!'
                          : 'Supercup-Bedingungen nicht erfüllt',
                      style: TextStyle(
                        fontSize: 14,
                        color: isEligible ? Colors.green.shade600 : Colors.orange.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isEligible)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        '+150',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'BONUS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          
          if (!isEligible && missingCriteria.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Fehlende Supercup-Bedingungen:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            ...missingCriteria.map((criteria) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.close,
                    color: Colors.red.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      criteria,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _pointsController.dispose();
    _imageUrlController.dispose();
    _locationController.dispose();
    _teamSearchController.dispose();
    _courtNameController.dispose();
    _courtDescriptionController.dispose();
    super.dispose();
  }

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  bool _isStatusAutomaticallySet() {
    final now = DateTime.now();
    final currentDate = DateTime(now.year, now.month, now.day); // Remove time component
    
    if (_startDate != null) {
      final startDateOnly = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      final endDateOnly = _endDate != null 
          ? DateTime(_endDate!.year, _endDate!.month, _endDate!.day)
          : startDateOnly;
      
      if (endDateOnly.isBefore(currentDate) && _status == 'completed') {
        // Tournament is completely in the past and status is completed
        return true;
      } else if ((startDateOnly.isAtSameMomentAs(currentDate) || 
                 (startDateOnly.isBefore(currentDate) && endDateOnly.isAfter(currentDate.subtract(const Duration(days: 1))))) 
                 && _status == 'ongoing') {
        // Tournament is happening now and status is ongoing
        return true;
      }
    }
    return false;
  }

  bool _isDateInPast(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    final currentDate = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    return dateOnly.isBefore(currentDate);
  }

  // Category-specific date selection methods
  void _selectCategoryStartDate(String category) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _categoryStartDates[category] ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _categoryStartDates[category] = date;
        // Update main start date to the earliest category date
        _updateMainDatesFromCategories();
      });
    }
  }

  void _selectCategoryEndDate(String category) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _categoryEndDates[category] ?? _categoryStartDates[category] ?? DateTime.now(),
      firstDate: _categoryStartDates[category] ?? DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _categoryEndDates[category] = date;
        // Update main end date to the latest category date
        _updateMainDatesFromCategories();
      });
    }
  }

  void _updateMainDatesFromCategories() {
    if (_categoryStartDates.isNotEmpty) {
      // Find earliest start date
      DateTime? earliestStart;
      for (DateTime? date in _categoryStartDates.values) {
        if (date != null) {
          if (earliestStart == null || date.isBefore(earliestStart)) {
            earliestStart = date;
          }
        }
      }
      _startDate = earliestStart;

      // Find latest end date
      DateTime? latestEnd;
      for (DateTime? date in _categoryEndDates.values) {
        if (date != null) {
          if (latestEnd == null || date.isAfter(latestEnd)) {
            latestEnd = date;
          }
        }
      }
      _endDate = latestEnd;
    }
  }

  int _getPlayingDaysForCategory(String category) {
    final startDate = _categoryStartDates[category];
    final endDate = _categoryEndDates[category];
    if (startDate == null) return 1;
    if (endDate == null) return 1;
    return endDate.difference(startDate).inDays + 1;
  }

  Widget _buildTournamentDaysWidget() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _criteria.tournamentDays > 1 ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _criteria.tournamentDays > 1 ? Colors.green.shade300 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Turniertage',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Anzahl der Turniertage (20 Punkte bei mehreren Tagen)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _criteria.tournamentDays > 1 ? Colors.green : Colors.grey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+${_criteria.tournamentDays > 1 ? 20 : 0}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: _criteria.tournamentDays > 1 ? () => _updateCriteria(_criteria.copyWith(tournamentDays: _criteria.tournamentDays - 1)) : null,
                icon: const Icon(Icons.remove),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.shade100,
                  foregroundColor: Colors.red.shade700,
                  minimumSize: const Size(32, 32),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_criteria.tournamentDays}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => _updateCriteria(_criteria.copyWith(tournamentDays: _criteria.tournamentDays + 1)),
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.green.shade100,
                  foregroundColor: Colors.green.shade700,
                  minimumSize: const Size(32, 32),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_criteria.tournamentDays == 1 ? 'Eintägig (0 Punkte)' : 'Mehrtägig (20 Punkte)'}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
                      const Icon(Icons.sports_volleyball, color: Colors.blue),
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
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
            SizedBox(
              width: double.infinity,
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
                icon: const Icon(Icons.sports_volleyball),
                label: const Text('Zur Spieleverwaltung'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
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
    for (String division in _divisionPools.keys) {
      for (String pool in _divisionPools[division]!) {
        String poolId = '${division}_${pool}';
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
    for (String division in _divisionPools.keys) {
      int poolCount = _divisionPools[division]!.length;
      // Assuming top 2 from each pool advance
      totalAdvancingTeams += poolCount * 2;
    }
    
    if (totalAdvancingTeams > 1) {
      int eliminationGames = totalAdvancingTeams - 1; // n-1 games for n teams
      return '$eliminationGames Spiele für $totalAdvancingTeams Teams';
    }
    return 'Keine Teams definiert';
  }

  void _generatePoolGames() async {
    try {
      int generatedGames = 0;
      for (String division in _divisionPools.keys) {
        for (String pool in _divisionPools[division]!) {
          String poolId = '${division}_${pool}';
          List<String> teamIds = _poolTeams[poolId] ?? [];
          
          if (teamIds.length > 1) {
            // Get actual team objects
            List<Team> teams = teamIds
                .map((id) => _allTeams.firstWhere((team) => team.id == id, orElse: () => Team(
                  id: id,
                  name: 'Unknown Team',
                  city: '',
                  bundesland: '',
                  division: division,
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
          backgroundColor: Colors.green,
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

  void _generateEliminationBracket() async {
    try {
      // Create pool results map for placeholder generation
      Map<String, List<Team>> poolResults = {};
      for (String division in _divisionPools.keys) {
        for (String pool in _divisionPools[division]!) {
          String poolId = '${division}_${pool}';
          List<String> teamIds = _poolTeams[poolId] ?? [];
          
          // Create placeholder teams for bracket positions
          List<Team> placeholderTeams = [];
          for (int i = 0; i < math.min(teamIds.length, 4); i++) { // Max 4 teams advance per pool
            placeholderTeams.add(Team(
              id: 'placeholder_${poolId}_${i + 1}',
              name: '${i + 1}. aus Pool ${pool.toUpperCase()}',
              city: '',
              bundesland: '',
              division: division,
              createdAt: DateTime.now(),
            ));
          }
          poolResults[pool] = placeholderTeams;
        }
      }
      
      await _gameService.generateEliminationBracket(widget.tournament!.id, poolResults);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('K.O.-Spiele erfolgreich generiert!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Generieren der K.O.-Spiele: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildPoolGamesSection() {
    if (_divisionPools.isEmpty) {
      return Container(
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
                'Keine Pools definiert. Erstellen Sie zuerst Pools in der Divisionen-Sektion.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _divisionPools.entries.map((divisionEntry) {
        String division = divisionEntry.key;
        List<String> pools = divisionEntry.value;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.group_work, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    division,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...pools.map((pool) => _buildPoolNode(division, pool)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPoolNode(String division, String pool) {
    String poolId = '${division}_${pool}';
    List<String> teamIds = _poolTeams[poolId] ?? [];
    List<Game> poolGames = _gameService.getPoolGames(widget.tournament!.id, pool);
    int possibleGames = teamIds.length > 1 ? (teamIds.length * (teamIds.length - 1)) ~/ 2 : 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          // Pool info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pool ${pool.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${teamIds.length} Teams • $possibleGames Spiele möglich',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (poolGames.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${poolGames.length} Spiele generiert',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Generate button
          Tooltip(
            message: _getPoolTooltip(poolId, teamIds, poolGames),
            child: ElevatedButton.icon(
              onPressed: teamIds.length > 1 ? () => _generatePoolGamesForPool(division, pool) : null,
              icon: Icon(
                poolGames.isNotEmpty ? Icons.refresh : Icons.add_circle,
                size: 16,
              ),
              label: Text(
                poolGames.isNotEmpty ? 'Neu generieren' : 'Spiele erstellen',
                style: const TextStyle(fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: poolGames.isNotEmpty ? Colors.orange : Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEliminationBracketSection() {
    List<Game> eliminationGames = _gameService.getEliminationGames(widget.tournament!.id);
    
    if (eliminationGames.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.purple.shade300),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: Colors.purple.shade700),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Noch keine Eliminationsspiele generiert',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _generateEliminationBracket(),
                  icon: const Icon(Icons.account_tree),
                  label: const Text('K.O.-Spiele generieren'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Group games by round
    Map<int, List<Game>> gamesByRound = {};
    for (Game game in eliminationGames) {
      int round = game.bracketRound ?? 1;
      gamesByRound[round] = gamesByRound[round] ?? [];
      gamesByRound[round]!.add(game);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, color: Colors.purple.shade700),
              const SizedBox(width: 8),
              Text(
                'K.O.-Runden',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.purple.shade700,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _generateEliminationBracket(),
                icon: const Icon(Icons.refresh),
                label: const Text('Neu generieren'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...gamesByRound.entries.map((roundEntry) {
            int round = roundEntry.key;
            List<Game> games = roundEntry.value;
            int totalRounds = gamesByRound.keys.length;
            String roundName = _gameService.getBracketRoundName(round, totalRounds);
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roundName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.purple.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...games.map((game) => _buildEliminationGameNode(game)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEliminationGameNode(Game game) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatTeamNameShort(game.teamAName)} vs ${_formatTeamNameShort(game.teamBName)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (game.result != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Ergebnis: ${game.result!.finalScore}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Tooltip(
            message: _getEliminationGameTooltip(game),
            child: Icon(
              Icons.info_outline,
              size: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTeamNameShort(String teamName) {
    if (teamName.contains('. aus Pool ')) {
      return teamName.replaceAll('. aus Pool ', ' Pool ');
    }
    if (teamName.startsWith('Sieger:')) {
      return 'Sieger';
    }
    return teamName.length > 15 ? '${teamName.substring(0, 15)}...' : teamName;
  }

  String _getPoolTooltip(String poolId, List<String> teamIds, List<Game> poolGames) {
    List<String> teamNames = teamIds.map((id) {
      Team? team = _allTeams.cast<Team?>().firstWhere((t) => t?.id == id, orElse: () => null);
      return team?.name ?? 'Unknown Team';
    }).toList();
    
    String tooltip = 'Teams in diesem Pool:\n';
    tooltip += teamNames.isEmpty ? 'Keine Teams' : teamNames.join(', ');
    
    if (poolGames.isNotEmpty) {
      tooltip += '\n\nGenerierte Spiele:';
      for (Game game in poolGames) {
        tooltip += '\n• ${game.teamAName} vs ${game.teamBName}';
        if (game.result != null) {
          tooltip += ' (${game.result!.finalScore})';
        }
      }
    }
    
    return tooltip;
  }

  String _getEliminationGameTooltip(Game game) {
    String tooltip = 'Spiel: ${game.teamAName} vs ${game.teamBName}\n';
    tooltip += 'Status: ${_getGameStatusText(game.status)}\n';
    
    if (game.result != null) {
      tooltip += 'Ergebnis: ${game.result!.finalScore}\n';
      tooltip += 'Sieger: ${game.result!.winnerName}';
    } else {
      tooltip += 'Noch kein Ergebnis';
    }
    
    return tooltip;
  }

  String _getGameStatusText(GameStatus status) {
    switch (status) {
      case GameStatus.scheduled:
        return 'Geplant';
      case GameStatus.inProgress:
        return 'Laufend';
      case GameStatus.completed:
        return 'Beendet';
      case GameStatus.cancelled:
        return 'Abgesagt';
    }
  }

  void _generatePoolGamesForPool(String division, String pool) async {
    try {
      String poolId = '${division}_${pool}';
      List<String> teamIds = _poolTeams[poolId] ?? [];
      
      if (teamIds.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mindestens 2 Teams erforderlich für Pool-Spiele'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // Get actual team objects
      List<Team> teams = teamIds
          .map((id) => _allTeams.firstWhere((team) => team.id == id, orElse: () => Team(
            id: id,
            name: 'Unknown Team',
            city: '',
            bundesland: '',
            division: division,
            createdAt: DateTime.now(),
          )))
          .toList();
      
      await _gameService.generatePoolGames(widget.tournament!.id, pool, teams);
      int gamesGenerated = (teams.length * (teams.length - 1)) ~/ 2;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$gamesGenerated Spiele für Pool ${pool.toUpperCase()} generiert!'),
          backgroundColor: Colors.green,
        ),
      );
      
      setState(() {
        // Trigger rebuild to update UI
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Generieren der Spiele: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 