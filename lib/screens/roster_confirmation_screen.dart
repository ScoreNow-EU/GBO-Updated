import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_colors.dart';
import 'package:toastification/toastification.dart';

import '../models/game_squad.dart';
import '../services/game_squad_service.dart';

/// Lightweight screen for a team manager to confirm their roster pre-game.
/// Reached via notification tap or deep-link.
class RosterConfirmationScreen extends StatefulWidget {
  final String gameId;
  final String teamId;
  final String teamName;

  const RosterConfirmationScreen({
    super.key,
    required this.gameId,
    required this.teamId,
    required this.teamName,
  });

  @override
  State<RosterConfirmationScreen> createState() =>
      _RosterConfirmationScreenState();
}

class _RosterConfirmationScreenState extends State<RosterConfirmationScreen> {
  final GameSquadService _squadService = GameSquadService();
  GameSquad? _squad;
  bool _isLoading = true;
  bool _isConfirming = false;
  bool _isConfirmed = false;

  @override
  void initState() {
    super.initState();
    _loadSquad();
  }

  Future<void> _loadSquad() async {
    try {
      final squad =
          await _squadService.getSquadForGame(widget.gameId, widget.teamId);
      // Check if already confirmed in gameStates
      final doc = await FirebaseFirestore.instance
          .collection('gameStates')
          .doc(widget.gameId)
          .get();
      bool alreadyConfirmed = false;
      if (doc.exists) {
        final data = doc.data()!;
        final rosterKey = _resolveRosterConfirmedKey(data);
        alreadyConfirmed = data[rosterKey] == true;
      }
      if (mounted) {
        setState(() {
          _squad = squad;
          _isConfirmed = alreadyConfirmed;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Figure out the Firestore key based on which team this is
  String _resolveRosterConfirmedKey(Map<String, dynamic> data) {
    return 'rosterConfirmed_${widget.teamId}';
  }

  Future<void> _confirmRoster() async {
    if (_squad == null) return;
    setState(() => _isConfirming = true);

    try {
      final confirmKey = 'rosterConfirmed_${widget.teamId}';
      await FirebaseFirestore.instance
          .collection('gameStates')
          .doc(widget.gameId)
          .set({
        confirmKey: true,
        '${confirmKey}At': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _isConfirmed = true;
          _isConfirming = false;
        });
        toastification.show(
          context: context,
          type: ToastificationType.success,
          title: const Text('Kader bestätigt'),
          description: Text('${widget.teamName} – Kader wurde erfolgreich bestätigt.'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConfirming = false);
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Fehler'),
          description: Text('Kaderbestätigung fehlgeschlagen: $e'),
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kader bestätigen – ${widget.teamName}'),
        backgroundColor: AppColors.rhdBlack,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _squad == null
              ? _buildNoSquad()
              : _buildSquadView(),
    );
  }

  Widget _buildNoSquad() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.group_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Kein Kader für ${widget.teamName} gefunden.',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Der Kader wurde noch nicht aufgestellt.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildSquadView() {
    final squad = _squad!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status banner
          if (_isConfirmed)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kader bestätigt',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800)),
                        const SizedBox(height: 2),
                        Text('Der Kader wurde erfolgreich bestätigt.',
                            style: TextStyle(
                                fontSize: 13, color: Colors.green.shade600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Team info header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.rhdBlack,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.groups, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.teamName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    Text('${squad.playerCount} Spieler',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Players list
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 18, color: Colors.black54),
                      const SizedBox(width: 8),
                      Text('Spieler (${squad.playerCount})',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ),
                ...squad.selectedPlayers.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final player = entry.value;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                            color: idx < squad.playerCount - 1
                                ? Colors.grey.shade200
                                : Colors.transparent),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.rhdBlack.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            player.jerseyNumber ?? '${idx + 1}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(player.fullName,
                              style: const TextStyle(fontSize: 14)),
                        ),
                        if (player.classification != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(player.classification!,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue.shade700)),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          // Officials
          if (squad.officials.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.badge, size: 18, color: Colors.black54),
                        const SizedBox(width: 8),
                        Text('Team-Offizielle (${squad.officials.length})',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ),
                  ...squad.officials.map((official) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom:
                                BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(official.name,
                                  style: const TextStyle(fontSize: 14)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(official.role,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange.shade700)),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Confirm button
          if (!_isConfirmed)
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isConfirming ? null : _confirmRoster,
                icon: _isConfirming
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline, size: 22),
                label: Text(
                    _isConfirming ? 'Wird bestätigt…' : 'Kader bestätigen',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.rhdBlack,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
