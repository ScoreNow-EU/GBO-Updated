import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import '../models/player.dart';
import '../models/team.dart';
import '../services/player_service.dart';
import '../services/team_service.dart';
import '../widgets/responsive_layout.dart';
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
  
  String _searchQuery = '';
  bool _isLoading = false;

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
                    label: const Text('Alle löschen'),
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
                    label: const Text('Spieler hinzufügen'),
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
                'Verwalten Sie alle Spieler im System. Diese Spieler können von Team-Managern zu ihren Kadern hinzugefügt werden.',
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
                        Expanded(child: Text('Position', style: TextStyle(fontWeight: FontWeight.bold))),
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
                                    'Fügen Sie Spieler hinzu, um sie hier zu verwalten.',
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
              player.position ?? '-',
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
            child: FutureBuilder<Team?>(
              future: _teamService.getTeamById(player.clubId ?? ''),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                
                final team = snapshot.data;
                if (team != null) {
                  return Text(
                    team.name,
                    style: TextStyle(color: Colors.grey[700]),
                    overflow: TextOverflow.ellipsis,
                  );
                } else {
                  return Text(
                    'Kein Team',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  );
                }
              },
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
                  tooltip: 'Löschen',
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
            print('🔍 Detected semicolon delimiter');
          } else {
            headers = headerLine.split(',').map((h) => h.trim()).toList();
            print('🔍 Detected comma delimiter');
          }
          
          // Log CSV column analysis
          print('\n📋 CSV COLUMN ANALYSIS:');
          print('📥 Found columns: ${headers.join(', ')}');
          print('📊 Total columns found: ${headers.length}');
          
          // Validate required headers
          final requiredHeaders = ['Firstname', 'Lastname', 'Jersey Number', 'Position', 'Club Name', 'Division'];
          final missingHeaders = requiredHeaders.where((h) => !headers.contains(h)).toList();
          final foundHeaders = requiredHeaders.where((h) => headers.contains(h)).toList();
          
          print('\n✅ EXPECTED columns: ${requiredHeaders.join(', ')}');
          print('✅ FOUND expected columns: ${foundHeaders.join(', ')}');
          
          if (missingHeaders.isNotEmpty) {
            print('❌ MISSING expected columns: ${missingHeaders.join(', ')}');
            print('\n💡 SUGGESTIONS:');
            print('   - Check if column names match exactly (case-sensitive)');
            print('   - Common variations:');
            print('     * "Firstname" vs "First Name" vs "FirstName"');
            print('     * "Lastname" vs "Last Name" vs "LastName"');
            print('     * "Jersey Number" vs "JerseyNumber" vs "Number"');
            print('     * "Club Name" vs "ClubName" vs "Team"');
            print('     * "Division" vs "Category" vs "Class"');
            
            _showError('Fehlende Spalten: ${missingHeaders.join(', ')}\n\nGefundene Spalten: ${headers.join(', ')}');
            return;
          } else {
            print('✅ All required columns found!');
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
            _showError('Keine gültigen Daten in der CSV-Datei gefunden.');
            return;
          }
          
          // Log sample data for debugging
          print('\n📊 SAMPLE DATA (first 3 rows):');
          for (int i = 0; i < csvData.length && i < 3; i++) {
            final row = csvData[i];
            print('Row ${i + 1}: ${row.toString()}');
          }
          if (csvData.length > 3) {
            print('... and ${csvData.length - 3} more rows');
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

  void _showAddPlayerDialog() {
    _clearFormControllers();
    _showPlayerDialog(isEdit: false);
  }

  void _showEditPlayerDialog(Player player) {
    _firstNameController.text = player.firstName;
    _lastNameController.text = player.lastName;
    _emailController.text = player.email ?? '';
    _phoneController.text = player.phone ?? '';
    _positionController.text = player.position ?? '';
    _jerseyNumberController.text = player.jerseyNumber ?? '';
    _showPlayerDialog(isEdit: true, player: player);
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
                        labelText: 'Position',
                        border: OutlineInputBorder(),
                        hintText: 'z.B. Blocker, Defender',
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
                : Text(isEdit ? 'Speichern' : 'Hinzufügen'),
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
        title: const Text('Bitte füllen Sie alle Pflichtfelder aus.'),
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
        position: _positionController.text.trim().isEmpty ? null : _positionController.text.trim(),
        jerseyNumber: _jerseyNumberController.text.trim().isEmpty ? null : _jerseyNumberController.text.trim(),
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
          title: Text('Spieler ${isEdit ? 'aktualisiert' : 'hinzugefügt'}.'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      } else {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          title: Text('Fehler beim ${isEdit ? 'Aktualisieren' : 'Hinzufügen'} des Spielers.'),
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
        title: const Text('Spieler löschen'),
        content: Text('Möchten Sie ${player.fullName} wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.'),
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
      final success = await _playerService.deletePlayer(player.id);
      if (success) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          title: Text('${player.fullName} wurde gelöscht.'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      } else {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          title: const Text('Fehler beim Löschen des Spielers.'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    }
  }

  void _showDeleteAllPlayersDialog() async {
    // First, get the current count of players
    final players = await _playerService.getAllPlayers().first;
    
    if (players.isEmpty) {
      _showError('Keine Spieler zum Löschen vorhanden.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alle Spieler löschen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Möchten Sie wirklich alle ${players.length} Spieler löschen?'),
            const SizedBox(height: 8),
            const Text(
              '⚠️ Diese Aktion kann nicht rückgängig gemacht werden!',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Alle Spielerdaten werden permanent gelöscht.',
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
            child: const Text('Alle löschen'),
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
        _showError('Keine Spieler zum Löschen vorhanden.');
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
            title: Text('Alle $successCount Spieler erfolgreich gelöscht.'),
            autoCloseDuration: const Duration(seconds: 4),
          );
        } else {
          toastification.show(
            context: context,
            type: ToastificationType.warning,
            style: ToastificationStyle.fillColored,
            title: Text('$successCount Spieler gelöscht, $errorCount Fehler aufgetreten.'),
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
          title: Text('Fehler beim Löschen: $e'),
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
    );
  }

  void _clearFormControllers() {
    _firstNameController.clear();
    _lastNameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _positionController.clear();
    _jerseyNumberController.clear();
  }

  Future<void> _fixTeamRosters() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Team Roster Fix'),
        content: const Text(
          'Diese Aktion fügt alle Spieler mit einem ClubId zu ihrem Team hinzu, falls sie noch nicht dort sind.',
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
          if (player.clubId != null && player.clubId!.isNotEmpty) {
            final team = teams.firstWhere(
              (t) => t.id == player.clubId,
              orElse: () => throw Exception('Team not found'),
            );
            
            if (!team.rosterPlayerIds.contains(player.id)) {
              final updatedRosterIds = List<String>.from(team.rosterPlayerIds)..add(player.id);
              final updatedTeam = team.copyWith(rosterPlayerIds: updatedRosterIds);
              
              final success = await _teamService.updateTeam(team.id, updatedTeam);
              if (success) {
                successCount++;
                print('✅ Added player ${player.fullName} to team ${team.name}');
              } else {
                errorCount++;
                print('❌ Failed to add player ${player.fullName} to team ${team.name}');
              }
            }
          }
        }

        if (mounted) {
          if (errorCount == 0) {
            toastification.show(
              context: context,
              type: ToastificationType.success,
              style: ToastificationStyle.fillColored,
              title: Text('Alle $successCount Spieler erfolgreich zum Team hinzugefügt.'),
              autoCloseDuration: const Duration(seconds: 4),
            );
          } else {
            toastification.show(
              context: context,
              type: ToastificationType.warning,
              style: ToastificationStyle.fillColored,
              title: Text('$successCount Spieler hinzugefügt, $errorCount Fehler aufgetreten.'),
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
