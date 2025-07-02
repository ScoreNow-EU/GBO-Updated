import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../models/player.dart';
import '../services/player_service.dart';
import '../widgets/responsive_layout.dart';
import 'bulk_add_players_screen.dart';

class PlayerManagementScreen extends StatefulWidget {
  const PlayerManagementScreen({super.key});

  @override
  State<PlayerManagementScreen> createState() => _PlayerManagementScreenState();
}

class _PlayerManagementScreenState extends State<PlayerManagementScreen> {
  final PlayerService _playerService = PlayerService();
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
                    onPressed: () => _showAddPlayerDialog(),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Spieler hinzufügen'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D5016),
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
              player.email,
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

  void _showAddPlayerDialog() {
    _clearFormControllers();
    _showPlayerDialog(isEdit: false);
  }

  void _showEditPlayerDialog(Player player) {
    _firstNameController.text = player.firstName;
    _lastNameController.text = player.lastName;
    _emailController.text = player.email;
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
}
