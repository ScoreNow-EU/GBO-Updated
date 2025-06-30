import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/team_manager_service.dart';
import '../models/team.dart';

class SideNavigation extends StatefulWidget {
  final String selectedSection;
  final Function(String) onSectionChanged;

  const SideNavigation({
    super.key,
    required this.selectedSection,
    required this.onSectionChanged,
  });

  @override
  State<SideNavigation> createState() => _SideNavigationState();
}

class _SideNavigationState extends State<SideNavigation> {
  User? _currentUser;
  final TeamManagerService _teamManagerService = TeamManagerService();
  List<Team> _managedTeams = [];
  bool _isTeamManager = false;
  bool _isLoadingTeams = false;

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
      }
    });
    
    _loadTeamManagerData();
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
          print('Team: ${team.name} - ${team.division}');
        }
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
          // Logo Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFffd665),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: Column(
              children: [
                Image.asset(
                  'logo.png',
                  height: 80,
                  width: 120,
                ),
                const SizedBox(height: 8),
                const Text(
                  'German Beach Open',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
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
                  icon: Icons.sports_volleyball,
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
                
                // Admin Section with continuous black background
                _buildAdminSection(),
              ],
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
                  Icons.sports_volleyball,
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
              title: '${team.name} - ${team.division}',
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
              icon: Icons.sports_volleyball,
              isSelected: widget.selectedSection == 'team_${team.id}_tournaments',
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
              team.division,
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
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF0D1A05) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          color: isSelected ? const Color(0xFFffd665) : Colors.white54,
          size: 16,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
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
          
          // Admin Items
          if (defaultTargetPlatform != TargetPlatform.iOS)
            _buildAdminItem(
              icon: Icons.architecture,
              title: 'Preset Verwaltung',
              key: 'preset_management',
              isSelected: widget.selectedSection == 'preset_management',
            ),
          _buildAdminItem(
            icon: Icons.settings,
            title: 'Tournament Management',
            key: 'tournament_management',
            isSelected: widget.selectedSection == 'tournament_management',
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
        ],
      ),
    );
  }

  Widget _buildAdminItem({
    required IconData icon,
    required String title,
    required String key,
    required bool isSelected,
  }) {
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
        onTap: () => widget.onSectionChanged(key),
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
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFffd665).withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          color: isSelected ? Colors.black87 : Colors.grey.shade600,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.black87 : Colors.black87,
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