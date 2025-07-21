import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';
import '../models/tournament.dart';
import '../models/team.dart';
import '../models/game.dart';  // This should contain GameType and GameStatus
import '../services/team_service.dart';
import '../services/tournament_service.dart';
import '../services/game_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added for FirebaseFirestore
import 'package:flutter/rendering.dart'; // Added for CustomPaint
import 'dart:math'; // Added for pow and log functions

// Custom painter for bracket preview
class BracketPreviewPainter extends CustomPainter {
  final int teamCount;
  final Map<int, String> roundBestOf;

  BracketPreviewPainter({
    required this.teamCount,
    required this.roundBestOf,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.shade700
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final linePaint = Paint()
      ..color = Colors.grey[700]!
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final bgPaint = Paint()
      ..color = Colors.blue.shade100.withOpacity(0.5);

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Calculate dimensions
    final rounds = _calculateRounds(teamCount);
    final matchHeight = 60.0;
    final matchWidth = 160.0;
    final horizontalGap = (size.width - (rounds * matchWidth)) / (rounds + 1);
    final startX = horizontalGap;

    // Draw each round
    for (int round = 0; round < rounds; round++) {
      final matchesInRound = _getMatchesInRound(teamCount, round);
      final verticalSpace = size.height - (matchHeight * matchesInRound);
      final verticalGap = verticalSpace / (matchesInRound + 1);
      
      for (int match = 0; match < matchesInRound; match++) {
        // Calculate match position
        final x = startX + (round * (matchWidth + horizontalGap));
        final y = verticalGap + match * (matchHeight + verticalGap);

        // Draw match box
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, matchWidth, matchHeight),
          const Radius.circular(8),
        );
        
        canvas.drawRRect(rect, bgPaint);
        canvas.drawRRect(rect, paint);

        // Draw round name and match number
        final roundName = round == rounds - 1 
            ? 'Finale'
            : round == rounds - 2 
                ? 'Halbfinale'
                : round == rounds - 3 
                    ? 'Viertelfinale'
                    : '${pow(2, rounds - round - 1).toInt()}tel Finale';

        textPainter.text = TextSpan(
          children: [
            TextSpan(
              text: '$roundName\n',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade700,
              ),
            ),
            TextSpan(
              text: 'Match ${match + 1}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade600,
              ),
            ),
          ],
        );
        textPainter.layout(maxWidth: matchWidth - 16);
        
        // Center the text in the box
        final textX = x + (matchWidth - textPainter.width) / 2;
        final textY = y + (matchHeight - textPainter.height) / 2;
        textPainter.paint(canvas, Offset(textX, textY));

        // Draw connection lines to next round
        if (round < rounds - 1) {
          final nextX = x + matchWidth;
          final nextY = y + matchHeight / 2;
          final nextMatchIndex = match ~/ 2;
          final nextMatchesInRound = _getMatchesInRound(teamCount, round + 1);
          final nextVerticalSpace = size.height - (matchHeight * nextMatchesInRound);
          final nextVerticalGap = nextVerticalSpace / (nextMatchesInRound + 1);
          final nextMatchY = nextVerticalGap + nextMatchIndex * (matchHeight + nextVerticalGap) + matchHeight / 2;
          final nextRoundX = nextX + horizontalGap;
          final controlPointX = nextX + horizontalGap / 2;

          // Draw curved connection lines
          final path = Path()
            ..moveTo(nextX, nextY)
            ..cubicTo(
              controlPointX, nextY,
              controlPointX, nextMatchY,
              nextRoundX, nextMatchY,
            );

          canvas.drawPath(path, linePaint);
        }
      }
    }
  }

  int _calculateRounds(int teamCount) {
    return (log(teamCount) / log(2)).ceil();
  }

  int _getMatchesInRound(int teamCount, int round) {
    final matchesInRound = teamCount ~/ pow(2, round + 1);
    return max(1, matchesInRound);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class NewDivisionPoolsScreen extends StatefulWidget {
  final Tournament tournament;

  const NewDivisionPoolsScreen({
    super.key,
    required this.tournament,
  });

  @override
  State<NewDivisionPoolsScreen> createState() => _NewDivisionPoolsScreenState();
}

class _NewDivisionPoolsScreenState extends State<NewDivisionPoolsScreen> {
  // Add GameService to the class
  final TeamService _teamService = TeamService();
  final TournamentService _tournamentService = TournamentService();
  final GameService _gameService = GameService();
  
  // State variables
  bool _isLoading = true;
  String? _selectedDivision;
  Map<String, List<Team>> _teamsByDivision = {};
  bool _isSidebarCollapsed = false;
  List<Map<String, dynamic>> _createdNodes = [];
  bool _showTeams = false;
  
  // Team position tracking
  Map<String, String> _teamPositions = {}; // teamId -> "sidebar" or "pool_[poolId]"
  
  // SharedPreferences keys for auto-save
  static const String _keySelectedDivision = 'division_pools_selected_division';
  static const String _keyCreatedNodes = 'division_pools_created_nodes';
  static const String _keyTeamPositions = 'division_pools_team_positions';
  static const String _keyTournamentId = 'division_pools_tournament_id';
  
  // Division-specific state
  Map<String, List<Map<String, dynamic>>> _divisionNodes = {};
  Map<String, Map<String, String>> _divisionTeamPositions = {};

  // Add state for menu visibility
  Map<String, bool> _showPoolMenu = {};
  // Add state for text visibility
  Map<String, bool> _showPoolText = {};
  
  @override
  void initState() {
    super.initState();
    print('InitState called');
    _loadTeams();
  }

  Future<void> _loadSavedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get saved tournament ID to ensure we're loading state for the correct tournament
      final savedTournamentId = prefs.getString(_keyTournamentId);
      if (savedTournamentId != widget.tournament.id) {
        // If tournament changed, clear saved state
        await _clearSavedState();
        return;
      }
      
      // Load selected division
      final savedDivision = prefs.getString(_keySelectedDivision);
      if (savedDivision != null) {
        _selectedDivision = savedDivision;
      }
      
      // Load division-specific nodes
      final divisionNodesJson = prefs.getString(_keyCreatedNodes);
      if (divisionNodesJson != null) {
        final divisionNodesData = json.decode(divisionNodesJson) as Map<String, dynamic>;
        _divisionNodes = divisionNodesData.map((division, nodes) {
          final nodesList = (nodes as List).map((node) {
            final nodeData = Map<String, dynamic>.from(node);
            
            // Convert team data back to Team objects
            if (nodeData['teams'] != null) {
              final teamsList = nodeData['teams'] as List;
              nodeData['teams'] = teamsList.map((teamData) {
                if (teamData != null) {
                  return Team(
                    id: teamData['id'],
                    name: teamData['name'],
                    teamManager: teamData['teamManager'],
                    logoUrl: teamData['logoUrl'],
                    city: teamData['city'],
                    bundesland: teamData['bundesland'],
                    division: teamData['division'],
                    clubId: teamData['clubId'],
                    rosterPlayerIds: List<String>.from(teamData['rosterPlayerIds']),
                    createdAt: DateTime.parse(teamData['createdAt']),
                  );
                }
                return null;
              }).toList();
            }
            
            return nodeData;
          }).toList();
          return MapEntry(division, nodesList);
        });
      }
      
      // Load division-specific team positions
      final divisionTeamPositionsJson = prefs.getString(_keyTeamPositions);
      if (divisionTeamPositionsJson != null) {
        _divisionTeamPositions = Map<String, Map<String, String>>.from(
          json.decode(divisionTeamPositionsJson).map((key, value) => MapEntry(key, Map<String, String>.from(value)))
        );
      }
      
      // Set current division state
      if (_selectedDivision != null) {
        _createdNodes = _divisionNodes[_selectedDivision] ?? [];
        _teamPositions = _divisionTeamPositions[_selectedDivision] ?? {};
      }

      // Load pool game states after nodes are created
      _loadPoolGameStates();
      
    } catch (e) {
      print('Error loading saved state: $e');
      // If loading fails, start fresh
      _selectedDivision = null;
      _createdNodes = [];
      _teamPositions = {};
    }
  }

  void _loadPoolGameStates() {
    print('Loading pool game states...');
    print('Created nodes: ${_createdNodes.length}');
    print('Tournament pools: ${widget.tournament.pools}');
    print('Tournament pool metadata: ${widget.tournament.poolMetadata}');
    
    if (_createdNodes.isNotEmpty == true) {
      for (final node in _createdNodes) {
        if (node['type'] == 'pool') {
          final poolId = node['id'];
          print('Checking pool $poolId');
          
          final metadata = widget.tournament.poolMetadata[poolId];
          print('Pool metadata for $poolId: $metadata');
          
          final isGenerated = metadata?['gamesGenerated'] == true;
          final gameCount = metadata?['gameCount'] as int? ?? 0;
          
          print('Is generated: $isGenerated');
          print('Game count: $gameCount');
          
          if (isGenerated) {
            print('Setting state for pool $poolId');
            node['gamesGenerated'] = true;
            node['gameCount'] = gameCount;
          }
        }
      }
      setState(() {});
    }
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
      
      // Load saved state if exists
      await _loadSavedState();
      
      setState(() {
        _teamsByDivision = groupedTeams;
        _isLoading = false;
        
        // Auto-select first division if none selected and no saved state
        if (_selectedDivision == null && groupedTeams.isNotEmpty) {
          _selectedDivision = groupedTeams.keys.first;
        }
        
        // Initialize team positions if not loaded from saved state
        if (_selectedDivision != null && _teamPositions.isEmpty) {
          final divisionTeams = _teamsByDivision[_selectedDivision] ?? [];
          for (final team in divisionTeams) {
            _teamPositions[team.id] = 'sidebar';
          }
          _divisionTeamPositions[_selectedDivision!] = Map.from(_teamPositions);
          }
        
          _showTeams = !_isSidebarCollapsed;
      });
    } catch (e) {
      print('Error loading teams: $e');
      setState(() => _isLoading = false);
    }
  }

  // Auto-save methods
  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save tournament ID to ensure we restore state for the correct tournament
      await prefs.setString(_keyTournamentId, widget.tournament.id);
      
      // Save selected division
      if (_selectedDivision != null) {
        await prefs.setString(_keySelectedDivision, _selectedDivision!);
        
        // Update division-specific state with current state
        _divisionNodes[_selectedDivision!] = List<Map<String, dynamic>>.from(_createdNodes);
        _divisionTeamPositions[_selectedDivision!] = Map.from(_teamPositions);
      }
      
      // Save division-specific nodes - Convert Team objects to maps
      final divisionNodesData = _divisionNodes.map((division, nodes) {
        final nodesData = nodes.map((node) {
          final nodeData = Map<String, dynamic>.from(node);
          
          // Convert Team objects in 'teams' property to maps
          if (nodeData['teams'] is List) {
            final teams = nodeData['teams'] as List;
            nodeData['teams'] = teams.map((team) {
              if (team is Team) {
                return {
                  'id': team.id,
                  'name': team.name,
                  'teamManager': team.teamManager,
                  'logoUrl': team.logoUrl,
                  'city': team.city,
                  'bundesland': team.bundesland,
                  'division': team.division,
                  'clubId': team.clubId,
                  'rosterPlayerIds': team.rosterPlayerIds,
                  'createdAt': team.createdAt.toIso8601String(),
                };
              }
              return null; // Return null for empty slots
            }).toList();
          }
          
          return nodeData;
        }).toList();
        
        return MapEntry(division, nodesData);
      });
      
      final divisionNodesJson = json.encode(divisionNodesData);
      await prefs.setString(_keyCreatedNodes, divisionNodesJson);
      
      // Save division-specific team positions
      final divisionTeamPositionsJson = json.encode(_divisionTeamPositions);
      await prefs.setString(_keyTeamPositions, divisionTeamPositionsJson);
      
    } catch (e) {
      // If saving fails, continue silently
    }
  }

  Future<void> _clearSavedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyTournamentId);
      await prefs.remove(_keySelectedDivision);
      await prefs.remove(_keyCreatedNodes);
      await prefs.remove(_keyTeamPositions);
      
      // Clear in-memory state
      _divisionNodes.clear();
      _divisionTeamPositions.clear();
    } catch (e) {
      // If clearing fails, continue silently
    }
  }

  Future<void> _saveTournament() async {
    try {
      // Get current tournament data
      final tournament = widget.tournament;
      
      // Create a map of pool teams from the team positions
      Map<String, List<String>> poolTeams = {};
      Map<String, Map<String, dynamic>> poolMetadata = {};
      Map<String, CustomBracketStructure> customBrackets = {};

      // Process team positions for both pools and KO rounds
      _teamPositions.forEach((teamId, position) {
        if (position.startsWith('pool_')) {
          final poolId = position.substring(5); // Remove 'pool_' prefix
          if (!poolTeams.containsKey(poolId)) {
            poolTeams[poolId] = [];
            poolMetadata[poolId] = {
              'gamesGenerated': tournament.poolMetadata[poolId]?['gamesGenerated'] ?? false,
              'gameCount': tournament.poolMetadata[poolId]?['gameCount'] ?? 0,
            };
          }
          poolTeams[poolId]!.add(teamId);
        }
      });

      // Create custom bracket structure for the current division
      if (_selectedDivision != null) {
        final nodes = _createdNodes.map((node) {
          // Convert teams list to proper format
          List<Team?> teams = List<Team?>.from(node['teams'] ?? []);
          
          return CustomBracketNode(
            id: node['id'],
            nodeType: node['type'],
            title: node['name'] ?? '',
            matchId: node['matchId'],
            x: node['x']?.toDouble() ?? 0.0,
            y: node['y']?.toDouble() ?? 0.0,
            properties: {
              ...node,
              'teams': teams.map((team) {
                if (team == null) return null;
                return team.id;
              }).toList(),
            },
          );
        }).toList();

        customBrackets[_selectedDivision!] = CustomBracketStructure(
          nodes: nodes,
          divisionName: _selectedDivision!,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
      
      // Create updated tournament with new pools and brackets
      final updatedTournament = tournament.copyWith(
        pools: poolTeams,
        poolMetadata: poolMetadata,
        customBrackets: customBrackets,
      );

      await _tournamentService.updateTournament(updatedTournament);
    } catch (e) {
      print('Error saving tournament: $e');
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        title: const Text('Fehler'),
        description: Text('Fehler beim Speichern: $e'),
        autoCloseDuration: const Duration(seconds: 3),
      );
    }
  }

  void _onDivisionChanged(String? newDivision) {
    if (newDivision != _selectedDivision) {
      // Save current division state before switching
      if (_selectedDivision != null) {
        _divisionNodes[_selectedDivision!] = List<Map<String, dynamic>>.from(_createdNodes);
        _divisionTeamPositions[_selectedDivision!] = Map.from(_teamPositions);
      }
      
      setState(() {
        _selectedDivision = newDivision;
        
        // Load saved state for new division OR start fresh
        if (newDivision != null) {
          if (_divisionNodes.containsKey(newDivision)) {
            // Restore saved state for this division
            _createdNodes = List<Map<String, dynamic>>.from(_divisionNodes[newDivision]!);
            _teamPositions = Map.from(_divisionTeamPositions[newDivision]!);
          } else {
            // Start fresh for this division
            _createdNodes.clear();
            _teamPositions.clear();
            
            // Initialize all teams to sidebar
            final divisionTeams = _teamsByDivision[newDivision] ?? [];
            for (final team in divisionTeams) {
              _teamPositions[team.id] = 'sidebar';
            }
          }
        } else {
          _createdNodes.clear();
          _teamPositions.clear();
        }
        
        // Show teams if sidebar is expanded
        _showTeams = !_isSidebarCollapsed;
      });
      
      _saveState();
      _saveTournament();
    }
  }

  void _toggleSidebar() {
    setState(() {
      if (!_isSidebarCollapsed) {
        // Collapsing: hide teams immediately, then animate
        _showTeams = false;
        _isSidebarCollapsed = true;
      } else {
        // Expanding: animate first, then show teams after delay
        _isSidebarCollapsed = false;
        // Don't show teams yet - wait for animation to complete
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted && !_isSidebarCollapsed) {
            setState(() {
              _showTeams = true;
            });
          }
        });
      }
    });
    _saveState(); // Auto-save after sidebar toggle
  }

  Widget _buildDivisionSelector() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              const Icon(Icons.category, color: Colors.purple),
              const SizedBox(width: 16),
              SizedBox(
                width: 250,
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
        ),
        const Divider(height: 1, color: Colors.grey),
      ],
    );
  }

  Widget _buildTeamNavbar() {
    if (_selectedDivision == null) {
      return const SizedBox.shrink();
    }

    final teams = _getAvailableTeams();
    
    if (teams.isEmpty) {
      return Container(
        padding: _isSidebarCollapsed 
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 12)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.grey[50],
                child: _isSidebarCollapsed || !_showTeams
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    children: [
                      Icon(Icons.groups, color: Colors.grey[600], size: 20),
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '0',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  IconButton(
                    icon: Icon(
                      _isSidebarCollapsed ? Icons.chevron_right : Icons.chevron_left,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                    onPressed: () {
                      _toggleSidebar();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              )
            : Row(
                children: [
                  Icon(Icons.groups, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Keine Teams (0)',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                    onPressed: () {
                      _toggleSidebar();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
      );
    }

    return Column(
      children: [
        Container(
          padding: _isSidebarCollapsed 
              ? const EdgeInsets.symmetric(horizontal: 8, vertical: 12)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.grey[50],
          child: _isSidebarCollapsed || !_showTeams
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      children: [
                        Icon(Icons.groups, color: Colors.blue[600], size: 20),
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.blue[600],
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${teams.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      icon: Icon(
                        _isSidebarCollapsed ? Icons.chevron_right : Icons.chevron_left,
                        color: Colors.blue[600],
                        size: 20,
                      ),
                      onPressed: () {
                        _toggleSidebar();
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Icon(Icons.groups, color: Colors.blue[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Teams (${teams.length})',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.chevron_left,
                        color: Colors.blue[600],
                        size: 20,
                      ),
                      onPressed: () {
                        _toggleSidebar();
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
        ),
        if (_showTeams)
          Container(
            color: Colors.white,
            child: Column(
              children: teams.asMap().entries.map((entry) {
              final index = entry.key;
              final team = entry.value;
              final position = index + 1;
              
              return Draggable<Map<String, dynamic>>(
                data: {
                  'team': team,
                  'origin': 'sidebar',
                  'originIndex': index,
                },
                feedback: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 200,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: _getDivisionColor(team.division),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: Text(
                              '$position',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            team.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                childWhenDragging: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Text(
                            '$position',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          team.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.drag_indicator, color: Colors.grey[300], size: 14),
                    ],
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _getDivisionColor(team.division),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Text(
                            '$position',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              team.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.drag_indicator, color: Colors.grey[400], size: 14),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Color _getDivisionColor(String division) {
    if (division.contains('Women')) {
      if (division.contains('FUN')) return Colors.pink;
      if (division.contains('U14')) return Colors.purple;
      if (division.contains('U16')) return Colors.deepPurple;
      if (division.contains('U18')) return Colors.indigo;
      return Colors.blue; // Women's Seniors
    } else {
      if (division.contains('FUN')) return Colors.orange;
      if (division.contains('U14')) return Colors.green;
      if (division.contains('U16')) return Colors.teal;
      if (division.contains('U18')) return Colors.cyan;
      return Colors.red; // Men's Seniors
    }
  }

  Widget _buildRoundColumns() {
    // Find the last column with content
    int lastColumnWithContent = -1;
    for (var node in _createdNodes) {
      final column = node['column'] as int;
      if (column > lastColumnWithContent) {
        lastColumnWithContent = column;
      }
    }

    // Calculate columns to show
    final List<Widget> columns = [];
    
    // If no nodes exist, show just + button and positions
    if (lastColumnWithContent == -1) {
      columns.addAll([
        _buildRoundColumn('Runde 1', 0), // Will show + button
        const SizedBox(width: 16),
        _buildFinalPositionsCard(),
      ]);
    } else {
      // Show columns with content plus one empty column with + button
      for (int i = 0; i <= lastColumnWithContent + 1; i++) {
        columns.add(_buildRoundColumn('Runde ${i + 1}', i));
        columns.add(const SizedBox(width: 16));
      }
      
      // Add final positions card
      columns.add(_buildFinalPositionsCard());
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Turnier-Aufbau: $_selectedDivision',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          // Rounds layout
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: columns,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalPositionsCard() {
    // Get total number of teams in the division
    final teams = _teamsByDivision[_selectedDivision] ?? [];
    final int totalTeams = teams.length;

    return Container(
      width: 300,
      child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.emoji_events, color: Colors.amber[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Finale Platzierungen',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[700],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Position slots
                ...List.generate(totalTeams, (index) {
                  final position = index + 1;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.amber[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: Text(
                              '$position',
                              style: TextStyle(
                                color: Colors.amber[900],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                ],
              ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

    Widget _buildRoundColumn(String title, int roundIndex) {
    final columnNodes = _createdNodes.where((node) => node['column'] == roundIndex).toList();
    final hasContentInPreviousColumn = _createdNodes.any((node) => node['column'] == roundIndex - 1);
    
    // Show add button if:
    // - This is column 0 (first column), OR
    // - Previous column has content
    final bool showAddButton = roundIndex == 0 || hasContentInPreviousColumn;
    
    return Container(
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Content area with scrolling
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Display created nodes for this column
                    ...columnNodes.map((node) => _buildNodeWidget(node)).toList(),
                    // Add node button if applicable
                    if (showAddButton)
                      _buildAddNodeButton(roundIndex),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddNodeButton(int columnIndex) {
    return Container(
      width: double.infinity,
      height: 40,
      margin: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton(
        onPressed: () => _showCreateNodeDialog(columnIndex),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[50],
          foregroundColor: Colors.blue[700],
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.blue.shade200, width: 2),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Icon(Icons.add, size: 24, color: Colors.blue[700]),
      ),
    );
  }

  Widget _buildNodeWidget(Map<String, dynamic> node) {
    if (node['type'] == 'pool') {
      return _buildPoolWidget(node);
    } else if (node['type'] == 'ko') {
      return _buildKORoundWidget(node);
    }
    return Container();
  }

  Widget _buildPoolWidget(Map<String, dynamic> pool) {
    String gameModeText = pool['gameMode'] == 'single_round_robin' 
        ? 'Einfache Runde' 
        : 'Hin- und Rückspiel';
    
    // Load game generation state from tournament metadata
    final metadata = widget.tournament.poolMetadata[pool['id']] ?? {};
    final bool gamesGenerated = metadata['gamesGenerated'] ?? false;
    final int gameCount = metadata['gameCount'] ?? 0;
    
    // Update pool state without setState
    pool['gamesGenerated'] = gamesGenerated;
    pool['gameCount'] = gameCount;
    
    // Also update the node in _createdNodes
    final nodeIndex = _createdNodes.indexWhere((node) => node['id'] == pool['id']);
    if (nodeIndex != -1) {
      _createdNodes[nodeIndex]['gamesGenerated'] = gamesGenerated;
      _createdNodes[nodeIndex]['gameCount'] = gameCount;
    }

    // Initialize menu state if not exists
    _showPoolMenu.putIfAbsent(pool['id'], () => false);
    _showPoolText.putIfAbsent(pool['id'], () => true);

    // Calculate height based on number of teams
    final int teamCount = pool['teamCount'] as int;
    final double baseHeight = 160.0; // Header + info + table header + padding
    final double teamRowHeight = 50.0;
    final double totalHeight = baseHeight + (teamCount * teamRowHeight);
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: totalHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Pool Menu
            if (_showPoolMenu[pool['id']]!)
              Positioned(
                left: 0,
                top: 0,
                width: 268, // Match main card width (300 - 16*2 padding)
                height: totalHeight,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Menu header
                      Row(
                        children: [
                          Icon(Icons.sports_volleyball, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Pool Menü',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.blue[700]),
                            onPressed: () {
                              setState(() {
                                _showPoolText[pool['id']] = false;
                              });
                              Future.delayed(const Duration(milliseconds: 150), () {
                                setState(() {
                                  _showPoolMenu[pool['id']] = false;
                                });
                                Future.delayed(const Duration(milliseconds: 300), () {
                                  setState(() {
                                    _showPoolText[pool['id']] = true;
                                  });
                                });
                              });
                            },
                          ),
                        ],
                      ),
                      const Divider(),
                      // Menu items
                      ListTile(
                        leading: const Icon(Icons.delete_outline, color: Colors.red),
                        title: const Text('Pool löschen'),
                        onTap: () => _deletePool(pool['id']),
                      ),
                      ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: const Text('Pool bearbeiten'),
                        onTap: () {
                          setState(() {
                            _showPoolText[pool['id']] = false;
                          });
                          Future.delayed(const Duration(milliseconds: 150), () {
                            setState(() {
                              _showPoolMenu[pool['id']] = false;
                            });
                            Future.delayed(const Duration(milliseconds: 300), () {
                              setState(() {
                                _showPoolText[pool['id']] = true;
                              });
                            });
                          });
                          // TODO: Implement pool editing
                        },
                      ),
                    ],
                  ),
                ),
              ),
            // Main Pool Content
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              left: _showPoolMenu[pool['id']]! ? 300 : 0,
              right: 0,
              top: 0,
              height: totalHeight,
              child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pool header
          Row(
            children: [
              Icon(Icons.group_work, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Expanded(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: _showPoolText[pool['id']]! ? 1.0 : 0.0,
                child: Text(
                  pool['name'],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.more_horiz, color: Colors.blue[700]),
                          onPressed: () {
                            setState(() {
                              _showPoolText[pool['id']] = false;
                            });
                            Future.delayed(const Duration(milliseconds: 150), () {
                              setState(() {
                                _showPoolMenu[pool['id']] = true;
                              });
                            });
                          },
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Pool info
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: _showPoolText[pool['id']]! ? 1.0 : 0.0,
                      child: Text(
            '${pool['teamCount']} Teams • $gameModeText',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue[600],
                        ),
            ),
          ),
          const SizedBox(height: 12),
          // Pool table
                    Expanded(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: _showPoolText[pool['id']]! ? 1.0 : 0.0,
                        child: _buildPoolTable(pool),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        ),
      ),
    );
  }

  Widget _buildPoolTable(Map<String, dynamic> pool) {
    List<Team?> poolTeams = List<Team?>.from(pool['teams'] ?? []);
    int filledTeamCount = poolTeams.where((team) => team != null).length;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Team',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Spiele',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Punkte',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          // Team rows
          ...List.generate(pool['teamCount'] as int, (index) {
            final team = index < poolTeams.length ? poolTeams[index] : null;
            
            return DragTarget<Map<String, dynamic>>(
              onWillAccept: (data) => data != null && (data['origin'] == 'sidebar' || data['origin'] == 'pool'),
              onAccept: (dragData) {
                _handleTeamDrop(pool['id'], dragData, index);
              },
              builder: (context, candidateData, rejectedData) {
                final isHighlighted = candidateData.isNotEmpty;
                
                return Container(
                  decoration: BoxDecoration(
                    color: isHighlighted ? Colors.blue[50] : Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[200]!),
                      ),
                    ),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: team != null
                            ? Draggable<Map<String, dynamic>>(
                                data: {
                                  'team': team,
                                  'origin': 'pool',
                                  'originPoolId': pool['id'],
                                  'originIndex': index,
                                },
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: Container(
                                    width: 120,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[100],
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      team.name,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                child: Text(
                                  team.name,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                            : Text(
                                'Team hier ablegen...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                      ),
                      Expanded(
                        child: Text(
                          '0/0',
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '0',
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }),
          // Generate games button
          if (filledTeamCount >= 2)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: TextButton.icon(
                onPressed: () => _showGenerateGamesDialog(pool),
                icon: Icon(
                  pool['gamesGenerated'] == true ? Icons.refresh : Icons.sports_volleyball,
                  color: pool['gamesGenerated'] == true ? Colors.orange[700] : Colors.blue[700],
                ),
                label: Text(
                  pool['gamesGenerated'] == true
                    ? '${pool['gameCount']} Spiele neu generieren'
                    : 'Spiele generieren',
                  style: TextStyle(
                    color: pool['gamesGenerated'] == true ? Colors.orange[700] : Colors.blue[700],
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: pool['gamesGenerated'] == true ? Colors.orange[700] : Colors.blue[700],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleTeamDrop(String targetPoolId, Map<String, dynamic> dragData, int targetIndex) {
    setState(() {
      Team droppedTeam = dragData['team'];
      String origin = dragData['origin'];
      
      // Update team position
      _teamPositions[droppedTeam.id] = 'pool_${_selectedDivision}_$targetPoolId';
      
      // Update pool teams in nodes
      final targetPoolIndex = _createdNodes.indexWhere((node) => node['id'] == targetPoolId);
      if (targetPoolIndex != -1) {
      List<Team?> targetPoolTeams = List<Team?>.from(_createdNodes[targetPoolIndex]['teams'] ?? []);
      
      // Ensure the target list is long enough
      while (targetPoolTeams.length <= targetIndex) {
        targetPoolTeams.add(null);
      }
      
        targetPoolTeams[targetIndex] = droppedTeam;
        _createdNodes[targetPoolIndex]['teams'] = targetPoolTeams;
      }
    });
    
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.fillColored,
      title: Text('Team verschoben'),
      description: Text('${dragData['team'].name} wurde erfolgreich verschoben'),
      autoCloseDuration: const Duration(seconds: 2),
    );
    
    _saveState();
    _saveTournament();
  }

  void _moveTeamToSidebar(Map<String, dynamic> dragData) {
    setState(() {
      Team team = dragData['team'];
      String origin = dragData['origin'];
      
      // Update team position
      _teamPositions[team.id] = 'sidebar';
      
      // Remove team from source node
      if (origin == 'pool') {
        String originPoolId = dragData['originPoolId'];
        int originIndex = dragData['originIndex'];
        
        final originPoolIndex = _createdNodes.indexWhere((node) => node['id'] == originPoolId);
        if (originPoolIndex != -1) {
          List<Team?> originPoolTeams = List<Team?>.from(_createdNodes[originPoolIndex]['teams'] ?? []);
          
          if (originIndex < originPoolTeams.length) {
            originPoolTeams[originIndex] = null;
          }
          
          _createdNodes[originPoolIndex]['teams'] = originPoolTeams;
        }
      } else if (origin == 'ko') {
        String originNodeId = dragData['originNodeId'];
        int originIndex = dragData['originIndex'];
        
        final originNode = _createdNodes.firstWhere(
          (node) => node['id'] == originNodeId,
          orElse: () => {},
        );
        if (originNode.isNotEmpty) {
          List<Team?> originTeams = List<Team?>.from(originNode['teams'] ?? []);
          if (originIndex < originTeams.length) {
            originTeams[originIndex] = null;
          }
          originNode['teams'] = originTeams;
        }
      }
    });
    
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.fillColored,
      title: const Text('Team zur Liste zurückgegeben'),
      description: Text('${dragData['team'].name} ist wieder verfügbar'),
      autoCloseDuration: const Duration(seconds: 2),
    );
    
    _saveState();
    _saveTournament();
  }

  void _showCreateNodeDialog(int columnIndex) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Text(
                  'Knoten erstellen',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Wählen Sie den Typ des Knotens aus:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                // Node type options
                _buildNodeTypeOption(
                  icon: Icons.sports_tennis,
                  title: '1 vs 1 Spiel',
                  description: 'Direktes Spiel zwischen zwei Teams',
                  color: Colors.green,
                  onTap: () {
                    Navigator.of(context).pop();
                    _createNode('1v1', columnIndex);
                  },
                ),
                const SizedBox(height: 12),
                _buildNodeTypeOption(
                  icon: Icons.group_work,
                  title: 'Pool',
                  description: 'Mehrere Teams in einer Gruppe',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.of(context).pop();
                    _createNode('pool', columnIndex);
                  },
                ),
                const SizedBox(height: 12),
                _buildNodeTypeOption(
                  icon: Icons.emoji_events,
                  title: 'KO-Runde',
                  description: 'Eliminierungsspiel',
                  color: Colors.red,
                  onTap: () {
                    Navigator.of(context).pop();
                    _createNode('ko', columnIndex);
                  },
                ),
                const SizedBox(height: 24),
                // Cancel button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Abbrechen',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNodeTypeOption({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }

  void _showPoolConfigurationDialog(int columnIndex) {
    int teamCount = 4;
    String gameMode = 'single_round_robin';
    String poolName = 'Pool ${String.fromCharCode(65 + _createdNodes.length)}';
    bool autofillTeams = false;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: 450,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      'Pool konfigurieren',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Stellen Sie die Parameter für den Pool ein:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Pool Name
                    Text(
                      'Pool Name',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: poolName,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Pool A',
                      ),
                      onChanged: (value) {
                        poolName = value;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Team Count
                    Text(
                      'Anzahl Teams',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: teamCount,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: [2, 3, 4, 5, 6].map((count) {
                        return DropdownMenuItem(
                          value: count,
                          child: Text('$count Teams'),
                        );
                      }).toList(),
                            onChanged: (value) {
                              setState(() {
                          teamCount = value!;
                              });
                            },
                          ),
                    const SizedBox(height: 16),
                    
                    // Autofill Teams Option
                    Row(
                      children: [
                        Checkbox(
                          value: autofillTeams,
                          onChanged: (value) {
                            setState(() {
                              autofillTeams = value ?? false;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Teams automatisch ausfüllen',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Warning if not enough teams
                    if (autofillTeams && _getAvailableTeams().length < teamCount)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          border: Border.all(color: Colors.orange[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Warnung: Nur ${_getAvailableTeams().length} Teams verfügbar, ${teamCount} benötigt.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Info text for autofill when enough teams available
                    if (autofillTeams && _getAvailableTeams().length >= teamCount)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          border: Border.all(color: Colors.green[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${teamCount} Teams werden zufällig ausgewählt.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.green[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 20),
                    
                    // Game Mode
                    Text(
                      'Spielmodus',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      children: [
                        RadioListTile<String>(
                          title: const Text('Einfache Runde (jeder gegen jeden)'),
                          value: 'single_round_robin',
                          groupValue: gameMode,
                          onChanged: (value) {
                            setState(() {
                              gameMode = value!;
                            });
                          },
                        ),
                        RadioListTile<String>(
                          title: const Text('Hin- und Rückspiel (doppelte Runde)'),
                          value: 'double_round_robin',
                          groupValue: gameMode,
                          onChanged: (value) {
                            setState(() {
                              gameMode = value!;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('Abbrechen'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            _addPoolNode(
                              name: poolName,
                              teamCount: teamCount,
                              gameMode: gameMode,
                              columnIndex: columnIndex,
                            );
                          },
                          child: const Text('Pool erstellen'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _addPoolNode({
    required String name,
    required int teamCount,
    required String gameMode,
    required int columnIndex,
  }) {
    setState(() {
      final poolId = DateTime.now().millisecondsSinceEpoch.toString();
      
      _createdNodes.add({
        'id': poolId,
        'type': 'pool',
        'name': name,
        'teamCount': teamCount,
        'gameMode': gameMode,
        'teams': List<Team?>.filled(teamCount, null),
        'column': columnIndex,
      });
      
      _saveState();
      _saveTournament();
    });
  }

  void _showKORoundConfigurationDialog(int columnIndex) {
    int teamCount = 4;
    String roundName = 'KO Runde ${_createdNodes.where((node) => node['type'] == 'ko').length + 1}';
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: 450,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      'KO-Runde konfigurieren',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Stellen Sie die Parameter für die KO-Runde ein:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Round Name
                    Text(
                      'Rundenname',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: roundName,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'KO Runde 1',
                      ),
                      onChanged: (value) {
                        roundName = value;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Team Count
                    Text(
                      'Anzahl Teams',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: teamCount,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: [2, 4, 8, 16, 32].map((count) {
                        return DropdownMenuItem(
                          value: count,
                          child: Text('$count Teams'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          teamCount = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('Abbrechen'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _showKORoundMatchConfigDialog(
                              name: roundName,
                              teamCount: teamCount,
                              columnIndex: columnIndex,
                            );
                          },
                          child: const Text('Weiter'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showKORoundMatchConfigDialog({
    required String name,
    required int teamCount,
    required int columnIndex,
  }) {
    String bestOf = 'one';
    Map<int, String> roundBestOf = {};
    final rounds = (log(teamCount) / log(2)).ceil();
    final matchWidth = 160.0;
    
    // Initialize all rounds with 'one'
    for (int i = 0; i < rounds; i++) {
      roundBestOf[i] = 'one';
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final size = MediaQuery.of(context).size;
          return Dialog(
            insetPadding: EdgeInsets.zero,
            child: SizedBox.expand(
              child: Material(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _showKORoundConfigurationDialog(columnIndex);
                            },
                            icon: const Icon(Icons.arrow_back),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Spielmodus konfigurieren',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  'Wählen Sie den Spielmodus für jede Runde:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Bracket preview with round selectors at the top
                      Expanded(
                        child: Column(
                          children: [
                            // Round selectors
                            Container(
                              height: 80,
                              margin: EdgeInsets.symmetric(
                                horizontal: (size.width - (rounds * matchWidth)) / (rounds + 1),
                              ),
                              child: Row(
                                children: List.generate(rounds, (index) {
                                  final isLastRound = index == rounds - 1;
                                  final roundName = isLastRound 
                                      ? 'Finale'
                                      : index == rounds - 2 
                                          ? 'Halbfinale'
                                          : index == rounds - 3 
                                              ? 'Viertelfinale'
                                              : '${pow(2, rounds - index - 1).toInt()}tel Finale';
                                  
                                  return Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                            roundName,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          SizedBox(
                                            height: 40,
                                            child: DropdownButtonFormField<String>(
                                              value: roundBestOf[index],
                                              isDense: true,
                                              isExpanded: true,
                                              decoration: const InputDecoration(
                                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                border: OutlineInputBorder(),
                                              ),
                                              items: [
                                                DropdownMenuItem(
                                                  value: 'one',
                                                  child: const Text('Best of One', style: TextStyle(fontSize: 12)),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'three',
                                                  child: const Text('Best of Three', style: TextStyle(fontSize: 12)),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'five',
                                                  child: const Text('Best of Five', style: TextStyle(fontSize: 12)),
                                                ),
                                              ],
                                              onChanged: (value) {
                                                setState(() {
                                                  roundBestOf[index] = value!;
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Bracket preview
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: CustomPaint(
                                  painter: BracketPreviewPainter(
                                    teamCount: teamCount,
                                    roundBestOf: roundBestOf,
                                  ),
                                  size: Size.infinite,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _showKORoundConfigurationDialog(columnIndex);
                            },
                            child: const Text('Zurück'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              _addKORoundNode(
                                name: name,
                                teamCount: teamCount,
                                roundBestOf: roundBestOf,
                                columnIndex: columnIndex,
                              );
                            },
                            child: const Text('KO-Runde erstellen'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _addKORoundNode({
    required String name,
    required int teamCount,
    required Map<int, String> roundBestOf,
    required int columnIndex,
  }) {
    setState(() {
      final nodeId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Initialize empty teams list with nulls
      final List<Team?> teams = List.filled(teamCount, null);
      
      _createdNodes.add({
        'id': nodeId,
        'type': 'ko',
        'name': name,
        'teamCount': teamCount,
        'roundBestOf': roundBestOf,
        'column': columnIndex,
        'teams': teams,
      });
      
      _saveState();
      _saveTournament();
    });
  }

  void _createNode(String type, int columnIndex) {
    if (type == 'pool') {
      _showPoolConfigurationDialog(columnIndex);
    } else if (type == 'ko') {
      _showKORoundConfigurationDialog(columnIndex);
    } else if (type == '1v1') {
      // TODO: Implement 1v1 node type
      toastification.show(
        context: context,
        type: ToastificationType.success,
        style: ToastificationStyle.fillColored,
        title: const Text('1 vs 1 Spiel Knoten erstellt'),
        description: const Text('Der Knoten wurde erfolgreich hinzugefügt'),
        autoCloseDuration: const Duration(seconds: 3),
      );
    }
  }

  // Helper method to get available teams (teams in sidebar)
  List<Team> _getAvailableTeams() {
    if (_selectedDivision == null) return [];
    
    return _teamsByDivision[_selectedDivision]?.where(
      (team) => _teamPositions[team.id] == 'sidebar'
    ).toList() ?? [];
  }

  // Add helper method for Berger table generation
  List<List<Map<String, Team>>> generateBergerTable(List<Team> teams) {
    print('🎲 Generating Berger table for ${teams.length} teams');
    
    // If odd number of teams, add a dummy team for byes
    final List<Team> allTeams = List<Team>.from(teams);
    if (allTeams.length % 2 != 0) {
      print('🎲 Adding dummy team for odd number of teams');
      allTeams.add(Team(
        id: 'bye',
        name: 'Spielfrei',
        city: '',
        bundesland: '',
        division: '',
        createdAt: DateTime.now(),
      ));
    }

    final n = allTeams.length;
    final rounds = n - 1;
    final halfSize = n ~/ 2;
    
    print('🎲 Teams: $n, Rounds: $rounds, Half size: $halfSize');
    
    List<List<Map<String, Team>>> schedule = [];
    
    // Create initial team arrangement
    List<Team> firstHalf = allTeams.sublist(0, halfSize);
    List<Team> secondHalf = allTeams.sublist(halfSize).reversed.toList();
    
    print('🎲 Initial arrangement:');
    print('   First half: ${firstHalf.map((t) => t.name).join(', ')}');
    print('   Second half: ${secondHalf.map((t) => t.name).join(', ')}');
    
    // Generate games for each round
    for (int round = 0; round < rounds; round++) {
      List<Map<String, Team>> roundGames = [];
      print('🎲 Generating round ${round + 1}:');
      
      // Create games between teams in corresponding positions
      for (int i = 0; i < halfSize; i++) {
        // Alternate home/away for better distribution
        if ((round + i) % 2 == 0) {
          print('   - ${firstHalf[i].name} (H) vs ${secondHalf[i].name} (A)');
          roundGames.add({
            'home': firstHalf[i],
            'away': secondHalf[i],
          });
        } else {
          print('   - ${secondHalf[i].name} (H) vs ${firstHalf[i].name} (A)');
          roundGames.add({
            'home': secondHalf[i],
            'away': firstHalf[i],
        });
      }
    }
    
      schedule.add(roundGames);
      
      // Rotate teams for next round (except first team)
      if (round < rounds - 1) {  // Don't rotate after the last round
        final lastTeamFirstHalf = firstHalf.last;
        firstHalf.removeLast();
        firstHalf.insert(1, secondHalf.first);
        secondHalf.removeAt(0);
        secondHalf.add(lastTeamFirstHalf);
        
        print('🎲 Rotated teams for next round:');
        print('   First half: ${firstHalf.map((t) => t.name).join(', ')}');
        print('   Second half: ${secondHalf.map((t) => t.name).join(', ')}');
      }
    }
    
    // Remove games with dummy team if we added one
    if (teams.length % 2 != 0) {
      print('🎲 Removing games with dummy team');
      schedule = schedule.map((round) {
        return round.where((game) =>
          game['home']!.id != 'bye' && game['away']!.id != 'bye'
        ).toList();
      }).toList();
    }
    
    print('🎲 Final schedule has ${schedule.length} rounds with games:');
    for (int i = 0; i < schedule.length; i++) {
      print('   Round ${i + 1}: ${schedule[i].length} games');
      for (final game in schedule[i]) {
        print('     - ${game['home']!.name} vs ${game['away']!.name}');
      }
    }
    
    return schedule;
  }

  void _showGenerateGamesDialog(Map<String, dynamic> pool) {
    final bool hasExistingGames = pool['gamesGenerated'] == true;
    final List<Team> poolTeams = List<Team>.from(pool['teams'] ?? []);
    poolTeams.removeWhere((team) => team == null);
    
    print('🎮 Pool teams: ${poolTeams.map((t) => t.name).join(', ')}');
    print('🎮 Pool ID: ${pool['id']}');
    print('🎮 Pool metadata before: ${widget.tournament.poolMetadata[pool['id']]}');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(hasExistingGames 
          ? 'Spiele für Pool ${pool['name']} neu generieren?' 
          : 'Spiele für Pool ${pool['name']} generieren?'
        ),
        content: Text(hasExistingGames
          ? 'Möchten Sie die Spiele für diesen Pool neu generieren? Die bestehenden ${pool['gameCount']} Spiele werden gelöscht.'
          : 'Möchten Sie die Spiele für diesen Pool generieren?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final navigatorState = Navigator.of(context);
              
              try {
                // Generate games in order of rounds
                final Set<String> createdGameIds = {};  // Track created games to prevent duplicates
                final now = DateTime.now();
                final batch = FirebaseFirestore.instance.batch();
                final gamesRef = FirebaseFirestore.instance
                    .collection('tournaments')
                    .doc(widget.tournament.id)
                    .collection('games');

                // Show initial message
                toastification.show(
                  context: context,
                  type: ToastificationType.warning,
                  title: const Text('Spiele werden neu generiert'),
                  description: const Text('Bestehende Spiele werden gelöscht...'),
                  autoCloseDuration: const Duration(seconds: 2),
                );

                // Delete existing games for this pool
                final existingGames = await gamesRef
                    .where('poolId', isEqualTo: pool['id'])
                    .get();
                
                print('🎮 Deleting ${existingGames.docs.length} existing games for pool ${pool['id']}');
                
                for (final doc in existingGames.docs) {
                  batch.delete(doc.reference);
                }

                print('🎮 Generating games for ${poolTeams.length} teams');
                
                // Generate Berger table for round-robin games
                final schedule = generateBergerTable(poolTeams);

                // Create games for each round
                for (int roundIndex = 0; roundIndex < schedule.length; roundIndex++) {
                  final round = schedule[roundIndex];
                  
                  for (final game in round) {
                    final homeTeam = game['home']!;
                    final awayTeam = game['away']!;
                    
                    // Create a unique game ID based on teams (order independent)
                    final teamIds = [homeTeam.id, awayTeam.id]..sort();
                    final gameId = '${pool['id']}_${teamIds.join('_')}';
                    
                    // Skip if this game combination already exists in this batch
                    if (createdGameIds.contains(gameId)) {
                      print('🎮 Skipping duplicate game: ${homeTeam.name} vs ${awayTeam.name}');
                      continue;
                    }
                    createdGameIds.add(gameId);
                    
                    print('🎮 Creating game: ${homeTeam.name} vs ${awayTeam.name} (Round ${roundIndex + 1})');
                    
                    // Create the game
                    final newGame = Game(
                      id: gameId,
                      tournamentId: widget.tournament.id,
                      teamAId: homeTeam.id,
                      teamBId: awayTeam.id,
                      teamAName: homeTeam.name,
                      teamBName: awayTeam.name,
                      gameType: GameType.pool,
                      poolId: pool['id'],
                      status: GameStatus.scheduled,
                      bracketRound: roundIndex + 1,
                      createdAt: now,
                      updatedAt: now,
                    );
                    
                    final gameData = newGame.toJson();
                    gameData.remove('id'); // Remove ID from data since it's used as document ID
                    batch.set(gamesRef.doc(gameId), gameData);
                  }
                }

                print('🎮 Generated ${createdGameIds.length} unique games');

                // Close dialog before the long operation
                navigatorState.pop();

                // Commit all operations in one batch
                await batch.commit();
                
                // Force refresh games cache
                await _gameService.forceRefreshGames(widget.tournament.id);

                // Show completion message
                toastification.show(
                  context: context,
                  type: ToastificationType.success,
                  title: const Text('Spiele erfolgreich generiert'),
                  description: Text('${createdGameIds.length} Spiele wurden neu erstellt'),
                  autoCloseDuration: const Duration(seconds: 3),
                );

                // Update tournament with pool game generation state
                final updatedPoolMetadata = Map<String, Map<String, dynamic>>.from(widget.tournament.poolMetadata);
                updatedPoolMetadata[pool['id']] = {
                  'gamesGenerated': true,
                  'gameCount': createdGameIds.length,
                };
                
                print('🎮 Pool metadata after: ${updatedPoolMetadata[pool['id']]}');
                
                final updatedTournament = widget.tournament.copyWith(
                  poolMetadata: updatedPoolMetadata,
                );
                
                await _tournamentService.updateTournament(updatedTournament);

                // Update UI
    setState(() {
                  // Update both the local pool state and the node state
                  pool['gamesGenerated'] = true;
                  pool['gameCount'] = createdGameIds.length;
                  
                  // Find and update the node in _createdNodes
                  final nodeIndex = _createdNodes.indexWhere((node) => node['id'] == pool['id']);
                  if (nodeIndex != -1) {
                    _createdNodes[nodeIndex]['gamesGenerated'] = true;
                    _createdNodes[nodeIndex]['gameCount'] = createdGameIds.length;
                  }
                  
                  // Force rebuild of the pool widget
                  _createdNodes = List.from(_createdNodes);
                });

                // Save state to persist the changes
                _saveState();

              } catch (e) {
                print('❌ Error generating games: $e');
                toastification.show(
                  context: context,
                  type: ToastificationType.error,
                  title: const Text('Fehler'),
                  description: Text('Fehler beim Generieren der Spiele: $e'),
                  autoCloseDuration: const Duration(seconds: 4),
                );
              }
            },
            icon: const Icon(Icons.sports_handball),
            label: Text(hasExistingGames ? 'Spiele neu generieren' : 'Spiele generieren'),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasExistingGames ? Colors.orange : Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  void _deletePool(String poolId) {
    // Find and remove the pool from _createdNodes
    setState(() {
      // Find the pool
      final poolIndex = _createdNodes.indexWhere((node) => node['id'] == poolId);
      if (poolIndex != -1) {
        final pool = _createdNodes[poolIndex];
        final poolColumn = pool['column'] as int;
        
        // Check if we can delete this pool
        final hasNodesAfter = _createdNodes.any((node) => 
          node['column'] as int > poolColumn
        );
        
        if (poolColumn > 0 && hasNodesAfter) {
          // Show error message if trying to delete a node with dependent nodes
    toastification.show(
      context: context,
            type: ToastificationType.error,
      style: ToastificationStyle.fillColored,
            title: const Text('Löschen nicht möglich'),
            description: const Text('Bitte löschen Sie zuerst die abhängigen Knoten in den nachfolgenden Spalten.'),
      autoCloseDuration: const Duration(seconds: 3),
    );
          return;
        }

        // Move all teams back to sidebar
        final teams = List<Team?>.from(pool['teams'] ?? []);
        for (final team in teams) {
          if (team != null) {
            _teamPositions[team.id] = 'sidebar';
          }
        }
        
        // Remove the pool
        _createdNodes.removeAt(poolIndex);
        
        // Remove menu state
        _showPoolMenu.remove(poolId);
        _showPoolText.remove(poolId);
        
        // Save state
        _saveState();
        _saveTournament();

        // Show success message
      toastification.show(
        context: context,
        type: ToastificationType.success,
        style: ToastificationStyle.fillColored,
          title: Text('${pool['name']} gelöscht'),
          description: const Text('Der Pool wurde erfolgreich gelöscht.'),
          autoCloseDuration: const Duration(seconds: 2),
      );
    }
    });
  }

  Widget _buildStatItem(String value, String label, MaterialColor color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color[700],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: color[700],
          ),
        ),
      ],
    );
  }

  Widget _buildKORoundWidget(Map<String, dynamic> node) {
    // Initialize menu state if not exists
    _showPoolMenu.putIfAbsent(node['id'], () => false);
    _showPoolText.putIfAbsent(node['id'], () => true);

    // Get assigned teams
    final List<Team?> assignedTeams = List<Team?>.from(node['teams'] ?? []);
    final int teamCount = node['teamCount'] as int;
    final double baseHeight = 100.0;
    final double teamRowHeight = 40.0;
    final double totalHeight = baseHeight + (teamCount * teamRowHeight);
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: totalHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Menu
            if (_showPoolMenu[node['id']]!)
              Positioned(
                left: 0,
                top: 0,
                width: 268,
                height: totalHeight,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.delete_outline, color: Colors.red),
                        title: const Text('KO-Runde löschen'),
                        onTap: () => _deleteNode(node['id']),
                      ),
                      ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: const Text('KO-Runde bearbeiten'),
                        onTap: () {
                          setState(() {
                            _showPoolText[node['id']] = false;
                          });
                          Future.delayed(const Duration(milliseconds: 150), () {
                            setState(() {
                              _showPoolMenu[node['id']] = false;
                            });
                            Future.delayed(const Duration(milliseconds: 300), () {
                              setState(() {
                                _showPoolText[node['id']] = true;
                              });
                            });
                          });
                          // TODO: Implement KO round editing
                        },
                      ),
                    ],
                  ),
                ),
              ),
            // Main Content
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              left: _showPoolMenu[node['id']]! ? 300 : 0,
              right: 0,
              top: 0,
              height: totalHeight,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(Icons.sports_handball, color: Colors.red[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: _showPoolText[node['id']]! ? 1.0 : 0.0,
                            child: Text(
                              node['name'],
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red[700],
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.more_horiz, color: Colors.red[700]),
                          onPressed: () {
                            setState(() {
                              _showPoolText[node['id']] = false;
                            });
                            Future.delayed(const Duration(milliseconds: 150), () {
                              setState(() {
                                _showPoolMenu[node['id']] = true;
                              });
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Info
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: _showPoolText[node['id']]! ? 1.0 : 0.0,
                      child: Text(
                        '${node['teamCount']} Teams • ${_getBestOfText(node)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red[600],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Teams list
                    Expanded(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: _showPoolText[node['id']]! ? 1.0 : 0.0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade100),
                          ),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: teamCount,
                            itemBuilder: (context, index) {
                              final team = index < assignedTeams.length ? assignedTeams[index] : null;
                              
                              return DragTarget<Map<String, dynamic>>(
                                onAccept: (data) {
                                  if (data.containsKey('team')) {
                                    final droppedTeam = data['team'] as Team;
                                    final origin = data['origin'] as String?;
                                    final originNodeId = data['originNodeId'] as String?;
                                    final originIndex = data['originIndex'] as int?;

                                    setState(() {
                                      // Remove team from original position if it's from another node
                                      if (origin == 'ko' && originNodeId != null) {
                                        final originNode = _createdNodes.firstWhere(
                                          (n) => n['id'] == originNodeId,
                                          orElse: () => {},
                                        );
                                        if (originNode.isNotEmpty) {
                                          final originTeams = List<Team?>.from(originNode['teams'] ?? []);
                                          if (originIndex != null && originIndex < originTeams.length) {
                                            originTeams[originIndex] = null;
                                            originNode['teams'] = originTeams;
                                          }
                                        }
                                      }

                                      // Update teams list for this node
                                      final teams = List<Team?>.from(node['teams'] ?? []);
                                      while (teams.length < teamCount) {
                                        teams.add(null);
                                      }
                                      teams[index] = droppedTeam;
                                      node['teams'] = teams;

                                      // Update team position to remove from sidebar
                                      if (origin == 'sidebar') {
                                        _teamPositions[droppedTeam.id] = 'ko_${_selectedDivision}_${node['id']}';
                                      }
                                    });

                                    // Save state and update tournament
                                    _saveState();
                                    _saveTournament();

                                    // Show success toast
                                    toastification.show(
                                      context: context,
                                      type: ToastificationType.success,
                                      style: ToastificationStyle.fillColored,
                                      title: const Text('Team zugeordnet'),
                                      description: Text('${droppedTeam.name} wurde der KO-Runde zugeordnet'),
                                      autoCloseDuration: const Duration(seconds: 2),
                                    );
                                  }
                                },
                                builder: (context, candidateData, rejectedData) {
                                  final isHovering = candidateData.isNotEmpty;
                                  
                                  return Container(
                                    height: teamRowHeight,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: isHovering ? Colors.red.shade50 : null,
                                      border: index < teamCount - 1
                                          ? Border(bottom: BorderSide(color: Colors.red.shade50))
                                          : null,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${index + 1}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.red.shade700,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: team != null
                                              ? Draggable<Map<String, dynamic>>(
                                                  data: {
                                                    'team': team,
                                                    'origin': 'ko',
                                                    'originNodeId': node['id'],
                                                    'originIndex': index,
                                                  },
                                                  feedback: Material(
                                                    color: Colors.transparent,
                                                    child: Container(
                                                      width: 120,
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red[100],
                                                        borderRadius: BorderRadius.circular(4),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black.withOpacity(0.2),
                                                            blurRadius: 4,
                                                            offset: const Offset(0, 2),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Text(
                                                        team.name,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  childWhenDragging: Text(
                                                    'Team ${index + 1}',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.red.shade200,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    team.name,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.red.shade700,
                                                    ),
                                                  ),
                                                )
                                              : Text(
                                                  'Team ${index + 1}',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.red.shade300,
                                                  ),
                                                ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getBestOfText(Map<String, dynamic> node) {
    final Map<int, String> roundBestOf = Map<int, String>.from(node['roundBestOf'] ?? {});
    final List<String> bestOfCounts = roundBestOf.values.toSet().toList();
    
    if (bestOfCounts.isEmpty) {
      return 'Best of One';
    } else if (bestOfCounts.length == 1) {
      final bestOf = bestOfCounts[0];
      return bestOf == 'one' ? 'Best of One' : bestOf == 'three' ? 'Best of Three' : 'Best of Five';
    } else {
      return 'Mixed Best of';
    }
  }

  void _deleteNode(String nodeId) {
    setState(() {
      _createdNodes.removeWhere((node) => node['id'] == nodeId);
      _showPoolMenu[nodeId] = false;
      _showPoolText[nodeId] = true;
    });
    _saveState();
    _saveTournament();
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
          // Debug indicator
          // Container( // Removed debug message bar
          //   width: double.infinity,
          //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          //   color: Colors.red[100],
          //   child: Text(
          //     'DEBUG: $_debugMessage | Tournament: ${widget.tournament.id}',
          //     style: TextStyle(fontSize: 12, color: Colors.red[800]),
          //   ),
          // ),
          _buildDivisionSelector(),
          Expanded(
            child: Row(
              children: [
                                 // Left sidebar with teams
                 DragTarget<Map<String, dynamic>>(
                   onWillAccept: (data) => data != null && data['origin'] == 'pool',
                   onAccept: (dragData) {
                     _moveTeamToSidebar(dragData);
                   },
                   builder: (context, candidateData, rejectedData) {
                     bool isHighlighted = candidateData.isNotEmpty;
                     
                     return AnimatedContainer(
                       duration: const Duration(milliseconds: 300),
                       width: _isSidebarCollapsed ? 60 : 250,
                       decoration: BoxDecoration(
                         color: isHighlighted ? Colors.blue[100] : Colors.transparent,
                         border: isHighlighted ? Border.all(color: Colors.blue.shade300, width: 2) : null,
                       ),
                       child: Column(
                         children: [
                           if (isHighlighted && _isSidebarCollapsed)
                             Container(
                               width: double.infinity,
                               padding: const EdgeInsets.symmetric(vertical: 8),
                               color: Colors.blue[200],
                               child: Icon(
                                 Icons.assignment_return,
                                 color: Colors.blue[700],
                                 size: 20,
                               ),
                             ),
                           if (isHighlighted && !_isSidebarCollapsed)
                             Container(
                               width: double.infinity,
                               padding: const EdgeInsets.symmetric(vertical: 8),
                               color: Colors.blue[200],
                               child: Text(
                                 'Team zur Liste hinzufügen',
                                 style: TextStyle(
                                   fontSize: 12,
                                   fontWeight: FontWeight.w500,
                                   color: Colors.blue[700],
                                 ),
                                 textAlign: TextAlign.center,
                               ),
                             ),
                           _buildTeamNavbar(),
                           Expanded(
                             child: Container(
                               color: Colors.grey[50],
                             ),
                           ),
                         ],
                       ),
                     );
                   },
                 ),
                 // Vertical divider
                 const VerticalDivider(width: 1, color: Colors.grey),
                 // Main content area
                 Expanded(
                  child: _selectedDivision != null 
                      ? _buildRoundColumns()
                      : Container(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.workspaces,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Neue Pool-Verwaltung',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Bitte wählen Sie eine Division aus',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 