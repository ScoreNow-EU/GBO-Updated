import 'package:flutter/material.dart';
import '../models/team.dart';
import '../services/team_service.dart';
import '../data/german_cities.dart';
import '../widgets/team_avatar.dart';

class BulkAddTeamsScreen extends StatefulWidget {
  const BulkAddTeamsScreen({super.key});

  @override
  State<BulkAddTeamsScreen> createState() => _BulkAddTeamsScreenState();
}

class _BulkAddTeamsScreenState extends State<BulkAddTeamsScreen> {
  final TeamService _teamService = TeamService();
  final _formKey = GlobalKey<FormState>();

  String _selectedDivision = 'Men\'s Seniors';
  bool _isLoading = false;

  // List to hold team data
  List<TeamFormData> _teams = [
    TeamFormData(), // Start with one empty team
    TeamFormData(), // Always have one extra for adding new teams
  ];

  // Available divisions
  final List<String> _divisions = [
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

  // German Bundesländer and international regions
  final List<String> _bundeslaender = [
    'Baden-Württemberg',
    'Bayern',
    'Berlin',
    'Brandenburg',
    'Bremen',
    'Hamburg',
    'Hessen',
    'Mecklenburg-Vorpommern',
    'Niedersachsen',
    'Nordrhein-Westfalen',
    'Rheinland-Pfalz',
    'Saarland',
    'Sachsen',
    'Sachsen-Anhalt',
    'Schleswig-Holstein',
    'Thüringen',
    // International regions
    'Dänemark',
    'Norwegen',
    'Niederlande',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teams Bulk Hinzufügen'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Container(
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Text(
                    'Teams hinzufügen',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_teams.where((t) => t.name.text.isNotEmpty).length} Teams werden erstellt',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Geben Sie für jedes Team individuelle Daten ein. Alle Teams werden in der gleichen Division erstellt.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),

              // Division Selection (shared)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.group, color: Colors.blue),
                    const SizedBox(width: 12),
                    const Text(
                      'Division für alle Teams:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedDivision,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: _divisions.map((String division) {
                          return DropdownMenuItem<String>(
                            value: division,
                            child: Text(division),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedDivision = newValue;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Teams List
              Expanded(
                child: ListView.builder(
                  itemCount: _teams.length,
                  itemBuilder: (context, index) {
                    return _buildTeamCard(index);
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Abbrechen'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _previewTeams,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Teams Vorschau'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamCard(int index) {
    final team = _teams[index];
    final isLast = index == _teams.length - 1;
    final isEmpty = team.name.text.isEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEmpty && !isLast ? Colors.grey.shade50 : Colors.white,
        border: Border.all(
          color: isEmpty && !isLast ? Colors.grey.shade300 : Colors.grey.shade400,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                isLast ? 'Team ${index + 1} hinzufügen' : 'Team ${index + 1}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isEmpty && !isLast ? Colors.grey : Colors.black87,
                ),
              ),
              const Spacer(),
              if (!isLast && !isEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _removeTeam(index),
                  tooltip: 'Team entfernen',
                ),
            ],
          ),
          const SizedBox(height: 12),

          // All fields in one row
          Row(
            children: [
              // Team Name
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: team.name,
                  decoration: const InputDecoration(
                    labelText: 'Team Name *',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (value) => _onTeamNameChanged(index, value),
                  validator: isLast ? null : (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Team Namen eingeben';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Team Manager
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: team.teamManager,
                  decoration: const InputDecoration(
                    labelText: 'Manager',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // City Autocomplete
              Expanded(
                flex: 3,
                child: Autocomplete<GermanCity>(
                  key: Key('autocomplete_$index'), // Add key for proper widget identification
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    return GermanCities.searchCities(textEditingValue.text).take(10);
                  },
                  displayStringForOption: (GermanCity option) => option.displayName,
                  onSelected: (GermanCity selection) {
                    // Defensive check to prevent using disposed controllers
                    if (index < _teams.length && !_teams[index]._disposed) {
                      setState(() {
                        team.selectedCity = selection;
                        // Only update controller text if it's safe to do so
                        if (team.cityController != null && !team._disposed) {
                          try {
                            team.cityController!.text = selection.displayName;
                          } catch (e) {
                            // Controller might be disposed, ignore the error
                            print('Controller disposal error ignored: $e');
                          }
                        }
                      });
                    }
                  },
                  fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                    // Always use the provided controller to avoid disposal issues
                    team.cityController = controller;
                    
                    // Set initial value if team has a selected city
                    if (team.selectedCity != null && controller.text != team.selectedCity!.displayName) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!team._disposed) {
                          try {
                            controller.text = team.selectedCity!.displayName;
                          } catch (e) {
                            // Ignore disposal errors
                          }
                        }
                      });
                    }
                    
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      onEditingComplete: onEditingComplete,
                      decoration: const InputDecoration(
                        labelText: 'Stadt (Bundesland)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (value) {
                        // Clear selected city if user manually types different text
                        if (team.selectedCity != null && value != team.selectedCity!.displayName) {
                          if (!team._disposed) {
                            setState(() {
                              team.selectedCity = null;
                            });
                          }
                        }
                      },
                      validator: isLast ? null : null,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Logo URL
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: team.logoUrl,
                  decoration: const InputDecoration(
                    labelText: 'Logo URL',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onTeamNameChanged(int index, String value) {
    // If this is the last (empty) team and user starts typing, add a new empty team
    if (index == _teams.length - 1 && value.isNotEmpty) {
      setState(() {
        _teams.add(TeamFormData());
      });
    }
    
    setState(() {
      // Update the counter in the header
    });
  }

  void _removeTeam(int index) {
    if (_teams.length > 2 && index < _teams.length) { // Keep at least one team + one empty
      setState(() {
        // Safely dispose the team data before removal
        try {
          _teams[index].dispose();
        } catch (e) {
          // Ignore disposal errors
        }
        _teams.removeAt(index);
      });
    }
  }

  void _previewTeams() {
    if (!_formKey.currentState!.validate()) return;

    // Get only teams with names (exclude the last empty one)
    List<TeamFormData> teamsToPreview = _teams
        .where((team) => team.name.text.trim().isNotEmpty && !team._disposed)
        .toList();

    if (teamsToPreview.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte geben Sie mindestens einen Team Namen ein'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Convert to Team objects for preview
    List<Team> previewTeams = [];
    for (TeamFormData teamData in teamsToPreview) {
      // Parse city and state from selection with better error handling
      String city = 'Unknown';
      String state = 'Baden-Württemberg';
      
      try {
        if (teamData.selectedCity != null) {
          city = teamData.selectedCity!.name;
          state = teamData.selectedCity!.state;
        } else if (teamData.cityController?.text.isNotEmpty == true) {
          String cityText = teamData.cityController!.text.trim();
          // Try to parse from text if no selection was made
          GermanCity? foundCity = GermanCities.findByDisplayName(cityText);
          if (foundCity != null) {
            city = foundCity.name;
            state = foundCity.state;
          } else {
            // Use the text as city name with default state
            city = cityText.isNotEmpty ? cityText : 'Unknown';
          }
        }
      } catch (e) {
        // If there's any error accessing the city data, use defaults
        print('Error parsing city data: $e');
        city = 'Unknown';
        state = 'Baden-Württemberg';
      }

      Team team = Team(
        id: '',
        name: teamData.name.text.trim(),
        teamManager: teamData.teamManager.text.trim().isEmpty 
            ? null 
            : teamData.teamManager.text.trim(),
        logoUrl: teamData.logoUrl.text.trim().isEmpty 
            ? null 
            : teamData.logoUrl.text.trim(),
        city: city,
        bundesland: state,
        division: _selectedDivision,
        createdAt: DateTime.now(),
      );

      previewTeams.add(team);
    }

    // Navigate to confirmation screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TeamConfirmationScreen(
          teams: previewTeams,
          onConfirm: _bulkAddTeams,
        ),
      ),
    );
  }

  Future<void> _bulkAddTeams(List<Team> teams) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Add each team
      for (Team team in teams) {
        await _teamService.addTeam(team);
      }

      Navigator.of(context).pop(); // Close confirmation screen
      Navigator.of(context).pop(); // Close bulk add screen
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${teams.length} Teams erfolgreich hinzugefügt'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // Dispose all team form data safely
    for (int i = 0; i < _teams.length; i++) {
      try {
        if (!_teams[i]._disposed) {
          _teams[i].dispose();
        }
      } catch (e) {
        // Ignore disposal errors for individual teams
        print('Error disposing team $i: $e');
      }
    }
    super.dispose();
  }
}

class TeamFormData {
  final TextEditingController name = TextEditingController();
  final TextEditingController teamManager = TextEditingController();
  final TextEditingController logoUrl = TextEditingController();
  TextEditingController? cityController;
  GermanCity? selectedCity;
  bool _disposed = false;

  void dispose() {
    if (!_disposed) {
      try {
        name.dispose();
        teamManager.dispose();
        logoUrl.dispose();
        // Don't dispose cityController as it's managed by the Autocomplete widget
        _disposed = true;
      } catch (e) {
        // Ignore disposal errors
        _disposed = true;
      }
    }
  }
}

class TeamConfirmationScreen extends StatelessWidget {
  final List<Team> teams;
  final Future<void> Function(List<Team>) onConfirm;

  const TeamConfirmationScreen({
    super.key,
    required this.teams,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teams Bestätigen'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Text(
                  'Teams Vorschau',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Text(
                  '${teams.length} Teams werden hinzugefügt',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Überprüfen Sie die Team-Details bevor Sie sie hinzufügen.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),

            // Teams Preview Table
            Expanded(
              child: SingleChildScrollView(
                child: Container(
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
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
                    columns: const [
                      DataColumn(label: Text('Team Name', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Team Manager', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Division', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Stadt', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Bundesland', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Logo', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: teams.map((team) {
                      return DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 200,
                              child: Text(
                                team.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                          DataCell(Text(team.teamManager ?? 'Nicht angegeben')),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getDivisionColor(team.division).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                team.division,
                                style: TextStyle(
                                  color: _getDivisionColor(team.division),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          DataCell(Text(team.city)),
                          DataCell(Text(team.bundesland)),
                          DataCell(
                            TeamAvatar(
                              teamName: team.name,
                              logoUrl: team.logoUrl,
                              size: 40,
                              division: team.division,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Zurück'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => onConfirm(teams),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text('${teams.length} Teams Hinzufügen'),
                ),
              ],
            ),
          ],
        ),
      ),
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
} 