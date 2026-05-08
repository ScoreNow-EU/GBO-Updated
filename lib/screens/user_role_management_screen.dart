import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../models/user.dart' as app_user;
import '../models/referee.dart';
import '../models/team_manager.dart';
import '../models/team.dart';
import '../services/auth_service.dart';
import '../services/referee_service.dart';
import '../services/team_manager_service.dart';
import '../services/team_service.dart';
import '../utils/responsive_helper.dart';

class UserRoleManagementScreen extends StatefulWidget {
  const UserRoleManagementScreen({super.key});

  @override
  State<UserRoleManagementScreen> createState() => _UserRoleManagementScreenState();
}

class _UserRoleManagementScreenState extends State<UserRoleManagementScreen> {
  final AuthService _authService = AuthService();
  final RefereeService _refereeService = RefereeService();
  final TeamManagerService _teamManagerService = TeamManagerService();
  final TeamService _teamService = TeamService();
  
  List<app_user.User> _users = [];
  List<Team> _teams = [];
  String _searchQuery = '';
  String _roleFilter = 'Alle';
  bool _isLoading = true;

  final List<String> _roleFilters = [
    'Alle',
    'Admin',
    'Referee',
    'Team Manager',
    'Delegate',
    'Scoring Tablet',
    'Series Organizer',
    'Spieler',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      
      // Load users and teams
      final users = await _authService.getAllUsers();
      final teams = await _teamService.getTeams().first;
      
      if (mounted) {
        setState(() {
          _users = users;
          _teams = teams;
          _isLoading = false;
        });
      }
      
      // Auto-assign roles based on existing referee and team manager emails
      final rolesAdded = await _autoAssignRoles();
      if (rolesAdded > 0) {
        debugPrint('ðŸ”„ Auto-assigned $rolesAdded roles during initial load');
      }
      
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshData() async {
    try {
      setState(() => _isLoading = true);
      
      // Refresh all data including referee and team manager emails
      await _loadData();
      
      // Auto-assign roles based on existing referee and team manager emails
      final rolesAdded = await _autoAssignRoles();
      
      if (mounted) {
        String description = 'Benutzer-, Referee- und Team Manager-Daten wurden erfolgreich aktualisiert.';
        if (rolesAdded > 0) {
          description += ' $rolesAdded Rollen wurden automatisch zugewiesen.';
        }
        
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          title: const Text('Daten aktualisiert'),
          description: Text(description),
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
          description: Text('Fehler beim Aktualisieren der Daten: $e'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    }
  }

  Future<int> _autoAssignRoles() async {
    try {
      // Get all referees and team managers
      final referees = await _refereeService.getAllReferees();
      final teamManagers = await _teamManagerService.getAllTeamManagers();
      
      // Create maps for quick lookup
      final refereeEmails = {for (var ref in referees) ref.email.toLowerCase(): ref};
      final teamManagerEmails = {for (var tm in teamManagers) tm.email.toLowerCase(): tm};
      
      int rolesAdded = 0;
      
      // Check each user and auto-assign roles
      for (final user in _users) {
        final userEmail = user.email.toLowerCase();
        bool userUpdated = false;
        
        // Check if user should have referee role
        if (refereeEmails.containsKey(userEmail) && !user.roles.contains(app_user.UserRole.referee)) {
          final referee = refereeEmails[userEmail]!;
          final success = await _authService.addRoleToUser(
            user.id, 
            app_user.UserRole.referee,
            refereeId: referee.id,
          );
          if (success) {
            rolesAdded++;
            userUpdated = true;
            debugPrint('âœ… Auto-assigned referee role to ${user.fullName} (${user.email}) with refereeId: ${referee.id}');
          }
        }
        
        // Check if user should have team manager role
        if (teamManagerEmails.containsKey(userEmail) && !user.roles.contains(app_user.UserRole.teamManager)) {
          final teamManager = teamManagerEmails[userEmail]!;
          final success = await _authService.addRoleToUser(
            user.id, 
            app_user.UserRole.teamManager,
            teamManagerId: teamManager.id,
          );
          if (success) {
            rolesAdded++;
            userUpdated = true;
            debugPrint('âœ… Auto-assigned team manager role to ${user.fullName} (${user.email}) with teamManagerId: ${teamManager.id}');
          }
        }
      }
      
      // Reload data to reflect changes
      if (rolesAdded > 0) {
        // Re-fetch users to reflect the updated roles
        final users = await _authService.getAllUsers();
        if (mounted) {
          setState(() {
            _users = users;
          });
        }
        debugPrint('ðŸ”„ Auto-assigned $rolesAdded roles during refresh');
      }
      
      return rolesAdded;
      
    } catch (e) {
      debugPrint('âŒ Error during auto-role assignment: $e');
      return 0;
    }
  }

  void _showAddRoleDialog(app_user.User user, List<app_user.UserRole> availableRoles) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rolle hinzufügen für ${user.fullName}'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: availableRoles.map((role) {
              Color color = _getRoleColor(role);
              return ListTile(
                leading: Icon(_getRoleIcon(role), color: color),
                title: Text(_getRoleDisplayName(role)),
                onTap: () {
                  Navigator.of(context).pop();
                  _addRoleToUser(user, role);
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
  }

  void _showRemoveRoleDialog(app_user.User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rolle entfernen von ${user.fullName}'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: user.roles.map((role) {
              Color color = _getRoleColor(role);
              return ListTile(
                leading: Icon(_getRoleIcon(role), color: color),
                title: Text(_getRoleDisplayName(role)),
                onTap: () {
                  Navigator.of(context).pop();
                  _removeRoleFromUser(user, role);
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveHelper.isMobile(screenWidth);
    
    return Scaffold(
      body: Container(
        padding: EdgeInsets.all(isMobile ? 16 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(isMobile),
            const SizedBox(height: 24),
            
            // Filters
            _buildFilters(isMobile),
            const SizedBox(height: 24),
            
            // Users List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildUsersList(isMobile),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.manage_accounts,
            color: Colors.purple.shade700,
            size: 32,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Benutzer-Rollen-Verwaltung',
                style: TextStyle(
                  fontSize: isMobile ? 20 : 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                'Verwalten Sie Benutzerrollen und Berechtigungen',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _refreshData,
          icon: const Icon(Icons.refresh),
          tooltip: 'Daten aktualisieren',
          style: IconButton.styleFrom(
            backgroundColor: Colors.blue.shade100,
            foregroundColor: Colors.blue.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildFilters(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (isMobile) ...[
            _buildSearchField(),
            const SizedBox(height: 16),
            _buildRoleFilter(),
          ] else ...[
            Row(
              children: [
                Expanded(child: _buildSearchField()),
                const SizedBox(width: 16),
                Container(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: _buildRoleFilter(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Benutzer suchen...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
    );
  }

  Widget _buildRoleFilter() {
    return DropdownButtonFormField<String>(
      value: _roleFilter,
      decoration: InputDecoration(
        labelText: 'Rolle filtern',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      items: _roleFilters.map((filter) {
        return DropdownMenuItem(
          value: filter,
          child: Text(filter),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _roleFilter = value!;
        });
      },
    );
  }

  Widget _buildUsersList(bool isMobile) {
    final filteredUsers = _getFilteredUsers();
    
    if (filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Keine Benutzer gefunden',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredUsers.length,
      itemBuilder: (context, index) {
        final user = filteredUsers[index];
        return _buildUserCard(user, isMobile);
      },
    );
  }





  Color _getRoleColor(app_user.UserRole role) {
    switch (role) {
      case app_user.UserRole.admin:
        return Colors.red;
      case app_user.UserRole.user:
        return Colors.grey;
      case app_user.UserRole.referee:
        return Colors.orange;
      case app_user.UserRole.teamManager:
        return Colors.blue;
      case app_user.UserRole.delegate:
        return Colors.green;
      case app_user.UserRole.scoringTablet:
        return Colors.purple;
      case app_user.UserRole.seriesOrganizer:
        return Colors.indigo;
      case app_user.UserRole.spieler:
        return Colors.amber;
      case app_user.UserRole.tournamentOrganizer:
        return Colors.deepPurple;
      case app_user.UserRole.teamRHD:
        return Colors.brown;
    }
  }

  IconData _getRoleIcon(app_user.UserRole role) {
    switch (role) {
      case app_user.UserRole.admin:
        return Icons.admin_panel_settings;
      case app_user.UserRole.user:
        return Icons.account_circle;
      case app_user.UserRole.referee:
        return Icons.sports_handball;
      case app_user.UserRole.teamManager:
        return Icons.groups;
      case app_user.UserRole.delegate:
        return Icons.badge;
      case app_user.UserRole.scoringTablet:
        return Icons.tablet_android;
      case app_user.UserRole.seriesOrganizer:
        return Icons.event_note;
      case app_user.UserRole.spieler:
        return Icons.person;
      case app_user.UserRole.tournamentOrganizer:
        return Icons.event;
      case app_user.UserRole.teamRHD:
        return Icons.gavel;
    }
  }

  Widget _buildUserCard(app_user.User user, bool isMobile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
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
          // User Info Header
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.purple.shade100,
                child: Text(
                  user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : 'U',
                  style: TextStyle(
                    color: Colors.purple.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              // Status indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: user.isActive ? Colors.green.shade100 : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  user.isActive ? 'Aktiv' : 'Inaktiv',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: user.isActive ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Current Roles
          _buildCurrentRoles(user),
          
          const SizedBox(height: 16),
          
          // Role Management Actions
          _buildRoleActions(user, isMobile),
          
          const SizedBox(height: 8),
          
          // Quick Action Buttons
          _buildQuickActions(user),
        ],
      ),
    );
  }

  Widget _buildCurrentRoles(app_user.User user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Aktuelle Rollen:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: user.roles.map((role) => _buildRoleChip(role)).toList(),
        ),
      ],
    );
  }

  Widget _buildRoleChip(app_user.UserRole role) {
    Color color;
    IconData icon;
    
    switch (role) {
      case app_user.UserRole.admin:
        color = Colors.red;
        icon = Icons.admin_panel_settings;
        break;
      case app_user.UserRole.user:
        color = Colors.grey;
        icon = Icons.account_circle;
        break;
      case app_user.UserRole.referee:
        color = Colors.orange;
        icon = Icons.sports_handball;
        break;
      case app_user.UserRole.teamManager:
        color = Colors.blue;
        icon = Icons.groups;
        break;
      case app_user.UserRole.delegate:
        color = Colors.green;
        icon = Icons.badge;
        break;
      case app_user.UserRole.scoringTablet:
        color = Colors.purple;
        icon = Icons.tablet_android;
        break;
      case app_user.UserRole.seriesOrganizer:
        color = Colors.indigo;
        icon = Icons.event_note;
        break;
      case app_user.UserRole.spieler:
        color = Colors.amber;
        icon = Icons.person;
        break;
      case app_user.UserRole.tournamentOrganizer:
        color = Colors.deepPurple;
        icon = Icons.event;
        break;
      case app_user.UserRole.teamRHD:
        color = Colors.brown;
        icon = Icons.gavel;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            _getRoleDisplayName(role),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleActions(app_user.User user, bool isMobile) {
    final availableRoles = app_user.UserRole.values
        .where((role) => !user.roles.contains(role)) // Exclude current roles
        .toList();
    
    if (availableRoles.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rollen hinzufügen:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableRoles.map((role) => _buildRoleActionButton(user, role)).toList(),
        ),
      ],
    );
  }

  Widget _buildQuickActions(app_user.User user) {
    final availableRoles = app_user.UserRole.values
        .where((role) => !user.roles.contains(role))
        .toList();
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (user.roles.length > 1)
          OutlinedButton.icon(
            onPressed: () => _showRemoveRoleDialog(user),
            icon: const Icon(Icons.remove, size: 16),
            label: const Text('Rolle entfernen'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
          ),
        if (availableRoles.isNotEmpty) ...[
          if (user.roles.length > 1) const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _showAddRoleDialog(user, availableRoles),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Rolle hinzufügen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => _showResetPasswordDialog(user),
          icon: const Icon(Icons.lock_reset, size: 16),
          label: const Text('Passwort zurücksetzen'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange,
            side: const BorderSide(color: Colors.orange),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => _showDeleteAccountDialog(user),
          icon: const Icon(Icons.delete, size: 16),
          label: const Text('Konto löschen'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleActionButton(app_user.User user, app_user.UserRole role) {
    Color color;
    IconData icon;
    
    switch (role) {
      case app_user.UserRole.admin:
        color = Colors.red;
        icon = Icons.admin_panel_settings;
        break;
      case app_user.UserRole.user:
        color = Colors.grey;
        icon = Icons.account_circle;
        break;
      case app_user.UserRole.referee:
        color = Colors.orange;
        icon = Icons.sports_handball;
        break;
      case app_user.UserRole.teamManager:
        color = Colors.blue;
        icon = Icons.groups;
        break;
      case app_user.UserRole.delegate:
        color = Colors.green;
        icon = Icons.badge;
        break;
      case app_user.UserRole.scoringTablet:
        color = Colors.purple;
        icon = Icons.tablet_android;
        break;
      case app_user.UserRole.seriesOrganizer:
        color = Colors.indigo;
        icon = Icons.event_note;
        break;
      case app_user.UserRole.spieler:
        color = Colors.amber;
        icon = Icons.person;
        break;
      case app_user.UserRole.tournamentOrganizer:
        color = Colors.deepPurple;
        icon = Icons.event;
        break;
      case app_user.UserRole.teamRHD:
        color = Colors.brown;
        icon = Icons.gavel;
        break;
    }
    
    return OutlinedButton.icon(
      onPressed: () => _addRoleToUser(user, role),
      icon: Icon(icon, size: 16, color: color),
      label: Text(
        _getRoleDisplayName(role),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withOpacity(0.5)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );
  }

  String _getRoleDisplayName(app_user.UserRole role) {
    switch (role) {
      case app_user.UserRole.admin:
        return 'Admin';
      case app_user.UserRole.user:
        return 'User';
      case app_user.UserRole.referee:
        return 'Referee';
      case app_user.UserRole.teamManager:
        return 'Team Manager';
      case app_user.UserRole.delegate:
        return 'Delegate';
      case app_user.UserRole.scoringTablet:
        return 'Scoring Tablet';
      case app_user.UserRole.seriesOrganizer:
        return 'Series Organizer';
      case app_user.UserRole.spieler:
        return 'Spieler';
      case app_user.UserRole.tournamentOrganizer:
        return 'Tournament Organizer';
      case app_user.UserRole.teamRHD:
        return 'Team RHD';
    }
  }

  List<app_user.User> _getFilteredUsers() {
    List<app_user.User> filtered = _users;
    
    // Filter out system accounts (but keep managed scoring/medic accounts visible)
    filtered = filtered.where((user) {
      final email = user.email.toLowerCase();
      // Only hide the internal system accounts, not managed devices
      return !email.endsWith('@rollstuhlhandball.de');
    }).toList();
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((user) {
        final searchLower = _searchQuery.toLowerCase();
        return user.fullName.toLowerCase().contains(searchLower) ||
               user.email.toLowerCase().contains(searchLower);
      }).toList();
    }
    
    // Filter by role
    if (_roleFilter != 'Alle') {
      app_user.UserRole? filterRole;
      switch (_roleFilter) {
        case 'Admin':
          filterRole = app_user.UserRole.admin;
          break;
        case 'Referee':
          filterRole = app_user.UserRole.referee;
          break;
        case 'Team Manager':
          filterRole = app_user.UserRole.teamManager;
          break;
        case 'Delegate':
          filterRole = app_user.UserRole.delegate;
          break;
        case 'Scoring Tablet':
          filterRole = app_user.UserRole.scoringTablet;
          break;
        case 'Series Organizer':
          filterRole = app_user.UserRole.seriesOrganizer;
          break;
        case 'Spieler':
          filterRole = app_user.UserRole.spieler;
          break;
      }
      
      if (filterRole != null) {
        filtered = filtered.where((user) => user.roles.contains(filterRole)).toList();
      }
    }
    
    return filtered;
  }

  Future<void> _addRoleToUser(app_user.User user, app_user.UserRole role) async {
    switch (role) {
      case app_user.UserRole.referee:
        await _showRefereeCreationDialog(user);
        break;
      case app_user.UserRole.teamManager:
        await _showTeamManagerCreationDialog(user);
        break;
      case app_user.UserRole.admin:
      case app_user.UserRole.user:
      case app_user.UserRole.delegate:
      case app_user.UserRole.scoringTablet:
      case app_user.UserRole.seriesOrganizer:
      case app_user.UserRole.spieler:
      case app_user.UserRole.tournamentOrganizer:
      case app_user.UserRole.teamRHD:
        await _assignSimpleRole(user, role);
        break;
    }
  }

  Future<void> _showRefereeCreationDialog(app_user.User user) async {
    showDialog(
      context: context,
      builder: (context) => _RefereeCreationDialog(
        user: user,
        onCreateReferee: (refereeData) async {
          try {
            // Create referee object
            final referee = Referee(
              id: '', // Will be set by Firestore
              firstName: refereeData['firstName'],
              lastName: refereeData['lastName'],
              email: refereeData['email'],
              licenseType: refereeData['qualification'] ?? 'Basis-Lizenz',
              createdAt: refereeData['createdAt'],
              updatedAt: refereeData['createdAt'],
            );
            
            // Add referee to database
            await _refereeService.addReferee(referee);
            
            // Update user with referee role and link to referee record
            await _authService.addRoleToUser(user.id, app_user.UserRole.referee, refereeId: referee.id);
            
            // Refresh data
            await _loadData();
            
            if (mounted) {
              toastification.show(
                context: context,
                type: ToastificationType.success,
                style: ToastificationStyle.fillColored,
                title: const Text('Referee erstellt'),
                description: Text('${user.fullName} wurde als Referee hinzugefügt.'),
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
                description: Text('Fehler beim Erstellen des Referees: $e'),
                autoCloseDuration: const Duration(seconds: 3),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _showTeamManagerCreationDialog(app_user.User user) async {
    showDialog(
      context: context,
      builder: (context) => _TeamManagerCreationDialog(
        user: user,
        teams: _teams,
        onCreateTeamManager: (teamManagerData, selectedTeam) async {
          try {
            // Create team manager object
            final teamManager = TeamManager(
              id: '', // Will be set by Firestore
              name: '${teamManagerData['firstName']} ${teamManagerData['lastName']}',
              email: teamManagerData['email'],
              phone: teamManagerData['phone'],
              teamIds: selectedTeam != null ? [selectedTeam.id] : [],
              isActive: teamManagerData['isActive'],
              createdAt: teamManagerData['createdAt'],
            );
            
            // Create team manager in database
            final success = await _teamManagerService.createTeamManager(teamManager);
            
            if (success) {
              // Update user with team manager role and link to team manager record
              await _authService.addRoleToUser(user.id, app_user.UserRole.teamManager, teamManagerId: teamManager.id);
            } else {
              throw Exception('Failed to create team manager');
            }
            
            // Refresh data
            await _loadData();
            
            if (mounted) {
              toastification.show(
                context: context,
                type: ToastificationType.success,
                style: ToastificationStyle.fillColored,
                title: const Text('Team Manager erstellt'),
                description: Text('${user.fullName} wurde als Team Manager hinzugefügt.'),
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
                description: Text('Fehler beim Erstellen des Team Managers: $e'),
                autoCloseDuration: const Duration(seconds: 3),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _assignSimpleRole(app_user.User user, app_user.UserRole role) async {
    try {
      String? refereeId;
      String? teamManagerId;
      
      // For referee role, try to find existing referee record
      if (role == app_user.UserRole.referee) {
        final referees = await _refereeService.getAllReferees();
        final referee = referees.firstWhere(
          (ref) => ref.email.toLowerCase() == user.email.toLowerCase(),
          orElse: () => throw Exception('Referee record not found for ${user.email}'),
        );
        refereeId = referee.id;
      }
      
      // For team manager role, try to find existing team manager record
      if (role == app_user.UserRole.teamManager) {
        final teamManagers = await _teamManagerService.getAllTeamManagers();
        final teamManager = teamManagers.firstWhere(
          (tm) => tm.email.toLowerCase() == user.email.toLowerCase(),
          orElse: () => throw Exception('Team Manager record not found for ${user.email}'),
        );
        teamManagerId = teamManager.id;
      }
      
      await _authService.addRoleToUser(
        user.id, 
        role,
        refereeId: refereeId,
        teamManagerId: teamManagerId,
      );
      await _loadData();
      
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          title: const Text('Rolle zugewiesen'),
          description: Text('${user.fullName} wurde die Rolle ${_getRoleDisplayName(role)} zugewiesen.'),
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
          description: Text('Fehler beim Zuweisen der Rolle: $e'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    }
  }

  Future<void> _removeRoleFromUser(app_user.User user, app_user.UserRole role) async {
    try {
      await _authService.removeRoleFromUser(user.id, role);
      await _loadData();
      
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          title: const Text('Rolle entfernt'),
          description: Text('Die Rolle ${_getRoleDisplayName(role)} wurde von ${user.fullName} entfernt.'),
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
          description: Text('Fehler beim Entfernen der Rolle: $e'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    }
  }

  void _showResetPasswordDialog(app_user.User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Passwort zurücksetzen'),
        content: Text(
          'Möchten Sie wirklich eine Passwort-Zurücksetzen-E-Mail an ${user.email} senden?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resetPassword(user);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Passwort zurücksetzen'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassword(app_user.User user) async {
    try {
      await _authService.sendPasswordResetEmail(user.email);
      
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          title: const Text('E-Mail versendet'),
          description: Text('Passwort-Zurücksetzen-E-Mail wurde an ${user.email} versendet.'),
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
          description: Text('Fehler beim Versenden der E-Mail: $e'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    }
  }

  void _showDeleteAccountDialog(app_user.User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konto löschen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Möchten Sie wirklich das Konto von ${user.fullName} (${user.email}) dauerhaft löschen?',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Diese Aktion kann nicht rückgängig gemacht werden!',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAccount(user);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Konto löschen'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(app_user.User user) async {
    try {
      await _authService.deleteUserAccount(user.id);
      await _loadData();
      
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          title: const Text('Konto gelöscht'),
          description: Text('Das Konto von ${user.fullName} wurde erfolgreich gelöscht.'),
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
          description: Text('Fehler beim Löschen des Kontos: $e'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    }
  }
}

// Dialog for creating referee
class _RefereeCreationDialog extends StatefulWidget {
  final app_user.User user;
  final Function(Map<String, dynamic>) onCreateReferee;

  const _RefereeCreationDialog({
    required this.user,
    required this.onCreateReferee,
  });

  @override
  State<_RefereeCreationDialog> createState() => _RefereeCreationDialogState();
}

class _RefereeCreationDialogState extends State<_RefereeCreationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _qualificationController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _qualificationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Referee erstellen'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Erstelle einen Referee-Eintrag für ${widget.user.fullName}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefonnummer',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bitte geben Sie eine Telefonnummer ein';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _qualificationController,
                decoration: const InputDecoration(
                  labelText: 'Qualifikation',
                  hintText: 'z.B. Landesverband, Kreisverband',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notizen (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final refereeData = {
                'firstName': widget.user.firstName,
                'lastName': widget.user.lastName,
                'email': widget.user.email,
                'phone': _phoneController.text.trim(),
                'qualification': _qualificationController.text.trim(),
                'notes': _notesController.text.trim(),
                'isActive': true,
                'createdAt': DateTime.now(),
              };
              
              widget.onCreateReferee(refereeData);
              Navigator.of(context).pop();
            }
          },
          child: const Text('Erstellen'),
        ),
      ],
    );
  }
}

// Dialog for creating team manager
class _TeamManagerCreationDialog extends StatefulWidget {
  final app_user.User user;
  final List<Team> teams;
  final Function(Map<String, dynamic>, Team?) onCreateTeamManager;

  const _TeamManagerCreationDialog({
    required this.user,
    required this.teams,
    required this.onCreateTeamManager,
  });

  @override
  State<_TeamManagerCreationDialog> createState() => _TeamManagerCreationDialogState();
}

class _TeamManagerCreationDialogState extends State<_TeamManagerCreationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _organizationController = TextEditingController();
  final _notesController = TextEditingController();
  Team? _selectedTeam;

  @override
  void dispose() {
    _phoneController.dispose();
    _organizationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Team Manager erstellen'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Erstelle einen Team Manager-Eintrag für ${widget.user.fullName}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefonnummer',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bitte geben Sie eine Telefonnummer ein';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _organizationController,
                decoration: const InputDecoration(
                  labelText: 'Organisation/Verein',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<Team>(
                value: _selectedTeam,
                decoration: const InputDecoration(
                  labelText: 'Team zuweisen (optional)',
                  border: OutlineInputBorder(),
                ),
                items: widget.teams.map((team) {
                  return DropdownMenuItem(
                    value: team,
                    child: Text('${team.name} - ${team.city}'),
                  );
                }).toList(),
                onChanged: (team) {
                  setState(() {
                    _selectedTeam = team;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notizen (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final teamManagerData = {
                'firstName': widget.user.firstName,
                'lastName': widget.user.lastName,
                'email': widget.user.email,
                'phone': _phoneController.text.trim(),
                'organization': _organizationController.text.trim(),
                'notes': _notesController.text.trim(),
                'isActive': true,
                'createdAt': DateTime.now(),
              };
              
              widget.onCreateTeamManager(teamManagerData, _selectedTeam);
              Navigator.of(context).pop();
            }
          },
          child: const Text('Erstellen'),
        ),
      ],
    );
  }
} 