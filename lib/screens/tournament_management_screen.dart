import 'package:flutter/material.dart';
import '../models/tournament.dart';
import '../services/tournament_service.dart';
import '../services/team_service.dart';
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

                return _buildTournamentDataTable(filteredTournaments);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentDataTable(List<Tournament> tournaments) {
    return SingleChildScrollView(
      child: Container(
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
        ),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
          columns: const [
            DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Divisionen', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Datum', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Ort', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Punkte', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Aktionen', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: tournaments.map((tournament) {
            final tournamentDivisions = _tournamentDivisions[tournament.id] ?? [];
            
            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 200,
                    child: Text(
                      tournament.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 400,
                    child: _buildDivisionChips(tournamentDivisions),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 150,
                    child: _buildDateColumn(tournament),
                  ),
                ),
                DataCell(Text(tournament.location)),
                DataCell(Text(tournament.points.toString())),
                DataCell(_buildStatusChip(tournament.status)),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _editTournament(tournament),
                        tooltip: 'Bearbeiten',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteTournament(tournament),
                        tooltip: 'Löschen',
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
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

  Widget _buildDateColumn(Tournament tournament) {
    // Check if tournament has category-specific dates
    if (tournament.categoryStartDates != null && tournament.categoryStartDates!.isNotEmpty) {
      List<Widget> dateWidgets = [];
      
      // Add Senior dates if exists
      if (tournament.categories.contains('GBO Seniors Cup')) {
        final seniorStart = tournament.getStartDateForCategory('GBO Seniors Cup');
        final seniorEnd = tournament.getEndDateForCategory('GBO Seniors Cup');
        
        String seniorDateStr;
        if (seniorEnd != null) {
          seniorDateStr = '${seniorStart.day}.${seniorStart.month} - ${seniorEnd.day}.${seniorEnd.month}.${seniorEnd.year}';
        } else {
          seniorDateStr = '${seniorStart.day}.${seniorStart.month}.${seniorStart.year}';
        }
        
        dateWidgets.add(
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Senior',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  seniorDateStr,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }
      
      // Add Junior dates if exists
      if (tournament.categories.contains('GBO Juniors Cup')) {
        final juniorStart = tournament.getStartDateForCategory('GBO Juniors Cup');
        final juniorEnd = tournament.getEndDateForCategory('GBO Juniors Cup');
        
        String juniorDateStr;
        if (juniorEnd != null) {
          juniorDateStr = '${juniorStart.day}.${juniorStart.month} - ${juniorEnd.day}.${juniorEnd.month}.${juniorEnd.year}';
        } else {
          juniorDateStr = '${juniorStart.day}.${juniorStart.month}.${juniorStart.year}';
        }
        
        if (dateWidgets.isNotEmpty) {
          dateWidgets.add(const SizedBox(height: 4));
        }
        
        dateWidgets.add(
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Junior',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  juniorDateStr,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: dateWidgets,
      );
    } else {
      // Fallback to regular date display
      return Text(
        tournament.dateString,
        style: const TextStyle(fontSize: 12),
        overflow: TextOverflow.ellipsis,
      );
    }
  }

  Widget _buildStatusChip(String status) {
    MaterialColor color;
    String label;
    
    switch (status) {
      case 'upcoming':
        color = Colors.orange;
        label = 'Bevorstehend';
        break;
      case 'ongoing':
        color = Colors.green;
        label = 'Laufend';
        break;
      case 'completed':
        color = Colors.grey;
        label = 'Abgeschlossen';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.shade700,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
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