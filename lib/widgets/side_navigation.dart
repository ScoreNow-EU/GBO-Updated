import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math';
import '../services/team_manager_service.dart';
import '../services/auth_service.dart';
import '../services/tournament_service.dart';
import '../services/managed_account_service.dart';
import '../models/team.dart';
import '../models/tournament.dart';
import '../models/user.dart' as app_user;
import '../models/referee.dart';
import '../services/referee_service.dart';
import '../screens/app_store_splash_screen.dart';

import '../utils/app_colors.dart';
import '../utils/version_helper.dart';

class SideNavigation extends StatefulWidget {
  final String selectedSection;
  final Function(String) onSectionChanged;
  final VoidCallback? onUserUpdated;

  const SideNavigation({
    super.key,
    required this.selectedSection,
    required this.onSectionChanged,
    this.onUserUpdated,
  });

  @override
  State<SideNavigation> createState() => _SideNavigationState();
}

class _SideNavigationState extends State<SideNavigation> {
  User? _currentUser;
  app_user.User? _currentAppUser;
  final TeamManagerService _teamManagerService = TeamManagerService();
  final AuthService _authService = AuthService();
  final TournamentService _tournamentService = TournamentService();
  final RefereeService _refereeService = RefereeService();
  List<Team> _managedTeams = [];
  bool _isTeamManager = false;
  bool _isLoadingTeams = false;
  List<Tournament> _refereeTournaments = [];
  List<Tournament> _organizerTournaments = [];
  bool _isLoadingTournaments = false;
  bool _isLoadingOrganizerTournaments = false;
  Referee? _refereeProfile;
  StreamSubscription<User?>? _authSubscription;
  bool _isAdminExpanded = false;
  String _appVersion = 'Loading...';

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadAppVersion();
    
    // Listen to auth state changes
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
        _loadUserData();
      }
    });
    
    _loadUserData();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    // Load app user data
    if (_currentUser != null) {
      try {
        // Ensure managed accounts have a users doc (self-healing migration)
        await ManagedAccountService().ensureUserDocForCurrentUser(_currentUser!.uid);
        
        final appUser = await _authService.getUserById(_currentUser!.uid);
        if (mounted) {
          setState(() {
            _currentAppUser = appUser;
          });
        }
        await _loadOrganizerTournaments();
      } catch (e) {
        // Error loading app user: $e
        if (mounted) {
          setState(() {
            _currentAppUser = null;
            _refereeProfile = null;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _currentAppUser = null;
          _refereeProfile = null;
        });
      }
    }
    
    // Load team manager data
    await _loadTeamManagerData();
  }

  Future<void> _loadAppVersion() async {
    try {
      final version = await VersionHelper.getAppVersion();
      if (mounted) {
        setState(() {
          _appVersion = version;
        });
      }
    } catch (e) {
              // Error loading app version: $e
      if (mounted) {
        setState(() {
          _appVersion = '0.1.0';
        });
      }
    }
  }

  

  Future<void> _loadOrganizerTournaments() async {
    if (_currentAppUser?.id == null) return;

    if (mounted) {
      setState(() {
        _isLoadingOrganizerTournaments = true;
      });
    }

    try {
      print('🔄 Nav: Loading tournaments for organizer: ${_currentAppUser!.fullName}');
      final allTournaments = await _tournamentService.getTournaments().first;
      final organizerTournaments = allTournaments.where((tournament) => 
        tournament.tournamentOrganizerId == _currentAppUser!.id
      ).toList();
      
      print('✅ Nav: Loaded ${organizerTournaments.length} organizer tournaments');
      if (mounted) {
        setState(() {
          _organizerTournaments = organizerTournaments;
          _isLoadingOrganizerTournaments = false;
        });
      }
    } catch (e) {
      print('❌ Nav: Error loading organizer tournaments: $e');
      if (mounted) {
        setState(() {
          _organizerTournaments = [];
          _isLoadingOrganizerTournaments = false;
        });
      }
    }
  }

  Future<void> _loadTeamManagerData() async {
    if (_currentUser == null) {
      if (mounted) {
        setState(() {
          _isTeamManager = false;
          _managedTeams = [];
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingTeams = true;
      });
    }

    try {
      // Debug: Check if team manager exists by email
      final teamManagerByEmail = await _teamManagerService.getTeamManagerByEmail(_currentUser!.email ?? '');
      print('Team manager by email: ${teamManagerByEmail?.name}');
      
      // If team manager exists by email but not linked, try to link
      if (teamManagerByEmail != null && teamManagerByEmail.userId == null) {
        print('Attempting to link user to team manager...');
        final linked = await _teamManagerService.linkUserToTeamManager(_currentUser!.email!, _currentUser!.uid);
        print('Link successful: $linked');
      }
      
      final isManager = await _teamManagerService.isUserTeamManager(_currentUser!.uid);
      print('Is user team manager: $isManager');
      
      if (isManager) {
        final teams = await _teamManagerService.getTeamsManagedByUser(_currentUser!.uid);
        print('Managed teams: ${teams.length}');
        for (final team in teams) {
          print('Team: ${team.name} - ${team.city}');
        }
        if (mounted) {
          setState(() {
            _isTeamManager = true;
            _managedTeams = teams;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isTeamManager = false;
            _managedTeams = [];
          });
        }
      }
    } catch (e) {
      print('Error loading team manager data: $e');
      if (mounted) {
        setState(() {
          _isTeamManager = false;
          _managedTeams = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTeams = false;
        });
      }
    }
  }



  @override
  Widget build(BuildContext context) {
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
          // Logo Section - RHBL
          Container(
            padding: const EdgeInsets.all(20),
            width: 280,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              gradient: AppColors.primaryGradient,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: Column(
              children: [
                Image.asset(
                  'rhbl_logo.png',
                  height: 120,
                  fit: BoxFit.contain,
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
                _currentUser != null ? _buildUserProfile() : _buildNavigationItem(
                  icon: Icons.person,
                  title: 'Login',
                  key: 'login',
                  isSelected: widget.selectedSection == 'login',
                ),
                _buildNavigationItem(
                  icon: Icons.sports_handball,
                  title: 'Turniere',
                  key: 'turniere',
                  isSelected: widget.selectedSection == 'turniere',
                ),
                _buildNavigationItem(
                  icon: Icons.leaderboard,
                  title: 'Rangliste',
                  key: 'rangliste',
                  isSelected: widget.selectedSection == 'rangliste',
                ),
                
                const SizedBox(height: 16),
                
                // Team Manager Section
                if (_isTeamManager && _managedTeams.isNotEmpty)
                  _buildTeamManagerSection(),
                
                if (_isTeamManager && _managedTeams.isNotEmpty)
                  const SizedBox(height: 16),
                
                // Referee Section - Only show if user is logged in and has referee role with loaded profile
                if (_currentAppUser?.roles.contains(app_user.UserRole.referee) == true && _currentAppUser?.refereeId != null && _refereeProfile != null)
                  _buildRefereeSection(),
                
                if (_currentAppUser?.roles.contains(app_user.UserRole.referee) == true && _currentAppUser?.refereeId != null && _refereeProfile != null)
                  const SizedBox(height: 16),
                
                // Scoring Tablet Section - Show for admin users and scoring tablet managed accounts
                if (_currentAppUser?.roles.contains(app_user.UserRole.admin) == true ||
                    _currentAppUser?.roles.contains(app_user.UserRole.scoringTablet) == true)
                  _buildScoringTabletSection(),
                
                if (_currentAppUser?.roles.contains(app_user.UserRole.admin) == true ||
                    _currentAppUser?.roles.contains(app_user.UserRole.scoringTablet) == true)
                  const SizedBox(height: 16),
                
                // Tournament Organizer Section - Only show if user has tournament organizer role
                if (_currentAppUser?.roles.contains(app_user.UserRole.tournamentOrganizer) == true)
                  _buildTournamentOrganizerSection(),
                
                if (_currentAppUser?.roles.contains(app_user.UserRole.tournamentOrganizer) == true)
                  const SizedBox(height: 16),
                
                // Admin Section - Only show if user has admin role
                if (_currentAppUser?.roles.contains(app_user.UserRole.admin) == true)
                  _buildAdminSection(),
              ],
            ),
          ),
          
          // Donation Section - DISABLED for Apple App Store submission
          // Container(
          //   margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          //   decoration: BoxDecoration(
          //     gradient: LinearGradient(
          //       colors: [Colors.pink.shade400, Colors.red.shade400],
          //       begin: Alignment.topLeft,
          //       end: Alignment.bottomRight,
          //     ),
          //     borderRadius: BorderRadius.circular(12),
          //     boxShadow: [
          //       BoxShadow(
          //         color: Colors.pink.withOpacity(0.3),
          //         blurRadius: 8,
          //         offset: const Offset(0, 4),
          //       ),
          //     ],
          //   ),
          //   child: Material(
          //     color: Colors.transparent,
          //     child: InkWell(
          //       borderRadius: BorderRadius.circular(12),
          //       onTap: () => widget.onSectionChanged('donation'),
          //       child: Container(
          //         padding: const EdgeInsets.all(16),
          //         child: Row(
          //           children: [
          //             Container(
          //               padding: const EdgeInsets.all(8),
          //               decoration: BoxDecoration(
          //                 color: Colors.white.withOpacity(0.2),
          //                 borderRadius: BorderRadius.circular(8),
          //               ),
          //               child: const Icon(
          //                 Icons.favorite,
          //                 color: Colors.white,
          //                 size: 20,
          //               ),
          //             ),
          //             const SizedBox(width: 12),
          //             Expanded(
          //               child: Column(
          //                 crossAxisAlignment: CrossAxisAlignment.start,
          //                 children: [
          //                   const Text(
          //                     'Unterstützen',
          //                     style: TextStyle(
          //                       color: Colors.white,
          //                       fontSize: 14,
          //                       fontWeight: FontWeight.w600,
          //                     ),
          //                   ),
          //                   Text(
          //                     'Werbefrei halten',
          //                     style: TextStyle(
          //                       color: Colors.white.withOpacity(0.9),
          //                       fontSize: 11,
          //                       fontWeight: FontWeight.w500,
          //                     ),
          //                   ),
          //                 ],
          //               ),
          //             ),
          //             Container(
          //               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          //               decoration: BoxDecoration(
          //                 color: Colors.white.withOpacity(0.2),
          //                 borderRadius: BorderRadius.circular(12),
          //               ),
          //               child: const Text(
          //                 '💝',
          //                 style: TextStyle(fontSize: 16),
          //               ),
          //             ),
          //           ],
          //         ),
          //       ),
          //     ),
          //   ),
          // ),
          
          // Version Number at the very bottom
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: Text(
              'Version $_appVersion',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamManagerSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2D5016), // Dark green for team manager
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Team Manager Section Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.sports_handball,
                  color: Color(0xFFffd665),
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Text(
                  'MEINE TEAMS',
                  style: TextStyle(
                    color: Color(0xFFffd665),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                if (_isLoadingTeams) ...[
                  const Spacer(),
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFffd665)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Team Items
          ...(_managedTeams.map((team) => [
            _buildTeamManagerItem(
              title: '${team.name} - ${team.city}',
              key: 'team_${team.id}',
              isSelected: widget.selectedSection.startsWith('team_${team.id}'),
              team: team,
            ),
            // Sub-items always visible
            _buildTeamSubItem(
              title: 'Übersicht',
              key: 'team_${team.id}_overview',
              icon: Icons.dashboard,
              isSelected: widget.selectedSection == 'team_${team.id}_overview' || widget.selectedSection == 'team_${team.id}',
            ),
            _buildTeamSubItem(
              title: 'Turnier Anmeldung',
              key: 'team_${team.id}_tournaments',
              icon: Icons.sports_handball,
              isSelected: widget.selectedSection == 'team_${team.id}_tournaments',
            ),
            _buildTeamSubItem(
              title: 'Spiele & Kader',
              key: 'team_${team.id}_roster',
              icon: Icons.group,
              isSelected: widget.selectedSection == 'team_${team.id}_roster',
            ),
            _buildTeamSubItem(
              title: 'Einstellungen',
              key: 'team_${team.id}_settings',
              icon: Icons.settings,
              isSelected: widget.selectedSection == 'team_${team.id}_settings',
            ),
          ]).expand((x) => x)),
        ],
      ),
    );
  }

  Widget _buildTeamManagerItem({
    required String title,
    required String key,
    required bool isSelected,
    required Team team,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF1A3009) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFffd665) : Colors.white24,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.group,
            color: isSelected ? Colors.black87 : Colors.white70,
            size: 14,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              team.name,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              team.city,
              style: TextStyle(
                color: isSelected ? const Color(0xFFffd665) : Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        onTap: () => widget.onSectionChanged('${key}_overview'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
    );
  }

  Widget _buildTeamSubItem({
    required String title,
    required String key,
    required IconData icon,
    required bool isSelected,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      decoration: isSelected 
        ? AppColors.selectedItemDecoration.copyWith(borderRadius: BorderRadius.circular(6))
        : const BoxDecoration(),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          color: isSelected ? AppColors.onPrimary : Colors.white54,
          size: 16,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppColors.onPrimary : Colors.white60,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 12,
          ),
        ),
        onTap: () => widget.onSectionChanged(key),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      ),
    );
  }

  Widget _buildAdminSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF4A5568),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Admin Section Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Text(
              'ADMIN BEREICH',
              style: TextStyle(
                color: Color(0xFFffd665),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
          
          // Always visible admin items
          _buildAdminItem(
            icon: Icons.settings,
            title: 'Tournament Management',
            key: 'tournament_management',
            isSelected: widget.selectedSection == 'tournament_management',
          ),
          _buildAdminItem(
            icon: Icons.check_circle,
            title: 'Turnier-Freigaben',
            key: 'tournament_approval',
            isSelected: widget.selectedSection == 'tournament_approval',
          ),
          _buildAdminItem(
            icon: Icons.group,
            title: 'Team Management',
            key: 'team_management',
            isSelected: widget.selectedSection == 'team_management',
          ),
          _buildAdminItem(
            icon: Icons.sports_hockey,
            title: 'Schiedsrichter Verwaltung',
            key: 'referee_management',
            isSelected: widget.selectedSection == 'referee_management',
          ),
          _buildAdminItem(
            icon: Icons.gavel,
            title: 'Kampfgericht Verwaltung',
            key: 'kampfgericht_management',
            isSelected: widget.selectedSection == 'kampfgericht_management',
          ),
          _buildAdminItem(
            icon: Icons.account_balance,
            title: 'Delegierte Verwaltung',
            key: 'delegate_management',
            isSelected: widget.selectedSection == 'delegate_management',
          ),
          _buildAdminItem(
            icon: Icons.supervisor_account,
            title: 'Team Manager Verwaltung',
            key: 'team_manager_management',
            isSelected: widget.selectedSection == 'team_manager_management',
          ),
          _buildAdminItem(
            icon: Icons.people,
            title: 'Kader Verwaltung (Global)',
            key: 'player_management',
            isSelected: widget.selectedSection == 'player_management',
          ),
          _buildAdminItem(
            icon: Icons.manage_accounts,
            title: 'Benutzer-Rollen-Verwaltung',
            key: 'user_role_management',
            isSelected: widget.selectedSection == 'user_role_management',
          ),
          _buildAdminItem(
            icon: Icons.tablet_android,
            title: 'Verwaltete Accounts',
            key: 'managed_accounts',
            isSelected: widget.selectedSection == 'managed_accounts',
          ),
          // Donation management disabled for Apple App Store submission
          // _buildAdminItem(
          //   icon: Icons.volunteer_activism,
          //   title: 'Spenden verwalten',
          //   key: 'admin_donation_management',
          //   isSelected: widget.selectedSection == 'admin_donation_management',
          // ),
          _buildAdminItem(
            icon: Icons.key,
            title: 'Einmalone Codes erstellen',
            key: 'generate_sign_in_codes',
            isSelected: widget.selectedSection == 'generate_sign_in_codes',
          ),
          _buildAdminItem(
            icon: Icons.delete_forever,
            title: 'Datenverwaltung',
            key: 'admin_data_management',
            isSelected: widget.selectedSection == 'admin_data_management',
          ),
          
          // "Mehr" entry after regular items
          _buildAdminItem(
            icon: _isAdminExpanded ? Icons.expand_less : Icons.expand_more,
            title: _isAdminExpanded ? 'Weniger' : 'Mehr',
            key: 'admin_expand',
            isSelected: false,
            onTap: () {
              setState(() {
                _isAdminExpanded = !_isAdminExpanded;
              });
            },
            isYellow: true,
          ),
          
          // Expandable admin items
          if (_isAdminExpanded) ...[
            if (defaultTargetPlatform != TargetPlatform.iOS)
              _buildAdminItem(
                icon: Icons.architecture,
                title: 'Preset Verwaltung',
                key: 'preset_management',
                isSelected: widget.selectedSection == 'preset_management',
              ),
            _buildAdminItem(
              icon: Icons.notifications_active,
              title: 'Benachrichtigung Senden',
              key: 'custom_notifications',
              isSelected: widget.selectedSection == 'custom_notifications',
            ),
            _buildAdminItem(
              icon: Icons.calendar_today,
              title: 'Saison Management',
              key: 'season_management',
              isSelected: widget.selectedSection == 'season_management',
            ),
            _buildAdminItem(
              icon: Icons.dashboard,
              title: 'Kanban Board',
              key: 'kanban_board',
              isSelected: widget.selectedSection == 'kanban_board',
            ),
            _buildAdminItem(
              icon: Icons.location_city,
              title: 'Städte Migration',
              key: 'city_migration',
              isSelected: widget.selectedSection == 'city_migration',
            ),
            _buildAdminItem(
              icon: Icons.image,
              title: 'App Store Splash',
              key: 'app_store_splash',
              isSelected: widget.selectedSection == 'app_store_splash',
            ),
            _buildAdminItem(
              icon: Icons.data_array,
              title: 'Demo Daten Erstellen',
              key: 'demo_data',
              isSelected: widget.selectedSection == 'demo_data',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRefereeSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade600,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Referee Section Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Row(
              children: [
                Icon(
                  Icons.sports_hockey,
                  color: Colors.white,
                  size: 16,
                ),
                SizedBox(width: 8),
                Text(
                  'SCHIEDSRICHTER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          
          // Dashboard Item
          _buildRefereeItem(
            icon: Icons.dashboard,
            title: 'Dashboard',
            key: 'referee_dashboard',
            isSelected: widget.selectedSection == 'referee_dashboard',
          ),

          // Games Item
          _buildRefereeItem(
            icon: Icons.sports_hockey,
            title: 'Meine Spiele',
            key: 'referee_games',
            isSelected: widget.selectedSection == 'referee_games',
          ),
          
          // Tournament Items
          if (_isLoadingTournaments)
            Container(
              padding: const EdgeInsets.all(16),
              child: const Row(
                children: [
                  Spacer(),
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  Spacer(),
                ],
              ),
            )
          else if (_refereeTournaments.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Keine Turniere',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: _refereeTournaments.map((tournament) => [
                _buildRefereeTournamentItem(
                  title: tournament.name,
                  key: 'referee_tournament_${tournament.id}',
                  isSelected: widget.selectedSection.startsWith('referee_tournament_${tournament.id}'),
                  tournament: tournament,
                ),
                // Sub-items for tournament details
                _buildRefereeSubItem(
                  title: 'Übersicht',
                  key: 'referee_tournament_${tournament.id}_overview',
                  icon: Icons.info_outline,
                  isSelected: widget.selectedSection == 'referee_tournament_${tournament.id}_overview' || widget.selectedSection == 'referee_tournament_${tournament.id}',
                ),
                _buildRefereeSubItem(
                  title: 'Spielplan',
                  key: 'referee_tournament_${tournament.id}_games',
                  icon: Icons.sports_hockey,
                  isSelected: widget.selectedSection == 'referee_tournament_${tournament.id}_games',
                ),
              ]).expand((x) => x).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildScoringTabletSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.teal.shade700,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Scoring Section Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Row(
              children: [
                Icon(
                  Icons.scoreboard,
                  color: Colors.white,
                  size: 16,
                ),
                SizedBox(width: 8),
                Text(
                  'KAMPFGERICHT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          
          // Scoring System Item
          _buildScoringTabletItem(
            icon: Icons.tablet_mac,
            title: 'Scoring System',
            key: 'scoring_system',
            isSelected: widget.selectedSection == 'scoring_system',
          ),
          
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildScoringTabletItem({
    required IconData icon,
    required String title,
    required String key,
    required bool isSelected,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: Colors.white, size: 18),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
        onTap: () => widget.onSectionChanged(key),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      ),
    );
  }

  Widget _buildTournamentOrganizerSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2D3748),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Tournament Organizer Section Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Row(
              children: [
                Icon(
                  Icons.event,
                  color: Colors.white,
                  size: 16,
                ),
                SizedBox(width: 8),
                Text(
                  'TURNIER ORGANISATOR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          
          // Neues Turnier
          _buildTournamentOrganizerItem(
            icon: Icons.add_circle,
            title: 'Neues Turnier',
            key: 'new_tournament',
            isSelected: widget.selectedSection == 'new_tournament',
          ),
          
          // Assigned Tournaments Section
          if (_organizerTournaments.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Text(
                'Zugewiesene Turniere',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          
          // Tournament Items
          if (_isLoadingOrganizerTournaments)
            Container(
              padding: const EdgeInsets.all(16),
              child: const Row(
                children: [
                  Spacer(),
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  Spacer(),
                ],
              ),
            )
          else if (_organizerTournaments.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Keine zugewiesenen Turniere',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: _organizerTournaments.map((tournament) => [
                _buildOrganizerTournamentItem(
                  title: '${tournament.name} - ${tournament.location}',
                  key: 'organizer_tournament_${tournament.id}',
                  isSelected: widget.selectedSection.startsWith('organizer_tournament_${tournament.id}'),
                  tournament: tournament,
                ),
                // Sub-items for each tournament (always visible)
                _buildOrganizerTournamentSubItem(
                  title: 'Bearbeiten',
                  key: 'organizer_tournament_${tournament.id}_edit',
                  icon: Icons.edit,
                  isSelected: widget.selectedSection == 'organizer_tournament_${tournament.id}_edit',
                ),
                // Debug: Print tournament info
                Builder(builder: (context) {
                  print('Creating TO Software button for tournament: ${tournament.id}');
                  return _buildOrganizerTournamentSubItem(
                    title: 'TO Software',
                    key: 'organizer_tournament_${tournament.id}_to_software',
                    icon: Icons.computer,
                    isSelected: widget.selectedSection == 'organizer_tournament_${tournament.id}_to_software',
                  );
                }),
              ]).expand((x) => x).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTournamentOrganizerItem({
    required IconData icon,
    required String title,
    required String key,
    required bool isSelected,
    bool isComingSoon = false,
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
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
            if (isComingSoon)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade600,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Coming Soon',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        onTap: isComingSoon ? null : () {
          widget.onSectionChanged(key);
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildOrganizerTournamentItem({
    required String title,
    required String key,
    required bool isSelected,
    required Tournament tournament,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF1A202C) : const Color(0xFF2D3748),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.sports_handball,
            color: const Color(0xFF2D3748),
            size: 14,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tournament.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              tournament.location,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        onTap: null, // Tournament items are not clickable
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
    );
  }

  Widget _buildOrganizerTournamentSubItem({
    required String title,
    required String key,
    required IconData icon,
    required bool isSelected,
    bool isComingSoon = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 1),
      decoration: isSelected 
        ? AppColors.selectedItemDecoration.copyWith(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.primaryColorAlt, width: 0.5),
          )
        : BoxDecoration(
            color: const Color(0xFF2D3748),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.primaryColorAlt, width: 0.5),
          ),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          color: isSelected ? AppColors.onPrimary : Colors.white70,
          size: 14,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? AppColors.onPrimary : Colors.white70,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
            if (isComingSoon)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade600,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Coming Soon',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        onTap: isComingSoon ? null : () {
          print('TO Software clicked with key: $key');
          widget.onSectionChanged(key);
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      ),
    );
  }

  Widget _buildRefereeItem({
    required IconData icon,
    required String title,
    required String key,
    required bool isSelected,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: isSelected ? Colors.orange.shade800 : Colors.transparent,
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
        onTap: () => widget.onSectionChanged(key),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildRefereeTournamentItem({
    required String title,
    required String key,
    required bool isSelected,
    required Tournament tournament,
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
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.sports_handball,
            color: Colors.orange.shade600,
            size: 14,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tournament.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              tournament.location,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        onTap: () => widget.onSectionChanged('${key}_overview'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
    );
  }

  Widget _buildRefereeSubItem({
    required String title,
    required String key,
    required IconData icon,
    required bool isSelected,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 1),
      decoration: isSelected 
        ? AppColors.selectedItemDecoration.copyWith(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.primaryColorAlt, width: 0.5),
          )
        : BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.primaryColorAlt, width: 0.5),
          ),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          color: isSelected ? AppColors.onPrimary : AppColors.primaryColorAlt,
          size: 14,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppColors.onPrimary : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
        onTap: () => widget.onSectionChanged(key),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      ),
    );
  }

  Widget _buildAdminItem({
    required IconData icon,
    required String title,
    required String key,
    required bool isSelected,
    VoidCallback? onTap,
    bool isYellow = false,
  }) {
    final textColor = isYellow 
        ? const Color(0xFFffd665) 
        : (isSelected ? AppColors.onPrimary : Colors.white70);
    final iconColor = isYellow 
        ? const Color(0xFFffd665) 
        : (isSelected ? AppColors.onPrimary : Colors.white70);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: isSelected 
        ? AppColors.selectedItemDecoration
        : const BoxDecoration(),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          color: iconColor,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: textColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        onTap: onTap ?? () => widget.onSectionChanged(key),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildNavigationItem({
    required IconData icon,
    required String title,
    required String key,
    required bool isSelected,
    bool hasExpansion = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: isSelected 
        ? AppColors.selectedItemDecoration
        : const BoxDecoration(),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          color: isSelected ? AppColors.onPrimary : Colors.grey.shade600,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppColors.onPrimary : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        trailing: hasExpansion
            ? Icon(
                Icons.chevron_right,
                color: Colors.grey.shade600,
                size: 18,
              )
            : null,
        onTap: () => widget.onSectionChanged(key),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildUserProfile() {
    if (_currentUser == null) return Container();
    
    final displayName = _currentAppUser?.fullName ?? _currentUser!.displayName ?? 'Benutzer';
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
                        style: const TextStyle(
                          fontSize: 14,
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
                          fontSize: 12,
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
          
          // Profile Settings Button
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: TextButton.icon(
              onPressed: () => widget.onSectionChanged('profile_settings'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.black87,
                backgroundColor: Colors.grey.shade100,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.settings, size: 16),
              label: const Text(
                'Profil Einstellungen',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          // Logout Button
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: TextButton.icon(
              onPressed: () async {
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
                  fontSize: 12,
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
} 

class SparkleOverlay extends StatefulWidget {
  const SparkleOverlay({super.key});

  @override
  State<SparkleOverlay> createState() => _SparkleOverlayState();
}

class _SparkleOverlayState extends State<SparkleOverlay>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  final List<Sparkle> _sparkles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    // Generate random sparkles
    for (int i = 0; i < 50; i++) {
      _sparkles.add(Sparkle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 3 + 1,
        opacity: _random.nextDouble() * 0.6 + 0.2,
        delay: _random.nextDouble(),
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: SparklePainter(_sparkles, _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class Sparkle {
  final double x;
  final double y;
  final double size;
  final double opacity;
  final double delay;

  Sparkle({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.delay,
  });
}

class SparklePainter extends CustomPainter {
  final List<Sparkle> sparkles;
  final double animationValue;

  SparklePainter(this.sparkles, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (final sparkle in sparkles) {
      final adjustedValue = (animationValue + sparkle.delay) % 1.0;
      final sparkleOpacity = sparkle.opacity * 
          (0.5 + 0.5 * sin(adjustedValue * 2 * pi));
      
      paint.color = Colors.white.withOpacity(sparkleOpacity);
      
      final x = sparkle.x * size.width;
      final y = sparkle.y * size.height;
      
      // Draw sparkle as a small star
      _drawStar(canvas, paint, Offset(x, y), sparkle.size);
    }
  }

  void _drawStar(Canvas canvas, Paint paint, Offset center, double size) {
    final path = Path();
    
    // Simple 4-pointed star
    path.moveTo(center.dx, center.dy - size);
    path.lineTo(center.dx + size * 0.3, center.dy - size * 0.3);
    path.lineTo(center.dx + size, center.dy);
    path.lineTo(center.dx + size * 0.3, center.dy + size * 0.3);
    path.lineTo(center.dx, center.dy + size);
    path.lineTo(center.dx - size * 0.3, center.dy + size * 0.3);
    path.lineTo(center.dx - size, center.dy);
    path.lineTo(center.dx - size * 0.3, center.dy - size * 0.3);
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 