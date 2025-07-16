import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../models/team.dart';
import '../models/tournament.dart';
import '../models/player.dart';
import '../services/team_service.dart';
import '../services/tournament_service.dart';
import '../services/player_service.dart';
import '../widgets/responsive_layout.dart';
import '../screens/bulk_add_players_screen.dart';

class TeamDetailScreen extends StatefulWidget {
  final String teamId;
  final String subSection;
  
  const TeamDetailScreen({super.key, required this.teamId, this.subSection = 'overview'});

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  final TeamService _teamService = TeamService();
  final PlayerService _playerService = PlayerService();
  Team? _team;
  List<Player> _teamPlayers = [];
  bool _isLoading = true;
  bool _playersLoading = false;
  late String _selectedSubSection;

  @override
  void initState() {
    super.initState();
    _selectedSubSection = widget.subSection;
    _loadTeam();
  }

  Future<void> _loadTeam() async {
    try {
      final team = await _teamService.getTeamById(widget.teamId);
      if (mounted) {
        setState(() {
          _team = team;
          _isLoading = false;
        });
        _loadTeamPlayers();
      }
    } catch (e) {
      print('Error loading team: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadTeamPlayers() async {
    if (_team == null) return;
    
    setState(() {
      _playersLoading = true;
    });

    try {
      // For now, avoid complex queries that require Firestore indexes
      // In a real implementation, you would have a proper team-player relationship
      final teamPlayers = <Player>[];
      
      if (mounted) {
        setState(() {
          _teamPlayers = teamPlayers;
          _playersLoading = false;
        });
      }
    } catch (e) {
      print('Error loading team players: $e');
      if (mounted) {
        setState(() {
          _playersLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return ResponsiveLayout(
        selectedSection: 'team_${widget.teamId}_${widget.subSection}',
        onSectionChanged: (section) {},
        title: 'Team wird geladen...',
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_team == null) {
      return ResponsiveLayout(
        selectedSection: 'team_${widget.teamId}_${widget.subSection}',
        onSectionChanged: (section) {},
        title: 'Team nicht gefunden',
        body: const Center(
          child: Text('Team konnte nicht geladen werden'),
        ),
      );
    }

    return ResponsiveLayout(
      selectedSection: 'team_${widget.teamId}_${widget.subSection}',
      onSectionChanged: (section) {
        // Navigation is handled by the parent HomeScreen
      },
      title: _getScreenTitle(),
      body: _getContentForSection(_selectedSubSection),
    );
  }

  String _getScreenTitle() {
    final sectionName = _getSectionName(_selectedSubSection);
    return '${_team!.name} - $sectionName';
  }

  String _getSectionName(String section) {
    switch (section) {
      case 'overview':
        return 'Übersicht';
      case 'tournaments':
        return 'Turnier Anmeldung';
      case 'roster':
        return 'Kader Verwaltung';
      case 'settings':
        return 'Einstellungen';
      default:
        return 'Übersicht';
    }
  }

  Widget _getContentForSection(String section) {
    switch (section) {
      case 'overview':
        return _buildOverviewContent();
      case 'tournaments':
        return _buildTournamentRegistrationContent();
      case 'roster':
        return _buildRosterContent();
      case 'settings':
        return _buildSettingsContent();
      default:
        return _buildOverviewContent();
    }
  }

  Widget _buildOverviewContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Team Info Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D5016),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Icon(
                      Icons.group,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _team!.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFffd665),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _team!.division,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_team!.city}, ${_team!.bundesland}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Header
          Row(
            children: [
              const Icon(Icons.dashboard, color: Colors.black87),
              const SizedBox(width: 8),
              const Text(
                'Team Übersicht',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Stats Cards
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.sports_volleyball, size: 32, color: Colors.blue),
                        const SizedBox(height: 8),
                        const Text(
                          '12',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        Text(
                          'Turniere gespielt',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.emoji_events, size: 32, color: Colors.green),
                        const SizedBox(height: 8),
                        const Text(
                          '8',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          'Siege',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Recent Results
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Letzte Ergebnisse',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildResultItem('vs. Beach Warriors', '2:1', true, '15.03.2024'),
                  _buildResultItem('vs. Sand Kings', '1:2', false, '12.03.2024'),
                  _buildResultItem('vs. Volleyball Pros', '2:0', true, '08.03.2024'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(String opponent, String score, bool won, String date) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: won ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: won ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            won ? Icons.check_circle : Icons.cancel,
            color: won ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              opponent,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            score,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: won ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            date,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentRegistrationContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sports_volleyball, color: Colors.black87),
              const SizedBox(width: 8),
              const Text(
                'Turnier Anmeldung',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Verfügbare Turniere',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildTournamentItem('German Beach Open 2024', '25.-27. Mai 2024', 'Hamburg'),
                  _buildTournamentItem('Nord Cup 2024', '15.-16. Juni 2024', 'Bremen'),
                  _buildTournamentItem('Summer Beach Tournament', '20.-22. Juli 2024', 'Rostock'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentItem(String name, String date, String location) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text('Datum: $date', style: TextStyle(color: Colors.grey[600])),
          Text('Ort: $location', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Anmeldung für $name gestartet'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D5016),
              foregroundColor: Colors.white,
            ),
            child: const Text('Anmelden'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings, color: Colors.black87),
              const SizedBox(width: 8),
              const Text(
                'Team Einstellungen',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Team Informationen',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildSettingItem('Team Name', _team!.name),
                  _buildSettingItem('Division', _team!.division),
                  _buildSettingItem('Stadt', _team!.city),
                  _buildSettingItem('Bundesland', _team!.bundesland),
                  if (_team!.teamManager != null)
                    _buildSettingItem('Team Manager', _team!.teamManager!),
                  
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Team bearbeiten - Coming Soon!'),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D5016),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.edit),
                    label: const Text('Team bearbeiten'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRosterContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people, color: Colors.black87),
              const SizedBox(width: 8),
              const Text(
                'Kader Verwaltung',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Spieler Verwaltung',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.group_add,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Kader-Verwaltung wird entwickelt',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Hier können Sie bald Ihre Spieler verwalten, hinzufügen und bearbeiten.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  Column(
                    children: [
                      // First row of buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showAddPlayerDialog(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2D5016),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Spieler hinzufügen'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showBulkImportDialog(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.upload),
                              label: const Text('Bulk Import'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Second row of buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showCurrentRoster(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.list),
                              label: const Text('Aktueller Kader'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showPlayerSearchDialog(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.search),
                              label: const Text('Spieler suchen'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPlayerDialog() {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final positionController = TextEditingController();
    final jerseyNumberController = TextEditingController();
    String selectedGender = 'male';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Neuer Spieler hinzufügen'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
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
                      const SizedBox(width: 16),
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
                      labelText: 'E-Mail *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Telefon',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: positionController,
                          decoration: const InputDecoration(
                            labelText: 'Position',
                            border: OutlineInputBorder(),
                            hintText: 'z.B. Blocker, Defender',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: jerseyNumberController,
                          decoration: const InputDecoration(
                            labelText: 'Trikotnummer',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedGender,
                    decoration: const InputDecoration(
                      labelText: 'Geschlecht *',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Männlich')),
                      DropdownMenuItem(value: 'female', child: Text('Weiblich')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedGender = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (firstNameController.text.trim().isEmpty || 
                    lastNameController.text.trim().isEmpty ||
                    emailController.text.trim().isEmpty) {
                  toastification.show(
                    context: context,
                    type: ToastificationType.error,
                    style: ToastificationStyle.fillColored,
                    title: const Text('Fehler'),
                    description: const Text('Bitte füllen Sie alle Pflichtfelder aus.'),
                    autoCloseDuration: const Duration(seconds: 3),
                  );
                  return;
                }

                setState(() {
                  isLoading = true;
                });

                try {
                  final player = Player(
                    id: '',
                    firstName: firstNameController.text.trim(),
                    lastName: lastNameController.text.trim(),
                    email: emailController.text.trim(),
                    phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                    position: positionController.text.trim().isEmpty ? null : positionController.text.trim(),
                    jerseyNumber: jerseyNumberController.text.trim().isEmpty ? null : jerseyNumberController.text.trim(),
                    clubId: _team?.clubId,
                    gender: selectedGender,
                    createdAt: DateTime.now(),
                  );

                                                    // For demo purposes, add the player to the local list
                  // In a real implementation, this would use the PlayerService
                  final newPlayer = Player(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    firstName: firstNameController.text.trim(),
                    lastName: lastNameController.text.trim(),
                    email: emailController.text.trim(),
                    phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                    position: positionController.text.trim().isEmpty ? null : positionController.text.trim(),
                    jerseyNumber: jerseyNumberController.text.trim().isEmpty ? null : jerseyNumberController.text.trim(),
                    clubId: _team?.clubId,
                    gender: selectedGender,
                    createdAt: DateTime.now(),
                  );
                  
                  // Add to local team players list
                  setState(() {
                    _teamPlayers.add(newPlayer);
                  });
                  
                  Navigator.of(context).pop();
                  toastification.show(
                    context: context,
                    type: ToastificationType.success,
                    style: ToastificationStyle.fillColored,
                    title: const Text('Erfolg'),
                    description: Text('${newPlayer.fullName} wurde hinzugefügt.'),
                    autoCloseDuration: const Duration(seconds: 3),
                  );
                } catch (e) {
                  toastification.show(
                    context: context,
                    type: ToastificationType.error,
                    style: ToastificationStyle.fillColored,
                    title: const Text('Fehler'),
                    description: Text('Fehler beim Hinzufügen: $e'),
                    autoCloseDuration: const Duration(seconds: 3),
                  );
                } finally {
                  setState(() {
                    isLoading = false;
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D5016),
                foregroundColor: Colors.white,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBulkImportDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const BulkAddPlayersScreen(),
      ),
    ).then((_) {
      // Reload players when returning from bulk import
      _loadTeamPlayers();
    });
  }

  void _showCurrentRoster() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.people, color: Color(0xFF2D5016)),
            const SizedBox(width: 8),
            const Text('Aktueller Kader'),
            const Spacer(),
            Text(
              '${_teamPlayers.length} Spieler',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          height: 400,
          child: _playersLoading
              ? const Center(child: CircularProgressIndicator())
              : _teamPlayers.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.group_off, size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Noch keine Spieler im Kader',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Fügen Sie Spieler hinzu, um Ihren Kader aufzubauen.',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Header row
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Expanded(flex: 3, child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                              Expanded(flex: 2, child: Text('Position', style: TextStyle(fontWeight: FontWeight.bold))),
                              Expanded(child: Text('Nr.', style: TextStyle(fontWeight: FontWeight.bold))),
                              Expanded(child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Players list
                        Expanded(
                          child: ListView.builder(
                            itemCount: _teamPlayers.length,
                            itemBuilder: (context, index) {
                              final player = _teamPlayers[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              player.fullName,
                                              style: const TextStyle(fontWeight: FontWeight.w500),
                                            ),
                                            if (player.email.isNotEmpty)
                                              Text(
                                                player.email,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          player.position ?? '-',
                                          style: TextStyle(color: Colors.grey[700]),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          player.jerseyNumber ?? '-',
                                          style: TextStyle(color: Colors.grey[700]),
                                        ),
                                      ),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: player.isActive ? Colors.green.shade100 : Colors.red.shade100,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            player.isActive ? 'Aktiv' : 'Inaktiv',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: player.isActive ? Colors.green.shade800 : Colors.red.shade800,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ],
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
          if (_teamPlayers.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _showAddPlayerDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D5016),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Spieler hinzufügen'),
            ),
        ],
      ),
    );
  }

  void _showPlayerSearchDialog() {
    final searchController = TextEditingController();
    List<Player> searchResults = [];
    List<Player> allPlayers = [];
    bool isLoading = false;
    bool isSearching = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
                     // For now, avoid complex queries that require Firestore indexes
           if (allPlayers.isEmpty && !isLoading) {
             setState(() {
               allPlayers = []; // Empty for now to avoid index requirement
               searchResults = [];
               isLoading = false;
             });
           }

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.search, color: Color(0xFF2D5016)),
                SizedBox(width: 8),
                Text('Spieler suchen'),
              ],
            ),
            content: SizedBox(
              width: 500,
              height: 400,
              child: Column(
                children: [
                  // Search field
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Name oder E-Mail eingeben...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (query) {
                      setState(() {
                        isSearching = true;
                        if (query.trim().isEmpty) {
                          searchResults = allPlayers.take(10).toList();
                        } else {
                          searchResults = allPlayers.where((player) {
                            final name = '${player.firstName} ${player.lastName}'.toLowerCase();
                            final email = player.email.toLowerCase();
                            final searchQuery = query.toLowerCase();
                            return name.contains(searchQuery) || email.contains(searchQuery);
                          }).toList();
                        }
                        isSearching = false;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Results
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : isSearching
                            ? const Center(child: CircularProgressIndicator())
                            : searchResults.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                                        const SizedBox(height: 16),
                                        Text(
                                          searchController.text.trim().isEmpty
                                              ? 'Noch keine Spieler im System'
                                              : 'Keine Spieler gefunden',
                                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: searchResults.length,
                                    itemBuilder: (context, index) {
                                      final player = searchResults[index];
                                      final isAlreadyInTeam = _teamPlayers.any((p) => p.id == player.id);
                                      
                                      return Card(
                                        margin: const EdgeInsets.symmetric(vertical: 2),
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: const Color(0xFF2D5016),
                                            child: Text(
                                              player.firstName[0].toUpperCase(),
                                              style: const TextStyle(color: Colors.white),
                                            ),
                                          ),
                                          title: Text(player.fullName),
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(player.email),
                                              if (player.position != null)
                                                Text('Position: ${player.position}'),
                                            ],
                                          ),
                                          trailing: isAlreadyInTeam
                                              ? const Chip(
                                                  label: Text('Im Team'),
                                                  backgroundColor: Colors.green,
                                                  labelStyle: TextStyle(color: Colors.white),
                                                )
                                              : ElevatedButton(
                                                  onPressed: () async {
                                                    // In a real implementation, you would add the player to the team
                                                    // For now, we'll show a toast that the feature is coming
                                                    toastification.show(
                                                      context: context,
                                                      type: ToastificationType.info,
                                                      style: ToastificationStyle.fillColored,
                                                      title: const Text('Info'),
                                                      description: Text('${player.fullName} zum Team hinzufügen - Diese Funktion wird noch implementiert.'),
                                                      autoCloseDuration: const Duration(seconds: 3),
                                                    );
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF2D5016),
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
          );
        },
      ),
    );
  }
}

// Content-only widget for use within ResponsiveLayout
class TeamDetailContent extends StatefulWidget {
  final String teamId;
  final String subSection;
  
  const TeamDetailContent({super.key, required this.teamId, this.subSection = 'overview'});

  @override
  State<TeamDetailContent> createState() => _TeamDetailContentState();
}

class _TeamDetailContentState extends State<TeamDetailContent> {
  final TeamService _teamService = TeamService();
  final TournamentService _tournamentService = TournamentService();
  final PlayerService _playerService = PlayerService();
  Team? _team;
  List<Tournament> _tournaments = [];
  List<Player> _teamPlayers = [];
  bool _isLoading = true;
  bool _tournamentsLoading = true;
  bool _playersLoading = false;
  late String _selectedSubSection;

  @override
  void initState() {
    super.initState();
    _selectedSubSection = widget.subSection;
    _loadTeam();
  }

  @override
  void didUpdateWidget(TeamDetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subSection != widget.subSection) {
      setState(() {
        _selectedSubSection = widget.subSection;
      });
    }
  }

  Future<void> _loadTeam() async {
    try {
      final team = await _teamService.getTeamById(widget.teamId);
      if (mounted) {
        setState(() {
          _team = team;
          _isLoading = false;
        });
        // Load tournaments and players after team is loaded
        _loadTournaments();
        _loadTeamPlayers();
      }
    } catch (e) {
      print('Error loading team: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadTeamPlayers() async {
    if (_team == null) return;
    
    setState(() {
      _playersLoading = true;
    });

    try {
      // For now, avoid complex queries that require Firestore indexes
      // In a real implementation, you would have a proper team-player relationship
      final teamPlayers = <Player>[];
      
      if (mounted) {
        setState(() {
          _teamPlayers = teamPlayers;
          _playersLoading = false;
        });
      }
    } catch (e) {
      print('Error loading team players: $e');
      if (mounted) {
        setState(() {
          _playersLoading = false;
        });
      }
    }
  }

  Future<void> _loadTournaments() async {
    try {
      _tournamentService.getTournamentsWithCache().listen((tournaments) {
        if (mounted) {
          final upcomingTournaments = tournaments.where((t) => t.status == 'upcoming').toList();
          final eligibleTournaments = upcomingTournaments.where((t) => _isTeamEligibleForTournament(t)).toList();
          
          setState(() {
            _tournaments = eligibleTournaments;
            _tournamentsLoading = false;
          });
        }
      });
    } catch (e) {
      print('Error loading tournaments: $e');
      if (mounted) {
        setState(() {
          _tournamentsLoading = false;
        });
      }
    }
  }

  bool _isTeamEligibleForTournament(Tournament tournament) {
    if (_team == null) return false;
    
    // Check if team division matches tournament categories
    String teamDivision = _team!.division.toLowerCase();
    
    // Check if team is a senior team (contains "senior" or adult divisions)
    bool isTeamSenior = teamDivision.contains('senior') || 
                       teamDivision.contains('men') ||
                       teamDivision.contains('women') ||
                       teamDivision.contains('fun');
    
    // Check if team is a junior team (contains age groups)
    bool isTeamJunior = teamDivision.contains('u14') ||
                       teamDivision.contains('u16') ||
                       teamDivision.contains('u18') ||
                       teamDivision.contains('junior');
    
    // Check tournament categories
    for (String category in tournament.categories) {
      String categoryLower = category.toLowerCase();
      
      // Senior teams can register for Senior Cups
      if (isTeamSenior && categoryLower.contains('seniors')) {
        return true;
      }
      
      // Junior teams can register for Junior Cups
      if (isTeamJunior && categoryLower.contains('juniors')) {
        return true;
      }
    }
    
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_team == null) {
      return const Center(
        child: Text('Team konnte nicht geladen werden'),
      );
    }

    return _getContentForSection(_selectedSubSection);
  }

  Widget _getContentForSection(String section) {
    switch (section) {
      case 'overview':
        return _buildOverviewContent();
      case 'tournaments':
        return _buildTournamentRegistrationContent();
      case 'roster':
        return _buildRosterContent();
      case 'settings':
        return _buildSettingsContent();
      default:
        return _buildOverviewContent();
    }
  }

  Widget _buildOverviewContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Team Info Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D5016),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Icon(
                      Icons.group,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _team!.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFffd665),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _team!.division,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_team!.city}, ${_team!.bundesland}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Header
          Row(
            children: [
              const Icon(Icons.dashboard, color: Colors.black87),
              const SizedBox(width: 8),
              const Text(
                'Team Übersicht',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Real data message
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Team Informationen',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hier werden in Zukunft echte Statistiken und Ergebnisse aus der Firestore-Datenbank angezeigt.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aktuell verfügbare Daten:',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('• Team Name: ${_team!.name}'),
                  Text('• Division: ${_team!.division}'),
                  Text('• Stadt: ${_team!.city}'),
                  Text('• Bundesland: ${_team!.bundesland}'),
                  if (_team!.teamManager != null)
                    Text('• Team Manager: ${_team!.teamManager}'),
                  if (_team!.clubId != null)
                    Text('• Verein ID: ${_team!.clubId}'),
                  Text('• Erstellt am: ${_team!.createdAt.day}.${_team!.createdAt.month}.${_team!.createdAt.year}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentRegistrationContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sports_volleyball, color: Colors.black87),
              const SizedBox(width: 8),
              const Text(
                'Turnier Anmeldung',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          if (_tournamentsLoading)
            const Center(child: CircularProgressIndicator())
          else if (_tournaments.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verfügbare Turniere',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _team != null 
                        ? 'Aktuell sind keine Turniere für ${_team!.division} Teams verfügbar.'
                        : 'Aktuell sind keine Turniere verfügbar.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_team != null) ...[
                      Text(
                        '• Senior Teams (Men\'s, Women\'s, Seniors, FUN) können sich für "GBO Seniors Cup" Turniere anmelden',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• Junior Teams (U14, U16, U18) können sich für "GBO Juniors Cup" Turniere anmelden',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verfügbare Turniere (${_tournaments.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ..._tournaments.map((tournament) => _buildTournamentCard(tournament)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTournamentCard(Tournament tournament) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tournament.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            tournament.location,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '${tournament.startDate.day}.${tournament.startDate.month}.${tournament.startDate.year}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (tournament.endDate != null) ...[
                            const Text(' - '),
                            Text(
                              '${tournament.endDate!.day}.${tournament.endDate!.month}.${tournament.endDate!.year}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: tournament.categories.map((category) =>
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFffd665),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              category,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ).toList(),
                      ),
                      if (tournament.description != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          tournament.description!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D5016),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${tournament.points} Punkte',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Anmeldung für "${tournament.name}" - Coming Soon!'),
                            backgroundColor: Colors.blue,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D5016),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('Anmelden'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings, color: Colors.black87),
              const SizedBox(width: 8),
              const Text(
                'Team Einstellungen',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Team Informationen',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildSettingItem('Team Name', _team!.name),
                  _buildSettingItem('Division', _team!.division),
                  _buildSettingItem('Stadt', _team!.city),
                  _buildSettingItem('Bundesland', _team!.bundesland),
                  if (_team!.teamManager != null)
                    _buildSettingItem('Team Manager', _team!.teamManager!),
                  
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Team bearbeiten - Coming Soon!'),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D5016),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.edit),
                    label: const Text('Team bearbeiten'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRosterContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people, color: Colors.black87),
              const SizedBox(width: 8),
              const Text(
                'Kader Verwaltung',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Spieler Verwaltung',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.group_add,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Kader-Verwaltung wird entwickelt',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Hier können Sie bald Ihre Spieler verwalten, hinzufügen und bearbeiten.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  Column(
                    children: [
                      // First row of buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showAddPlayerDialog(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2D5016),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Spieler hinzufügen'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showBulkImportDialog(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.upload),
                              label: const Text('Bulk Import'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Second row of buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showCurrentRoster(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.list),
                              label: const Text('Aktueller Kader'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showPlayerSearchDialog(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.search),
                              label: const Text('Spieler suchen'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPlayerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Spieler hinzufügen'),
        content: const Text('Diese Funktion wird implementiert, um Spieler direkt zu Ihrem Team hinzuzufügen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  void _showBulkImportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Import'),
        content: const Text('Diese Funktion wird implementiert, um mehrere Spieler gleichzeitig zu importieren.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  void _showCurrentRoster() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aktueller Kader'),
        content: const Text('Diese Funktion wird implementiert, um den aktuellen Kader anzuzeigen und zu bearbeiten.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  void _showPlayerSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Spieler suchen'),
        content: const Text('Diese Funktion wird implementiert, um Spieler zu suchen und zu Ihrem Team hinzuzufügen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }
} 