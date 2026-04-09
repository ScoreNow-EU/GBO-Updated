import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:toastification/toastification.dart';
import '../models/game_squad.dart';
import '../models/player.dart';
import '../services/game_squad_service.dart';
import '../services/player_service.dart';
import 'protest_screen.dart';

class SpielerpassCheckScreen extends StatefulWidget {
  final String gameId;
  final String tournamentId;
  final String? gameDisplayName;

  const SpielerpassCheckScreen({
    super.key,
    required this.gameId,
    required this.tournamentId,
    this.gameDisplayName,
  });

  @override
  State<SpielerpassCheckScreen> createState() => _SpielerpassCheckScreenState();
}

class _SpielerpassCheckScreenState extends State<SpielerpassCheckScreen> {
  final GameSquadService _gameSquadService = GameSquadService();
  final PlayerService _playerService = PlayerService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  List<_TeamSquadData> _teamSquads = [];
  Map<String, bool> _checkedPlayers = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final squads = await _gameSquadService.getSquadsForGame(widget.gameId);
      final teamSquads = <_TeamSquadData>[];

      // Load existing checks
      final checkDoc = await _firestore
          .collection('gameReports')
          .doc(widget.gameId)
          .get();
      final existingChecks = checkDoc.exists
          ? Map<String, bool>.from(
              (checkDoc.data()?['spielerpassChecks'] as Map<String, dynamic>?) ?? {})
          : <String, bool>{};

      for (final squad in squads) {
        // Look up full Player objects to get spielerpassNummer
        final playersWithPass = <_PlayerCheckData>[];
        for (final sp in squad.selectedPlayers) {
          final player = await _playerService.getPlayerById(sp.playerId);
          playersWithPass.add(_PlayerCheckData(
            playerId: sp.playerId,
            firstName: sp.firstName,
            lastName: sp.lastName,
            jerseyNumber: sp.jerseyNumber,
            classification: sp.classification,
            spielerpassNummer: player?.spielerpassNummer,
          ));
        }
        teamSquads.add(_TeamSquadData(
          teamId: squad.teamId,
          players: playersWithPass,
        ));
      }

      setState(() {
        _teamSquads = teamSquads;
        _checkedPlayers = existingChecks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        toastification.show(
          context: context,
          title: Text('Fehler: $e'),
          type: ToastificationType.error,
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    }
  }

  Future<void> _toggleCheck(String playerId, bool checked) async {
    setState(() {
      _checkedPlayers[playerId] = checked;
    });

    try {
      await _firestore
          .collection('gameReports')
          .doc(widget.gameId)
          .set({
        'spielerpassChecks': {playerId: checked},
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving Spielerpass check: $e');
    }
  }

  void _openProtest(String teamId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProtestScreen(
          tournamentId: widget.tournamentId,
          gameId: widget.gameId,
          gameDisplayName: widget.gameDisplayName,
          teamId: teamId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Spielerpass-Kontrolle${widget.gameDisplayName != null ? '\n${widget.gameDisplayName}' : ''}',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: const Color(0xFF1a237e),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _teamSquads.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.badge_outlined,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('Keine Kader für dieses Spiel',
                          style: TextStyle(
                              fontSize: 16, color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Summary
                    _buildSummary(),
                    const SizedBox(height: 16),
                    ..._teamSquads.map(_buildTeamSection),
                  ],
                ),
    );
  }

  Widget _buildSummary() {
    final totalPlayers =
        _teamSquads.fold<int>(0, (sum, t) => sum + t.players.length);
    final checkedCount =
        _checkedPlayers.values.where((v) => v).length;
    final missingPass = _teamSquads.fold<int>(
        0,
        (sum, t) =>
            sum +
            t.players.where((p) => p.spielerpassNummer == null).length);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _buildSummaryChip(
              '$checkedCount/$totalPlayers', 'Geprüft', Colors.green),
          const SizedBox(width: 12),
          _buildSummaryChip(
              '$missingPass', 'Ohne Pass-Nr.', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style:
                    TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamSection(_TeamSquadData team) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Team header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.groups, size: 18, color: Colors.black54),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Team ${team.teamId.substring(0, 6)}...',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                TextButton.icon(
                  onPressed: () => _openProtest(team.teamId),
                  icon: const Icon(Icons.gavel, size: 14),
                  label: const Text('Protest',
                      style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red[700],
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
          ),
          // Player list
          ...team.players.asMap().entries.map((entry) {
            final player = entry.value;
            final isChecked = _checkedPlayers[player.playerId] ?? false;
            final hasPass = player.spielerpassNummer != null;

            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade100),
                ),
                color: isChecked ? Colors.green.shade50 : null,
              ),
              child: Row(
                children: [
                  // Check toggle
                  Checkbox(
                    value: isChecked,
                    onChanged: (v) =>
                        _toggleCheck(player.playerId, v ?? false),
                    activeColor: Colors.green,
                  ),
                  // Jersey number
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1a237e).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      player.jerseyNumber ?? '-',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Player info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${player.firstName} ${player.lastName}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        if (player.classification != null)
                          Text(player.classification!,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  // Spielerpass number
                  if (hasPass)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.badge_outlined,
                              size: 12, color: Colors.green.shade700),
                          const SizedBox(width: 4),
                          Text(player.spielerpassNummer!,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber,
                              size: 12, color: Colors.orange.shade700),
                          const SizedBox(width: 4),
                          Text('Kein Pass',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange.shade700)),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TeamSquadData {
  final String teamId;
  final List<_PlayerCheckData> players;

  _TeamSquadData({required this.teamId, required this.players});
}

class _PlayerCheckData {
  final String playerId;
  final String firstName;
  final String lastName;
  final String? jerseyNumber;
  final String? classification;
  final String? spielerpassNummer;

  _PlayerCheckData({
    required this.playerId,
    required this.firstName,
    required this.lastName,
    this.jerseyNumber,
    this.classification,
    this.spielerpassNummer,
  });
}
