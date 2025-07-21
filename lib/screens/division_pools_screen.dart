import 'package:flutter/material.dart';
import '../models/tournament.dart';
import '../models/team.dart';
import '../services/team_service.dart';
import '../services/tournament_service.dart';
import '../widgets/custom_bracket_builder.dart';
import 'dart:developer' as developer;

class DivisionPoolsScreen extends StatefulWidget {
  final Tournament tournament;

  const DivisionPoolsScreen({
    super.key,
    required this.tournament,
  });

  @override
  State<DivisionPoolsScreen> createState() => _DivisionPoolsScreenState();
}

class _DivisionPoolsScreenState extends State<DivisionPoolsScreen> {
  final TeamService _teamService = TeamService();
  final TournamentService _tournamentService = TournamentService();
  
  // State variables
  bool _isLoading = true;
  String? _selectedDivision;
  Map<String, List<Team>> _teamsByDivision = {};
  
  // Pool management
  Map<String, List<String>> _poolTeams = {};
  Map<String, Map<String, dynamic>> _poolMetadata = {};
  List<CustomBracketNode> _nodes = [];
  
  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    try {
      setState(() => _isLoading = true);
      
      // Load all teams and filter for this tournament
      final allTeams = await _teamService.getTeams().first;
      final teams = allTeams.where((team) => widget.tournament.teamIds.contains(team.id)).toList();
      
      // Group teams by division
      final Map<String, List<Team>> groupedTeams = {};
      for (final team in teams) {
        if (!groupedTeams.containsKey(team.division)) {
          groupedTeams[team.division] = [];
        }
        groupedTeams[team.division]!.add(team);
      }
      
      setState(() {
        _teamsByDivision = groupedTeams;
        _isLoading = false;
        
        // Auto-select first division if none selected
        if (_selectedDivision == null && groupedTeams.isNotEmpty) {
          _selectedDivision = groupedTeams.keys.first;
        }
      });
    } catch (e) {
      developer.log('Error loading teams: $e');
      setState(() => _isLoading = false);
    }
  }

  void _onDivisionChanged(String? newDivision) {
    if (newDivision != _selectedDivision) {
      setState(() {
        _selectedDivision = newDivision;
        // Clear nodes when division changes
        _nodes = [];
      });
    }
  }

  void _onBracketChanged(List<CustomBracketNode> nodes) {
    setState(() => _nodes = nodes);
    _updatePoolTeams(nodes);
  }

  void _updatePoolTeams(List<CustomBracketNode> nodes) {
    if (_selectedDivision == null) return;

    // Create new mutable maps for the updated data
    final updatedPoolTeams = <String, List<String>>{};
    final updatedPoolMetadata = <String, Map<String, dynamic>>{};
    
    // Add teams from nodes
    for (var node in nodes) {
      if (node.nodeType == 'pool') {
        final poolId = '${_selectedDivision}_${node.title}';
        final teams = List<String>.from(node.properties['teams'] ?? []);
        updatedPoolTeams[poolId] = teams;
        updatedPoolMetadata[poolId] = {
          'gamesGenerated': widget.tournament.poolMetadata[poolId]?['gamesGenerated'] ?? false,
          'gameCount': widget.tournament.poolMetadata[poolId]?['gameCount'] ?? 0,
        };
      }
    }

    setState(() {
      _poolTeams = updatedPoolTeams;
      _poolMetadata = updatedPoolMetadata;
    });
    _saveTournament();
  }

  Future<void> _saveTournament() async {
    if (_selectedDivision == null) return;

    try {
      // Create updated tournament with new pools and metadata
      final updatedTournament = widget.tournament.copyWith(
        pools: _poolTeams,
        poolMetadata: _poolMetadata,
      );

      await _tournamentService.updateTournament(updatedTournament);
    } catch (e) {
      developer.log('Error saving tournament: $e');
    }
  }

  void _onTeamDrop(Team team, CustomBracketNode node) {
    if (_selectedDivision == null) return;

    // Get current teams in the node
    final currentTeams = List<String>.from(node.properties['teams'] ?? []);
    
    // Add team if not already present
    if (!currentTeams.contains(team.id)) {
      currentTeams.add(team.id);
      
      // Update node properties
      final updatedNode = node.copyWith(
        properties: {
          ...node.properties,
          'teams': currentTeams,
        },
      );
      
      // Find and update the node in the list
      final nodeIndex = _nodes.indexWhere((n) => n.id == node.id);
      if (nodeIndex != -1) {
        final updatedNodes = List<CustomBracketNode>.from(_nodes);
        updatedNodes[nodeIndex] = updatedNode;
        _onBracketChanged(updatedNodes);
      }
    }
  }

  Widget _buildDivisionSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.category, color: Colors.purple),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedDivision,
              decoration: const InputDecoration(
                labelText: 'Division auswählen',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
              items: _teamsByDivision.keys.map((division) {
                return DropdownMenuItem(
                  value: division,
                  child: Text(division),
                );
              }).toList(),
              onChanged: _onDivisionChanged,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildDivisionSelector(),
          Expanded(
            child: CustomBracketBuilder(
              initialNodes: _nodes,
              onBracketChanged: _onBracketChanged,
              divisionName: _selectedDivision ?? '',
              availableTeams: _selectedDivision != null ? _teamsByDivision[_selectedDivision] ?? [] : [],
              onTeamDrop: _onTeamDrop,
              poolTeams: _poolTeams,
              allTeams: _selectedDivision != null ? _teamsByDivision[_selectedDivision] ?? [] : [],
              tournament: widget.tournament,
              showLeftSidebar: true,
              divisions: _teamsByDivision.keys.toList(),
              selectedDivision: _selectedDivision,
              onDivisionChanged: _onDivisionChanged,
            ),
          ),
        ],
      ),
    );
  }
}