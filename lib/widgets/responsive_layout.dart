import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/responsive_helper.dart';
import 'side_navigation.dart';
import '../services/team_manager_service.dart';
import '../services/tournament_service.dart';
import '../models/team.dart';
import '../models/tournament.dart';
import '../models/user.dart' as app_user;
import '../models/referee.dart';
import '../services/referee_service.dart';

class ResponsiveLayout extends StatefulWidget {
  final String selectedSection;
  final Function(String) onSectionChanged;
  final String title;
  final Widget body;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final app_user.User? currentUser;

  const ResponsiveLayout({
    super.key,
    required this.selectedSection,
    required this.onSectionChanged,
    required this.title,
    required this.body,
    this.showBackButton = false,
    this.onBackPressed,
    this.currentUser,
  });

  @override
  State<ResponsiveLayout> createState() => _ResponsiveLayoutState();
}

class _ResponsiveLayoutState extends State<ResponsiveLayout> {
  User? _currentUser;
  final TeamManagerService _teamManagerService = TeamManagerService();
  final TournamentService _tournamentService = TournamentService();
  final RefereeService _refereeService = RefereeService();
  List<Team> _managedTeams = [];
  bool _isTeamManager = false;
  bool _isLoadingTeams = false;
  List<Tournament> _refereeTournaments = [];
  bool _isLoadingTournaments = false;
  Referee? _refereeProfile;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    
    // Listen to auth state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
        _loadTeamManagerData();
        _loadRefereeProfile();
      }
    });
    
    _loadTeamManagerData();
    _loadRefereeProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadTeamManagerData();
    _loadRefereeProfile();
  }

  @override
  void didUpdateWidget(ResponsiveLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if currentUser changed
    if (oldWidget.currentUser != widget.currentUser) {
      print('🔄 Responsive: currentUser changed, reloading referee profile');
      _loadRefereeProfile();
    }
  }

  Future<void> _loadRefereeProfile() async {
    // Only try to load if currentUser is available
    if (widget.currentUser == null) {
      print('⏳ Responsive: currentUser is null, waiting...');
      setState(() {
        _refereeProfile = null;
        _refereeTournaments = [];
      });
      return;
    }

    if (widget.currentUser!.role == app_user.UserRole.referee && widget.currentUser!.refereeId != null) {
      try {
        print('📝 Responsive: Loading referee profile for ID: ${widget.currentUser!.refereeId}');
        _refereeProfile = await _refereeService.getRefereeById(widget.currentUser!.refereeId!);
        if (_refereeProfile != null) {
          print('✅ Responsive: Referee profile loaded: ${_refereeProfile!.fullName}');
          await _loadRefereeTournaments();
        } else {
          print('❌ Responsive: Referee profile not found');
          setState(() {
            _refereeProfile = null;
            _refereeTournaments = [];
          });
        }
      } catch (e) {
        print('❌ Responsive: Error loading referee profile: $e');
        setState(() {
          _refereeProfile = null;
          _refereeTournaments = [];
        });
      }
    } else {
      print('ℹ️ Responsive: User is not a referee (role: ${widget.currentUser!.role}, refereeId: ${widget.currentUser!.refereeId})');
      setState(() {
        _refereeProfile = null;
        _refereeTournaments = [];
      });
    }
  }

  Future<void> _loadRefereeTournaments() async {
    if (_refereeProfile == null) return;

    setState(() {
      _isLoadingTournaments = true;
    });

    try {
      print('🔄 Responsive: Loading tournaments for referee: ${_refereeProfile!.fullName}');
      final tournamentsStream = _tournamentService.getAcceptedTournamentsForReferee(_refereeProfile!.id);
      final tournaments = await tournamentsStream.first;
      
      print('✅ Responsive: Loaded ${tournaments.length} tournaments');
      setState(() {
        _refereeTournaments = tournaments;
        _isLoadingTournaments = false;
      });
    } catch (e) {
      print('❌ Responsive: Error loading tournaments: $e');
      setState(() {
        _refereeTournaments = [];
        _isLoadingTournaments = false;
      });
    }
  }

  Future<void> _loadTeamManagerData() async {
    if (_currentUser == null) {
      setState(() {
        _isTeamManager = false;
        _managedTeams = [];
      });
      return;
    }

    setState(() {
      _isLoadingTeams = true;
    });

    try {
      // Check if current user is a team manager (either through role or existing system)
      bool isManager = false;
      
      // First check if currentUser has teamManager role
      if (widget.currentUser?.role == app_user.UserRole.teamManager) {
        isManager = true;
      } else {
        // Fallback to old system check
        isManager = await _teamManagerService.isUserTeamManager(_currentUser!.uid);
      }
      
      // Debug: Check if team manager exists by email and try to link if needed
      final teamManagerByEmail = await _teamManagerService.getTeamManagerByEmail(_currentUser!.email ?? '');
      print('Team manager by email: ${teamManagerByEmail?.name}');
      
      // If team manager exists by email but not linked, try to link
      if (teamManagerByEmail != null && teamManagerByEmail.userId == null) {
        print('Attempting to link user to team manager...');
        final linked = await _teamManagerService.linkUserToTeamManager(_currentUser!.email!, _currentUser!.uid);
        print('Link successful: $linked');
        if (linked) isManager = true;
      }
      
      print('Is user team manager: $isManager');
      
      if (isManager) {
        final teams = await _teamManagerService.getTeamsManagedByUser(_currentUser!.uid);
        print('Managed teams: ${teams.length}');
        setState(() {
          _isTeamManager = true;
          _managedTeams = teams;
        });
      } else {
        setState(() {
          _isTeamManager = false;
          _managedTeams = [];
        });
      }
    } catch (e) {
      print('Error loading team manager data: $e');
      setState(() {
        _isTeamManager = false;
        _managedTeams = [];
      });
    } finally {
      setState(() {
        _isLoadingTeams = false;
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        
        if (ResponsiveHelper.shouldUseDrawer(screenWidth)) {
          // Mobile layout with drawer
          return Scaffold(
            appBar: AppBar(
              title: Text(
                widget.title,
                style: TextStyle(
                  fontSize: 18 * ResponsiveHelper.getFontScale(screenWidth),
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 1,
              leading: widget.showBackButton 
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: widget.onBackPressed ?? () => Navigator.of(context).pop(),
                    tooltip: 'Zurück',
                  )
                : Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      tooltip: 'Menü öffnen',
                    ),
                  ),
              actions: widget.showBackButton 
                ? [
                    Builder(
                      builder: (context) => IconButton(
                        icon: const Icon(Icons.menu),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                        tooltip: 'Menü öffnen',
                      ),
                    ),
                  ]
                : null,
            ),
            drawer: _buildNavigationDrawer(screenWidth),
            body: Container(
              color: Colors.grey[100],
              child: Padding(
                padding: EdgeInsets.all(ResponsiveHelper.getContentPadding(screenWidth)),
                child: widget.body,
              ),
            ),
          );
        } else {
          // Desktop/Tablet layout with side navigation
          return Scaffold(
            body: Row(
              children: [
                SideNavigation(
                  selectedSection: widget.selectedSection,
                  onSectionChanged: widget.onSectionChanged,
                ),
                Expanded(
                  child: Container(
                    color: Colors.grey[100],
                    child: Column(
                      children: [
                        if (widget.showBackButton)
                          Container(
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
                                IconButton(
                                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                                  onPressed: widget.onBackPressed ?? () => Navigator.of(context).pop(),
                                  tooltip: 'Zurück',
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    widget.title,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(ResponsiveHelper.getContentPadding(screenWidth)),
                            child: widget.body,
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
      },
    );
  }

  Widget _buildNavigationDrawer(double screenWidth) {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Header
            Container(
              height: 190,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 10),
              decoration: BoxDecoration(
                color: const Color(0xFFffd665),
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'logo.png',
                    height: 119,
                    width: 190,
                  ),
                ],
              ),
            ),
            // Navigation Menu
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // User Profile or Login
                  _currentUser != null ? _buildDrawerUserProfile(screenWidth) : _buildDrawerItem(
                    icon: Icons.person,
                    title: 'Login',
                    key: 'login',
                    isSelected: widget.selectedSection == 'login',
                    screenWidth: screenWidth,
                  ),
                  _buildDrawerItem(
                    icon: Icons.sports_volleyball,
                    title: 'Turniere',
                    key: 'turniere',
                    isSelected: widget.selectedSection == 'turniere',
                    screenWidth: screenWidth,
                  ),
                  _buildDrawerItem(
                    icon: Icons.leaderboard,
                    title: 'Rangliste',
                    key: 'rangliste',
                    isSelected: widget.selectedSection == 'rangliste',
                    screenWidth: screenWidth,
                  ),
                  
                  // Team Manager Section
                  if (_isTeamManager && _managedTeams.isNotEmpty) ...[
                    const Divider(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.sports_volleyball,
                            color: const Color(0xFF2D5016),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'MEINE TEAMS',
                            style: TextStyle(
                              color: const Color(0xFF2D5016),
                              fontSize: 12 * ResponsiveHelper.getFontScale(screenWidth),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                          if (_isLoadingTeams) ...[
                            const Spacer(),
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2D5016)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    ...(_managedTeams.map((team) => [
                      _buildDrawerTeamItem(
                        team: team,
                        key: 'team_${team.id}',
                        isSelected: widget.selectedSection.startsWith('team_${team.id}'),
                        screenWidth: screenWidth,
                      ),
                      // Sub-items always visible
                      _buildDrawerTeamSubItem(
                        title: 'Übersicht',
                        key: 'team_${team.id}_overview',
                        icon: Icons.dashboard,
                        isSelected: widget.selectedSection == 'team_${team.id}_overview' || widget.selectedSection == 'team_${team.id}',
                        screenWidth: screenWidth,
                      ),
                      _buildDrawerTeamSubItem(
                        title: 'Turnier Anmeldung',
                        key: 'team_${team.id}_tournaments',
                        icon: Icons.sports_volleyball,
                        isSelected: widget.selectedSection == 'team_${team.id}_tournaments',
                        screenWidth: screenWidth,
                      ),
                      _buildDrawerTeamSubItem(
                        title: 'Kader Verwaltung',
                        key: 'team_${team.id}_roster',
                        icon: Icons.people,
                        isSelected: widget.selectedSection == 'team_${team.id}_roster',
                        screenWidth: screenWidth,
                      ),
                      _buildDrawerTeamSubItem(
                        title: 'Einstellungen',
                        key: 'team_${team.id}_settings',
                        icon: Icons.settings,
                        isSelected: widget.selectedSection == 'team_${team.id}_settings',
                        screenWidth: screenWidth,
                      ),
                    ]).expand((x) => x)),
                  ],
                  
                  // Referee Section (only show for referees with loaded profile)
                  if (widget.currentUser?.role == app_user.UserRole.referee && widget.currentUser?.refereeId != null && _refereeProfile != null) ...[
                    const Divider(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.sports_hockey,
                            color: Colors.orange.shade600,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'SCHIEDSRICHTER',
                            style: TextStyle(
                              color: Colors.orange.shade600,
                              fontSize: 12 * ResponsiveHelper.getFontScale(screenWidth),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildDrawerItem(
                      icon: Icons.dashboard,
                      title: 'Dashboard',
                      key: 'referee_dashboard',
                      isSelected: widget.selectedSection == 'referee_dashboard',
                      screenWidth: screenWidth,
                      isReferee: true,
                    ),
                    // Tournament Items
                    if (_isLoadingTournaments)
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Spacer(),
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                      )
                    else if (_refereeTournaments.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.grey.shade600, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Keine Turniere',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12 * ResponsiveHelper.getFontScale(screenWidth),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        children: _refereeTournaments.map((tournament) => [
                          _buildDrawerRefereeTournamentItem(
                            tournament: tournament,
                            key: 'referee_tournament_${tournament.id}',
                            isSelected: widget.selectedSection.startsWith('referee_tournament_${tournament.id}'),
                            screenWidth: screenWidth,
                          ),
                          // Sub-items for tournament details
                          _buildDrawerRefereeSubItem(
                            title: 'Übersicht',
                            key: 'referee_tournament_${tournament.id}_overview',
                            icon: Icons.info_outline,
                            isSelected: widget.selectedSection == 'referee_tournament_${tournament.id}_overview' || widget.selectedSection == 'referee_tournament_${tournament.id}',
                            screenWidth: screenWidth,
                          ),
                          _buildDrawerRefereeSubItem(
                            title: 'Spielplan',
                            key: 'referee_tournament_${tournament.id}_schedule',
                            icon: Icons.schedule,
                            isSelected: widget.selectedSection == 'referee_tournament_${tournament.id}_schedule',
                            screenWidth: screenWidth,
                          ),
                        ]).expand((x) => x).toList(),
                      ),
                  ],
                  
                  const Divider(height: 32),
                  
                  // Admin Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'ADMIN BEREICH',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12 * ResponsiveHelper.getFontScale(screenWidth),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  if (defaultTargetPlatform != TargetPlatform.iOS)
                    _buildDrawerItem(
                      icon: Icons.architecture,
                      title: 'Preset Verwaltung',
                      key: 'preset_management',
                      isSelected: widget.selectedSection == 'preset_management',
                      screenWidth: screenWidth,
                      isAdmin: true,
                    ),
                  _buildDrawerItem(
                    icon: Icons.settings,
                    title: 'Tournament Management',
                    key: 'tournament_management',
                    isSelected: widget.selectedSection == 'tournament_management',
                    screenWidth: screenWidth,
                    isAdmin: true,
                  ),
                  _buildDrawerItem(
                    icon: Icons.group,
                    title: 'Team Management',
                    key: 'team_management',
                    isSelected: widget.selectedSection == 'team_management',
                    screenWidth: screenWidth,
                    isAdmin: true,
                  ),
                  _buildDrawerItem(
                    icon: Icons.sports_hockey,
                    title: 'Schiedsrichter Verwaltung',
                    key: 'referee_management',
                    isSelected: widget.selectedSection == 'referee_management',
                    screenWidth: screenWidth,
                    isAdmin: true,
                  ),
                  _buildDrawerItem(
                    icon: Icons.person_pin_circle,
                    title: 'Delegierte Verwaltung',
                    key: 'delegate_management',
                    isSelected: widget.selectedSection == 'delegate_management',
                    screenWidth: screenWidth,
                    isAdmin: true,
                  ),
                  _buildDrawerItem(
                    icon: Icons.supervisor_account,
                    title: 'Team Manager Verwaltung',
                    key: 'team_manager_management',
                    isSelected: widget.selectedSection == 'team_manager_management',
                    screenWidth: screenWidth,
                    isAdmin: true,
                  ),
                  _buildDrawerItem(
                    icon: Icons.people,
                    title: 'Kader Verwaltung (Global)',
                    key: 'player_management',
                    isSelected: widget.selectedSection == 'player_management',
                    screenWidth: screenWidth,
                    isAdmin: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

    Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String key,
    required bool isSelected,
    required double screenWidth,
    bool isAdmin = false,
    bool isReferee = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected 
            ? (isAdmin 
                ? const Color(0xFF4A5568).withOpacity(0.2) 
                : isReferee 
                    ? Colors.orange.withOpacity(0.2)
                    : const Color(0xFFffd665).withOpacity(0.2))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Builder(
        builder: (context) => ListTile(
          dense: true,
          leading: Icon(
            icon,
            color: isSelected 
              ? (isAdmin 
                  ? const Color(0xFF4A5568) 
                  : isReferee 
                      ? Colors.orange.shade600
                      : Colors.black87)
              : (isAdmin 
                  ? const Color(0xFF4A5568).withOpacity(0.7) 
                  : isReferee 
                      ? Colors.orange.shade600.withOpacity(0.7)
                      : Colors.grey.shade600),
            size: 20,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: isSelected 
                ? (isAdmin 
                    ? const Color(0xFF4A5568) 
                    : isReferee 
                        ? Colors.orange.shade600
                        : Colors.black87)
                : (isAdmin 
                    ? const Color(0xFF4A5568).withOpacity(0.8) 
                    : isReferee 
                        ? Colors.orange.shade600.withOpacity(0.8)
                        : Colors.black87),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 14 * ResponsiveHelper.getFontScale(screenWidth),
            ),
          ),
          onTap: () {
            widget.onSectionChanged(key);
            Navigator.of(context).pop(); // Close drawer after selection
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
      ),
    );
  }

  Widget _buildDrawerTeamItem({
    required Team team,
    required String key,
    required bool isSelected,
    required double screenWidth,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: isSelected 
            ? const Color(0xFF2D5016).withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Builder(
        builder: (context) => ListTile(
          dense: true,
          leading: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isSelected 
                  ? const Color(0xFF2D5016) 
                  : const Color(0xFF2D5016).withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.group,
              color: isSelected ? Colors.white : const Color(0xFF2D5016),
              size: 14,
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                team.name,
                style: TextStyle(
                  color: isSelected 
                      ? const Color(0xFF2D5016) 
                      : Colors.black87,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13 * ResponsiveHelper.getFontScale(screenWidth),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                team.division,
                style: TextStyle(
                  color: const Color(0xFF2D5016).withOpacity(0.7),
                  fontSize: 11 * ResponsiveHelper.getFontScale(screenWidth),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          onTap: () {
            widget.onSectionChanged('${key}_overview');
            Navigator.of(context).pop();
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        ),
      ),
    );
  }

  Widget _buildDrawerTeamSubItem({
    required String title,
    required String key,
    required IconData icon,
    required bool isSelected,
    required double screenWidth,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      decoration: BoxDecoration(
        color: isSelected 
            ? const Color(0xFF1A3009)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Builder(
        builder: (context) => ListTile(
          dense: true,
          leading: Icon(
            icon,
            color: isSelected ? const Color(0xFFffd665) : const Color(0xFF2D5016).withOpacity(0.6),
            size: 16,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF2D5016),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 12 * ResponsiveHelper.getFontScale(screenWidth),
            ),
          ),
          onTap: () {
            widget.onSectionChanged(key);
            Navigator.of(context).pop(); // Close drawer after selection
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        ),
      ),
    );
  }

  Widget _buildDrawerUserProfile(double screenWidth) {
    if (_currentUser == null) return Container();
    
    final displayName = _currentUser!.displayName ?? 'Benutzer';
    final email = _currentUser!.email ?? '';
    final photoUrl = _currentUser!.photoURL;
    
    // Generate initials from display name
    String getInitials(String name) {
      List<String> nameParts = name.trim().split(' ');
      if (nameParts.length >= 2) {
        return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
      } else if (nameParts.isNotEmpty) {
        return nameParts[0][0].toUpperCase();
      }
      return 'U';
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFffd665).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFffd665).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // User Info Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Profile Picture or Initials
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: photoUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Text(
                                  getInitials(displayName),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : Center(
                          child: Text(
                            getInitials(displayName),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                
                // User Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 14 * ResponsiveHelper.getFontScale(screenWidth),
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 12 * ResponsiveHelper.getFontScale(screenWidth),
                          color: Colors.grey.shade600,
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
          
          // Logout Button
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: TextButton.icon(
              onPressed: () async {
                Navigator.of(context).pop(); // Close drawer first
                await FirebaseAuth.instance.signOut();
                widget.onSectionChanged('turniere'); // Navigate to tournaments after logout
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red.shade600,
                backgroundColor: Colors.red.shade50,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: Icon(Icons.logout, size: 16, color: Colors.red.shade600),
              label: Text(
                'Abmelden',
                style: TextStyle(
                  fontSize: 12 * ResponsiveHelper.getFontScale(screenWidth),
                  fontWeight: FontWeight.w500,
                  color: Colors.red.shade600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerRefereeTournamentItem({
    required Tournament tournament,
    required String key,
    required bool isSelected,
    required double screenWidth,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: isSelected ? Colors.orange.shade700 : Colors.orange.shade600,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.sports_volleyball,
            color: Colors.orange.shade600,
            size: 12,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tournament.name,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13 * ResponsiveHelper.getFontScale(screenWidth),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              tournament.location,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 11 * ResponsiveHelper.getFontScale(screenWidth),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        onTap: () {
          widget.onSectionChanged('${key}_overview');
          Navigator.of(context).pop();
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
    );
  }

  Widget _buildDrawerRefereeSubItem({
    required String title,
    required String key,
    required IconData icon,
    required bool isSelected,
    required double screenWidth,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 1),
      decoration: BoxDecoration(
        color: isSelected ? Colors.orange.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.orange.shade200, width: 0.5),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          color: isSelected ? Colors.orange.shade800 : Colors.orange.shade600,
          size: 14,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.orange.shade800 : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13 * ResponsiveHelper.getFontScale(screenWidth),
          ),
        ),
        onTap: () {
          widget.onSectionChanged(key);
          Navigator.of(context).pop();
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      ),
    );
  }
} 