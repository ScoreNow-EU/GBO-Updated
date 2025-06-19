import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/tournament.dart';
import '../models/team.dart';
import '../services/team_service.dart';
import '../services/tournament_service.dart';
import '../widgets/custom_bracket_builder.dart';
import '../widgets/team_avatar.dart';
import '../utils/bracket_templates.dart';

class DivisionPoolsScreen extends StatefulWidget {
  final Tournament tournament;
  final List<String> selectedTeamIds;

  const DivisionPoolsScreen({
    super.key,
    required this.tournament,
    required this.selectedTeamIds,
  });

  @override
  State<DivisionPoolsScreen> createState() => _DivisionPoolsScreenState();
}

class _DivisionPoolsScreenState extends State<DivisionPoolsScreen> {
  final TeamService _teamService = TeamService();
  final TournamentService _tournamentService = TournamentService();
  
  List<Team> _allTeams = [];
  bool _isLoading = true;
  String? _selectedDivision;
  Map<String, List<Team>> _teamsByDivision = {};
  Map<String, List<String>> _poolTeams = {};
  Map<String, List<String>> _placeholderTeams = {};
  Map<String, List<CustomBracketNode>> _divisionCustomBrackets = {};
  String _selectedTopTab = 'teams'; // 'teams' or 'palette'

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    try {
      final teams = await _teamService.getTeams().first;
      final selectedTeams = teams.where((team) => 
        widget.selectedTeamIds.contains(team.id)).toList();
      
      // Group teams by division
      Map<String, List<Team>> groupedTeams = {};
      for (Team team in selectedTeams) {
        if (!groupedTeams.containsKey(team.division)) {
          groupedTeams[team.division] = [];
        }
        groupedTeams[team.division]!.add(team);
      }

      setState(() {
        _allTeams = selectedTeams;
        _teamsByDivision = _expandDivisionsWithFunTournaments(groupedTeams);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Fehler beim Laden der Teams: $e');
    }
  }

  Map<String, List<Team>> _expandDivisionsWithFunTournaments(Map<String, List<Team>> teamsByDivision) {
    final expanded = <String, List<Team>>{};
    
    for (final entry in teamsByDivision.entries) {
      final division = entry.key;
      final teams = entry.value;
      
      expanded[division] = teams;
      
      // Add Fun tournament for Senior divisions
      if (division.contains('Seniors') && teams.length >= 4) {
        final funDivision = division.replaceAll('Seniors', 'FUN');
        if (!teamsByDivision.containsKey(funDivision)) {
          expanded[funDivision] = teams;
        }
      }
    }
    
    return expanded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Divisionen & Pools'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.shade300,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _selectedDivision == null
              ? _buildDivisionSelection()
              : _buildPoolManagement(),
    );
  }

  Widget _buildDivisionSelection() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.category, color: Colors.blue, size: 24),
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
                      const SizedBox(height: 12),
                      Text(
                        'Wählen Sie eine Division aus, um Pools/Gruppen zu erstellen und Teams zuzuweisen.',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        if (_teamsByDivision.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.sports_volleyball,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Keine Teams verfügbar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fügen Sie zuerst Teams zum Turnier hinzu',
                      style: TextStyle(
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final entry = _teamsByDivision.entries.elementAt(index);
                  final division = entry.key;
                  final teams = entry.value;
                  
                  return _buildDivisionCard(division, teams);
                },
                childCount: _teamsByDivision.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDivisionCard(String division, List<Team> teams) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedDivision = division;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Division Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _getDivisionColor(division).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.group,
                    color: _getDivisionColor(division),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Division Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        division,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${teams.length} Teams',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      if (teams.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        // Show first few team names
                        Text(
                          teams.take(3).map((t) => t.name).join(', ') + 
                          (teams.length > 3 ? '...' : ''),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Arrow
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[400],
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPoolManagement() {
    final divisionTeams = _teamsByDivision[_selectedDivision] ?? [];
    final customNodes = _divisionCustomBrackets[_selectedDivision] ?? [];

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios),
                  onPressed: () {
                    setState(() {
                      _selectedDivision = null;
                    });
                  },
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _getDivisionColor(_selectedDivision!).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.group,
                    color: _getDivisionColor(_selectedDivision!),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedDivision!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '${divisionTeams.length} Teams',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Main Content
        Expanded(
          child: _buildCustomBracketView(divisionTeams, customNodes),
        ),
      ],
    );
  }



  Widget _buildCustomBracketView(List<Team> divisionTeams, List<CustomBracketNode> customNodes) {
    // Get available teams (not assigned to any pool)
    Set<String> teamsInPools = {};
    for (String poolId in _poolTeams.keys) {
      if (_isPoolIdRelatedToDivision(poolId, _selectedDivision!)) {
        teamsInPools.addAll(_poolTeams[poolId] ?? []);
      }
    }
    
    List<Team> availableTeams = divisionTeams.where((team) => 
      !teamsInPools.contains(team.id)).toList();

    return Column(
      children: [
        // Top 40% - Tabbed Section (Teams & Palette)
        Expanded(
          flex: 4,
          child: Column(
            children: [
              // Tab Headers
              Container(
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTabButton('Teams', 'teams'),
                    ),
                    Expanded(
                      child: _buildTabButton('Palette', 'palette'),
                    ),
                  ],
                ),
              ),
              // Tab Content
              Expanded(
                child: _selectedTopTab == 'teams' 
                    ? _buildTeamsTabContent(availableTeams)
                    : _buildPaletteTabContent(),
              ),
            ],
          ),
        ),
        
        // Bottom 60% - Custom Bracket Builder (Full Width)
        Expanded(
          flex: 6,
          child: Container(
            width: double.infinity,
            child: CustomBracketBuilder(
              initialNodes: customNodes,
              divisionName: _selectedDivision!,
              availableTeams: availableTeams,
              poolTeams: _poolTeams,
              allTeams: divisionTeams,
              tournament: widget.tournament,
              showLeftSidebar: false, // Hide the left sidebar since we have tabs above
              onPresetTeamsLoaded: (poolId, presetTeamIds) {
                setState(() {
                  _poolTeams[poolId] = List.from(presetTeamIds);
                  _placeholderTeams[poolId] = List.from(presetTeamIds);
                });
              },
              onTeamRemove: (poolId, teamId) {
                _removeTeamFromPool(poolId, teamId);
              },
              placeholderTeams: _placeholderTeams,
              onTeamDrop: _handleTeamDrop,
              onBracketChanged: (nodes) {
                setState(() {
                  _divisionCustomBrackets[_selectedDivision!] = nodes;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton(String title, String tabId) {
    final isSelected = _selectedTopTab == tabId;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTopTab = tabId;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.blue : Colors.grey.shade300,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.blue : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildTeamsTabContent(List<Team> availableTeams) {
    if (availableTeams.isEmpty) {
      return Container(
        color: Colors.grey.shade50,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Alle Teams zugewiesen',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        itemCount: availableTeams.length,
        itemBuilder: (context, index) {
          final team = availableTeams[index];
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TeamAvatar(
                  teamName: team.name,
                  size: 40,
                ),
                const SizedBox(height: 8),
                Text(
                  team.name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaletteTabContent() {
    final nodeTemplates = {
      'Pool': {
        'nodeType': 'pool',
        'color': Colors.purple,
        'icon': Icons.workspaces,
      },
      '1v1 Match': {
        'nodeType': 'match',
        'color': Colors.blue,
        'icon': Icons.sports_handball,
      },
      'Placement': {
        'nodeType': 'placement',
        'color': Colors.orange,
        'icon': Icons.emoji_events,
      },
    };

    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
        ),
        itemCount: nodeTemplates.length,
        itemBuilder: (context, index) {
          final entry = nodeTemplates.entries.elementAt(index);
          final name = entry.key;
          final template = entry.value;
          
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (template['color'] as Color).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    template['icon'] as IconData,
                    color: template['color'] as Color,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }



  void _handleTeamDrop(Team team, CustomBracketNode node) {
    if (node.nodeType == 'pool') {
      setState(() {
        final poolId = '${_selectedDivision}_${node.title}';
        
        // Remove team from any other pools first
        for (String existingPoolId in _poolTeams.keys.toList()) {
          if (_isPoolIdRelatedToDivision(existingPoolId, _selectedDivision!) && existingPoolId != poolId) {
            if (_poolTeams[existingPoolId]!.contains(team.id)) {
              _poolTeams[existingPoolId]!.remove(team.id);
              
              // Restore placeholder teams if needed
              if (_placeholderTeams.containsKey(existingPoolId)) {
                final placeholders = _placeholderTeams[existingPoolId]!;
                final currentTeams = _poolTeams[existingPoolId]!;
                
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
        
        // Handle placeholder replacement or add team
        if (_placeholderTeams.containsKey(poolId)) {
          final placeholders = _placeholderTeams[poolId]!;
          final currentTeams = _poolTeams[poolId]!;
          
          bool replacedPlaceholder = false;
          for (String placeholder in placeholders) {
            if (currentTeams.contains(placeholder)) {
              final index = currentTeams.indexOf(placeholder);
              currentTeams[index] = team.id;
              replacedPlaceholder = true;
              break;
            }
          }
          
          if (!replacedPlaceholder && !currentTeams.contains(team.id)) {
            currentTeams.add(team.id);
          }
        } else {
          if (!_poolTeams[poolId]!.contains(team.id)) {
            _poolTeams[poolId]!.add(team.id);
          }
        }
      });
    }
  }

  void _removeTeamFromPool(String poolId, String teamId) {
    setState(() {
      if (_poolTeams.containsKey(poolId)) {
        _poolTeams[poolId]!.remove(teamId);
        
        // Restore placeholder if needed
        if (_placeholderTeams.containsKey(poolId)) {
          final placeholders = _placeholderTeams[poolId]!;
          final currentTeams = _poolTeams[poolId]!;
          
          if (currentTeams.length < placeholders.length) {
            final availablePlaceholder = placeholders.firstWhere(
              (p) => !currentTeams.contains(p), 
              orElse: () => '',
            );
            if (availablePlaceholder.isNotEmpty) {
              currentTeams.add(availablePlaceholder);
            }
          }
        }
      }
    });
  }

  bool _isPoolIdRelatedToDivision(String poolId, String division) {
    return poolId.startsWith(division) || 
           (division.contains('Seniors') && poolId.startsWith(division.replaceAll('Seniors', 'FUN'))) ||
           (division.contains('FUN') && poolId.startsWith(division.replaceAll('FUN', 'Seniors')));
  }

  Color _getDivisionColor(String division) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.red,
      Colors.indigo,
      Colors.brown,
    ];
    
    final hash = division.hashCode.abs();
    return colors[hash % colors.length];
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}