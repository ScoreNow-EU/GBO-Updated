import 'package:flutter/material.dart';
import '../models/tournament.dart';
import '../services/tournament_service.dart';
import '../services/team_service.dart';
import '../utils/responsive_helper.dart';
import 'tournament_edit_screen.dart';
import 'package:toastification/toastification.dart';

class TournamentManagementScreen extends StatefulWidget {
  const TournamentManagementScreen({super.key});

  @override
  State<TournamentManagementScreen> createState() => _TournamentManagementScreenState();
}

class _TournamentManagementScreenState extends State<TournamentManagementScreen> {
  final TournamentService _tournamentService = TournamentService();
  final TeamService _teamService = TeamService();
  
  // Available divisions for filtering
  final List<String> _availableDivisions = [
    'Women\'s U14',
    'Women\'s U16', 
    'Women\'s U18',
    'Women\'s Seniors',
    'Women\'s FUN',
    'Men\'s U14',
    'Men\'s U16',
    'Men\'s U18', 
    'Men\'s Seniors',
    'Men\'s FUN',
  ];
  
  List<String> _selectedDivisions = [];
  Map<String, List<String>> _tournamentDivisions = {}; // tournamentId -> divisions

  @override
  void initState() {
    super.initState();
    _loadTournamentDivisions();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text(
                'Turniere verwalten',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _createNewTournament(),
                icon: const Icon(Icons.add),
                label: const Text('Neues Turnier'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Division Filter Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nach Divisionen filtern:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableDivisions.map((division) {
                      final isSelected = _selectedDivisions.contains(division);
                      return FilterChip(
                        label: Text(division),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedDivisions.add(division);
                            } else {
                              _selectedDivisions.remove(division);
                            }
                          });
                        },
                        selectedColor: _getDivisionColor(division).withValues(alpha: 0.2),
                        checkmarkColor: _getDivisionColor(division),
                        backgroundColor: Colors.grey.shade100,
                      );
                    }).toList(),
                  ),
                  if (_selectedDivisions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${_selectedDivisions.length} Divisionen ausgewählt',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedDivisions.clear();
                            });
                          },
                          child: const Text('Alle abwählen'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tournament List
          Expanded(
            child: StreamBuilder<List<Tournament>>(
              stream: _tournamentService.getTournaments(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'Keine Turniere gefunden.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                // Filter tournaments by selected divisions
                List<Tournament> filteredTournaments = snapshot.data!;
                if (_selectedDivisions.isNotEmpty) {
                  filteredTournaments = snapshot.data!.where((tournament) {
                    final tournamentDivisions = _tournamentDivisions[tournament.id] ?? [];
                    return _selectedDivisions.any((selectedDiv) => 
                        tournamentDivisions.contains(selectedDiv));
                  }).toList();
                }

                return _buildTournamentDataTable(filteredTournaments, MediaQuery.of(context).size.width);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentDataTable(List<Tournament> tournaments, double screenWidth) {
    final isMobile = ResponsiveHelper.isMobile(screenWidth);
    
    // Remove the horizontal scroll hint and table, replace with cards
    return ListView.builder(
      itemCount: tournaments.length,
      itemBuilder: (context, index) {
        final tournament = tournaments[index];
        final tournamentDivisions = _tournamentDivisions[tournament.id] ?? [];
        
        return _buildTournamentManagementCard(tournament, tournamentDivisions, isMobile);
      },
    );
  }

  Widget _buildTournamentManagementCard(Tournament tournament, List<String> divisions, bool isMobile) {
    // Get status colors for the card border
    Color borderColor;
    switch (tournament.status) {
      case 'upcoming':
        borderColor = Colors.blue.shade600;
        break;
      case 'ongoing':
        borderColor = Colors.green.shade600;
        break;
      case 'completed':
        borderColor = Colors.grey.shade500;
        break;
      default:
        borderColor = Colors.grey.shade300;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: borderColor,
          width: 3,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with tournament name and action buttons
          Row(
            children: [
              // Tournament Logo
              Container(
                width: 60,
                height: 45,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: tournament.imageUrl != null && tournament.imageUrl!.isNotEmpty
                      ? Image.network(
                          tournament.imageUrl!,
                          width: 60,
                          height: 45,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildGeneratedImage(tournament);
                          },
                        )
                      : _buildGeneratedImage(tournament),
                ),
              ),
              const SizedBox(width: 16),
              // Tournament name and status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tournament.name,
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildProminentStatusBadge(tournament.status),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${tournament.points} Punkte',
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _editTournament(tournament),
                      tooltip: 'Bearbeiten',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteTournament(tournament),
                      tooltip: 'Löschen',
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Tournament details in responsive layout
          isMobile ? _buildMobileDetails(tournament, divisions) : _buildDesktopDetails(tournament, divisions),
        ],
      ),
    );
  }

  Widget _buildMobileDetails(Tournament tournament, List<String> divisions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date and location
        Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                tournament.dateString,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                tournament.location,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Divisions
        if (divisions.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.groups, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                'Divisionen:',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildDivisionChips(divisions),
        ],
      ],
    );
  }

  Widget _buildDesktopDetails(Tournament tournament, List<String> divisions) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date and location column
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tournament.dateString,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tournament.location,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Divisions column
        Expanded(
          flex: 3,
          child: divisions.isNotEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.groups, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          'Divisionen:',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildDivisionChips(divisions),
                  ],
                )
              : Container(),
        ),
      ],
    );
  }

  Widget _buildGeneratedImage(Tournament tournament) {
    // Generate colors based on tournament name
    int nameHash = tournament.name.hashCode;
    
    List<Color> colors = [
      Color((nameHash & 0xFF6B73FF) | 0xFF000000),
      Color((nameHash & 0xFF4ECDC4) | 0xFF000000),
      Color((nameHash & 0xFF45B7D1) | 0xFF000000),
    ];
    
    return Container(
      width: 60,
      height: 45,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors.take(2).toList(),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          tournament.name.isNotEmpty ? tournament.name[0].toUpperCase() : 'T',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildDivisionChips(List<String> divisions) {
    if (divisions.isEmpty) {
      return Text(
        'Keine Teams',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: divisions.map((division) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _getDivisionColor(division).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _getDivisionColor(division).withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Text(
            division,
            style: TextStyle(
              color: _getDivisionColor(division).shade700,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProminentStatusBadge(String status) {
    MaterialColor color;
    String label;
    IconData icon;
    
    switch (status) {
      case 'upcoming':
        color = Colors.blue;
        label = 'Geplant';
        icon = Icons.schedule;
        break;
      case 'ongoing':
        color = Colors.green;
        label = 'Aktiv';
        icon = Icons.play_circle;
        break;
      case 'completed':
        color = Colors.grey;
        label = 'Beendet';
        icon = Icons.check_circle;
        break;
      default:
        color = Colors.grey;
        label = status;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.shade600,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.shade800,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _createNewTournament() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TournamentEditScreen()),
    );
  }

  void _editTournament(Tournament tournament) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TournamentEditScreen(tournament: tournament),
      ),
    );
  }

  void _deleteTournament(Tournament tournament) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Turnier löschen'),
          content: Text('Sind Sie sicher, dass Sie "${tournament.name}" löschen möchten?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _tournamentService.deleteTournament(tournament.id);
                  Navigator.of(context).pop();
                  toastification.show(
                    context: context,
                    type: ToastificationType.success,
                    style: ToastificationStyle.fillColored,
                    title: const Text('Erfolg'),
                    description: const Text('Turnier erfolgreich gelöscht'),
                    alignment: Alignment.topRight,
                    autoCloseDuration: const Duration(seconds: 3),
                    showProgressBar: false,
                  );
                  // Reload divisions after deletion
                  _loadTournamentDivisions();
                } catch (e) {
                  Navigator.of(context).pop();
                  toastification.show(
                    context: context,
                    type: ToastificationType.error,
                    style: ToastificationStyle.fillColored,
                    title: const Text('Fehler'),
                    description: Text('Fehler beim Löschen: $e'),
                    alignment: Alignment.topRight,
                    autoCloseDuration: const Duration(seconds: 4),
                    showProgressBar: false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Löschen', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _loadTournamentDivisions() async {
    try {
      final teams = await _teamService.getTeams().first;
      final tournaments = await _tournamentService.getTournaments().first;
      
      Map<String, List<String>> tournamentDivs = {};
      
      for (Tournament tournament in tournaments) {
        Set<String> divisions = {};
        
        // Get divisions from teams in this tournament
        for (String teamId in tournament.teamIds) {
          try {
            final team = teams.firstWhere((t) => t.id == teamId);
            divisions.add(team.division);
          } catch (e) {
            // Team not found, skip it
            continue;
          }
        }
        
        tournamentDivs[tournament.id] = divisions.toList();
      }
      
      setState(() {
        _tournamentDivisions = tournamentDivs;
      });
    } catch (e) {
      print('Error loading tournament divisions: $e');
    }
  }

  MaterialColor _getDivisionColor(String division) {
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
} 