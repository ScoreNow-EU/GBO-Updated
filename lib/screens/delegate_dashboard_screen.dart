import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tournament.dart';
import '../services/tournament_service.dart';
import '../services/auth_service.dart';
import '../services/protest_service.dart';
import '../services/suspension_service.dart';
import '../models/user.dart' as app_user;
import '../models/protest.dart';
import '../models/suspension.dart';

class DelegateDashboardScreen extends StatefulWidget {
  const DelegateDashboardScreen({super.key});

  @override
  State<DelegateDashboardScreen> createState() => _DelegateDashboardScreenState();
}

class _DelegateDashboardScreenState extends State<DelegateDashboardScreen> {
  final TournamentService _tournamentService = TournamentService();
  final AuthService _authService = AuthService();
  final ProtestService _protestService = ProtestService();
  final SuspensionService _suspensionService = SuspensionService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  app_user.User? _currentUser;
  List<Tournament> _assignedTournaments = [];
  List<Map<String, dynamic>> _todaysGames = [];
  List<Protest> _openProtests = [];
  List<Suspension> _activeSuspensions = [];
  Map<String, Map<String, dynamic>> _signOffStatus = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _currentUser = await _authService.getCurrentUser();

      // Load tournaments where this user is a delegate
      final allTournaments = await _tournamentService.getTournaments().first;
      _assignedTournaments = allTournaments.where((t) {
        return t.delegateIds.contains(_currentUser?.id);
      }).toList();

      // Load today's games across assigned tournaments
      await _loadTodaysGames();

      // Load open protests across assigned tournaments
      final protests = <Protest>[];
      for (final t in _assignedTournaments) {
        final tp = await _protestService.getProtestsForTournament(t.id);
        protests.addAll(tp.where((p) => p.status == ProtestStatus.filed || p.status == ProtestStatus.underReview));
      }
      _openProtests = protests;

      // Load active suspensions
      _activeSuspensions = await _suspensionService.getAllActiveSuspensions();

      // Load sign-off status for today's games
      await _loadSignOffStatus();
    } catch (e) {
      debugPrint('Error loading delegate dashboard: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadTodaysGames() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final games = <Map<String, dynamic>>[];
    for (final tournament in _assignedTournaments) {
      try {
        final gamesSnap = await _firestore
            .collection('tournaments')
            .doc(tournament.id)
            .collection('games')
            .where('scheduledTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('scheduledTime', isLessThan: Timestamp.fromDate(endOfDay))
            .get();

        for (final doc in gamesSnap.docs) {
          games.add({
            ...doc.data(),
            'id': doc.id,
            'tournamentName': tournament.name,
            'tournamentId': tournament.id,
          });
        }
      } catch (e) {
        debugPrint('Error loading games for tournament ${tournament.id}: $e');
      }
    }
    _todaysGames = games;
  }

  Future<void> _loadSignOffStatus() async {
    for (final game in _todaysGames) {
      final gameId = game['id'] as String;
      try {
        final reportDoc = await _firestore.collection('gameReports').doc(gameId).get();
        if (reportDoc.exists) {
          _signOffStatus[gameId] = reportDoc.data() ?? {};
        }
      } catch (e) {
        debugPrint('Error loading sign-off for $gameId: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(),
            const SizedBox(height: 24),

            // Summary cards row
            _buildSummaryRow(),
            const SizedBox(height: 24),

            // Today's games with sign-off status
            _buildSectionHeader('Spiele heute', Icons.today),
            const SizedBox(height: 12),
            if (_todaysGames.isEmpty)
              _buildEmptyCard('Keine Spiele für heute.')
            else
              ..._todaysGames.map(_buildGameCard),

            const SizedBox(height: 24),

            // Open protests
            _buildSectionHeader('Offene Proteste', Icons.warning_amber),
            const SizedBox(height: 12),
            if (_openProtests.isEmpty)
              _buildEmptyCard('Keine offenen Proteste.')
            else
              ..._openProtests.map(_buildProtestCard),

            const SizedBox(height: 24),

            // Active suspensions
            _buildSectionHeader('Aktive Sperren', Icons.block),
            const SizedBox(height: 12),
            if (_activeSuspensions.isEmpty)
              _buildEmptyCard('Keine aktiven Sperren.')
            else
              ..._activeSuspensions.take(5).map(_buildSuspensionCard),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade600, Colors.indigo.shade800],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Hallo, ${_currentUser?.fullName ?? 'Delegierte(r)'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_assignedTournaments.length} Turnier${_assignedTournaments.length == 1 ? '' : 'e'} zugewiesen',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    final pendingSignOffs = _todaysGames.where((g) {
      final status = _signOffStatus[g['id']];
      return status == null || status['delegateSigned'] != true;
    }).length;

    return Row(
      children: [
        Expanded(child: _buildSummaryCard('Spiele heute', '${_todaysGames.length}', Icons.sports_handball, Colors.blue)),
        const SizedBox(width: 12),
        Expanded(child: _buildSummaryCard('Signatur ausstehend', '$pendingSignOffs', Icons.edit, Colors.orange)),
        const SizedBox(width: 12),
        Expanded(child: _buildSummaryCard('Offene Proteste', '${_openProtests.length}', Icons.warning, Colors.red)),
        const SizedBox(width: 12),
        Expanded(child: _buildSummaryCard('Aktive Sperren', '${_activeSuspensions.length}', Icons.block, Colors.purple)),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildEmptyCard(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(message, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        ),
      ),
    );
  }

  Widget _buildGameCard(Map<String, dynamic> game) {
    final teamA = game['teamAName'] ?? 'Team A';
    final teamB = game['teamBName'] ?? 'Team B';
    final gameId = game['id'] as String;
    final status = _signOffStatus[gameId];
    final delegateSigned = status?['delegateSigned'] == true;
    final isFullySigned = status?['isLocked'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isFullySigned
              ? Colors.green
              : delegateSigned
                  ? Colors.blue
                  : Colors.orange,
          child: Icon(
            isFullySigned ? Icons.check : delegateSigned ? Icons.done : Icons.pending,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text('$teamA vs $teamB'),
        subtitle: Text(game['tournamentName'] ?? ''),
        trailing: Chip(
          label: Text(
            isFullySigned ? 'Abgeschlossen' : delegateSigned ? 'Signiert' : 'Ausstehend',
            style: const TextStyle(fontSize: 11, color: Colors.white),
          ),
          backgroundColor: isFullySigned ? Colors.green : delegateSigned ? Colors.blue : Colors.orange,
        ),
      ),
    );
  }

  Widget _buildProtestCard(Protest protest) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: protest.status == ProtestStatus.filed ? Colors.red.shade100 : Colors.orange.shade100,
          child: Icon(
            Icons.warning_amber,
            color: protest.status == ProtestStatus.filed ? Colors.red : Colors.orange,
          ),
        ),
        title: Text(protest.reason, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('Von: ${protest.filedByName} · ${protest.status.name}'),
        trailing: Chip(
          label: Text(
            protest.status == ProtestStatus.filed ? 'Neu' : 'In Prüfung',
            style: const TextStyle(fontSize: 11, color: Colors.white),
          ),
          backgroundColor: protest.status == ProtestStatus.filed ? Colors.red : Colors.orange,
        ),
      ),
    );
  }

  Widget _buildSuspensionCard(Suspension suspension) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red.shade100,
          child: Icon(Icons.block, color: Colors.red.shade700),
        ),
        title: Text(suspension.playerName),
        subtitle: Text('${suspension.teamName} · ${suspension.reason}'),
        trailing: Chip(
          label: Text(
            suspension.type.name,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ),
    );
  }
}
