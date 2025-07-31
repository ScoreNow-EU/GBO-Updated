import 'package:flutter/material.dart';
import '../models/team.dart';
import '../models/player.dart';
import '../models/team_manager.dart';
import '../services/team_service.dart';
import '../services/player_service.dart';
import '../services/team_manager_service.dart';
import '../widgets/team_avatar.dart';

class TeamEditScreen extends StatefulWidget {
  final String teamId;

  const TeamEditScreen({
    super.key,
    required this.teamId,
  });

  @override
  State<TeamEditScreen> createState() => _TeamEditScreenState();
}

class _TeamEditScreenState extends State<TeamEditScreen> {
  final TeamService _teamService = TeamService();
  final PlayerService _playerService = PlayerService();
  final TeamManagerService _teamManagerService = TeamManagerService();
  
  String _selectedTab = 'basic';
  Team? _team;
  List<Player> _players = [];
  TeamManager? _teamManager;
  bool _isLoading = true;
  
  // Controllers for base data form
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  
  String _selectedDivision = 'Men\'s Seniors';
  String _selectedBundesland = 'Bayern';
  
  final List<String> _divisions = [
    'Men\'s U14',
    'Men\'s U16',
    'Men\'s U18', 
    'Men\'s Seniors',
    'Women\'s U14',
    'Women\'s U16',
    'Women\'s U18',
    'Women\'s Seniors',
  ];
  
  final List<String> _bundeslaender = [
    'Baden-Württemberg', 'Bayern', 'Berlin', 'Brandenburg', 'Bremen',
    'Hamburg', 'Hessen', 'Mecklenburg-Vorpommern', 'Niedersachsen',
    'Nordrhein-Westfalen', 'Rheinland-Pfalz', 'Saarland', 'Sachsen',
    'Sachsen-Anhalt', 'Schleswig-Holstein', 'Thüringen'
  ];

  @override
  void initState() {
    super.initState();
    _loadTeam();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadTeam() async {
    try {
      print('🏐 Loading team data for ID: ${widget.teamId}');
      
      final team = await _teamService.getTeamById(widget.teamId);
      if (team != null && mounted) {
        setState(() {
          _team = team;
          _nameController.text = team.name;
          _cityController.text = team.city;
          _selectedDivision = team.division;
          _selectedBundesland = team.bundesland;
        });
        
        // Load team players using rosterPlayerIds
        print('🏐 Loading roster for team: ${team.name}');
        print('🏐 RosterPlayerIds: ${team.rosterPlayerIds}');
        if (team.rosterPlayerIds.isNotEmpty) {
          final players = await _playerService.getPlayersByIds(team.rosterPlayerIds);
          print('🏐 Loaded ${players.length} players from roster IDs');
          for (final player in players) {
            print('  - ${player.fullName} (ID: ${player.id})');
          }
          if (mounted) {
            setState(() {
              _players = players;
            });
          }
        } else {
          print('🏐 No roster player IDs found');
          if (mounted) {
            setState(() {
              _players = [];
            });
          }
        }
        
        // Load team manager if exists
        if (team.teamManager != null) {
          final teamManager = await _teamManagerService.getTeamManagerByName(team.teamManager!);
          if (mounted) {
            setState(() {
              _teamManager = teamManager;
            });
          }
        }
        
      } else {
        print('❌ Team not found or widget disposed');
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading team: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_team == null) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: const Center(
          child: Text('Team nicht gefunden'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Row(
        children: [
          // Side navigation
          _buildSideNavigation(),
          
          // Main content
          Expanded(
            child: Container(
              color: Colors.grey[100],
              child: _buildTabContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideNavigation() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: const Color(0xFF4A5568),
        border: Border(
          right: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            height: 160,
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF4A5568),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TeamAvatar(
                  teamName: _team!.name,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  _team!.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  _team!.division,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildNavItem('basic', 'Basisdaten', Icons.info_outline),
                _buildNavItem('roster', 'Kader', Icons.group),
                _buildNavItem('officials', 'Team Officials', Icons.supervisor_account),
                _buildNavItem('tournaments', 'Turniere', Icons.sports_volleyball),
                _buildNavItem('settings', 'Einstellungen', Icons.settings),
              ],
            ),
          ),
          // Save and Back Buttons
          _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildNavItem(String tabId, String title, IconData icon) {
    final isSelected = _selectedTab == tabId;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF2D3748) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.white70,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        onTap: () {
          setState(() {
            _selectedTab = tabId;
          });
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white24, width: 1),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveTeamData,
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Speichern'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFffd665),
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Zurück'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 'basic':
        return _buildBaseDataTab();
      case 'roster':
        return _buildRosterTab();
      case 'officials':
        return _buildTeamOfficialsTab();
      case 'tournaments':
        return _buildTournamentsTab();
      case 'settings':
        return _buildSettingsTab();
      default:
        return _buildBaseDataTab();
    }
  }

  Widget _buildBaseDataTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Grundlegende Informationen'),
          const SizedBox(height: 16),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Team name
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Team Name *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Division and City row
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedDivision,
                          decoration: const InputDecoration(
                            labelText: 'Division *',
                            border: OutlineInputBorder(),
                          ),
                          items: _divisions.map((division) => DropdownMenuItem(
                            value: division,
                            child: Text(division),
                          )).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedDivision = value!;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _cityController,
                          decoration: const InputDecoration(
                            labelText: 'Stadt *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Bundesland
                  DropdownButtonFormField<String>(
                    value: _selectedBundesland,
                    decoration: const InputDecoration(
                      labelText: 'Bundesland *',
                      border: OutlineInputBorder(),
                    ),
                    items: _bundeslaender.map((land) => DropdownMenuItem(
                      value: land,
                      child: Text(land),
                    )).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedBundesland = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRosterTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildSectionTitle('Teamkader'),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFffd665).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_players.length} Spieler',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _createNewPlayer,
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Neuen Spieler erstellen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _addExistingPlayer,
                  icon: const Icon(Icons.group_add, size: 18),
                  label: const Text('Vorhandenen Spieler hinzufügen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: _players.isEmpty
                ? _buildEmptyRoster()
                : _buildPlayersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamOfficialsTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Team Officials'),
          const SizedBox(height: 16),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Team Manager',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  if (_teamManager != null)
                    _buildTeamManagerCard()
                  else
                    _buildNoTeamManagerCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentsTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Turnier-Anmeldungen'),
          const SizedBox(height: 16),
          
          const Expanded(
            child: Center(
              child: Text(
                'Turnier-Anmeldungen werden hier angezeigt\n(Coming Soon)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Team-Einstellungen'),
          const SizedBox(height: 16),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.visibility, color: Colors.blue),
                    title: const Text('Team öffentlich sichtbar'),
                    subtitle: const Text('Team wird in öffentlichen Listen angezeigt'),
                    trailing: Switch(
                      value: true,
                      onChanged: (value) {
                        // Handle visibility toggle
                      },
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.notifications, color: Colors.orange),
                    title: const Text('Benachrichtigungen aktiviert'),
                    subtitle: const Text('Team erhält E-Mail-Benachrichtigungen'),
                    trailing: Switch(
                      value: true,
                      onChanged: (value) {
                        // Handle notifications toggle
                      },
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Team löschen'),
                    subtitle: const Text('Diese Aktion kann nicht rückgängig gemacht werden'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: _deleteTeam,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildPlayersList() {
    return ListView.builder(
      itemCount: _players.length,
      itemBuilder: (context, index) {
        final player = _players[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
                         leading: CircleAvatar(
               backgroundColor: Colors.blue.shade100,
               child: Text(
                 player.fullName.isNotEmpty ? player.fullName[0].toUpperCase() : 'P',
                 style: TextStyle(
                   color: Colors.blue.shade700,
                   fontWeight: FontWeight.bold,
                 ),
               ),
             ),
             title: Text(player.fullName),
             subtitle: Text('${player.position ?? 'Keine Position'} • Rückennr. ${player.jerseyNumber ?? 'N/A'}'),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _editPlayer(player);
                    break;
                  case 'remove':
                    _removePlayer(player);
                    break;
                }
              },
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
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.remove_circle, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Entfernen', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyRoster() {
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
            'Noch keine Spieler im Kader',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fügen Sie Spieler zu diesem Team hinzu',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamManagerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFffd665).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFffd665).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.black87,
            child: Text(
              _teamManager!.name.isNotEmpty ? _teamManager!.name[0].toUpperCase() : 'M',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _teamManager!.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _teamManager!.email,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
                if (_teamManager!.phone != null)
                  Text(
                    _teamManager!.phone!,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: _changeTeamManager,
            child: const Text('Ändern'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoTeamManagerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_outlined,
            color: Colors.orange.shade600,
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Kein Team Manager zugewiesen',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _assignTeamManager,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Zuweisen'),
          ),
        ],
      ),
    );
  }

  // Action methods
  Future<void> _saveTeamData() async {
    if (_nameController.text.trim().isEmpty || _cityController.text.trim().isEmpty) {
      _showError('Name und Stadt sind erforderlich');
      return;
    }

    try {
      print('🏐 Saving team data with roster: ${_team!.rosterPlayerIds}');
      final updatedTeam = Team(
        id: _team!.id,
        name: _nameController.text.trim(),
        teamManager: _team!.teamManager,
        logoUrl: _team!.logoUrl,
        city: _cityController.text.trim(),
        bundesland: _selectedBundesland,
        division: _selectedDivision,
        clubId: _team!.clubId,
        rosterPlayerIds: _team!.rosterPlayerIds, // ✅ FIXED: Include roster data!
        createdAt: _team!.createdAt,
      );

      final success = await _teamService.updateTeam(_team!.id, updatedTeam);
      if (success) {
        if (mounted) {
          setState(() {
            _team = updatedTeam;
          });
        }
        _showSuccess('Team-Daten erfolgreich gespeichert!');
      } else {
        _showError('Fehler beim Speichern der Team-Daten');
      }
    } catch (e) {
      _showError('Fehler beim Speichern: $e');
    }
  }

  void _createNewPlayer() {
    _showCreatePlayerDialog();
  }

  void _addExistingPlayer() {
    _showAddExistingPlayerDialog();
  }

  void _editPlayer(Player player) {
    _showEditPlayerDialog(player);
  }

  void _removePlayer(Player player) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Spieler entfernen'),
        content: Text('Möchten Sie "${player.fullName}" aus dem Team-Kader entfernen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Entfernen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Remove player from team roster
        final updatedRosterIds = List<String>.from(_team!.rosterPlayerIds);
        updatedRosterIds.remove(player.id);
        
        final updatedTeam = Team(
          id: _team!.id,
          name: _team!.name,
          teamManager: _team!.teamManager,
          logoUrl: _team!.logoUrl,
          city: _team!.city,
          bundesland: _team!.bundesland,
          division: _team!.division,
          clubId: _team!.clubId,
          rosterPlayerIds: updatedRosterIds,
          createdAt: _team!.createdAt,
        );

        print('🏐 Removing player from roster: ${player.fullName}');
        print('🏐 Updated roster IDs: $updatedRosterIds');
        final success = await _teamService.updateTeam(_team!.id, updatedTeam);
        print('🏐 Team update success: $success');
        if (success) {
          if (mounted) {
            setState(() {
              _team = updatedTeam;
              _players.remove(player);
            });
          }
          _showSuccess('Spieler erfolgreich aus dem Kader entfernt!');
        } else {
          _showError('Fehler beim Entfernen des Spielers');
        }
      } catch (e) {
        _showError('Fehler beim Entfernen: $e');
      }
    }
  }

  void _showCreatePlayerDialog() {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final jerseyController = TextEditingController();
    String selectedGender = 'male';
    String selectedPosition = 'Goalkeeper';
    
    final positions = ['Goalkeeper', 'Allrounder', 'Defense', 'Pivot', 'Right Wing', 'Left Wing'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Neuen Spieler erstellen'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'Vorname *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nachname *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'E-Mail',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Telefon',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: jerseyController,
                        decoration: const InputDecoration(
                          labelText: 'Rückennummer',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedGender,
                        decoration: const InputDecoration(
                          labelText: 'Geschlecht',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(value: 'male', child: Text('Männlich')),
                          DropdownMenuItem(value: 'female', child: Text('Weiblich')),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            selectedGender = value!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedPosition,
                        decoration: const InputDecoration(
                          labelText: 'Position',
                          border: OutlineInputBorder(),
                        ),
                        items: positions.map((pos) => DropdownMenuItem(
                          value: pos,
                          child: Text(pos),
                        )).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedPosition = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () => _createPlayerAndAddToTeam(
                firstNameController.text,
                lastNameController.text,
                emailController.text,
                phoneController.text.isEmpty ? null : phoneController.text,
                jerseyController.text.isEmpty ? null : jerseyController.text,
                selectedGender,
                selectedPosition,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Erstellen & Hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExistingPlayerDialog() async {
    try {
      // Get all available players from Firebase
      final allPlayersStream = _playerService.getAllPlayers();
      final allPlayers = await allPlayersStream.first;
      
      // Filter out players already in this team
      final availablePlayers = allPlayers.where(
        (player) => !_team!.rosterPlayerIds.contains(player.id)
      ).toList();

      if (availablePlayers.isEmpty) {
        _showError('Keine verfügbaren Spieler gefunden. Erstellen Sie zunächst neue Spieler.');
        return;
      }

      String searchQuery = '';
      List<Player> filteredPlayers = availablePlayers;

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Vorhandenen Spieler hinzufügen'),
            content: SizedBox(
              width: 500,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Spieler suchen...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        searchQuery = value.toLowerCase();
                        filteredPlayers = availablePlayers.where((player) =>
                          player.fullName.toLowerCase().contains(searchQuery) ||
                          player.email.toLowerCase().contains(searchQuery) ||
                          (player.position?.toLowerCase().contains(searchQuery) ?? false)
                        ).toList();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredPlayers.length,
                      itemBuilder: (context, index) {
                        final player = filteredPlayers[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.shade100,
                              child: Text(
                                player.fullName.isNotEmpty ? player.fullName[0].toUpperCase() : 'P',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(player.fullName),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(player.email.contains('@placeholder.com') ? 'Keine E-Mail' : player.email),
                                Text('${player.position ?? 'Keine Position'} • ${player.gender == 'male' ? 'Männlich' : 'Weiblich'}'),
                              ],
                            ),
                            trailing: ElevatedButton(
                              onPressed: () => _addPlayerToTeam(player),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Hinzufügen'),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Schließen'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      _showError('Fehler beim Laden der Spieler: $e');
    }
  }

  void _showEditPlayerDialog(Player player) {
    final firstNameController = TextEditingController(text: player.firstName);
    final lastNameController = TextEditingController(text: player.lastName);
    final emailController = TextEditingController(
      text: player.email.contains('@placeholder.com') ? '' : player.email
    );
    final phoneController = TextEditingController(text: player.phone ?? '');
    final jerseyController = TextEditingController(text: player.jerseyNumber ?? '');
    String selectedGender = player.gender;
    String selectedPosition = player.position ?? 'Goalkeeper';
    
    final positions = ['Goalkeeper', 'Allrounder', 'Defense', 'Pivot', 'Right Wing', 'Left Wing'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${player.fullName} bearbeiten'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'Vorname *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nachname *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'E-Mail',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Telefon',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: jerseyController,
                        decoration: const InputDecoration(
                          labelText: 'Rückennummer',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedGender,
                        decoration: const InputDecoration(
                          labelText: 'Geschlecht',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(value: 'male', child: Text('Männlich')),
                          DropdownMenuItem(value: 'female', child: Text('Weiblich')),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            selectedGender = value!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedPosition,
                        decoration: const InputDecoration(
                          labelText: 'Position',
                          border: OutlineInputBorder(),
                        ),
                        items: positions.map((pos) => DropdownMenuItem(
                          value: pos,
                          child: Text(pos),
                        )).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedPosition = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () => _updatePlayer(
                player,
                firstNameController.text,
                lastNameController.text,
                emailController.text,
                phoneController.text.isEmpty ? null : phoneController.text,
                jerseyController.text.isEmpty ? null : jerseyController.text,
                selectedGender,
                selectedPosition,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createPlayerAndAddToTeam(
    String firstName,
    String lastName,
    String email,
    String? phone,
    String? jerseyNumber,
    String gender,
    String position,
  ) async {
    if (firstName.trim().isEmpty || lastName.trim().isEmpty) {
      _showError('Vorname und Nachname sind erforderlich');
      return;
    }

    Navigator.of(context).pop(); // Close dialog

    try {
      // Create new player
      final newPlayer = Player(
        id: '',
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        email: email.trim().isEmpty ? 'no-email-${DateTime.now().millisecondsSinceEpoch}@placeholder.com' : email.trim().toLowerCase(),
        phone: phone?.trim(),
        jerseyNumber: jerseyNumber?.trim(),
        position: position,
        gender: gender,
        createdAt: DateTime.now(),
      );

      final playerId = await _playerService.addPlayer(newPlayer);
      if (playerId != null) {
        // Add player to team roster
        final updatedRosterIds = List<String>.from(_team!.rosterPlayerIds);
        updatedRosterIds.add(playerId);
        
        final updatedTeam = Team(
          id: _team!.id,
          name: _team!.name,
          teamManager: _team!.teamManager,
          logoUrl: _team!.logoUrl,
          city: _team!.city,
          bundesland: _team!.bundesland,
          division: _team!.division,
          clubId: _team!.clubId,
          rosterPlayerIds: updatedRosterIds,
          createdAt: _team!.createdAt,
        );

        print('🏐 Adding new player to roster');
        print('🏐 Updated roster IDs: $updatedRosterIds');
        final success = await _teamService.updateTeam(_team!.id, updatedTeam);
        print('🏐 Team update success: $success');
        if (success) {
          if (mounted) {
            setState(() {
              _team = updatedTeam;
              _players.add(Player(
               id: playerId,
               firstName: newPlayer.firstName,
               lastName: newPlayer.lastName,
               email: newPlayer.email,
               phone: newPlayer.phone,
               jerseyNumber: newPlayer.jerseyNumber,
               position: newPlayer.position,
               gender: newPlayer.gender,
               createdAt: newPlayer.createdAt,
             ));
            });
          }
          _showSuccess('Spieler erfolgreich erstellt und zum Kader hinzugefügt!');
        } else {
          _showError('Spieler erstellt, aber Fehler beim Hinzufügen zum Kader');
        }
      } else {
        _showError('Fehler beim Erstellen des Spielers');
      }
    } catch (e) {
      _showError('Fehler beim Erstellen: $e');
    }
  }

  Future<void> _addPlayerToTeam(Player player) async {
    Navigator.of(context).pop(); // Close dialog

    try {
      // Add player to team roster
      final updatedRosterIds = List<String>.from(_team!.rosterPlayerIds);
      updatedRosterIds.add(player.id);
      
      final updatedTeam = Team(
        id: _team!.id,
        name: _team!.name,
        teamManager: _team!.teamManager,
        logoUrl: _team!.logoUrl,
        city: _team!.city,
        bundesland: _team!.bundesland,
        division: _team!.division,
        clubId: _team!.clubId,
        rosterPlayerIds: updatedRosterIds,
        createdAt: _team!.createdAt,
      );

      print('🏐 Adding existing player to roster: ${player.fullName}');
      print('🏐 Updated roster IDs: $updatedRosterIds');
      final success = await _teamService.updateTeam(_team!.id, updatedTeam);
      print('🏐 Team update success: $success');
      if (success) {
        if (mounted) {
          setState(() {
            _team = updatedTeam;
            _players.add(player);
          });
        }
        _showSuccess('Spieler erfolgreich zum Kader hinzugefügt!');
      } else {
        _showError('Fehler beim Hinzufügen zum Kader');
      }
    } catch (e) {
      _showError('Fehler beim Hinzufügen: $e');
    }
  }

  Future<void> _updatePlayer(
    Player originalPlayer,
    String firstName,
    String lastName,
    String email,
    String? phone,
    String? jerseyNumber,
    String gender,
    String position,
  ) async {
    if (firstName.trim().isEmpty || lastName.trim().isEmpty) {
      _showError('Vorname und Nachname sind erforderlich');
      return;
    }

    Navigator.of(context).pop(); // Close dialog

    try {
      // Handle email - if empty, keep existing placeholder or create new one
      String finalEmail;
      if (email.trim().isEmpty) {
        // If original email was already a placeholder, keep it; otherwise create new placeholder
        if (originalPlayer.email.contains('@placeholder.com')) {
          finalEmail = originalPlayer.email;
        } else {
          finalEmail = 'no-email-${DateTime.now().millisecondsSinceEpoch}@placeholder.com';
        }
      } else {
        finalEmail = email.trim().toLowerCase();
      }

      final updatedPlayer = originalPlayer.copyWith(
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        email: finalEmail,
        phone: phone?.trim(),
        jerseyNumber: jerseyNumber?.trim(),
        position: position,
        gender: gender,
      );

      final success = await _playerService.updatePlayer(updatedPlayer);
      if (success) {
        setState(() {
          final index = _players.indexWhere((p) => p.id == originalPlayer.id);
          if (index != -1) {
            _players[index] = updatedPlayer;
          }
        });
        _showSuccess('Spieler erfolgreich aktualisiert!');
      } else {
        _showError('Fehler beim Aktualisieren des Spielers');
      }
    } catch (e) {
      _showError('Fehler beim Aktualisieren: $e');
    }
  }

  void _changeTeamManager() {
    _showTeamManagerSelectionDialog(isChanging: true);
  }

  void _assignTeamManager() {
    _showTeamManagerSelectionDialog(isChanging: false);
  }

  void _showTeamManagerSelectionDialog({required bool isChanging}) async {
    try {
      // Get all available team managers
      final allManagers = await _teamManagerService.getAllTeamManagers();
      
      if (allManagers.isEmpty) {
        _showError('Keine Team Manager gefunden. Erstellen Sie zunächst Team Manager.');
        return;
      }

      // Filter out inactive managers
      final activeManagers = allManagers.where((manager) => manager.isActive).toList();
      
      if (activeManagers.isEmpty) {
        _showError('Keine aktiven Team Manager gefunden.');
        return;
      }

      String searchQuery = '';
      List<TeamManager> filteredManagers = activeManagers;

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(isChanging ? 'Team Manager ändern' : 'Team Manager zuweisen'),
            content: SizedBox(
              width: 500,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Team Manager suchen...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        searchQuery = value.toLowerCase();
                        filteredManagers = activeManagers.where((manager) =>
                          manager.name.toLowerCase().contains(searchQuery) ||
                          manager.email.toLowerCase().contains(searchQuery)
                        ).toList();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredManagers.length,
                      itemBuilder: (context, index) {
                        final manager = filteredManagers[index];
                        final isCurrentManager = _teamManager?.id == manager.id;
                        
                        return Card(
                          color: isCurrentManager ? Colors.yellow.shade50 : null,
                          child: ListTile(
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isCurrentManager ? const Color(0xFFffd665) : Colors.grey.shade600,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Center(
                                child: Text(
                                  manager.name.isNotEmpty ? manager.name[0].toUpperCase() : 'M',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              manager.name,
                              style: TextStyle(
                                fontWeight: isCurrentManager ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(manager.email),
                                if (manager.phone != null)
                                  Text(manager.phone!),
                                if (isCurrentManager)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFffd665),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Aktueller Manager',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: isCurrentManager
                                ? (isChanging 
                                    ? ElevatedButton(
                                        onPressed: () => _removeTeamManager(),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Entfernen'),
                                      )
                                    : const Icon(Icons.check_circle, color: Colors.green))
                                : ElevatedButton(
                                    onPressed: () => _assignManagerToTeam(manager),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: Text(isChanging ? 'Ändern zu' : 'Zuweisen'),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Schließen'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      _showError('Fehler beim Laden der Team Manager: $e');
    }
  }

  Future<void> _assignManagerToTeam(TeamManager manager) async {
    Navigator.of(context).pop(); // Close dialog

    try {
      // Update team with new manager
      final updatedTeam = Team(
        id: _team!.id,
        name: _team!.name,
        teamManager: manager.name,
        logoUrl: _team!.logoUrl,
        city: _team!.city,
        bundesland: _team!.bundesland,
        division: _team!.division,
        clubId: _team!.clubId,
        rosterPlayerIds: _team!.rosterPlayerIds,
        createdAt: _team!.createdAt,
      );

      final teamSuccess = await _teamService.updateTeam(_team!.id, updatedTeam);
      
      // Also add team to manager's team list
      final managerSuccess = await _teamManagerService.assignTeamToManager(manager.id, _team!.id);

      if (teamSuccess && managerSuccess) {
        setState(() {
          _team = updatedTeam;
          _teamManager = manager;
        });
        _showSuccess('Team Manager erfolgreich zugewiesen!');
      } else {
        _showError('Fehler beim Zuweisen des Team Managers');
      }
    } catch (e) {
      _showError('Fehler beim Zuweisen: $e');
    }
  }

  Future<void> _removeTeamManager() async {
    Navigator.of(context).pop(); // Close dialog

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Team Manager entfernen'),
        content: Text('Möchten Sie "${_teamManager!.name}" als Team Manager entfernen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Entfernen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Update team to remove manager
        final updatedTeam = Team(
          id: _team!.id,
          name: _team!.name,
          teamManager: null,
          logoUrl: _team!.logoUrl,
          city: _team!.city,
          bundesland: _team!.bundesland,
          division: _team!.division,
          clubId: _team!.clubId,
          rosterPlayerIds: _team!.rosterPlayerIds,
          createdAt: _team!.createdAt,
        );

        final teamSuccess = await _teamService.updateTeam(_team!.id, updatedTeam);
        
        // Also remove team from manager's team list
        final managerSuccess = await _teamManagerService.removeTeamFromManager(_teamManager!.id, _team!.id);

        if (teamSuccess && managerSuccess) {
          setState(() {
            _team = updatedTeam;
            _teamManager = null;
          });
          _showSuccess('Team Manager erfolgreich entfernt!');
        } else {
          _showError('Fehler beim Entfernen des Team Managers');
        }
      } catch (e) {
        _showError('Fehler beim Entfernen: $e');
      }
    }
  }

  void _deleteTeam() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Team löschen'),
        content: Text('Möchten Sie das Team "${_team!.name}" wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await _teamService.deleteTeam(_team!.id);
        if (success) {
          Navigator.of(context).pop(); // Go back to team management
          _showSuccess('Team erfolgreich gelöscht!');
        } else {
          _showError('Fehler beim Löschen des Teams');
        }
      } catch (e) {
        _showError('Fehler beim Löschen: $e');
      }
    }
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
} 