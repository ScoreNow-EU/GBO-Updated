import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/tournament.dart';
import '../models/game.dart';
import '../models/game_event.dart';
import '../models/tournament_link.dart';
import '../services/game_service.dart';
import '../services/live_scoring_service.dart';
import '../services/tournament_stats_service.dart';
import '../widgets/responsive_layout.dart';
import '../utils/responsive_helper.dart';
import '../widgets/rhbl_loader.dart';
import '../utils/app_colors.dart';
import 'package:timeline_tile/timeline_tile.dart';
import '../models/user.dart';
import 'tournament_edit_screen.dart';
import 'tournament_link_editor_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TournamentDetailScreen extends StatefulWidget {
  final Tournament tournament;

  const TournamentDetailScreen({
    super.key,
    required this.tournament,
  });

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen>
    with TickerProviderStateMixin {
  final GameService _gameService = GameService();
  final LiveScoringService _liveScoringService = LiveScoringService();
  final TournamentStatsService _statsService = TournamentStatsService();
  
  // Player stats state
  List<PlayerTournamentStats> _playerStats = [];
  bool _statsLoading = false;
  bool _statsLoaded = false;
  String selectedCategory = 'Alle';
  String selectedRound = 'Alle';
  String selectedTeams = 'Alle';
  late String selectedResultTab;
  String selectedSection = 'turniere'; // Current section
  
  // State for expandable sections
  final Map<String, bool> _expandedSections = {
    'Teams / Ranking': false,
    'Gruppenphase': false,
    'Final & Platzierungsrunde': false,
    'Spielerstatistiken': false,
    'Grundlegende Regeln (MUST)': false,
    'Schiedsrichter': false,
    'Offizielle & Delegate': false,
    'Infrastruktur & Services': false,
    'criteria_must': false,
    'criteria_referees': false,
    'criteria_officials': false,
    'criteria_infrastructure': false,
  };
  
  // Animation controllers for each expandable section
  final Map<String, AnimationController> _animationControllers = {};
  final Map<String, Animation<double>> _animations = {};
  
  // Cached data
  DocumentSnapshot? _cachedOrganizerData;
  List<Map<String, dynamic>>? _cachedResultsData;
  List<Game>? _cachedGames;
  String _gamesFingerprint = '';
  Timer? _gamesRefreshTimer;
  bool _isPreloading = true;
  
  @override
  void initState() {
    super.initState();
    // Set initial selected result tab to first category if available
    selectedResultTab = 'Alle';
    
    // Initialize animation controllers for all expandable sections
    for (final sectionKey in _expandedSections.keys) {
      _animationControllers[sectionKey] = AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      );
      _animations[sectionKey] = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _animationControllers[sectionKey]!, curve: Curves.easeInOut),
      );
    }
    
    // Preload all tournament data
    _preloadTournamentData();
  }
  
  @override
  void dispose() {
    _gamesRefreshTimer?.cancel();
    // Dispose all animation controllers
    for (final controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPlayerStats() async {
    if (_statsLoading || _statsLoaded) return;
    setState(() => _statsLoading = true);
    try {
      final stats = await _statsService.getTopScorers(widget.tournament.id);
      if (!mounted) return;
      setState(() {
        _playerStats = stats;
        _statsLoading = false;
        _statsLoaded = true;
      });
    } catch (e) {
      debugPrint('\u274c Player stats load error: $e');
      if (!mounted) return;
      setState(() => _statsLoading = false);
    }
  }
  
  List<Game> _parseGameDocs(List<QueryDocumentSnapshot> docs) {
    return docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return Game.fromJson(data);
    }).toList();
  }

  String _buildGamesFingerprint(List<Game> games) {
    return (games
          .map((g) => '${g.id}:${g.updatedAt.millisecondsSinceEpoch}')
          .toList()
        ..sort())
        .join('|');
  }

  Future<void> _preloadTournamentData() async {
    try {
      // Preload organizer data if available
      if (widget.tournament.tournamentOrganizerId != null) {
        _cachedOrganizerData = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.tournament.tournamentOrganizerId!)
            .get();
      }
      
      // Preload results data if available
      if (widget.tournament.results != null && widget.tournament.results!.isNotEmpty) {
        _cachedResultsData = [];
        for (final resultEntry in widget.tournament.results!.entries) {
          _cachedResultsData!.addAll(List<Map<String, dynamic>>.from(resultEntry.value));
        }
      }
      
      // Preload games data and periodically check for Firebase changes
      try {
        final gamesQuery = FirebaseFirestore.instance
            .collection('tournaments')
            .doc(widget.tournament.id)
            .collection('games');

        // Initial load
        final gamesSnapshot = await gamesQuery.get();
        _cachedGames = _parseGameDocs(gamesSnapshot.docs);
        _gamesFingerprint = _buildGamesFingerprint(_cachedGames!);

        // Silent background polling every 15 seconds â€“ only setState when data changed
        _gamesRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
          if (!mounted) return;
          try {
            final snap = await gamesQuery.get();
            final newGames = _parseGameDocs(snap.docs);
            final newFp = _buildGamesFingerprint(newGames);
            if (newFp != _gamesFingerprint && mounted) {
              _gamesFingerprint = newFp;
              setState(() => _cachedGames = newGames);
            }
          } catch (_) {}
        });
      } catch (e) {
        debugPrint('Error preloading games: $e');
        _cachedGames = [];
      }
      
      if (mounted) {
        setState(() {
          _isPreloading = false;
        });
      }
    } catch (e) {
      debugPrint('Error preloading tournament data: $e');
      if (mounted) {
        setState(() {
          _isPreloading = false;
        });
      }
    }
  }

  Future<bool> _checkIfAdmin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!userDoc.exists) return false;
      
      final roles = userDoc.get('roles') as List<dynamic>? ?? [];
      return roles.contains('admin');
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }

  void _navigateToEdit() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TournamentEditScreen(tournament: widget.tournament),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      selectedSection: selectedSection,
      onSectionChanged: (section) {
        if (section != 'turniere') {
          // Navigate back to home with selected section
          Navigator.of(context).pop();
          // You could add additional navigation logic here if needed
        }
      },
      title: widget.tournament.name,
      showBackButton: true,
      onBackPressed: () => Navigator.of(context).pop(),
      body: _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveHelper.isMobile(screenWidth);
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTournamentHeader(),
          SizedBox(height: isMobile ? 24 : 32),
          _buildResultsSection(),
          SizedBox(height: isMobile ? 24 : 32),
          _buildCriteriaSection(),
          SizedBox(height: isMobile ? 24 : 32),
          _buildOrganizationSection(),
        ],
      ),
    );
  }

  Widget _buildTournamentHeader() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveHelper.isMobile(screenWidth);
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isMobile ? _buildMobileHeader() : _buildDesktopHeader(),
    );
  }

  Widget _buildMobileHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Edit Button (Admin Only)
        FutureBuilder<bool>(
          future: _checkIfAdmin(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data == true) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _navigateToEdit,
                    icon: const Icon(Icons.edit),
                    label: const Text('Turnier bearbeiten'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              );
            }
            return const SizedBox();
          },
        ),
        
        // Tournament Logo
        Center(
          child: Container(
            width: double.infinity,
            height: 200,
            constraints: const BoxConstraints(maxWidth: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200, width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: widget.tournament.imageUrl != null && widget.tournament.imageUrl!.isNotEmpty
                  ? Image.network(
                      widget.tournament.imageUrl!,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: double.infinity,
                          height: 200,
                          color: Colors.grey.shade100,
                          child: Center(
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / 
                                      loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: double.infinity,
                          height: 200,
                          color: Colors.grey.shade200,
                          child: Icon(
                            Icons.sports_handball,
                            color: Colors.grey.shade400,
                            size: 60,
                          ),
                        );
                      },
                    )
                  : Container(
                      width: double.infinity,
                      height: 200,
                      color: Colors.grey.shade200,
                      child: Icon(
                        Icons.sports_handball,
                        color: Colors.grey.shade400,
                        size: 60,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        
        // Tournament Details
        Text(
          widget.tournament.dateString,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        
        // Location
        Row(
          children: [
            const Icon(Icons.location_on, size: 18, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.tournament.location,
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Points
        const SizedBox(height: 16),
        
        // Links Section (Ausschreibung/AGBs and Social Media)
        _buildLinksSection(),
      ],
    );
  }

  Widget _buildLinksSection() {
    // Separate links by type
    final agbLinks = widget.tournament.links.where((link) => link.type == 'agb').toList();
    final socialLinks = widget.tournament.links.where((link) => link.type == 'social').toList();
    
    debugPrint('Detail screen: Tournament has ${widget.tournament.links.length} total links, ${agbLinks.length} AGBs, ${socialLinks.length} social');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ausschreibung/AGBs Section
        if (agbLinks.isNotEmpty) ...[
          Text(
            'Ausschreibung / AGBs',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: agbLinks
                .map((link) => _buildLinkButton(link))
                .toList(),
          ),
          const SizedBox(height: 24),
        ],
        
        // Social Media Section
        if (socialLinks.isNotEmpty) ...[
          Text(
            'Social Media',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: socialLinks
                .map((link) => _buildLinkButton(link))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildLinkButton(TournamentLink link) {
    // Get icon from icon name
    IconData icon = _getIconFromName(link.iconName);
    Color color = Color(link.colorValue);
    
    return GestureDetector(
      onTap: () => _launchLink(link.url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              link.label,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
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

  Future<void> _launchLink(String url) async {
    if (!url.contains('://')) {
      url = 'https://$url';
    }
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $url')),
        );
      }
    }
  }

  void _downloadAGBs() {
    // Show dialog with AGB links
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final agbLinks = widget.tournament.links
            .where((link) => link.type == 'agb')
            .toList();
        
        return AlertDialog(
          title: const Text('Ausschreibung / AGBs'),
          content: agbLinks.isEmpty
              ? const Text('Keine Links verfÃƒÂ¼gbar')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: agbLinks.map((link) {
                    return ListTile(
                      title: Text(link.label),
                      onTap: () {
                        Navigator.of(context).pop();
                        _launchLink(link.url);
                      },
                    );
                  }).toList(),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('SchlieÃƒÅ¸en'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDesktopHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Edit Button (Admin Only)
        FutureBuilder<bool>(
          future: _checkIfAdmin(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data == true) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ElevatedButton.icon(
                  onPressed: _navigateToEdit,
                  icon: const Icon(Icons.edit),
                  label: const Text('Turnier bearbeiten'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              );
            }
            return const SizedBox();
          },
        ),
        
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tournament Logo
            Container(
              width: 180,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: widget.tournament.imageUrl != null && widget.tournament.imageUrl!.isNotEmpty
                    ? Image.network(
                        widget.tournament.imageUrl!,
                        width: 180,
                        height: 120,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 180,
                            height: 120,
                            color: Colors.grey.shade100,
                            child: Center(
                              child: SizedBox(
                                width: 30,
                                height: 30,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded / 
                                        loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 180,
                            height: 120,
                            color: Colors.grey.shade200,
                            child: Icon(
                              Icons.sports_handball,
                              color: Colors.grey.shade400,
                              size: 40,
                            ),
                          );
                        },
                      )
                    : Container(
                        width: 180,
                        height: 120,
                        color: Colors.grey.shade200,
                        child: Icon(
                          Icons.sports_handball,
                          color: Colors.grey.shade400,
                          size: 40,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 24),
            
            // Tournament Details (middle section)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.tournament.dateString,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _downloadAGBs,
                    child: Row(
                      children: [
                        const Icon(Icons.download, size: 16, color: Colors.black87),
                        const SizedBox(width: 8),
                        Text(
                          'Ausschreibung/AGBs',
                          style: TextStyle(
                            color: Colors.black87,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.tournament.location,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Social Media (right side, stacked vertically)
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'Social Media',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...(widget.tournament.links
                .where((link) => link.type == 'social')
                .toList()
                .map((link) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildLinkButton(link),
                    ))),
          ],
        ),
          ],
        ),
      ],
    );
  }

  String? _getTournamentImage(String tournamentName) {
    // Return null to use placeholder/icon instead of hardcoded images
    return null;
  }

  Widget _buildMatchesSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveHelper.isMobile(screenWidth);
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Matches',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 20),
          
          // Games Display - Use cached games with optional live updates
          if (_cachedGames == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_cachedGames!.isEmpty)
            Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Noch keine Spiele fÃƒÂ¼r dieses Turnier erstellt.',
                      style: TextStyle(fontSize: isMobile ? 13 : 14),
                    ),
                  ),
                ],
              ),
            )
          else
            _buildGamesContent(_cachedGames!, isMobile),
        ],
      ),
    );
  }

  Widget _buildGamesContent(List<Game> allGames, bool isMobile) {
    // Categorize games
    final now = DateTime.now();
    
    // Current games: live games or games within 2 hours of start
    final currentGames = allGames.where((game) {
      if (game.status == GameStatus.inProgress) return true;
      if (game.scheduledTime == null) return false;
      
      final timeDiff = game.scheduledTime!.difference(now).inMinutes;
      return timeDiff >= -30 && timeDiff <= 120; // Started up to 30min ago or starting within 2 hours
    }).toList();

    // Upcoming games: future games not in current list
    final upcomingGames = allGames.where((game) {
      if (currentGames.contains(game)) return false;
      if (game.status == GameStatus.completed) return false;
      if (game.scheduledTime == null) return true; // Unscheduled games
      
      return game.scheduledTime!.isAfter(now);
    }).toList();

    // Completed games with results
    final completedGames = allGames
        .where((game) => game.status == GameStatus.completed && game.result != null)
        .toList()
      ..sort((a, b) => (b.scheduledTime ?? DateTime(1970)).compareTo(a.scheduledTime ?? DateTime(1970)));

    // Sort games
    currentGames.sort((a, b) {
      if (a.status == GameStatus.inProgress && b.status != GameStatus.inProgress) return -1;
      if (b.status == GameStatus.inProgress && a.status != GameStatus.inProgress) return 1;
      return (a.scheduledTime ?? DateTime(2100)).compareTo(b.scheduledTime ?? DateTime(2100));
    });
    
    upcomingGames.sort((a, b) => (a.scheduledTime ?? DateTime(2100)).compareTo(b.scheduledTime ?? DateTime(2100)));

    return FutureBuilder<List<Game>>(
      future: _getGamesWithActiveScoringTablets(allGames),
      builder: (context, activeScoringGamesSnapshot) {
        final gamesWithActiveScoring = activeScoringGamesSnapshot.data ?? [];
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live Scoring Games (Top Priority)
            if (gamesWithActiveScoring.isNotEmpty) ...[
              _buildLiveScoringSection(
                games: gamesWithActiveScoring,
                isMobile: isMobile,
              ),
              SizedBox(height: isMobile ? 16 : 20),
            ],
            
            // Current/Live Games
            if (currentGames.isNotEmpty) ...[
              _buildGamesSubsection(
                title: 'Aktuelle Spiele',
                icon: Icons.play_circle_filled,
                iconColor: Colors.green,
                games: currentGames.where((game) => !gamesWithActiveScoring.contains(game)).toList(),
                isMobile: isMobile,
              ),
              SizedBox(height: isMobile ? 16 : 20),
            ],
            
            // Upcoming Games
            if (upcomingGames.isNotEmpty) ...[
              _buildGamesSubsection(
                title: 'Kommende Spiele',
                icon: Icons.schedule,
                iconColor: Colors.blue,
                games: upcomingGames.take(6).toList(), // Limit to first 6
                isMobile: isMobile,
              ),
              SizedBox(height: isMobile ? 16 : 20),
            ],
            
            // Completed Games with Results
            if (completedGames.isNotEmpty) ...[
              _buildGamesSubsection(
                title: 'Ergebnisse',
                icon: Icons.check_circle,
                iconColor: Colors.green,
                games: completedGames,
                isMobile: isMobile,
              ),
              SizedBox(height: isMobile ? 16 : 20),
            ],

            // Show View All Games button if there are more games
            if (allGames.length > (currentGames.length + 6)) ...[
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    // TODO: Navigate to detailed games view
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Detaillierte Spieleansicht wird implementiert')),
                    );
                  },
                  icon: const Icon(Icons.list),
                  label: Text('Alle ${allGames.length} Spiele anzeigen'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildGamesSubsection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Game> games,
    required bool isMobile,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${games.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: isMobile ? 12 : 16),
        
        // Games List
        ...games.map((game) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildGameCard(game, isMobile),
        )).toList(),
      ],
    );
  }

  Widget _buildGameCard(Game game, bool isMobile) {
    final isLive = game.status == GameStatus.inProgress;
    final now = DateTime.now();
    String timeDisplay = 'TBD';
    String dateDisplay = '';
    
    if (game.scheduledTime != null) {
      final gameTime = game.scheduledTime!;
      timeDisplay = '${gameTime.hour.toString().padLeft(2, '0')}:${gameTime.minute.toString().padLeft(2, '0')}';
      
      if (gameTime.day == now.day && gameTime.month == now.month && gameTime.year == now.year) {
        dateDisplay = 'Heute';
      } else if (gameTime.day == now.day + 1 && gameTime.month == now.month && gameTime.year == now.year) {
        dateDisplay = 'Morgen';
      } else {
        dateDisplay = '${gameTime.day.toString().padLeft(2, '0')}.${gameTime.month.toString().padLeft(2, '0')}.${gameTime.year}';
      }
    }

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: isLive ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLive ? Colors.green.shade300 : Colors.grey.shade200,
          width: isLive ? 2 : 1,
        ),
      ),
      child: isMobile ? _buildMobileGameCard(game, isLive, timeDisplay, dateDisplay) : _buildDesktopGameCard(game, isLive, timeDisplay, dateDisplay),
    );
  }

  Widget _buildMobileGameCard(Game game, bool isLive, String timeDisplay, String dateDisplay) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time and Status
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isLive ? Colors.green : Colors.blue,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                timeDisplay,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (dateDisplay.isNotEmpty)
              Text(
                dateDisplay,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            const Spacer(),
            if (isLive) ...[
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        
        // Teams
        Text(
          '${game.teamAName} vs ${game.teamBName}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        
        // Score if available
        if (game.status == GameStatus.completed && game.result != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      game.result!.finalScore,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                        letterSpacing: 1,
                      ),
                    ),
                    if (game.result!.halfTimeScore != null) ...[
                      const SizedBox(width: 10),
                      Text(
                        'HZ: ${game.result!.halfTimeScore}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (game.result!.winnerName.isNotEmpty && game.result!.winnerName != 'Unentschieden')
                Flexible(
                  child: Text(
                    'âœ“ ${game.result!.winnerName}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ],
        // Game Type and Court Info
        const SizedBox(height: 8),
        Row(
          children: [
            if (game.courtId != null) ...[
              Icon(Icons.sports_tennis, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                _getCourtDisplayName(game.courtId!),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(width: 12),
            ],
            Icon(Icons.category, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              _getGameTypeDisplay(game),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopGameCard(Game game, bool isLive, String timeDisplay, String dateDisplay) {
    return Row(
      children: [
        // Time
        Container(
          width: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isLive ? Colors.green : Colors.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  timeDisplay,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (dateDisplay.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  dateDisplay,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Teams
        Expanded(
          child: Text(
            '${game.teamAName} vs ${game.teamBName}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        
        // Court Info
        if (game.courtId != null) ...[
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sports_tennis, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  _getCourtDisplayName(game.courtId!),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
        
        // Score
        if (game.status == GameStatus.completed && game.result != null) ...[
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  game.result!.finalScore,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                    letterSpacing: 1,
                  ),
                ),
                if (game.result!.halfTimeScore != null)
                  Text(
                    'HZ: ${game.result!.halfTimeScore}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
        ],

        // Game Type
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Text(
            _getGameTypeDisplay(game),
            style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.w500),
          ),
        ),
        
        // Live indicator
        if (isLive) ...[
          const SizedBox(width: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _getGameTypeDisplay(Game game) {
    if (game.gameType == GameType.pool) {
      return game.poolId != null ? 'Pool ${game.poolId}' : 'Poolspiel';
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
    
    return 'Spiel';
  }

  /// Resolves a court ID to a human-readable name using the tournament's court list.
  String _getCourtDisplayName(String courtId) {
    try {
      final court = widget.tournament.courts.firstWhere((c) => c.id == courtId);
      return 'Halle: ${court.name}';
    } catch (_) {
      return 'Halle $courtId';
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

  /// Returns a zero-padded sort key for natural numeric ordering of court names.
  /// E.g. "Halle 2" â†’ "Halle 000002", "Halle 10" â†’ "Halle 000010".
  String _courtSortKey(String? courtId) {
    if (courtId == null) return 'zzz'; // games without court go last
    try {
      final court = widget.tournament.courts.firstWhere((c) => c.id == courtId);
      return court.name.replaceAllMapped(
        RegExp(r'\d+'),
        (m) => m.group(0)!.padLeft(6, '0'),
      );
    } catch (_) {
      return courtId.replaceAllMapped(
        RegExp(r'\d+'),
        (m) => m.group(0)!.padLeft(6, '0'),
      );
    }
  }

  /// Builds a ranking table from all pool games: W / D / L / Tore / Punkte
  Widget _buildTeamsRankingTable() {
    final games = _cachedGames ?? [];
    // Collect all unique team names + IDs from games
    final Map<String, _TeamStats> statsMap = {};

    for (final game in games) {
      // Register both teams
      if (game.teamAId != null && game.teamAId!.isNotEmpty) {
        statsMap.putIfAbsent(game.teamAId!, () => _TeamStats(id: game.teamAId!, name: game.teamAName));
      }
      if (game.teamBId != null && game.teamBId!.isNotEmpty) {
        statsMap.putIfAbsent(game.teamBId!, () => _TeamStats(id: game.teamBId!, name: game.teamBName));
      }

      // Only count completed games for stats
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

      // Use winnerId (handles Sonderszenario correctly), fall back to score comparison
      if (r.winnerId != null && r.winnerId!.isNotEmpty) {
        if (r.winnerId == aId) {
          sA.wins++;
          sB.losses++;
        } else if (r.winnerId == bId) {
          sB.wins++;
          sA.losses++;
        } else {
          sA.draws++;
          sB.draws++;
        }
      } else if (r.teamAScore > r.teamBScore) {
        sA.wins++;
        sB.losses++;
      } else if (r.teamBScore > r.teamAScore) {
        sB.wins++;
        sA.losses++;
      } else {
        sA.draws++;
        sB.draws++;
      }
    }

    if (statsMap.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border(top: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Text(
          'Noch keine Teams zugeordnet.',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
      );
    }

    // Head-to-head comparison helper
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
      if (winsA > winsB) return -1; // A is better
      if (winsB > winsA) return 1;  // B is better
      return 0; // equal
    }

    // Sort: points desc â†’ head-to-head â†’ goal diff desc â†’ mark tiebreaker
    final sorted = statsMap.values.toList()
      ..sort((a, b) {
        final pCmp = b.points.compareTo(a.points);
        if (pCmp != 0) return pCmp;
        final h2hCmp = h2h(a.id, b.id);
        if (h2hCmp != 0) return h2hCmp;
        final dCmp = b.goalDiff.compareTo(a.goalDiff);
        if (dCmp != 0) return dCmp;
        // Same points, same H2H, same goal diff â†’ Entscheidungsspiel
        a.needsTiebreaker = true;
        b.needsTiebreaker = true;
        return a.name.compareTo(b.name);
      });

    final totalTeams = sorted.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.grey.shade200,
            child: Row(
              children: [
                const SizedBox(width: 28, child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                const SizedBox(width: 8),
                const Expanded(child: Text('Team', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                SizedBox(width: 32, child: Text('Sp', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700), textAlign: TextAlign.center)),
                SizedBox(width: 32, child: Text('S', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade700), textAlign: TextAlign.center)),
                SizedBox(width: 32, child: Text('U', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade700), textAlign: TextAlign.center)),
                SizedBox(width: 32, child: Text('N', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade700), textAlign: TextAlign.center)),
                SizedBox(width: 56, child: Text('Tore', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700), textAlign: TextAlign.center)),
                SizedBox(width: 32, child: Text('+/-', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700), textAlign: TextAlign.center)),
                SizedBox(width: 36, child: Text('Pkt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade700), textAlign: TextAlign.center)),
                SizedBox(width: 36, child: Text('LP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple.shade700), textAlign: TextAlign.center)),
              ],
            ),
          ),
          // Rows
          ...sorted.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final t = entry.value;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: rank <= 2 ? Colors.green.withOpacity(0.04) : Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: rank <= 2 ? Colors.green.shade100 : Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$rank',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: rank <= 2 ? Colors.green.shade800 : Colors.grey.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 32, child: Text('${t.played}', style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
                  SizedBox(width: 32, child: Text('${t.wins}', style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                  SizedBox(width: 32, child: Text('${t.draws}', style: TextStyle(fontSize: 12, color: Colors.orange.shade700), textAlign: TextAlign.center)),
                  SizedBox(width: 32, child: Text('${t.losses}', style: TextStyle(fontSize: 12, color: Colors.red.shade700), textAlign: TextAlign.center)),
                  SizedBox(width: 56, child: Text('${t.goalsFor}:${t.goalsAgainst}', style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
                  SizedBox(
                    width: 32,
                    child: Text(
                      t.goalDiff >= 0 ? '+${t.goalDiff}' : '${t.goalDiff}',
                      style: TextStyle(fontSize: 12, color: t.goalDiff >= 0 ? Colors.green.shade700 : Colors.red.shade700),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${t.points}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  // Ligapunkte
                  SizedBox(
                    width: 36,
                    child: t.needsTiebreaker
                        ? Tooltip(
                            message: 'Entscheidungsspiel erforderlich',
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.orange.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '?',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${totalTeams - rank + 1}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple.shade800),
                              textAlign: TextAlign.center,
                            ),
                          ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Future<List<Game>> _getGamesWithActiveScoringTablets(List<Game> allGames) async {
    List<Game> gamesWithActiveScoring = [];
    
    debugPrint('Ã°Å¸Å½Â¯ Checking ${allGames.length} games for active scoring tablets...');
    
    for (final game in allGames) {
      try {
        // First priority: Games that are currently in progress
        if (game.status == GameStatus.inProgress) {
          debugPrint('Ã¢Å“â€¦ Game ${game.id.substring(game.id.length - 8)} is in progress - adding to live scoring');
          gamesWithActiveScoring.add(game);
          continue;
        }
        
        // Second priority: Check if there's recent GameState activity (within last 10 minutes)
        final gameStateDoc = await FirebaseFirestore.instance
            .collection('gameStates')
            .doc(game.id)
            .get();
        
        if (gameStateDoc.exists) {
          debugPrint('Ã°Å¸â€œâ€¹ Found gameState for ${game.id.substring(game.id.length - 8)}');
          final data = gameStateDoc.data()!;
          
          // Check if the game has any scoring activity indicators
          bool hasActivity = false;
          String activityReason = '';
          
          // Check 1: Has lastUpdated timestamp within 10 minutes
          final lastUpdated = data['lastUpdated'] != null 
              ? (data['lastUpdated'] as Timestamp).toDate()
              : null;
          
          if (lastUpdated != null) {
            final now = DateTime.now();
            final timeDiff = now.difference(lastUpdated).inMinutes;
            debugPrint('Ã¢ÂÂ° Game ${game.id.substring(game.id.length - 8)} last updated ${timeDiff} minutes ago');
            
            if (timeDiff <= 10) {
              hasActivity = true;
              activityReason = 'recent update';
            }
          }
          
          // Check 2: Game timer is running
          if (!hasActivity && data['isRunning'] == true) {
            hasActivity = true;
            activityReason = 'timer running';
          }
          
          // Check 3: Has any game time (indicates scoring tablet has been used)
          if (!hasActivity && ((data['minutes'] != null && data['minutes'] > 0) || (data['seconds'] != null && data['seconds'] > 0))) {
            hasActivity = true;
            activityReason = 'has game time';
          }
          
          // Check 4: Check for recent game events
          if (!hasActivity) {
            try {
              final eventsSnapshot = await FirebaseFirestore.instance
                  .collection('gameEvents')
                  .where('gameId', isEqualTo: game.id)
                  .get();
              
              if (eventsSnapshot.docs.isNotEmpty) {
                hasActivity = true;
                activityReason = 'has game events';
                debugPrint('Ã°Å¸â€œÂ Game ${game.id.substring(game.id.length - 8)} has ${eventsSnapshot.docs.length} events');
              }
            } catch (e) {
              debugPrint('Ã¢ÂÅ’ Error checking events for ${game.id.substring(game.id.length - 8)}: $e');
            }
          }
          
          if (hasActivity) {
            debugPrint('Ã¢Å“â€¦ Game ${game.id.substring(game.id.length - 8)} has activity ($activityReason) - adding to live scoring');
            gamesWithActiveScoring.add(game);
          } else {
            debugPrint('Ã¢Å¡Â Ã¯Â¸Â Game ${game.id.substring(game.id.length - 8)} has gameState but no detectable activity');
          }
        } else {
          debugPrint('Ã¢ÂÅ’ No gameState found for ${game.id.substring(game.id.length - 8)}');
        }
      } catch (e) {
        // Skip games with errors
        debugPrint('Ã¢ÂÅ’ Error checking game state for ${game.id.substring(game.id.length - 8)}: $e');
      }
    }
    
    debugPrint('Ã°Å¸Å½Â¯ Found ${gamesWithActiveScoring.length} games with active scoring tablets');
    return gamesWithActiveScoring;
  }

  Widget _buildLiveScoringSection({
    required List<Game> games,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade50, Colors.orange.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tablet, color: Colors.red, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Live Scoring - Aktive Tablets',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${games.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 12 : 16),
          
          // Live Scoring Games
          ...games.map((game) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildLiveScoringGameCard(game, isMobile),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildLiveScoringGameCard(Game game, bool isMobile) {
    return StreamBuilder<GameState>(
      stream: _liveScoringService.streamGameState(game.id),
      builder: (context, snapshot) {
        final gameState = snapshot.data;
        
        return InkWell(
          onTap: () => _showLiveScoringDetails(game, gameState),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade300, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isMobile 
                ? _buildMobileLiveScoringCard(game, gameState)
                : _buildDesktopLiveScoringCard(game, gameState),
          ),
        );
      },
    );
  }

  Widget _buildMobileLiveScoringCard(Game game, GameState? gameState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with live indicator
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'LIVE SCORING',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const Spacer(),
            if (gameState?.gameTime != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  gameState!.gameTime.displayTime,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Teams and Score
        Row(
          children: [
            Expanded(
              child: Text(
                game.teamAName,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
                         if (gameState != null && game.teamAId != null && game.teamBId != null) ...[
               Text(
                 '${gameState.getTeamScore(game.teamAId!)}',
                 style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
               ),
               const Text(' - ', style: TextStyle(fontSize: 16)),
               Text(
                 '${gameState.getTeamScore(game.teamBId!)}',
                 style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
               ),
            ] else ...[
              const Text('0 - 0', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                game.teamBName,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        
        // Score
        if (gameState != null) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Ergebnis: ${gameState.teamAScore} - ${gameState.teamBScore}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDesktopLiveScoringCard(Game game, GameState? gameState) {
    return Row(
      children: [
        // Live indicator
        Column(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'LIVE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        
        const SizedBox(width: 16),
        
        // Game time
        Container(
          width: 60,
          child: gameState?.gameTime != null
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    gameState!.gameTime.displayTime,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : const Text('--:--', style: TextStyle(fontSize: 12)),
        ),
        
        const SizedBox(width: 16),
        
        // Team A
        Expanded(
          flex: 2,
          child: Text(
            game.teamAName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        
        // Score
                 Container(
           width: 80,
           child: gameState != null && game.teamAId != null && game.teamBId != null
               ? Text(
                   '${gameState.getTeamScore(game.teamAId!)} - ${gameState.getTeamScore(game.teamBId!)}',
                   style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                   textAlign: TextAlign.center,
                 )
               : const Text('0 - 0', 
                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                   textAlign: TextAlign.center,
                 ),
         ),
        
        // Team B
        Expanded(
          flex: 2,
          child: Text(
            game.teamBName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Score
        Container(
          width: 60,
          child: gameState != null
              ? Text(
                  '${gameState.teamAScore}-${gameState.teamBScore}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                )
              : const Text('0-0', 
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
        ),
      ],
    );
  }

  void _showLiveScoringDetails(Game game, GameState? gameState) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LiveScoringDetailsScreen(
          game: game,
          liveScoringService: _liveScoringService,
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label*',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    if (label == 'Kategorie') selectedCategory = newValue;
                    if (label == 'Spielrunde') selectedRound = newValue;
                    if (label == 'Teams') selectedTeams = newValue;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveHelper.isMobile(screenWidth);
    final allGames = _cachedGames ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live Scoring Section (always visible if active)
        if (allGames.isNotEmpty)
          FutureBuilder<List<Game>>(
            future: _getGamesWithActiveScoringTablets(allGames),
            builder: (context, snapshot) {
              final liveGames = snapshot.data ?? [];
              if (liveGames.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: EdgeInsets.only(bottom: isMobile ? 16 : 20),
                child: _buildLiveScoringSection(games: liveGames, isMobile: isMobile),
              );
            },
          ),

        // Ergebnisse Container
        Container(
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ergebnisse',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: isMobile ? 16 : 20),
              
              // Expandable sections
              _buildExpandableSection('Teams / Ranking', Icons.keyboard_arrow_down, 'Teams / Ranking'),
              SizedBox(height: isMobile ? 6 : 8),
              _buildExpandableSection('Gruppenphase', Icons.keyboard_arrow_down, 'Gruppenphase'),
              SizedBox(height: isMobile ? 6 : 8),
              _buildExpandableSection('Final & Platzierungsrunde', Icons.keyboard_arrow_down, 'Final & Platzierungsrunde'),
              SizedBox(height: isMobile ? 6 : 8),
              _buildExpandableSection('Spielerstatistiken', Icons.keyboard_arrow_down, 'Spielerstatistiken'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultTab(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[600] : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? Colors.blue[600]! : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableSection(String title, IconData icon, String sectionKey) {
    final isExpanded = _expandedSections[sectionKey] ?? false;
    final animationController = _animationControllers[sectionKey];
    final animation = _animations[sectionKey];
    
    if (animationController != null) {
      if (isExpanded) {
        animationController.forward();
      } else {
        animationController.reverse();
      }
    }
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _expandedSections[sectionKey] = !isExpanded;
        });
        // Lazy-load player stats on first expand
        if (!isExpanded && sectionKey == 'Spielerstatistiken') {
          _loadPlayerStats();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  AnimatedBuilder(
                    animation: animation ?? AlwaysStoppedAnimation(0.0),
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: (animation?.value ?? 0) * 3.14159,
                        child: Icon(icon, color: Colors.grey[600], size: 20),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Animated expand/collapse with SizeTransition
            SizeTransition(
              sizeFactor: animation ?? AlwaysStoppedAnimation(0.0),
              axisAlignment: -1.0,
              child: _buildSectionContent(sectionKey),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionContent(String title) {
    switch (title) {
      case 'Teams / Ranking':
        return _buildTeamsRankingTable();
      case 'Gruppenphase':
        return _buildCompletedGamesList(
          games: (_cachedGames ?? []).where((g) => g.gameType != GameType.elimination).toList()
            ..sort((a, b) {
              // 1. Uhrzeit
              final timeCmp = (a.scheduledTime ?? DateTime(2100)).compareTo(b.scheduledTime ?? DateTime(2100));
              if (timeCmp != 0) return timeCmp;
              // 2. Halle (natÃ¼rliche Sortierung: Halle 1 vor Halle 2)
              final courtCmp = _courtSortKey(a.courtId).compareTo(_courtSortKey(b.courtId));
              if (courtCmp != 0) return courtCmp;
              // 3. Team A Name (A vor B)
              return a.teamAName.compareTo(b.teamAName);
            }),
          emptyText: 'Noch keine Gruppenspiele vorhanden.',
        );
      case 'Final & Platzierungsrunde':
        return _buildCompletedGamesList(
          games: (_cachedGames ?? []).where((g) => g.gameType == GameType.elimination && g.result != null).toList()
            ..sort((a, b) {
              final timeCmp = (a.scheduledTime ?? DateTime(2100)).compareTo(b.scheduledTime ?? DateTime(2100));
              if (timeCmp != 0) return timeCmp;
              final courtCmp = _courtSortKey(a.courtId).compareTo(_courtSortKey(b.courtId));
              if (courtCmp != 0) return courtCmp;
              return a.teamAName.compareTo(b.teamAName);
            }),
          emptyText: 'Noch keine Ergebnisse aus der K.O.-Phase vorhanden.',
        );
      case 'Spielerstatistiken':
        return _buildPlayerStatsContent();
      case 'criteria_must':
      case 'criteria_referees':
      case 'criteria_officials':
      case 'criteria_infrastructure':
        return Padding(
          padding: const EdgeInsets.all(16),
          child: _buildCriteriaContentByCategory(title),
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildPlayerStatsContent() {
    if (_statsLoading) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border(top: BorderSide(color: Colors.grey[200]!)),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final players = _playerStats.where((s) =>
        s.totalGoals > 0 ||
        s.yellowCards > 0 ||
        s.twoMinuteSuspensions > 0 ||
        s.redCards > 0).toList();

    if (players.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border(top: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Text(
          _statsLoaded
              ? 'Noch keine Spielerstatistiken vorhanden.'
              : 'Statistiken werden beim Ã–ffnen geladen.',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
      );
    }

    // Sort: goals desc, then name
    final sorted = List<PlayerTournamentStats>.from(players)
      ..sort((a, b) {
        final g = b.totalGoals.compareTo(a.totalGoals);
        if (g != 0) return g;
        return a.playerName.compareTo(b.playerName);
      });

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
          columnSpacing: 16,
          dataRowMinHeight: 36,
          dataRowMaxHeight: 44,
          columns: const [
            DataColumn(label: Text('#',        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Spieler',  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Team',     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Tore',     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
            DataColumn(label: Text('7m',       style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
            DataColumn(label: Text('Zeitstr.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
            DataColumn(label: Text('Gelb',     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
            DataColumn(label: Text('Rot',      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
          ],
          rows: List.generate(sorted.length, (index) {
            final p = sorted[index];
            final rank = index + 1;
            Color? rowColor;
            if (rank == 1) rowColor = const Color(0xFFFFF8E1);
            else if (rank == 2) rowColor = Colors.grey[50];
            else if (rank == 3) rowColor = const Color(0xFFFFF3E0);
            return DataRow(
              color: rank <= 3 ? WidgetStateProperty.all(rowColor) : null,
              cells: [
                DataCell(Text('$rank',
                  style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 12,
                    color: rank == 1 ? const Color(0xFFFFD700)
                         : rank == 2 ? const Color(0xFFC0C0C0)
                         : rank == 3 ? const Color(0xFFCD7F32)
                         : Colors.grey[500],
                  ),
                )),
                DataCell(ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(p.playerName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: rank <= 3 ? FontWeight.bold : FontWeight.normal),
                  ),
                )),
                DataCell(ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Text(p.teamName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                )),
                DataCell(Text('${p.totalGoals}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13,
                    color: p.totalGoals > 0 ? Colors.blue[700] : Colors.grey[400],
                  ),
                )),
                DataCell(Text('${p.sevenMeterGoals}',
                  style: TextStyle(fontSize: 12,
                    color: p.sevenMeterGoals > 0 ? Colors.teal[700] : Colors.grey[400]),
                )),
                DataCell(Text('${p.twoMinuteSuspensions}',
                  style: TextStyle(fontSize: 12,
                    fontWeight: p.twoMinuteSuspensions > 0 ? FontWeight.w600 : FontWeight.normal,
                    color: p.twoMinuteSuspensions > 0 ? Colors.orange[800] : Colors.grey[400]),
                )),
                DataCell(Text('${p.yellowCards}',
                  style: TextStyle(fontSize: 12,
                    fontWeight: p.yellowCards > 0 ? FontWeight.w600 : FontWeight.normal,
                    color: p.yellowCards > 0 ? Colors.amber[800] : Colors.grey[400]),
                )),
                DataCell(Text('${p.redCards}',
                  style: TextStyle(fontSize: 12,
                    fontWeight: p.redCards > 0 ? FontWeight.bold : FontWeight.normal,
                    color: p.redCards > 0 ? Colors.red : Colors.grey[400]),
                )),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCriteriaSection() {
    return const SizedBox.shrink();
  }

  /// Shows a list of games (completed with scores, scheduled with time/court), used inside expandable sections.
  Widget _buildCompletedGamesList({required List<Game> games, required String emptyText}) {
    if (games.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border(top: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Text(emptyText, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        children: games.map((game) {
          final hasResult = game.result != null;
          final result = game.result;
          final isCompleted = game.status == GameStatus.completed && hasResult;
          final isLive = game.status == GameStatus.inProgress;
          final isWinnerA = hasResult && result!.winnerId == game.teamAId;
          final isWinnerB = hasResult && result!.winnerId == game.teamBId;
          
          // Format scheduled time
          String timeInfo = '';
          if (game.scheduledTime != null) {
            final t = game.scheduledTime!;
            timeInfo = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
          }
          
          // Court/Halle info
          final courtName = game.courtId != null ? _getCourtDisplayName(game.courtId!) : null;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              color: isLive ? Colors.green.shade50 : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Optional top row: time + court + status badge
                if (timeInfo.isNotEmpty || courtName != null || isLive)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        if (timeInfo.isNotEmpty) ...[
                          Icon(Icons.schedule, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(timeInfo, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                          const SizedBox(width: 12),
                        ],
                        if (courtName != null) ...[
                          Icon(Icons.location_on, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(courtName, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        ],
                        const Spacer(),
                        if (isLive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                // Main row: Team A - Score - Team B
                Row(
                  children: [
                    // Team A
                    Expanded(
                      child: Text(
                        game.teamAName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isWinnerA ? FontWeight.bold : FontWeight.normal,
                          color: isWinnerA ? Colors.green.shade700 : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Score or pending
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isCompleted ? Colors.green.shade200 : (isLive ? Colors.green.shade400 : Colors.grey.shade300),
                        ),
                      ),
                      child: isCompleted
                          ? Column(
                              children: [
                                Text(
                                  result!.finalScore,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800,
                                    letterSpacing: 1,
                                  ),
                                ),
                                if (result.halfTimeScore != null)
                                  Text(
                                    'HZ: ${result.halfTimeScore}',
                                    style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                                  ),
                              ],
                            )
                          : Text(
                              isLive ? 'lÃ¤uft' : '- : -',
                              style: TextStyle(
                                fontSize: isLive ? 12 : 15,
                                fontWeight: FontWeight.bold,
                                color: isLive ? Colors.green.shade700 : Colors.grey.shade400,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                    // Team B
                    Expanded(
                      child: Text(
                        game.teamBName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isWinnerB ? FontWeight.bold : FontWeight.normal,
                          color: isWinnerB ? Colors.green.shade700 : Colors.black87,
                        ),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                // Special scenario badge (WH/WG/NH/NG/X) + comment
                if (game.result?.specialScenario != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Text(
                          _scenarioShortCode(game.result!.specialScenario!),
                          style: TextStyle(fontSize: 10, color: Colors.orange.shade800, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          game.result!.resultComment ?? game.result!.specialScenario!,
                          style: TextStyle(fontSize: 10, color: Colors.grey[600], fontStyle: FontStyle.italic),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCriteriaContentByCategory(String category) {
    return const SizedBox.shrink();
  }

  Widget _buildOrganizationSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveHelper.isMobile(screenWidth);
    
    // If tournament has an assigned organizer, show that
    if (widget.tournament.tournamentOrganizerId != null) {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.tournament.tournamentOrganizerId)
            .get(),
        builder: (context, snapshot) {
          final innerScreenWidth = MediaQuery.of(context).size.width;
          final innerIsMobile = ResponsiveHelper.isMobile(innerScreenWidth);
          String organizerName = 'Organisator';
          String organizerEmail = '';
          
          if (snapshot.hasData && snapshot.data!.exists) {
            final userData = snapshot.data!.data() as Map<String, dynamic>;
            final firstName = userData['firstName'] ?? '';
            final lastName = userData['lastName'] ?? '';
            organizerName = '$firstName $lastName'.trim();
            organizerEmail = userData['email'] ?? '';
          }
          
          return Container(
            padding: EdgeInsets.all(innerIsMobile ? 16 : 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(innerIsMobile ? 12 : 16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: innerIsMobile ? 36 : 40,
                            height: innerIsMobile ? 36 : 40,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(innerIsMobile ? 18 : 20),
                            ),
                            child: const Center(
                              child: Icon(Icons.person, color: Colors.grey),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Turnierorganisation',
                                  style: TextStyle(
                                    fontSize: innerIsMobile ? 12 : 13,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  organizerName,
                                  style: TextStyle(
                                    fontSize: innerIsMobile ? 14 : 15,
                                    fontWeight: FontWeight.w600,
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
                  ],
                ),
                if (organizerEmail.isNotEmpty) ...[
                  SizedBox(height: innerIsMobile ? 16 : 20),
                  Row(
                    children: [
                      Icon(Icons.email, size: innerIsMobile ? 18 : 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          organizerEmail,
                          style: TextStyle(fontSize: innerIsMobile ? 13 : 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      );
    }
    
    // No organizer assigned â€” show neutral placeholder
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: isMobile ? 36 : 40,
            height: isMobile ? 36 : 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(isMobile ? 18 : 20),
            ),
            child: const Center(
              child: Icon(Icons.person, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Turnierorganisation',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Kein Veranstalter eingetragen',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LiveScoringDetailsScreen extends StatefulWidget {
  final Game game;
  final LiveScoringService liveScoringService;

  const LiveScoringDetailsScreen({
    super.key,
    required this.game,
    required this.liveScoringService,
  });

  @override
  State<LiveScoringDetailsScreen> createState() => _LiveScoringDetailsScreenState();
}

class _LiveScoringDetailsScreenState extends State<LiveScoringDetailsScreen>
    with TickerProviderStateMixin {
  Timer? _refreshTimer;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  GameState? _currentGameState;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController.forward();
    
    // Start 1-second refresh timer
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // This will trigger a rebuild and refresh the StreamBuilder
        });
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    
    return Theme(
      data: Theme.of(context).copyWith(
        appBarTheme: AppBarTheme(
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1A1A2E),
                const Color(0xFF16213E),
                const Color(0xFF0F3460),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildCustomAppBar(isMobile),
                Expanded(
                  child: StreamBuilder<GameState>(
                    stream: widget.liveScoringService.streamGameState(widget.game.id),
                    builder: (context, snapshot) {
                      final gameState = snapshot.data;
                      _currentGameState = gameState;
                      
                      if (snapshot.connectionState == ConnectionState.waiting && gameState == null) {
                        return _buildLoadingView(isMobile);
                      }
                      
                      if (snapshot.hasError) {
                        return _buildErrorView(snapshot.error.toString(), isMobile);
                      }
                      
                      return AnimatedBuilder(
                        animation: _slideController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, 50 * (1 - _slideController.value)),
                            child: Opacity(
                              opacity: _slideController.value,
                              child: SingleChildScrollView(
                                padding: EdgeInsets.all(isMobile ? 16 : 24),
                                child: gameState == null
                                    ? _buildNoDataView(isMobile)
                                    : _buildGameStateContent(gameState, isMobile),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar(bool isMobile) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.shade600,
            Colors.red.shade700,
            Colors.red.shade800,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
          // Enhanced Logo
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'RHBL',
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Live Scoring',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.game.teamAName} vs ${widget.game.teamBName}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.2 + 0.1 * _pulseController.value),
                      Colors.white.withOpacity(0.1 + 0.1 * _pulseController.value),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.5),
                            blurRadius: 4 + 2 * _pulseController.value,
                            spreadRadius: 1 + _pulseController.value,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: const Center(
        child: RHBLLoader(size: 80, showBackground: false),
      ),
    );
  }

  Widget _buildErrorView(String error, bool isMobile) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.red.shade900.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade700, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Fehler beim Laden der Live-Daten',
              style: TextStyle(
                fontSize: 18,
                color: Colors.red.shade300,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataView(bool isMobile) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.grey.shade800.withOpacity(0.3),
              Colors.grey.shade900.withOpacity(0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_empty, size: 64, color: Colors.white.withOpacity(0.6)),
            const SizedBox(height: 20),
            Text(
              'Warte auf Live-Daten...',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Spiel: ${widget.game.teamAName} vs ${widget.game.teamBName}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameStateContent(GameState gameState, bool isMobile) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Game Time and Status
          _buildTimeSection(gameState, isMobile),
          const SizedBox(height: 20),
          
          // Current Score
          _buildCurrentScoreSection(gameState, isMobile),
          const SizedBox(height: 20),
          
          // Recent Events
          _buildRecentEventsSection(gameState, isMobile),
        ],
      ),
    );
  }

  Widget _buildTimeSection(GameState gameState, bool isMobile) {
    // Determine the current set/period display
    String periodText;
    if (gameState.gameTime.isFullTime && gameState.teamAScore == gameState.teamBScore) {
      periodText = 'Shootout';
    } else {
      periodText = 'Halbzeit ${gameState.currentHalf}';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade800.withOpacity(0.3),
            Colors.grey.shade900.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Top row: Home team - Time with status - Guest team
          Row(
            children: [
              // Home team (left)
              Expanded(
                child: Text(
                  widget.game.teamAName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.left,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              // Center: Time with status indicator
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      gameState.gameTime.displayTime,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: gameState.isRunning ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (gameState.isRunning ? Colors.green : Colors.red).withOpacity(0.6),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Guest team (right)
              Expanded(
                child: Text(
                  widget.game.teamBName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Bottom: Period/Set indicator
          Text(
            periodText,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.7),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentScoreSection(GameState gameState, bool isMobile) {
    if (widget.game.teamAId == null || widget.game.teamBId == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.grey.shade700.withOpacity(0.3),
              Colors.grey.shade900.withOpacity(0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Text(
          'Team-IDs nicht verfÃƒÂ¼gbar fÃƒÂ¼r Anzeigetafel',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 16,
          ),
        ),
      );
    }

    final teamAScore = gameState.getTeamScore(widget.game.teamAId!);
    final teamBScore = gameState.getTeamScore(widget.game.teamBId!);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade600.withOpacity(0.2),
            Colors.blue.shade800.withOpacity(0.1),
            Colors.purple.shade800.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade400.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 25,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Text(
              'Aktuelle Halbzeit ${gameState.currentHalf}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Text(
                        widget.game.teamAName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                      ),
                      child: Center(
                        child: Text(
                          '$teamAScore',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Text(
                        widget.game.teamBName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                      ),
                      child: Center(
                        child: Text(
                          '$teamBScore',
                          style: const TextStyle(
                            fontSize: 36,
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
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Text(
              'Ergebnis: ${gameState.teamAScore} - ${gameState.teamBScore}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.9),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentEventsSection(GameState gameState, bool isMobile) {
    final recentEvents = gameState.events.reversed.take(10).toList();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.shade600.withOpacity(0.2),
            Colors.orange.shade800.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade400.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade400, Colors.orange.shade600],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.event_note, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Letzte Ereignisse',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${recentEvents.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentEvents.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.white.withOpacity(0.6),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Noch keine Ereignisse',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            ...recentEvents.map((event) => TimelineTile(
              alignment: TimelineAlign.center,
              isFirst: recentEvents.indexOf(event) == 0,
              isLast: recentEvents.indexOf(event) == recentEvents.length - 1,
              lineXY: 0.2, // Reduces the vertical gap between timeline dots
              indicatorStyle: IndicatorStyle(
                width: 45,
                height: 20,
                padding: const EdgeInsets.symmetric(vertical: 2), // Reduces padding around the indicator
                indicator: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    ),
                  child: Center(
                    child: Text(
                      '${event.gameMinute}:00',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              beforeLineStyle: LineStyle(
                color: Colors.white.withOpacity(0.3),
                thickness: 1,
              ),
              afterLineStyle: LineStyle(
                color: Colors.white.withOpacity(0.3),
                thickness: 1,
                          ),
              startChild: event.teamId == widget.game.teamAId ? _buildEventTile(event, true) : null,
              endChild: event.teamId == widget.game.teamBId ? _buildEventTile(event, false) : null,
            )).toList(),
                      ],
                    ),
    );
  }

  Widget _buildEventTile(GameEvent event, bool isHomeTeam) {
    return Container(
      margin: EdgeInsets.only(
        left: isHomeTeam ? 0 : 16,
        right: isHomeTeam ? 16 : 0,
        bottom: 2,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
            _getEventColor(event.eventType).withOpacity(0.3),
            _getEventColor(event.eventType).withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getEventIconColor(event.eventType).withOpacity(0.4),
          width: 1,
        ),
                    ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: isHomeTeam ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isHomeTeam) ...[
                Icon(
                  _getEventIcon(event.eventType),
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                event.playerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                  fontSize: 13,
                    ),
                  ),
              if (isHomeTeam) ...[
                const SizedBox(width: 6),
                Icon(
                  _getEventIcon(event.eventType),
                  size: 14,
                  color: Colors.white,
                ),
              ],
                ],
              ),
          const SizedBox(height: 2),
          Text(
            event.displayName,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Color _getEventColor(GameEventType eventType) {
    switch (eventType) {
      case GameEventType.goal:
      case GameEventType.sevenMeterHit:
        return Colors.green.shade600;
      case GameEventType.yellowCard:
        return Colors.yellow.shade700;
      case GameEventType.twoMinuteSuspension:
        return Colors.orange.shade600;
      case GameEventType.redCard:
        return Colors.red.shade600;
      case GameEventType.blueCard:
        return Colors.blue.shade800;
      case GameEventType.sevenMeterMiss:
        return Colors.grey.shade600;
      default:
        return Colors.blue.shade600;
    }
  }

  IconData _getEventIcon(GameEventType eventType) {
    switch (eventType) {
      case GameEventType.goal:
        return Icons.sports_handball;
      case GameEventType.sevenMeterHit:
        return Icons.my_location;
      case GameEventType.sevenMeterMiss:
        return Icons.location_off;
      case GameEventType.yellowCard:
        return Icons.square;
      case GameEventType.twoMinuteSuspension:
        return Icons.access_time;
      case GameEventType.redCard:
        return Icons.block;
      case GameEventType.blueCard:
        return Icons.report;
      case GameEventType.timeout:
        return Icons.pause;
      case GameEventType.substitution:
        return Icons.swap_horiz;
    }
  }

  Color _getEventIconColor(GameEventType eventType) {
    switch (eventType) {
      case GameEventType.goal:
      case GameEventType.sevenMeterHit:
        return Colors.green;
      case GameEventType.yellowCard:
        return Colors.yellow.shade700;
      case GameEventType.twoMinuteSuspension:
        return Colors.orange;
      case GameEventType.redCard:
        return Colors.red;
      case GameEventType.blueCard:
        return Colors.blue.shade800;
      case GameEventType.sevenMeterMiss:
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }
}

/// Helper class for team ranking calculations.
class _TeamStats {
  final String id;
  final String name;
  int played = 0;
  int wins = 0;
  int draws = 0;
  int losses = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;
  bool needsTiebreaker = false; // true if Entscheidungsspiel needed

  _TeamStats({required this.id, required this.name});

  int get goalDiff => goalsFor - goalsAgainst;
  int get points => wins * 2 + draws;
} 