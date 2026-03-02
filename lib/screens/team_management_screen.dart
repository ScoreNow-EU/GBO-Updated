import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/team.dart';
import '../services/team_service.dart';
import '../utils/responsive_helper.dart';
import '../widgets/team_avatar.dart';

import 'team_form_screen.dart';
import 'team_edit_screen.dart';

class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  final TeamService _teamService = TeamService();
  
  List<Team> _teams = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final teams = await _teamService.getTeams().first;
      setState(() {
        _teams = teams;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Fehler beim Laden der Daten: $e');
    }
  }

  List<Team> get _filteredTeams {
    List<Team> filtered = _teams;
    
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((team) =>
        team.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        team.city.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveHelper.isMobile(screenWidth);
    
    if (isMobile) {
      return _buildMobileLayout();
    } else {
      return _buildDesktopLayout();
    }
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildTeamsListView(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTeamDialog(),
        backgroundColor: Colors.black87,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text(
                'Teams verwalten',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showTeamDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Neues Team'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Search and filters
          _buildSearchAndFilters(),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _buildTeamsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamsListView() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 120,
          pinned: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
            title: const Text(
              'Teams',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: _buildSearchAndFilters(),
          ),
        ),
        _buildTeamsSliverList(),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Team suchen...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),

      ],
    );
  }

  Widget _buildTeamsList() {
    final teams = _filteredTeams;
    
    if (teams.isEmpty) {
      return _buildEmptyTeamsView();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: teams.length,
        itemBuilder: (context, index) {
          final team = teams[index];
          return _buildTeamCard(team, isMobile: false);
        },
      ),
    );
  }

  Widget _buildTeamsSliverList() {
    final teams = _filteredTeams;
    
    if (teams.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyTeamsView());
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final team = teams[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: _buildTeamCard(team, isMobile: true),
          );
        },
        childCount: teams.length,
      ),
    );
  }

  Widget _buildTeamCard(Team team, {required bool isMobile}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Team avatar
            TeamAvatar(
              teamName: team.name,
              size: isMobile ? 45 : 40,
            ),
            const SizedBox(width: 12),
            
            // Team info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team.name,
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${team.city}, ${team.bundesland}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: isMobile ? 14 : 12,
                    ),
                  ),
                  Text(
                    team.city,
                    style: TextStyle(
                      color: Colors.blue[600],
                      fontSize: isMobile ? 12 : 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            // Actions
            if (isMobile)
              PopupMenuButton<String>(
                onSelected: (value) => _handleTeamAction(value, team),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('Bearbeiten'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('L�schen', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _editTeam(team),
                    icon: const Icon(Icons.edit, size: 18),
                    tooltip: 'Team bearbeiten',
                  ),
                  IconButton(
                    onPressed: () => _deleteTeam(team),
                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                    tooltip: 'Team l�schen',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTeamsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Keine Teams gefunden',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Erstellen Sie Ihr erstes Team',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showTeamDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Team hinzuf�gen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _handleTeamAction(String action, Team team) {
    switch (action) {
      case 'edit':
        _editTeam(team);
        break;
      case 'delete':
        _deleteTeam(team);
        break;
    }
  }

  void _editTeam(Team team) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TeamEditScreen(teamId: team.id),
      ),
    ).then((_) {
      _loadData();
    });
  }

  void _deleteTeam(Team team) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Team l�schen'),
        content: Text('M�chten Sie das Team "${team.name}" wirklich l�schen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('L�schen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _teamService.deleteTeam(team.id);
      if (success) {
        _loadData();
        _showSuccess('Team erfolgreich gel�scht!');
      } else {
        _showError('Fehler beim L�schen des Teams');
      }
    }
  }

  void _showTeamDialog({Team? team}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TeamFormScreen(
          team: team,
        ),
      ),
    ).then((_) {
      _loadData();
    });
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
} 