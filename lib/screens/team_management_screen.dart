import 'package:flutter/material.dart';
import 'dart:async';
import '../models/team.dart';
import '../services/team_service.dart';
import '../widgets/team_avatar.dart';
import '../utils/responsive_helper.dart';
import 'bulk_add_teams_screen.dart';

class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  final TeamService _teamService = TeamService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _teamManagerController = TextEditingController();
  final _logoUrlController = TextEditingController();
  final _cityController = TextEditingController();

  String _selectedBundesland = 'Baden-Württemberg';
  String _selectedDivision = 'Men\'s Seniors';
  String _filterDivision = 'Alle';
  Team? _editingTeam;
  
  // Auto-save functionality
  Timer? _autoSaveTimer;
  bool _isAutoSaving = false;
  bool _hasUnsavedChanges = false;
  String? _autoSaveStatus;

  // German Bundesländer
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

  @override
  void initState() {
    super.initState();
    _setupAutoSaveListeners();
  }

  void _setupAutoSaveListeners() {
    _nameController.addListener(_onFormChanged);
    _teamManagerController.addListener(_onFormChanged);
    _logoUrlController.addListener(_onFormChanged);
    _cityController.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    if (_editingTeam == null) return; // Only auto-save when editing existing teams
    
    setState(() {
      _hasUnsavedChanges = true;
    });
    
    // Cancel previous timer
    _autoSaveTimer?.cancel();
    
    // Start new timer for auto-save (debounce for 2 seconds)
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      _performAutoSave();
    });
  }

  Future<void> _performAutoSave() async {
    if (!_hasUnsavedChanges || _editingTeam == null) return;
    
    if (!_formKey.currentState!.validate()) return; // Don't save invalid data
    
    setState(() {
      _isAutoSaving = true;
      _autoSaveStatus = 'Speichert...';
    });
    
    try {
      Team team = Team(
        id: _editingTeam!.id,
        name: _nameController.text,
        teamManager: _teamManagerController.text.isEmpty ? null : _teamManagerController.text,
        logoUrl: _logoUrlController.text.isEmpty ? null : _logoUrlController.text,
        city: _cityController.text,
        bundesland: _selectedBundesland,
        division: _selectedDivision,
        createdAt: _editingTeam!.createdAt,
      );

      await _teamService.updateTeam(team);
      
      setState(() {
        _isAutoSaving = false;
        _hasUnsavedChanges = false;
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
                'Teams verwalten',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              // Division Filter
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _filterDivision,
                    items: [
                      const DropdownMenuItem(
                        value: 'Alle',
                        child: Text('Division: Alle'),
                      ),
                      ..._divisions.map((division) => DropdownMenuItem(
                        value: division,
                        child: Text('Division: $division'),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filterDivision = value!;
                      });
                    },
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showTeamDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Neues Team'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const BulkAddTeamsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.group_add),
                label: const Text('Bulk Hinzufügen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Team List
          Expanded(
            child: StreamBuilder<List<Team>>(
              stream: _teamService.getTeamsWithCache(),
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
                      'Keine Teams gefunden.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                // Filter teams by division
                List<Team> filteredTeams = snapshot.data!;
                if (_filterDivision != 'Alle') {
                  filteredTeams = filteredTeams
                      .where((team) => team.division == _filterDivision)
                      .toList();
                }

                if (filteredTeams.isEmpty) {
                  return Center(
                    child: Text(
                      'Keine Teams in der gewählten Division gefunden.',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return _buildTeamDataTable(filteredTeams);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamDataTable(List<Team> teams) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = ResponsiveHelper.isMobile(width);
        
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            width: isMobile ? width * 1.5 : width,
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
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: width),
              child: DataTable(
                columnSpacing: isMobile ? 16 : 24,
                headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
                columns: [
                  DataColumn(
                    label: Expanded(
                      child: Text(
                        'Team Name', 
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 12 : 14,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Expanded(
                      child: Text(
                        'Team Manager', 
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 12 : 14,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Expanded(
                      child: Text(
                        'Division', 
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 12 : 14,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Expanded(
                      child: Text(
                        'Stadt', 
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 12 : 14,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Expanded(
                      child: Text(
                        'Bundesland', 
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 12 : 14,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Expanded(
                      child: Text(
                        'Logo', 
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 12 : 14,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Expanded(
                      child: Text(
                        'Aktionen', 
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 12 : 14,
                        ),
                      ),
                    ),
                  ),
                ],
                rows: teams.map((team) {
                  return DataRow(
                    cells: [
                      DataCell(
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isMobile ? 120 : 200,
                            minWidth: isMobile ? 80 : 120,
                          ),
                          child: Text(
                            team.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: isMobile ? 12 : 14,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isMobile ? 100 : 150,
                            minWidth: isMobile ? 80 : 100,
                          ),
                          child: Text(
                            team.teamManager ?? 'Nicht angegeben',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: isMobile ? 12 : 14),
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          constraints: BoxConstraints(
                            maxWidth: isMobile ? 80 : 120,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getDivisionColor(team.division).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            team.division,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _getDivisionColor(team.division),
                              fontSize: isMobile ? 10 : 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isMobile ? 80 : 120,
                            minWidth: isMobile ? 60 : 80,
                          ),
                          child: Text(
                            team.city,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: isMobile ? 12 : 14),
                          ),
                        ),
                      ),
                      DataCell(
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isMobile ? 80 : 120,
                            minWidth: isMobile ? 60 : 80,
                          ),
                          child: Text(
                            team.bundesland,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: isMobile ? 12 : 14),
                          ),
                        ),
                      ),
                      DataCell(
                        TeamAvatar(
                          teamName: team.name,
                          logoUrl: team.logoUrl,
                          size: isMobile ? 32 : 40,
                          division: team.division,
                        ),
                      ),
                      DataCell(
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isMobile ? 80 : 100,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.edit, 
                                  color: Colors.blue,
                                  size: isMobile ? 18 : 24,
                                ),
                                onPressed: () => _editTeam(team),
                                tooltip: 'Bearbeiten',
                                padding: EdgeInsets.all(isMobile ? 4 : 8),
                                constraints: BoxConstraints(
                                  minWidth: isMobile ? 32 : 40,
                                  minHeight: isMobile ? 32 : 40,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete, 
                                  color: Colors.red,
                                  size: isMobile ? 18 : 24,
                                ),
                                onPressed: () => _deleteTeam(team),
                                tooltip: 'Löschen',
                                padding: EdgeInsets.all(isMobile ? 4 : 8),
                                constraints: BoxConstraints(
                                  minWidth: isMobile ? 32 : 40,
                                  minHeight: isMobile ? 32 : 40,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTeamDialog([Team? team]) {
    _editingTeam = team;
    
    // Reset auto-save state
    _hasUnsavedChanges = false;
    _autoSaveStatus = null;
    
    if (team != null) {
      _nameController.text = team.name;
      _teamManagerController.text = team.teamManager ?? '';
      _logoUrlController.text = team.logoUrl ?? '';
      _cityController.text = team.city;
      _selectedBundesland = team.bundesland;
      _selectedDivision = team.division;
    } else {
      _clearForm();
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Text(team == null ? 'Neues Team' : 'Team bearbeiten'),
                  const Spacer(),
                  if (_autoSaveStatus != null) ...[
                    if (_isAutoSaving) 
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        _autoSaveStatus!.contains('Fehler') ? Icons.error_outline : Icons.check_circle_outline,
                        size: 16,
                        color: _autoSaveStatus!.contains('Fehler') ? Colors.red : Colors.green,
                      ),
                    const SizedBox(width: 4),
                    Text(
                      _autoSaveStatus!,
                      style: TextStyle(
                        fontSize: 12,
                        color: _autoSaveStatus!.contains('Fehler') ? Colors.red : Colors.green,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ],
              ),
              content: SizedBox(
                width: 500,
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Team Name *'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Bitte geben Sie einen Team Namen ein';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _teamManagerController,
                          decoration: const InputDecoration(labelText: 'Team Manager (optional)'),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _logoUrlController,
                          decoration: const InputDecoration(
                            labelText: 'Logo URL (optional)',
                            hintText: 'https://example.com/logo.png',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _cityController,
                          decoration: const InputDecoration(labelText: 'Stadt *'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Bitte geben Sie eine Stadt ein';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Flexible(
                          child: DropdownButtonFormField<String>(
                            value: _selectedBundesland,
                            decoration: const InputDecoration(labelText: 'Bundesland'),
                            items: _bundeslaender.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedBundesland = newValue;
                                });
                                _onFormChanged(); // Trigger auto-save
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        Flexible(
                          child: DropdownButtonFormField<String>(
                            value: _selectedDivision,
                            decoration: const InputDecoration(labelText: 'Division'),
                            items: _divisions.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedDivision = newValue;
                                });
                                _onFormChanged(); // Trigger auto-save
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Abbrechen'),
                ),
                ElevatedButton(
                  onPressed: () => _saveTeam(),
                  child: Text(team == null ? 'Erstellen' : 'Speichern'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _clearForm() {
    _nameController.clear();
    _teamManagerController.clear();
    _logoUrlController.clear();
    _cityController.clear();
    _selectedBundesland = 'Baden-Württemberg';
    _selectedDivision = 'Men\'s Seniors';
  }

  void _saveTeam() async {
    if (_formKey.currentState!.validate()) {
      try {
        Team team = Team(
          id: _editingTeam?.id ?? '',
          name: _nameController.text,
          teamManager: _teamManagerController.text.isEmpty ? null : _teamManagerController.text,
          logoUrl: _logoUrlController.text.isEmpty ? null : _logoUrlController.text,
          city: _cityController.text,
          bundesland: _selectedBundesland,
          division: _selectedDivision,
          createdAt: _editingTeam?.createdAt ?? DateTime.now(),
        );

        if (_editingTeam == null) {
          await _teamService.addTeam(team);
        } else {
          await _teamService.updateTeam(team);
        }

        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editingTeam == null 
                ? 'Team erfolgreich erstellt' 
                : 'Team erfolgreich aktualisiert'),
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
      }
    }
  }

  void _editTeam(Team team) {
    _showTeamDialog(team);
  }

  void _deleteTeam(Team team) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Team löschen'),
          content: Text('Sind Sie sicher, dass Sie "${team.name}" löschen möchten?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _teamService.deleteTeam(team.id);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Team erfolgreich gelöscht'),
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

  Color _getDivisionColor(String division) {
    if (division.startsWith('Women\'s')) {
      if (division.contains('U14')) return Colors.lightGreen;
      if (division.contains('U16')) return Colors.pink.shade300;
      if (division.contains('U18')) return Colors.purple.shade300;
      if (division.contains('Seniors')) return Colors.pink.shade600;
      if (division.contains('FUN')) return Colors.pink.shade400;
      return Colors.pink;
    } else if (division.startsWith('Men\'s')) {
      if (division.contains('U14')) return Colors.lightBlue;
      if (division.contains('U16')) return Colors.blue.shade300;
      if (division.contains('U18')) return Colors.blue.shade600;
      if (division.contains('Seniors')) return Colors.indigo;
      if (division.contains('FUN')) return Colors.teal;
      return Colors.blue;
    } else {
      return Colors.grey;
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _nameController.dispose();
    _teamManagerController.dispose();
    _logoUrlController.dispose();
    _cityController.dispose();
    super.dispose();
  }
} 