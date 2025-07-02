import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../models/player.dart';
import '../models/club.dart';
import '../services/player_service.dart';
import '../services/club_service.dart';

class BulkAddPlayersScreen extends StatefulWidget {
  const BulkAddPlayersScreen({super.key});

  @override
  State<BulkAddPlayersScreen> createState() => _BulkAddPlayersScreenState();
}

class PlayerFormData {
  final TextEditingController firstName = TextEditingController();
  final TextEditingController lastName = TextEditingController();
  final TextEditingController email = TextEditingController();
  String? position;
  String? clubId;
  String? gender;

  void dispose() {
    firstName.dispose();
    lastName.dispose();
    email.dispose();
  }

  bool get isComplete {
    return firstName.text.isNotEmpty &&
           lastName.text.isNotEmpty &&
           email.text.isNotEmpty &&
           position != null &&
           gender != null;
  }

  bool get hasAnyData {
    return firstName.text.isNotEmpty ||
           lastName.text.isNotEmpty ||
           email.text.isNotEmpty ||
           position != null ||
           clubId != null ||
           gender != null;
  }
}

class _BulkAddPlayersScreenState extends State<BulkAddPlayersScreen> {
  final PlayerService _playerService = PlayerService();
  final ClubService _clubService = ClubService();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  List<Club> _clubs = [];

  // List to hold player data
  List<PlayerFormData> _players = [
    PlayerFormData(), // Start with one empty player
    PlayerFormData(), // Always have one extra for adding new players
  ];

  // Available positions
  final List<String> _positions = [
    'Right Wing',
    'Left Wing',
    'Allrounder',
    'Defense',
    'Specialist',
    'Goalkeeper',
  ];

  // Available genders
  final List<String> _genders = [
    'male',
    'female',
  ];

  @override
  void initState() {
    super.initState();
    _loadClubs();
  }

  @override
  void dispose() {
    for (var player in _players) {
      player.dispose();
    }
    super.dispose();
  }

  Future<void> _loadClubs() async {
    try {
      final clubs = await _clubService.getAllClubs();
      setState(() {
        _clubs = clubs;
      });
    } catch (e) {
      print('Error loading clubs: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spieler Bulk Hinzufügen'),
        backgroundColor: Colors.green,
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
                    'Spieler hinzufügen',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_players.where((p) => p.isComplete).length} Spieler werden erstellt',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Geben Sie für jeden Spieler die erforderlichen Daten ein. Alle Felder außer Verein sind Pflichtfelder.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),

              // Players List
              Expanded(
                child: ListView.builder(
                  itemCount: _players.length,
                  itemBuilder: (context, index) {
                    return _buildPlayerCard(index);
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
                    onPressed: _isLoading ? null : _previewPlayers,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
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
                        : const Text('Spieler Vorschau'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _createPlayers,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
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
                        : const Text('Spieler Erstellen'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerCard(int index) {
    final player = _players[index];
    final isLast = index == _players.length - 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: player.hasAnyData ? Colors.white : Colors.grey.shade50,
        border: Border.all(
          color: player.hasAnyData ? Colors.green.shade300 : Colors.grey.shade300,
          width: player.hasAnyData ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: player.hasAnyData ? [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: player.hasAnyData ? Colors.green : Colors.grey,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Spieler ${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              if (player.hasAnyData && !isLast)
                IconButton(
                  onPressed: () => _removePlayer(index),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Spieler entfernen',
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Form Fields
          Row(
            children: [
              // First Name
              Expanded(
                child: TextFormField(
                  controller: player.firstName,
                  decoration: InputDecoration(
                    labelText: 'Vorname *',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.person),
                  ),
                  onChanged: (_) {
                    setState(() {
                      _ensureEmptyPlayerAtEnd();
                    });
                  },
                  validator: (value) {
                    if (player.hasAnyData && (value == null || value.trim().isEmpty)) {
                      return 'Vorname ist erforderlich';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              // Last Name
              Expanded(
                child: TextFormField(
                  controller: player.lastName,
                  decoration: InputDecoration(
                    labelText: 'Nachname *',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  onChanged: (_) {
                    setState(() {
                      _ensureEmptyPlayerAtEnd();
                    });
                  },
                  validator: (value) {
                    if (player.hasAnyData && (value == null || value.trim().isEmpty)) {
                      return 'Nachname ist erforderlich';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              // Email
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: player.email,
                  decoration: InputDecoration(
                    labelText: 'E-Mail *',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) {
                    setState(() {
                      _ensureEmptyPlayerAtEnd();
                    });
                  },
                  validator: (value) {
                    if (player.hasAnyData) {
                      if (value == null || value.trim().isEmpty) {
                        return 'E-Mail ist erforderlich';
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return 'Ungültige E-Mail-Adresse';
                      }
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              // Position
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: player.position,
                  decoration: InputDecoration(
                    labelText: 'Position *',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.sports_volleyball),
                  ),
                  items: _positions.map((String position) {
                    return DropdownMenuItem<String>(
                      value: position,
                      child: Text(position),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      player.position = newValue;
                      _ensureEmptyPlayerAtEnd();
                    });
                  },
                  validator: (value) {
                    if (player.hasAnyData && value == null) {
                      return 'Position ist erforderlich';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              // Gender
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: player.gender,
                  decoration: InputDecoration(
                    labelText: 'Geschlecht *',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.person),
                  ),
                  items: _genders.map((String gender) {
                    return DropdownMenuItem<String>(
                      value: gender,
                      child: Text(gender == 'male' ? 'Männlich' : 'Weiblich'),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      player.gender = newValue;
                      _ensureEmptyPlayerAtEnd();
                    });
                  },
                  validator: (value) {
                    if (player.hasAnyData && value == null) {
                      return 'Geschlecht ist erforderlich';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Club (Optional)
          DropdownButtonFormField<String>(
            value: player.clubId,
            decoration: InputDecoration(
              labelText: 'Verein (Optional)',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.groups),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('Kein Verein'),
              ),
              ..._clubs.map((Club club) {
                return DropdownMenuItem<String>(
                  value: club.id,
                  child: Text('${club.name} (${club.city})'),
                );
              }).toList(),
            ],
            onChanged: (String? newValue) {
              setState(() {
                player.clubId = newValue;
                _ensureEmptyPlayerAtEnd();
              });
            },
          ),
        ],
      ),
    );
  }

  void _ensureEmptyPlayerAtEnd() {
    // Remove empty players from the middle
    _players.removeWhere((player) => 
        !player.hasAnyData && _players.indexOf(player) != _players.length - 1);
    
    // Ensure we always have an empty player at the end
    if (_players.isEmpty || _players.last.hasAnyData) {
      _players.add(PlayerFormData());
    }
    
    // But don't have more than one empty at the end
    while (_players.length > 1 && 
           !_players[_players.length - 1].hasAnyData && 
           !_players[_players.length - 2].hasAnyData) {
      _players.removeLast().dispose();
    }
  }

  void _removePlayer(int index) {
    setState(() {
      _players[index].dispose();
      _players.removeAt(index);
      _ensureEmptyPlayerAtEnd();
    });
  }

  void _previewPlayers() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final validPlayers = _players.where((p) => p.isComplete).toList();
    
    if (validPlayers.isEmpty) {
      _showWarningToast('Keine gültigen Spieler zum Anzeigen');
      return;
    }

    _showPreviewDialog(validPlayers);
  }

  void _showPreviewDialog(List<PlayerFormData> validPlayers) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Spieler Vorschau (${validPlayers.length})'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: validPlayers.length,
            itemBuilder: (context, index) {
              final player = validPlayers[index];
              final club = player.clubId != null 
                  ? _clubs.firstWhere((c) => c.id == player.clubId, orElse: () => Club(id: '', name: 'Unbekannt', city: '', bundesland: '', createdAt: DateTime.now()))
                  : null;
              
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Text('${index + 1}'),
                  ),
                  title: Text('${player.firstName.text} ${player.lastName.text}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('E-Mail: ${player.email.text}'),
                      Text('Position: ${player.position}'),
                      Text('Geschlecht: ${player.gender == 'male' ? 'Männlich' : 'Weiblich'}'),
                      if (club != null) Text('Verein: ${club.name}'),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  Future<void> _createPlayers() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final validPlayers = _players.where((p) => p.isComplete).toList();
    
    if (validPlayers.isEmpty) {
      _showWarningToast('Keine gültigen Spieler zum Erstellen');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Convert form data to Player objects
      final players = validPlayers.map((playerData) => Player(
        id: '', // Will be set by Firestore
        firstName: playerData.firstName.text.trim(),
        lastName: playerData.lastName.text.trim(),
        email: playerData.email.text.trim(),
        position: playerData.position,
        clubId: playerData.clubId,
        gender: playerData.gender!,
        createdAt: DateTime.now(),
      )).toList();

      // Create players in bulk
      final results = await _playerService.addPlayersInBulk(players);
      
      _showResultsDialog(results);
      
    } catch (e) {
      _showErrorToast('Fehler beim Erstellen der Spieler: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showResultsDialog(List<String> results) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ergebnisse'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final result = results[index];
              final isSuccess = result.startsWith('ERFOLG');
              
              return ListTile(
                leading: Icon(
                  isSuccess ? Icons.check_circle : Icons.error,
                  color: isSuccess ? Colors.green : Colors.red,
                ),
                title: Text(
                  result.replaceFirst('ERFOLG: ', '').replaceFirst('FEHLER: ', ''),
                  style: TextStyle(
                    color: isSuccess ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close screen
            },
            child: const Text('Fertig'),
          ),
        ],
      ),
    );
  }

  void _showSuccessToast(String message) {
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.fillColored,
      title: Text(message),
      autoCloseDuration: const Duration(seconds: 3),
      alignment: Alignment.topCenter,
    );
  }

  void _showErrorToast(String message) {
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.fillColored,
      title: Text(message),
      autoCloseDuration: const Duration(seconds: 4),
      alignment: Alignment.topCenter,
    );
  }

  void _showWarningToast(String message) {
    toastification.show(
      context: context,
      type: ToastificationType.warning,
      style: ToastificationStyle.fillColored,
      title: Text(message),
      autoCloseDuration: const Duration(seconds: 3),
      alignment: Alignment.topCenter,
    );
  }
} 