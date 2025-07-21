import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../models/tournament.dart';
import '../services/tournament_service.dart';
import '../services/team_manager_service.dart';
import '../services/custom_notification_service.dart';

class RosterCreationScreen extends StatefulWidget {
  final Team team;
  final Tournament tournament;
  final String selectedDivision;

  const RosterCreationScreen({
    super.key,
    required this.team,
    required this.tournament,
    required this.selectedDivision,
  });

  @override
  State<RosterCreationScreen> createState() => _RosterCreationScreenState();
}

class _RosterCreationScreenState extends State<RosterCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // List to hold player data
  List<PlayerFormData> _players = [
    PlayerFormData(), // Start with one empty player
    PlayerFormData(), // Always have one extra for adding new players
  ];
  final TeamManagerService _teamManagerService = TeamManagerService();
  final CustomNotificationService _notificationService = CustomNotificationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Roster für ${widget.tournament.name}'),
        backgroundColor: const Color(0xFF2D5016),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Roster für ${widget.team.name}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Turnier: ${widget.tournament.name}',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Division: ${widget.selectedDivision}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_players.where((p) => p.firstName.text.isNotEmpty).length} Spieler werden hinzugefügt',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Geben Sie für jeden Spieler die erforderlichen Daten ein. Mindestens 2 Spieler sind für die Anmeldung erforderlich.',
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
                    onPressed: _isLoading ? null : _registerWithRoster,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D5016),
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
                        : const Text('Anmelden'),
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
    final isEmpty = player.firstName.text.isEmpty && player.lastName.text.isEmpty;

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
                isLast ? 'Spieler ${index + 1} hinzufügen' : 'Spieler ${index + 1}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isEmpty && !isLast ? Colors.grey : Colors.black87,
                ),
              ),
              const Spacer(),
              if (!isEmpty && !isLast)
                IconButton(
                  onPressed: () => _removePlayer(index),
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  iconSize: 20,
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Form Fields
          Row(
            children: [
              // First Name
              Expanded(
                child: TextFormField(
                  controller: player.firstName,
                  decoration: const InputDecoration(
                    labelText: 'Vorname *',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  validator: (value) => value?.trim().isEmpty == true ? 'Pflichtfeld' : null,
                  onChanged: (_) => _onPlayerDataChanged(index),
                ),
              ),
              const SizedBox(width: 16),

              // Last Name
              Expanded(
                child: TextFormField(
                  controller: player.lastName,
                  decoration: const InputDecoration(
                    labelText: 'Nachname *',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  validator: (value) => value?.trim().isEmpty == true ? 'Pflichtfeld' : null,
                  onChanged: (_) => _onPlayerDataChanged(index),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              // Email
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: player.email,
                  decoration: const InputDecoration(
                    labelText: 'E-Mail *',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value?.trim().isEmpty == true) return 'Pflichtfeld';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                      return 'Ungültige E-Mail';
                    }
                    return null;
                  },
                  onChanged: (_) => _onPlayerDataChanged(index),
                ),
              ),
              const SizedBox(width: 16),

              // Phone (optional)
              Expanded(
                child: TextFormField(
                  controller: player.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefon',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => _onPlayerDataChanged(index),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              // Position (optional)
              Expanded(
                child: TextFormField(
                  controller: player.position,
                  decoration: const InputDecoration(
                    labelText: 'Position',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    hintText: 'z.B. Blocker, Defender',
                  ),
                  onChanged: (_) => _onPlayerDataChanged(index),
                ),
              ),
              const SizedBox(width: 16),

              // Jersey Number (optional)
              Expanded(
                child: TextFormField(
                  controller: player.jerseyNumber,
                  decoration: const InputDecoration(
                    labelText: 'Trikotnummer',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _onPlayerDataChanged(index),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onPlayerDataChanged(int index) {
    setState(() {
      final player = _players[index];
      final hasData = player.firstName.text.isNotEmpty || player.lastName.text.isNotEmpty;
      
      // If this is the last item and now has data, add a new empty item
      if (index == _players.length - 1 && hasData) {
        _players.add(PlayerFormData());
      }
      
      // Remove empty items from the middle (except the last one)
      for (int i = _players.length - 2; i >= 0; i--) {
        final p = _players[i];
        if (p.firstName.text.isEmpty && p.lastName.text.isEmpty && p.email.text.isEmpty) {
          _players.removeAt(i);
        }
      }
    });
  }

  void _removePlayer(int index) {
    setState(() {
      _players.removeAt(index);
    });
  }

  Future<void> _registerWithRoster() async {
    if (!_formKey.currentState!.validate()) return;

    final validPlayers = _players.where((p) => 
      p.firstName.text.isNotEmpty && 
      p.lastName.text.isNotEmpty && 
      p.email.text.isNotEmpty
    ).toList();

    if (validPlayers.length < 2) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        title: const Text('Mindestens 2 Spieler sind für die Anmeldung erforderlich.'),
        autoCloseDuration: const Duration(seconds: 3),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Register team for tournament
      final success = await TournamentService().registerTeamForTournament(
        widget.tournament.id,
        widget.team.id,
        widget.selectedDivision,
        roster: validPlayers.map((p) => {
          'firstName': p.firstName.text.trim(),
          'lastName': p.lastName.text.trim(),
          'email': p.email.text.trim(),
          'phone': p.phone.text.trim(),
          'position': p.position.text.trim(),
          'jerseyNumber': p.jerseyNumber.text.trim(),
        }).toList(),
      );

      if (success) {
        // Send notification to team manager if one exists
        if (widget.team.teamManager != null) {
          // Get team manager's email
          final teamManager = await _teamManagerService.getTeamManagerByName(widget.team.teamManager!);
          if (teamManager != null) {
            await _notificationService.sendCustomNotification(
              title: 'Team hat sich für Turnier angemeldet',
              message: '${widget.team.name} hat sich für ${widget.tournament.name} angemeldet.',
              userEmail: teamManager.email,
            );
          }
        }

        final divisionType = widget.selectedDivision.contains('FUN') ? 'Fun Turnier' : 'A Cup';
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          title: Text('${widget.team.name} wurde erfolgreich für ${widget.tournament.name} ($divisionType - ${widget.selectedDivision}) mit ${validPlayers.length} Spielern angemeldet.'),
          autoCloseDuration: const Duration(seconds: 4),
        );
        
        // Go back to team detail screen
        Navigator.of(context).pop();
        Navigator.of(context).pop(); // Go back twice to get to team detail
      } else {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          title: const Text('Anmeldung fehlgeschlagen. Bitte versuchen Sie es erneut.'),
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

class PlayerFormData {
  final TextEditingController firstName = TextEditingController();
  final TextEditingController lastName = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController phone = TextEditingController();
  final TextEditingController position = TextEditingController();
  final TextEditingController jerseyNumber = TextEditingController();

  void dispose() {
    firstName.dispose();
    lastName.dispose();
    email.dispose();
    phone.dispose();
    position.dispose();
    jerseyNumber.dispose();
  }
} 