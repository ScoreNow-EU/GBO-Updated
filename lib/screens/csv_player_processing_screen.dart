import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../services/player_service.dart';
import '../services/team_service.dart';

class CSVPlayerProcessingScreen extends StatefulWidget {
  final List<Map<String, dynamic>> csvData;
  
  const CSVPlayerProcessingScreen({
    super.key,
    required this.csvData,
  });

  @override
  State<CSVPlayerProcessingScreen> createState() => _CSVPlayerProcessingScreenState();
}

class _CSVPlayerProcessingScreenState extends State<CSVPlayerProcessingScreen> {
  final PlayerService _playerService = PlayerService();
  final TeamService _teamService = TeamService();
  
  List<Team> availableTeams = [];
  Map<String, String> playerTeamAssignments = {}; // playerId -> teamId
  Map<String, bool> playerDiscardFlags = {}; // playerId -> should discard
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeamsAndProcessData();
  }

  Future<void> _loadTeamsAndProcessData() async {
    try {
      final teams = await _teamService.getAllTeams();
      setState(() {
        availableTeams = teams;
        isLoading = false;
      });
      
      // Now process CSV data after teams are loaded
      _processCSVData();
    } catch (e) {
      print('Error loading teams: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _processCSVData() {
    // Build team assignments without console logging
    
    // Process CSV data and create player assignments
    for (final row in widget.csvData) {
      final playerId = '${row['Firstname']}_${row['Lastname']}_${row['Jersey Number']}';
      final clubName = row['Club Name'] as String? ?? '';
      final division = row['Division'] as String? ?? '';
      
      // Try to find matching team with improved logic
      List<Team> matchingTeams = [];
      
      // First try exact name match
      matchingTeams = availableTeams.where((team) => 
        team.name.toLowerCase().trim() == clubName.toLowerCase().trim()
      ).toList();
      
      // If no exact match, try contains
      if (matchingTeams.isEmpty) {
        matchingTeams = availableTeams.where((team) => 
          team.name.toLowerCase().contains(clubName.toLowerCase()) ||
          clubName.toLowerCase().contains(team.name.toLowerCase())
        ).toList();
      }
      
      // If still no match, try division match
      if (matchingTeams.isEmpty) {
        matchingTeams = availableTeams.where((team) => 
          team.division.toLowerCase().contains(division.toLowerCase()) ||
          division.toLowerCase().contains(team.division.toLowerCase())
        ).toList();
      }
      
      if (matchingTeams.isNotEmpty) {
        final matchingTeam = matchingTeams.first;
        playerTeamAssignments[playerId] = matchingTeam.id;
        playerDiscardFlags[playerId] = false;
        // assigned
      } else {
        playerDiscardFlags[playerId] = true; // Mark for discard if no match
        // no match
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CSV Spieler Verarbeitung'),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    // Group players by club/team
    final Map<String, List<Map<String, dynamic>>> groupedPlayers = {};
    
    for (final row in widget.csvData) {
      final clubName = row['Club Name'] as String? ?? 'Unbekannter Verein';
      if (!groupedPlayers.containsKey(clubName)) {
        groupedPlayers[clubName] = [];
      }
      groupedPlayers[clubName]!.add(row);
    }

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CSV Upload Verarbeitung',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.csvData.length} Spieler gefunden. Überprüfen Sie die Zuordnungen und bestätigen Sie den Upload.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        
        // Teams and Players
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groupedPlayers.length,
            itemBuilder: (context, index) {
              final clubName = groupedPlayers.keys.elementAt(index);
              final players = groupedPlayers[clubName]!;
              
              return _buildTeamSection(clubName, players);
            },
          ),
        ),
        
        // Action Buttons
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _processUpload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D5016),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Upload Bestätigen'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Abbrechen'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTeamSection(String clubName, List<Map<String, dynamic>> players) {
    // Find matching team
    final matchingTeam = availableTeams.where((team) => 
      team.name.toLowerCase().contains(clubName.toLowerCase())
    ).firstOrNull;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Row(
          children: [
            Icon(
              matchingTeam != null ? Icons.check_circle : Icons.warning,
              color: matchingTeam != null ? Colors.green : Colors.orange,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                clubName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Text(
              '${players.length} Spieler',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        subtitle: matchingTeam != null
            ? Text('Zugeordnet zu: ${matchingTeam.name}')
            : const Text('Kein passendes Team gefunden'),
        children: [
          // Team assignment dropdown
          if (matchingTeam == null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Team zuordnen:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: null,
                    hint: const Text('Team auswählen...'),
                    items: availableTeams.map((team) {
                      return DropdownMenuItem<String>(
                        value: team.id,
                        child: Text('${team.name} (${team.division})'),
                      );
                    }).toList(),
                    onChanged: (teamId) {
                      if (teamId != null) {
                        setState(() {
                          for (final player in players) {
                            final playerId = '${player['Firstname']}_${player['Lastname']}_${player['Jersey Number']}';
                            playerTeamAssignments[playerId] = teamId;
                            playerDiscardFlags[playerId] = false;
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              for (final player in players) {
                                final playerId = '${player['Firstname']}_${player['Lastname']}_${player['Jersey Number']}';
                                playerDiscardFlags[playerId] = true;
                                playerTeamAssignments.remove(playerId);
                              }
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Alle verwerfen'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          
          // Players list
          ...players.map((player) => _buildPlayerTile(player, matchingTeam?.id)),
        ],
      ),
    );
  }

  Widget _buildPlayerTile(Map<String, dynamic> player, String? assignedTeamId) {
    final playerId = '${player['Firstname']}_${player['Lastname']}_${player['Jersey Number']}';
    final isDiscarded = playerDiscardFlags[playerId] ?? false;
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isDiscarded ? Colors.red.shade100 : Colors.green.shade100,
        child: Text(
          player['Jersey Number']?.toString() ?? '?',
          style: TextStyle(
            color: isDiscarded ? Colors.red.shade600 : Colors.green.shade600,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        '${player['Firstname']} ${player['Lastname']}',
        style: TextStyle(
          decoration: isDiscarded ? TextDecoration.lineThrough : null,
          color: isDiscarded ? Colors.grey : Colors.black87,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Position: ${player['Position'] ?? 'N/A'}'),
          Text('Verein: ${player['Club Name'] ?? 'N/A'}'),
          Text('Division: ${player['Division'] ?? 'N/A'}'),
        ],
      ),
      trailing: assignedTeamId != null
          ? Icon(Icons.check_circle, color: Colors.green, size: 20)
          : isDiscarded
              ? Icon(Icons.cancel, color: Colors.red, size: 20)
              : Icon(Icons.warning, color: Colors.orange, size: 20),
    );
  }

    Future<void> _processUpload() async {
    try {
      int successCount = 0;
      int discardCount = 0;
      
      for (final row in widget.csvData) {
        final playerId = '${row['Firstname']}_${row['Lastname']}_${row['Jersey Number']}';
        final firstName = row['Firstname'] as String? ?? '';
        final lastName = row['Lastname'] as String? ?? '';
        // final jerseyNumber = row['Jersey Number']?.toString() ?? '';
        
        if (playerDiscardFlags[playerId] == true) {
          discardCount++;
          continue;
        }
        
        final assignedTeamId = playerTeamAssignments[playerId];
        if (assignedTeamId != null) {
          // Determine gender based on division
          final division = row['Division'] as String? ?? '';
          final gender = division.toLowerCase().contains('women') || 
                        division.toLowerCase().contains('womens') || 
                        division.toLowerCase().contains('weiblich') 
                        ? 'female' : 'male';
          
          // Create player
          final player = Player(
            id: playerId,
            firstName: row['Firstname'] ?? '',
            lastName: row['Lastname'] ?? '',
            email: '', // Empty email - optional field
            jerseyNumber: row['Jersey Number']?.toString() ?? '',
            position: row['Position'] ?? '',
            clubId: assignedTeamId,
            gender: gender,
            createdAt: DateTime.now(),
          );
          
          final result = await _playerService.addPlayer(player);
          if (result != null) {
            successCount++;
            final team = availableTeams.firstWhere((t) => t.id == assignedTeamId);
            
            // Add player to team roster
            try {
              final updatedRosterIds = List<String>.from(team.rosterPlayerIds)..add(result);
              final updatedTeam = team.copyWith(rosterPlayerIds: updatedRosterIds);
              
              final teamUpdateSuccess = await _teamService.updateTeam(assignedTeamId, updatedTeam);
              if (teamUpdateSuccess) {
                // Single concise log per player as requested
                print('Added player ${firstName} ${lastName} to team ${team.name} (${team.division})');
              }
            } catch (e) {
              // Suppress verbose error logging
            }
          } else {
            // Suppress verbose failure logging
          }
        } else {
          discardCount++;
        }
      }
      
      // Keep UI feedback; suppress console summaries
      
      if (mounted) {
        Navigator.of(context).pop();
        toastification.show(
          context: context,
          type: ToastificationType.success,
          title: const Text('Upload erfolgreich'),
          description: Text('$successCount Spieler hinzugefügt, $discardCount verworfen'),
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
     } catch (e) {
       if (mounted) {
         toastification.show(
           context: context,
           type: ToastificationType.error,
           title: const Text('Fehler beim Upload'),
           description: Text('Fehler: $e'),
           autoCloseDuration: const Duration(seconds: 4),
         );
       }
     }
  }
} 