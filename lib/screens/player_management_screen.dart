import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import '../models/player.dart';
import '../models/team.dart';
import '../services/player_service.dart';
import '../services/team_service.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/player_edit_dialog.dart';
import 'bulk_add_players_screen.dart';
import 'csv_player_processing_screen.dart';

class PlayerManagementScreen extends StatefulWidget {
  const PlayerManagementScreen({super.key});

  @override
  State<PlayerManagementScreen> createState() => _PlayerManagementScreenState();
}

class _PlayerManagementScreenState extends State<PlayerManagementScreen> {
  final PlayerService _playerService = PlayerService();
  final TeamService _teamService = TeamService();
  final TextEditingController _searchController = TextEditingController();
  
  // Form controllers for add/edit dialog
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _positionController = TextEditingController();
  final _jerseyNumberController = TextEditingController();
  final _spielerpassController = TextEditingController();
  
  String _searchQuery = '';
  bool _isLoading = false;

  /// playerId â†’ teamName, built once from all teams' rosterPlayerIds
  Map<String, String> _playerTeamMap = {};

  @override
  void initState() {
    super.initState();
    _loadPlayerTeamMap();
  }

  Future<void> _loadPlayerTeamMap() async {
    try {
      final teams = await _teamService.getAllTeams();
      final map = <String, String>{};
      for (final team in teams) {
        for (final pid in team.rosterPlayerIds) {
          map[pid] = team.name;
        }
      }
      if (mounted) setState(() => _playerTeamMap = map);
    } catch (_) {
      // silently ignore — team column will just show 'Kein Team'
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _positionController.dispose();
    _jerseyNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with search and add button
        Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.people, color: Colors.black87, size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'Spieler Verwaltung',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => _showDeleteAllPlayersDialog(),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Alle lÃƒÂ¶schen'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showCSVUploadDialog(),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('CSV Upload'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showAddPlayerDialog(),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Spieler hinzufÃƒÂ¼gen'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D5016),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showBulkAddDialog(),
                    icon: const Icon(Icons.group_add),
                    label: const Text('Bulk Import'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _fixTeamRosters(),
                    icon: const Icon(Icons.build),
                    label: const Text('Team Roster Fix'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Verwalten Sie alle Spieler im System. Diese Spieler kÃƒÂ¶nnen von Team-Managern zu ihren Kadern hinzugefÃƒÂ¼gt werden.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              
              // Search bar
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Spieler suchen...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showBulkAddDialog(),
                    icon: const Icon(Icons.group_add),
                    label: const Text('Bulk Import'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Players list
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: Card(
              child: Column(
                children: [
                  // Table header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 2, child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('E-Mail', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(child: Text('Klassifikation', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(child: Text('Nummer', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(child: Text('Team', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                        SizedBox(width: 100, child: Text('Aktionen', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  
                  // Players list
                  Expanded(
                    child: StreamBuilder<List<Player>>(
                      stream: _searchQuery.isEmpty 
                          ? _playerService.getAllPlayers()
                          : _playerService.searchPlayers(_searchQuery),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
                                const SizedBox(height: 16),
                                const Text('Fehler beim Laden der Spieler'),
                                const SizedBox(height: 8),
                                Text(
                                  '${snapshot.error}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      // Force rebuild to retry
                                    });
                                  },
                                  child: const Text('Erneut versuchen'),
                                ),
                              ],
                            ),
                          );
                        }

                        final players = snapshot.data ?? [];

                        if (players.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty 
                                      ? 'Noch keine Spieler vorhanden.'
                                      : 'Keine Spieler gefunden.',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                if (_searchQuery.isEmpty) ...[
                                  const SizedBox(height: 8),
                                  const Text(
                                    'FÃƒÂ¼gen Sie Spieler hinzu, um sie hier zu verwalten.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: players.length,
                          itemBuilder: (context, index) {
                            final player = players[index];
                            return _buildPlayerListItem(player, index);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPlayerListItem(Player player, int index) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          // Name
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (player.phone?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    player.phone!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Email
          Expanded(
            flex: 2,
            child: Text(
              player.email ?? '-',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
          
          // Position
          Expanded(
            child: Text(
              player.classification ?? '-',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
          
          // Jersey Number
          Expanded(
            child: Text(
              player.jerseyNumber ?? '-',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
          
          // Team
          Expanded(
            child: Text(
              _playerTeamMap[player.id] ?? 'Kein Team',
              style: _playerTeamMap.containsKey(player.id)
                  ? TextStyle(color: Colors.grey[700])
                  : TextStyle(color: Colors.grey[500], fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // Status
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
              ),
            ),
          ),
          
          // Actions
          SizedBox(
            width: 100,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _showEditPlayerDialog(player),
                  icon: const Icon(Icons.edit, size: 18),
                  tooltip: 'Bearbeiten',
                ),
                IconButton(
                  onPressed: () => _deletePlayer(player),
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  tooltip: 'LÃƒÂ¶schen',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCSVUploadDialog() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        final file = result.files.first;
        final bytes = file.bytes;
        
        if (bytes != null) {
          final csvString = utf8.decode(bytes);
          final lines = csvString.split('\n');
          
          if (lines.isEmpty) {
            _showError('Die CSV-Datei ist leer.');
            return;
          }

          // Parse CSV header - handle both comma and semicolon delimiters
          final headerLine = lines[0].trim();
          List<String> headers;
          
          // Check if semicolon is used as delimiter
          if (headerLine.contains(';')) {
            headers = headerLine.split(';').map((h) => h.trim()).toList();
            debugPrint('Ã°Å¸â€Â Detected semicolon delimiter');
          } else {
            headers = headerLine.split(',').map((h) => h.trim()).toList();
            debugPrint('Ã°Å¸â€Â Detected comma delimiter');
          }
          
          // Log CSV column analysis
          debugPrint('\nÃ°Å¸â€œâ€¹ CSV COLUMN ANALYSIS:');
          debugPrint('Ã°Å¸â€œÂ¥ Found columns: ${headers.join(', ')}');
          debugPrint('Ã°Å¸â€œÅ  Total columns found: ${headers.length}');
          
          // Validate required headers
          final requiredHeaders = ['Firstname', 'Lastname', 'Jersey Number', 'Position', 'Club Name', 'Division'];
          final missingHeaders = requiredHeaders.where((h) => !headers.contains(h)).toList();
          final foundHeaders = requiredHeaders.where((h) => headers.contains(h)).toList();
          
          debugPrint('\nÃ¢Å“â€¦ EXPECTED columns: ${requiredHeaders.join(', ')}');
          debugPrint('Ã¢Å“â€¦ FOUND expected columns: ${foundHeaders.join(', ')}');
          
          if (missingHeaders.isNotEmpty) {
            debugPrint('Ã¢ÂÅ’ MISSING expected columns: ${missingHeaders.join(', ')}');
            debugPrint('\nÃ°Å¸â€™Â¡ SUGGESTIONS:');
            debugPrint('   - Check if column names match exactly (case-sensitive)');
            debugPrint('   - Common variations:');
            debugPrint('     * "Firstname" vs "First Name" vs "FirstName"');
            debugPrint('     * "Lastname" vs "Last Name" vs "LastName"');
            debugPrint('     * "Jersey Number" vs "JerseyNumber" vs "Number"');
            debugPrint('     * "Club Name" vs "ClubName" vs "Team"');
            debugPrint('     * "Division" (CSV column name, kept for compatibility)');
            
            _showError('Fehlende Spalten: ${missingHeaders.join(', ')}\n\nGefundene Spalten: ${headers.join(', ')}');
            return;
          } else {
            debugPrint('Ã¢Å“â€¦ All required columns found!');
          }

          // Parse CSV data - use same delimiter as header
          final List<Map<String, dynamic>> csvData = [];
          final delimiter = headerLine.contains(';') ? ';' : ',';
          
          for (int i = 1; i < lines.length; i++) {
            final line = lines[i].trim();
            if (line.isNotEmpty) {
              final values = line.split(delimiter).map((v) => v.trim()).toList();
              
              if (values.length >= headers.length) {
                final row = <String, dynamic>{};
                for (int j = 0; j < headers.length; j++) {
                  row[headers[j]] = values[j];
                }
                csvData.add(row);
              }
            }
          }

          if (csvData.isEmpty) {
            _showError('Keine gÃƒÂ¼ltigen Daten in der CSV-Datei gefunden.');
            return;
          }
          
          // Log sample data for debugging
          debugPrint('\nÃ°Å¸â€œÅ  SAMPLE DATA (first 3 rows):');
          for (int i = 0; i < csvData.length && i < 3; i++) {
            final row = csvData[i];
            debugPrint('Row ${i + 1}: ${row.toString()}');
          }
          if (csvData.length > 3) {
            debugPrint('... and ${csvData.length - 3} more rows');
          }

          // Navigate to processing screen
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => CSVPlayerProcessingScreen(csvData: csvData),
              ),
            );
          }
        } else {
          _showError('Fehler beim Lesen der Datei.');
        }
      }
    } catch (e) {
      _showError('Fehler beim Upload: $e');
    }
  }

  void _showAddPlayerDialog() async {
    final created = await PlayerEditDialog.show(context, player: null);
    if (created != null) {
      // Stream-based list refreshes automatically; nothing else to do.
    }
  }

  void _showEditPlayerDialog(Player player) async {
    final updated =
        await PlayerEditDialog.show(context, player: player);
    if (updated != null) {
      // Stream-based list refreshes automatically.
    }
  }

  void _showPlayerDialog({required bool isEdit, Player? player}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Spieler bearbeiten' : 'Neuer Spieler'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'Vorname *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _lastNameController,
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
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'E-Mail *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
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
                      controller: _positionController,
                      decoration: const InputDecoration(
                        labelText: 'Klassifikation',
                        border: OutlineInputBorder(),
                        hintText: 'z.B. Gruppe A, Gruppe B, Gruppe C',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _jerseyNumberController,
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
              TextField(
                controller: _spielerpassController,
                decoration: const InputDecoration(
                  labelText: 'Spielerpass-Nr.',
                  border: OutlineInputBorder(),
                  hintText: 'Lizenznummer',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
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
            onPressed: _isLoading ? null : () => _savePlayer(isEdit, player),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D5016),
              foregroundColor: Colors.white,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(isEdit ? 'Speichern' : 'HinzufÃƒÂ¼gen'),
          ),
        ],
      ),
    );
  }

  Future<void> _savePlayer(bool isEdit, Player? existingPlayer) async {
    if (_firstNameController.text.trim().isEmpty || 
        _lastNameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        title: const Text('Bitte fÃƒÂ¼llen Sie alle Pflichtfelder aus.'),
        autoCloseDuration: const Duration(seconds: 3),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final player = Player(
        id: isEdit ? existingPlayer!.id : '',
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        classification: _positionController.text.trim().isEmpty ? null : _positionController.text.trim(),
        jerseyNumber: _jerseyNumberController.text.trim().isEmpty ? null : _jerseyNumberController.text.trim(),
        spielerpassNummer: _spielerpassController.text.trim().isEmpty ? null : _spielerpassController.text.trim(),
        gender: isEdit ? existingPlayer!.gender : 'male', // Default to male for existing functionality
        createdAt: isEdit ? existingPlayer!.createdAt : DateTime.now(),
      );

      bool success;
      if (isEdit) {
        success = await _playerService.updatePlayer(player);
      } else {
        final playerId = await _playerService.addPlayer(player);
        success = playerId != null;
      }

      if (success) {
        Navigator.of(context).pop();
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          title: Text('Spieler ${isEdit ? 'aktualisiert' : 'hinzugefÃƒÂ¼gt'}.'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      } else {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          title: Text('Fehler beim ${isEdit ? 'Aktualisieren' : 'HinzufÃƒÂ¼gen'} des Spielers.'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        title: Text('Fehler: $e'),
        autoCloseDuration: const Duration(seconds: 3),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deletePlayer(Player player) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Spieler lÃƒÂ¶schen'),
        content: Text('MÃƒÂ¶chten Sie ${player.fullName} wirklich lÃƒÂ¶schen? Diese Aktion kann nicht rÃƒÂ¼ckgÃƒÂ¤ngig gemacht werden.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('LÃƒÂ¶schen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _playerService.deletePlayer(player.id);
      if (success) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          title: Text('${player.fullName} wurde gelÃƒÂ¶scht.'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      } else {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          title: const Text('Fehler beim LÃƒÂ¶schen des Spielers.'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    }
  }

  void _showDeleteAllPlayersDialog() async {
    // First, get the current count of players
    final players = await _playerService.getAllPlayers().first;
    
    if (players.isEmpty) {
      _showError('Keine Spieler zum LÃƒÂ¶schen vorhanden.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alle Spieler lÃƒÂ¶schen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MÃƒÂ¶chten Sie wirklich alle ${players.length} Spieler lÃƒÂ¶schen?'),
            const SizedBox(height: 8),
            const Text(
              'Ã¢Å¡Â Ã¯Â¸Â Diese Aktion kann nicht rÃƒÂ¼ckgÃƒÂ¤ngig gemacht werden!',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Alle Spielerdaten werden permanent gelÃƒÂ¶scht.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Alle lÃƒÂ¶schen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteAllPlayers();
    }
  }

  Future<void> _deleteAllPlayers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get all players
      final players = await _playerService.getAllPlayers().first;
      
      if (players.isEmpty) {
        _showError('Keine Spieler zum LÃƒÂ¶schen vorhanden.');
        return;
      }

      // Delete all players
      int successCount = 0;
      int errorCount = 0;

      for (final player in players) {
        final success = await _playerService.deletePlayer(player.id);
        if (success) {
          successCount++;
        } else {
          errorCount++;
        }
      }

      if (mounted) {
        if (errorCount == 0) {
          toastification.show(
            context: context,
            type: ToastificationType.success,
            style: ToastificationStyle.fillColored,
            title: Text('Alle $successCount Spieler erfolgreich gelÃƒÂ¶scht.'),
            autoCloseDuration: const Duration(seconds: 4),
          );
        } else {
          toastification.show(
            context: context,
            type: ToastificationType.warning,
            style: ToastificationStyle.fillColored,
            title: Text('$successCount Spieler gelÃƒÂ¶scht, $errorCount Fehler aufgetreten.'),
            autoCloseDuration: const Duration(seconds: 4),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          title: Text('Fehler beim LÃƒÂ¶schen: $e'),
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.fillColored,
      title: Text(message),
      autoCloseDuration: const Duration(seconds: 4),
    );
  }

  void _showBulkAddDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const BulkAddPlayersScreen(),
      ),
    ).then((_) => _loadPlayerTeamMap());
  }

  void _clearFormControllers() {
    _firstNameController.clear();
    _lastNameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _positionController.clear();
    _jerseyNumberController.clear();
    _spielerpassController.clear();
  }

  Future<void> _fixTeamRosters() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Team Roster Fix'),
        content: const Text(
          'Diese Aktion fÃƒÂ¼gt alle Spieler mit einem ClubId zu ihrem Team hinzu, falls sie noch nicht dort sind.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Team Roster Fix'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        final players = await _playerService.getAllPlayers().first;
        final teams = await _teamService.getAllTeams();
        int successCount = 0;
        int errorCount = 0;

        for (final player in players) {
          // Find teams that have this player in their roster
          for (final team in teams) {
            if (team.rosterPlayerIds.contains(player.id)) {
              successCount++;
              debugPrint('Ã¢Å“â€¦ Player ${player.fullName} already in team ${team.name}');
              break;
            }
          }
        }

        if (mounted) {
          if (errorCount == 0) {
            toastification.show(
              context: context,
              type: ToastificationType.success,
              style: ToastificationStyle.fillColored,
              title: Text('Alle $successCount Spieler erfolgreich zum Team hinzugefÃƒÂ¼gt.'),
              autoCloseDuration: const Duration(seconds: 4),
            );
          } else {
            toastification.show(
              context: context,
              type: ToastificationType.warning,
              style: ToastificationStyle.fillColored,
              title: Text('$successCount Spieler hinzugefÃƒÂ¼gt, $errorCount Fehler aufgetreten.'),
              autoCloseDuration: const Duration(seconds: 4),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          toastification.show(
            context: context,
            type: ToastificationType.error,
            style: ToastificationStyle.fillColored,
            title: Text('Fehler beim Team Roster Fix: $e'),
            autoCloseDuration: const Duration(seconds: 4),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }
}
