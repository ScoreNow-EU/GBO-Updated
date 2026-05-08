import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/team.dart';
import '../services/team_service.dart';
import '../utils/responsive_helper.dart';
import '../widgets/team_avatar.dart';

import 'team_form_screen.dart';
import 'team_edit_screen.dart';
import 'team_manager_management_screen.dart';

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

    final teamsTab = isMobile ? _buildMobileLayout() : _buildDesktopLayout();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Material(
            color: Colors.grey.shade50,
            elevation: 0,
            child: const TabBar(
              labelColor: Colors.indigo,
              unselectedLabelColor: Colors.black54,
              indicatorColor: Colors.indigo,
              tabs: [
                Tab(icon: Icon(Icons.groups_2_rounded), text: 'Teams'),
                Tab(icon: Icon(Icons.supervisor_account), text: 'Team Manager'),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            teamsTab,
            const TeamManagerManagementScreen(),
          ],
        ),
      ),
    );
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade600, Colors.indigo.shade400],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.indigo.withOpacity(0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.groups_2_rounded, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Teams verwalten',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_filteredTeams.length} / ${_teams.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showTeamDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Neues Team'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.indigo.shade700,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Team oder Stadt suchen...',
          prefixIcon: Icon(Icons.search, color: Colors.indigo.shade400),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => setState(() => _searchQuery = ''),
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.indigo.shade300, width: 1.5),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
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
    final initial = team.name.isNotEmpty ? team.name[0].toUpperCase() : '?';
    final accent = _accentForTeam(team);
    final secondary = team.secondaryColor != null
        ? Color(team.secondaryColor!)
        : accent.withOpacity(0.85);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _editTeam(team),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Accent stripe + avatar stack
              Container(
                width: 4,
                height: 56,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: isMobile ? 50 : 46,
                height: isMobile ? 50 : 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [secondary, accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.center,
                child: (team.logoUrl != null && team.logoUrl!.isNotEmpty)
                    ? ClipOval(
                        child: Image.network(
                          team.logoUrl!,
                          fit: BoxFit.cover,
                          width: isMobile ? 50 : 46,
                          height: isMobile ? 50 : 46,
                          errorBuilder: (_, __, ___) => Text(
                            initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    : Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              // Team info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      style: TextStyle(
                        fontSize: isMobile ? 17 : 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _chip(Icons.location_on_outlined,
                            '${team.city}, ${team.bundesland}'),
                        _chip(Icons.group_outlined,
                            '${team.rosterPlayerIds.length} Spieler'),
                        if ((team.teamManager ?? '').isNotEmpty)
                          _chip(Icons.person_outline, team.teamManager!),
                      ],
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
                          Text('Löschen',
                              style: TextStyle(color: Colors.red)),
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
                      icon: Icon(Icons.edit_outlined,
                          size: 20, color: Colors.indigo.shade400),
                      tooltip: 'Team bearbeiten',
                    ),
                    IconButton(
                      onPressed: () => _deleteTeam(team),
                      icon: Icon(Icons.delete_outline,
                          size: 20, color: Colors.red.shade400),
                      tooltip: 'Team löschen',
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _accentForTeam(Team team) {
    if (team.primaryColor != null) return Color(team.primaryColor!);
    const palette = <Color>[
      Color(0xFF3F51B5),
      Color(0xFF009688),
      Color(0xFFE91E63),
      Color(0xFFFF9800),
      Color(0xFF4CAF50),
      Color(0xFF9C27B0),
      Color(0xFF2196F3),
      Color(0xFFF44336),
    ];
    final hash = team.id.hashCode.abs();
    return palette[hash % palette.length];
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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