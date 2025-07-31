import 'package:flutter/material.dart';
import '../models/tournament.dart';
import '../models/team.dart';
import '../models/court.dart';
import '../services/team_service.dart';
import '../services/tournament_service.dart';
import '../widgets/custom_bracket_builder.dart';
import 'dart:developer' as developer;
import 'dart:async'; // Add Timer import

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
  
  List<CustomBracketNode> _nodes = [];
  Map<String, List<Team>> _teamsByDivision = {};
  Map<String, List<String>> _poolTeams = {};
  Map<String, Map<String, dynamic>> _poolMetadata = {};
  String? _selectedDivision;
  bool _isLoading = true;
  
  // Auto-save related variables
  Timer? _autoSaveTimer;
  bool _isAutoSaving = false;
  String? _autoSaveStatus;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final teams = await _teamService.getTeams().first;
      final teamsByDivision = <String, List<Team>>{};
      
      for (var team in teams) {
        if (!teamsByDivision.containsKey(team.division)) {
          teamsByDivision[team.division] = [];
        }
        teamsByDivision[team.division]!.add(team);
      }
      
      setState(() {
        _teamsByDivision = teamsByDivision;
        _poolTeams = Map<String, List<String>>.from(widget.tournament.pools);
        _poolMetadata = Map<String, Map<String, dynamic>>.from(widget.tournament.poolMetadata);
        _selectedDivision = teamsByDivision.keys.isNotEmpty ? teamsByDivision.keys.first : null;
        _isLoading = false;
      });
      
      _loadNodesForDivision();
    } catch (e) {
      developer.log('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _loadNodesForDivision() {
    if (_selectedDivision == null) return;
    
    // Load existing nodes from pools or create empty nodes
    final nodes = <CustomBracketNode>[];
    final divisionPoolIds = _poolTeams.keys.where((key) => key.startsWith('${_selectedDivision}_')).toList();
    
    for (String poolId in divisionPoolIds) {
      final poolName = poolId.replaceFirst('${_selectedDivision}_', '');
      final teams = _poolTeams[poolId] ?? [];
      nodes.add(CustomBracketNode(
        id: poolId,
        title: poolName,
        nodeType: 'pool',
        x: 100,
        y: 100 + (nodes.length * 150),
        properties: {'teams': teams},
      ));
    }
    
    setState(() => _nodes = nodes);
  }

  void _onBracketChanged(List<CustomBracketNode> nodes) {
    setState(() => _nodes = nodes);
    _updatePoolTeams(nodes);
    _triggerAutoSave(); // Use auto-save instead of immediate save
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
  }

  // Auto-save functionality with debouncing
  void _triggerAutoSave() {
    // Cancel previous timer
    _autoSaveTimer?.cancel();
    
    // Start new timer for auto-save (debounce for 2 seconds)
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      _performAutoSave();
    });
  }

  Future<void> _performAutoSave() async {
    setState(() {
      _isAutoSaving = true;
      _autoSaveStatus = 'Änderungen werden gespeichert...';
    });

    try {
      // Create updated tournament with new pools and metadata
      final updatedTournament = widget.tournament.copyWith(
        pools: _poolTeams,
        poolMetadata: _poolMetadata,
      );

      await _tournamentService.updateTournament(updatedTournament);
      
      setState(() {
        _isAutoSaving = false;
        _autoSaveStatus = 'Automatisch gespeichert';
      });
      
      // Clear status after 3 seconds
      Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _autoSaveStatus = null;
          });
        }
      });
      
    } catch (e) {
      developer.log('Error auto-saving tournament: $e');
      setState(() {
        _isAutoSaving = false;
        _autoSaveStatus = 'Fehler beim Speichern';
      });
      
      // Clear error after 5 seconds
      Timer(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _autoSaveStatus = null;
          });
        }
      });
    }
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
    // Handle team dropping logic
    if (node.nodeType == 'pool') {
      final teams = List<String>.from(node.properties['teams'] ?? []);
      if (!teams.contains(team.id)) {
        teams.add(team.id);
        node.properties['teams'] = teams;
        _onBracketChanged(_nodes);
      }
    }
  }

  void _onDivisionChanged(String? division) {
    setState(() => _selectedDivision = division);
    _loadNodesForDivision();
  }

  Widget _buildDivisionSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text(
            'Division:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButton<String>(
              value: _selectedDivision,
              isExpanded: true,
              onChanged: _onDivisionChanged,
              items: _teamsByDivision.keys.map((division) {
                return DropdownMenuItem(
                  value: division,
                  child: Text(division),
                );
              }).toList(),
            ),
          ),
          
          // Auto-save status indicator
          if (_autoSaveStatus != null) ...[
            const SizedBox(width: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isAutoSaving)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  )
                else
                  Icon(
                    _autoSaveStatus!.contains('Fehler') ? Icons.error : Icons.check_circle,
                    size: 16,
                    color: _autoSaveStatus!.contains('Fehler') ? Colors.red : Colors.green,
                  ),
                const SizedBox(width: 8),
                Text(
                  _autoSaveStatus!,
                  style: TextStyle(
                    fontSize: 12,
                    color: _autoSaveStatus!.contains('Fehler') ? Colors.red : Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
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