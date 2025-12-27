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
import '../widgets/responsive_layout.dart';
import '../utils/responsive_helper.dart';
import '../widgets/gbo_loader.dart';
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
  bool _isPreloading = true;
  
  @override
  void initState() {
    super.initState();
    // Set initial selected result tab to first category if available
    selectedResultTab = widget.tournament.categories.isNotEmpty 
        ? widget.tournament.categories.first 
        : 'Alle';
    
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
    // Dispose all animation controllers
    for (final controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
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
        for (final division in widget.tournament.results!.entries) {
          _cachedResultsData!.addAll(List<Map<String, dynamic>>.from(division.value));
        }
      }
      
      // Preload games data
      try {
        final gamesSnapshot = await FirebaseFirestore.instance
            .collection('games')
            .where('tournamentId', isEqualTo: widget.tournament.id)
            .get();
        
        _cachedGames = gamesSnapshot.docs
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return Game.fromJson(data);
            })
            .toList();
      } catch (e) {
        print('Error preloading games: $e');
        _cachedGames = [];
      }
      
      if (mounted) {
        setState(() {
          _isPreloading = false;
        });
      }
    } catch (e) {
      print('Error preloading tournament data: $e');
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
      print('Error checking admin status: $e');
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
          _buildMatchesSection(),
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
                            Icons.sports_volleyball,
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
                        Icons.sports_volleyball,
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
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${widget.tournament.points} Punkte',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
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
    
    print('Detail screen: Tournament has ${widget.tournament.links.length} total links, ${agbLinks.length} AGBs, ${socialLinks.length} social');
    
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
              ? const Text('Keine Links verfügbar')
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
              child: const Text('Schließen'),
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
                              Icons.sports_volleyball,
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
                          Icons.sports_volleyball,
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
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${widget.tournament.points}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Punkte',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
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
                      'Noch keine Spiele für dieses Turnier erstellt.',
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
        
        // Game Type and Court Info
        const SizedBox(height: 8),
        Row(
          children: [
            if (game.courtId != null) ...[
              Icon(Icons.sports_tennis, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                'Court ${game.courtId}',
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
                  'Court ${game.courtId}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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

  Future<List<Game>> _getGamesWithActiveScoringTablets(List<Game> allGames) async {
    List<Game> gamesWithActiveScoring = [];
    
    print('🎯 Checking ${allGames.length} games for active scoring tablets...');
    
    for (final game in allGames) {
      try {
        // First priority: Games that are currently in progress
        if (game.status == GameStatus.inProgress) {
          print('✅ Game ${game.id.substring(game.id.length - 8)} is in progress - adding to live scoring');
          gamesWithActiveScoring.add(game);
          continue;
        }
        
        // Second priority: Check if there's recent GameState activity (within last 10 minutes)
        final gameStateDoc = await FirebaseFirestore.instance
            .collection('gameStates')
            .doc(game.id)
            .get();
        
        if (gameStateDoc.exists) {
          print('📋 Found gameState for ${game.id.substring(game.id.length - 8)}');
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
            print('⏰ Game ${game.id.substring(game.id.length - 8)} last updated ${timeDiff} minutes ago');
            
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
                print('📝 Game ${game.id.substring(game.id.length - 8)} has ${eventsSnapshot.docs.length} events');
              }
            } catch (e) {
              print('❌ Error checking events for ${game.id.substring(game.id.length - 8)}: $e');
            }
          }
          
          if (hasActivity) {
            print('✅ Game ${game.id.substring(game.id.length - 8)} has activity ($activityReason) - adding to live scoring');
            gamesWithActiveScoring.add(game);
          } else {
            print('⚠️ Game ${game.id.substring(game.id.length - 8)} has gameState but no detectable activity');
          }
        } else {
          print('❌ No gameState found for ${game.id.substring(game.id.length - 8)}');
        }
      } catch (e) {
        // Skip games with errors
        print('❌ Error checking game state for ${game.id.substring(game.id.length - 8)}: $e');
      }
    }
    
    print('🎯 Found ${gamesWithActiveScoring.length} games with active scoring tablets');
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
                 '${gameState.getCurrentSetScore(game.teamAId!)}',
                 style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
               ),
               const Text(' - ', style: TextStyle(fontSize: 16)),
               Text(
                 '${gameState.getCurrentSetScore(game.teamBId!)}',
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
        
        // Set wins
        if (gameState != null) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Sätze: ${gameState.teamASetWins} - ${gameState.teamBSetWins}',
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
                   '${gameState.getCurrentSetScore(game.teamAId!)} - ${gameState.getCurrentSetScore(game.teamBId!)}',
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
        
        // Set wins
        Container(
          width: 60,
          child: gameState != null
              ? Text(
                  '${gameState.teamASetWins}-${gameState.teamBSetWins}',
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
            'Ergebnisse',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 20),
          
          // Dynamic category tabs from tournament.categories
          if (widget.tournament.categories.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Keine Kategorien definiert',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ),
            )
          else if (isMobile)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: widget.tournament.categories.asMap().entries.map((entry) {
                  final index = entry.key;
                  final category = entry.value;
                  final isSelected = selectedResultTab == category;
                  return Row(
                    children: [
                      _buildResultTab(category, isSelected, () {
                        setState(() => selectedResultTab = category);
                      }),
                      if (index < widget.tournament.categories.length - 1) 
                        const SizedBox(width: 12),
                    ],
                  );
                }).toList(),
              ),
            )
          else
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: widget.tournament.categories.map((category) {
                final isSelected = selectedResultTab == category;
                return _buildResultTab(category, isSelected, () {
                  setState(() => selectedResultTab = category);
                });
              }).toList(),
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
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(top: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Text(
            'Team-Rankings für $selectedResultTab werden geladen...',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        );
      case 'Gruppenphase':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(top: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Text(
            'Gruppenphase-Ergebnisse für $selectedResultTab werden geladen...',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        );
      case 'Final & Platzierungsrunde':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(top: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Text(
            'Finales und Platzierungsspiele für $selectedResultTab werden geladen...',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        );
      case 'Spielerstatistiken':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(top: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Text(
            'Spielerstatistiken für $selectedResultTab werden geladen...',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        );
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

  Widget _buildCriteriaSection() {
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
          Row(
            children: [
              const Text(
                'Turnier-Kriterien',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (widget.tournament.criteria != null) ...[  
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.tournament.criteria!.totalPoints} Punkte',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: isMobile ? 16 : 20),
          
          if (widget.tournament.criteria == null) ...[  
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Keine Kriterien für dieses Turnier definiert',
                      style: TextStyle(fontSize: 13, color: Colors.orange.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[  
            _buildExpandableSection('Grundlegende Regeln (MUST)', Icons.keyboard_arrow_down, 'criteria_must'),
            SizedBox(height: isMobile ? 6 : 8),
            _buildExpandableSection('Schiedsrichter', Icons.keyboard_arrow_down, 'criteria_referees'),
            SizedBox(height: isMobile ? 6 : 8),
            _buildExpandableSection('Offizielle & Delegate', Icons.keyboard_arrow_down, 'criteria_officials'),
            SizedBox(height: isMobile ? 6 : 8),
            _buildExpandableSection('Infrastruktur & Services', Icons.keyboard_arrow_down, 'criteria_infrastructure'),
          ],
        ],
      ),
    );
  }

  Widget _buildCriteriaContentByCategory(String category) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveHelper.isMobile(screenWidth);
    final criteria = widget.tournament.criteria!;
    
    List<({String name, int? points, bool isActive})> criteriaList = [];
    
    switch (category) {
      case 'criteria_must':
        criteriaList = [
          (name: 'Offizielle Beachhandball-Regeln', points: 30, isActive: criteria.officialBeachhandballRules),
          (name: 'Zwei Schiedsrichter pro Spiel', points: 30, isActive: criteria.twoRefereesPerGame),
          (name: 'Clean Zone', points: 30, isActive: criteria.cleanZone),
          (name: 'Ausspielen Platz 1-8', points: 30, isActive: criteria.ausspielenPlatz1To8),
        ];
        break;
      case 'criteria_referees':
        criteriaList = [
          (name: 'EHF Kader Schiedsrichter', points: 25, isActive: criteria.ehfKaderReferees > 0),
          (name: 'DHB Elite Kader', points: 20, isActive: criteria.dhbEliteKaderReferees > 0),
          (name: 'DHB Stammkader', points: 15, isActive: criteria.dhbStammKaderReferees > 0),
          (name: 'Perspektiv Kader', points: 10, isActive: criteria.perspektivKaderReferees > 0),
          (name: 'Basis Lizenz Schiedsrichter', points: 5, isActive: criteria.basisLizenzReferees > 0),
        ];
        break;
      case 'criteria_officials':
        criteriaList = [
          (name: 'EBT Delegate', points: 100, isActive: criteria.ebtDelegate),
          (name: 'DHB National Delegate', points: 80, isActive: criteria.dhbNationalDelegate),
        ];
        break;
      case 'criteria_infrastructure':
        criteriaList = [
          (name: 'Technisches Treffen', points: 20, isActive: criteria.technicalMeeting),
          (name: 'Fangnetzausstattung & Zäune', points: 30, isActive: criteria.fangneatzeZaeune),
          (name: 'Sanitäterdienst', points: 20, isActive: criteria.sanitaeterdienst),
          (name: 'Sitztribüne', points: 60, isActive: criteria.sitztribuene),
          (name: 'Spielfeldumrandung', points: 30, isActive: criteria.spielfeldumrandung),
          (name: 'Alle Beachplätze offizielle Maße', points: 20, isActive: criteria.alleBeachplaetzeOffiziellesMasse),
          (name: 'GBO Online Schedule', points: 100, isActive: criteria.gboOnlineSchedule),
          (name: 'GBO Scoring System', points: 50, isActive: criteria.gboScoringSystem),
          (name: 'Elektronische Anzeigetafeln', points: 40, isActive: criteria.elektronischeAnzeigetafeln),
          (name: 'Zeitnehmer gestellt', points: 20, isActive: criteria.zeitnehmerGestellt),
          (name: 'GBO Juniors Cup', points: 30, isActive: criteria.gboJuniorsCup),
          (name: 'Wasser für Spieler', points: 20, isActive: criteria.waterForPlayers),
          (name: 'Arena-Kommentator', points: 20, isActive: criteria.arenaCommentator),
          (name: 'Turnierauszeichnungen', points: 20, isActive: criteria.tournierauszeichnungen),
          (name: 'Turnier im Stadtzentrum', points: 250, isActive: criteria.tournamentInTownCenter),
        ];
        break;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: criteriaList.map((item) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 10),
          child: Container(
            padding: EdgeInsets.all(isMobile ? 12 : 14),
            decoration: BoxDecoration(
              color: item.isActive 
                ? Colors.green.withValues(alpha: 0.08)
                : Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: item.isActive 
                  ? Colors.green.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: item.isActive ? Colors.green : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    item.isActive ? Icons.check : Icons.close,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: isMobile ? 12 : 14),
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      fontWeight: FontWeight.w500,
                      color: item.isActive 
                        ? Colors.green.shade700
                        : Colors.grey.shade600,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.isActive 
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${item.points}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: item.isActive 
                        ? Colors.green.shade700
                        : Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOrganizationSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveHelper.isMobile(screenWidth);
    
    // Get current user
    final currentUser = FirebaseAuth.instance.currentUser;
    
    // If tournament has an assigned organizer, show that instead
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
    
    if (currentUser == null) {
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
            Row(
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
                        'Nicht angemeldet',
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 15,
                          fontWeight: FontWeight.w600,
                        ),
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
    
    // Fetch current user's data from Firestore
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
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
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        if (!snapshot.hasData || !snapshot.data!.exists) {
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
                Row(
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
                            currentUser.email ?? 'Benutzer',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 15,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
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
        
        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        final firstName = userData?['firstName'] ?? '';
        final lastName = userData?['lastName'] ?? '';
        final displayName = firstName.isNotEmpty || lastName.isNotEmpty 
            ? '$firstName $lastName'.trim() 
            : (userData?['displayName'] ?? currentUser.email ?? 'Benutzer');
        final profilePicture = userData?['profilePicture'];
        final email = userData?['email'] ?? currentUser.email ?? '';
        
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
              Row(
                children: [
                  // Profile Picture
                  Container(
                    width: isMobile ? 36 : 40,
                    height: isMobile ? 36 : 40,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(isMobile ? 18 : 20),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(isMobile ? 18 : 20),
                      child: profilePicture != null && profilePicture.isNotEmpty
                          ? Image.network(
                              profilePicture,
                              width: isMobile ? 36 : 40,
                              height: isMobile ? 36 : 40,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Text(
                                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: isMobile ? 14 : 16,
                                    ),
                                  ),
                                );
                              },
                            )
                          : Center(
                              child: Text(
                                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isMobile ? 14 : 16,
                                ),
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
                          'Turnierorganisation',
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 13,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 15,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 16 : 20),
              Row(
                children: [
                  Icon(Icons.email, size: isMobile ? 18 : 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      email,
                      style: TextStyle(fontSize: isMobile ? 13 : 14),
                      overflow: TextOverflow.ellipsis,
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
                'GBO',
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
        child: GBOLoader(size: 80, showBackground: false),
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
          
          // Set History
          if (gameState.setScores.isNotEmpty) ...[
            _buildSetHistorySection(gameState, isMobile),
            const SizedBox(height: 20),
          ],
          
          // Recent Events
          _buildRecentEventsSection(gameState, isMobile),
        ],
      ),
    );
  }

  Widget _buildTimeSection(GameState gameState, bool isMobile) {
    // Determine the current set/period display
    String periodText;
    if (gameState.gameTime.isFullTime && gameState.teamASetWins == gameState.teamBSetWins) {
      periodText = 'Shootout';
    } else {
      periodText = 'Satz ${gameState.currentSet}';
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
          'Team-IDs nicht verfügbar für Anzeigetafel',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 16,
          ),
        ),
      );
    }

    final teamAScore = gameState.getCurrentSetScore(widget.game.teamAId!);
    final teamBScore = gameState.getCurrentSetScore(widget.game.teamBId!);

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
              'Aktueller Satz ${gameState.currentSet}',
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
              'Sätze: ${gameState.teamASetWins} - ${gameState.teamBSetWins}',
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

  Widget _buildSetHistorySection(GameState gameState, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.shade600.withOpacity(0.2),
            Colors.purple.shade800.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.shade400.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.1),
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
                    colors: [Colors.purple.shade400, Colors.purple.shade600],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.history, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Satz-Historie',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...gameState.setScores.map((setScore) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple.shade300, Colors.purple.shade500],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${setScore.setNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Satz ${setScore.setNumber}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${setScore.teamAScore} - ${setScore.teamBScore}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (setScore.isCompleted) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade400, Colors.green.shade600],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 14),
                  ),
                ],
              ],
            ),
          )).toList(),
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
      case GameEventType.onePoint:
      case GameEventType.twoPoints:
      case GameEventType.sixMeterHit:
        return Colors.green.shade600;
      case GameEventType.suspension:
        return Colors.orange.shade600;
      case GameEventType.redCard:
        return Colors.red.shade600;
      case GameEventType.sixMeterMiss:
        return Colors.grey.shade600;
      default:
        return Colors.blue.shade600;
    }
  }

  IconData _getEventIcon(GameEventType eventType) {
    switch (eventType) {
      case GameEventType.onePoint:
      case GameEventType.twoPoints:
        return Icons.sports_volleyball;
      case GameEventType.suspension:
        return Icons.warning;
      case GameEventType.redCard:
        return Icons.block;
      case GameEventType.timeout:
        return Icons.pause;
      case GameEventType.substitution:
        return Icons.swap_horiz;
      case GameEventType.sixMeterHit:
        return Icons.my_location;
      case GameEventType.sixMeterMiss:
        return Icons.location_off;
    }
  }

  Color _getEventIconColor(GameEventType eventType) {
    switch (eventType) {
      case GameEventType.onePoint:
      case GameEventType.twoPoints:
      case GameEventType.sixMeterHit:
        return Colors.green;
      case GameEventType.suspension:
        return Colors.orange;
      case GameEventType.redCard:
        return Colors.red;
      case GameEventType.sixMeterMiss:
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }
} 