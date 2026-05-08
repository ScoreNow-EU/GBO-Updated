import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tournament.dart';
import '../services/tournament_service.dart';
import '../services/auth_service.dart';
import '../services/protest_service.dart';
import '../services/suspension_service.dart';
import '../services/referee_observation_service.dart';
import '../services/referee_service.dart';
import '../services/delegate_service.dart';
import '../models/user.dart' as app_user;
import '../models/protest.dart';
import '../models/suspension.dart';
import '../models/delegate.dart';
import '../models/referee_observation.dart';
import 'referee_observation_form_screen.dart';

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
  final RefereeObservationService _observationService = RefereeObservationService();
  final RefereeService _refereeService = RefereeService();
  final DelegateService _delegateService = DelegateService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  app_user.User? _currentUser;
  Delegate? _delegateRecord; // The delegate doc whose ID is stored in tournament.delegateIds
  List<Tournament> _assignedTournaments = [];
  List<Map<String, dynamic>> _allAssignedGames = [];
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
      debugPrint('Delegate dashboard: currentUser=${_currentUser?.id} email=${_currentUser?.email}');

      // Look up the Delegate record by email — its Firestore doc ID is what
      // tournament.delegateIds and game.delegateId actually store
      if (_currentUser?.email.isNotEmpty == true) {
        final allDelegates = await _delegateService.getAllDelegates();
        debugPrint('Delegate dashboard: ${allDelegates.length} delegate records loaded');
        try {
          _delegateRecord = allDelegates.firstWhere(
            (d) => d.email.toLowerCase() == _currentUser!.email.toLowerCase(),
          );
        } catch (_) {
          // Fall back to matching by full name
          try {
            _delegateRecord = allDelegates.firstWhere(
              (d) => '${d.firstName} ${d.lastName}'.toLowerCase() ==
                  _currentUser!.fullName.toLowerCase(),
            );
          } catch (_) {
            debugPrint('Delegate dashboard: no delegate record found for "${_currentUser!.email}"');
          }
        }
        debugPrint('Delegate dashboard: delegateRecord=${_delegateRecord?.id} email=${_delegateRecord?.email}');
      }

      // Load ALL tournaments — then filter those with this delegate in delegateIds
      // (for protests/summaries). Game loading scans all tournaments regardless.
      final allTournaments = await _tournamentService.getTournaments().first;
      debugPrint('Delegate dashboard: ${allTournaments.length} total tournaments');
      _assignedTournaments = _delegateRecord != null
          ? allTournaments
              .where((t) => t.delegateIds.contains(_delegateRecord!.id))
              .toList()
          : [];
      debugPrint('Delegate dashboard: ${_assignedTournaments.length} assigned tournaments via delegateIds');

      // Scan ALL tournaments for games assigned to this delegate
      // (covers cases where tournament delegateIds may not be set)
      await _loadAllAssignedGames(allTournaments);

      // Load open protests across assigned tournaments
      final protests = <Protest>[];
      for (final t in _assignedTournaments) {
        final tp = await _protestService.getProtestsForTournament(t.id);
        protests.addAll(tp.where((p) => p.status == ProtestStatus.filed || p.status == ProtestStatus.underReview));
      }
      _openProtests = protests;

      // Load active suspensions
      _activeSuspensions = await _suspensionService.getAllActiveSuspensions();

      // Load sign-off status for all assigned games
      await _loadSignOffStatus();
    } catch (e) {
      debugPrint('Error loading delegate dashboard: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadAllAssignedGames(List<Tournament> allTournaments) async {
    final delegateId = _delegateRecord?.id;
    if (delegateId == null) {
      debugPrint('Delegate dashboard: _loadAllAssignedGames skipped — no delegateRecord');
      return;
    }
    debugPrint('Delegate dashboard: scanning ${allTournaments.length} tournaments for delegateId=$delegateId');

    final games = <Map<String, dynamic>>[];
    for (final tournament in allTournaments) {
      try {
        final gamesSnap = await _firestore
            .collection('tournaments')
            .doc(tournament.id)
            .collection('games')
            .where('delegateId', isEqualTo: delegateId)
            .get();

        if (gamesSnap.docs.isNotEmpty) {
          debugPrint('Delegate dashboard: ${gamesSnap.docs.length} games found in tournament ${tournament.name}');
        }

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

    // Sort by scheduledTime ascending
    games.sort((a, b) {
      final aTime = a['scheduledTime'];
      final bTime = b['scheduledTime'];
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      DateTime aDate = aTime is Timestamp ? aTime.toDate() : DateTime.tryParse(aTime.toString()) ?? DateTime(0);
      DateTime bDate = bTime is Timestamp ? bTime.toDate() : DateTime.tryParse(bTime.toString()) ?? DateTime(0);
      return aDate.compareTo(bDate);
    });

    _allAssignedGames = games;
  }

  Future<void> _loadSignOffStatus() async {
    for (final game in _allAssignedGames) {
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

            ..._buildGameSections(),

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

  List<Widget> _buildGameSections() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    DateTime? _parseTime(dynamic t) {
      if (t == null) return null;
      if (t is Timestamp) return t.toDate();
      return DateTime.tryParse(t.toString());
    }

    final upcomingGames = _allAssignedGames.where((g) {
      final d = _parseTime(g['scheduledTime']);
      return d == null || !d.isBefore(todayStart);
    }).toList();

    final pastGames = _allAssignedGames.where((g) {
      final d = _parseTime(g['scheduledTime']);
      return d != null && d.isBefore(todayStart);
    }).toList()
      ..sort((a, b) {
        final aDate = _parseTime(a['scheduledTime']) ?? DateTime(0);
        final bDate = _parseTime(b['scheduledTime']) ?? DateTime(0);
        return bDate.compareTo(aDate);
      });

    return [
      _buildSectionHeader('Kommende Zuordnungen', Icons.event_note),
      const SizedBox(height: 12),
      if (upcomingGames.isEmpty)
        _buildEmptyCard('Keine bevorstehenden Spiele.')
      else
        ...upcomingGames.map(_buildGameCard),
      const SizedBox(height: 24),
      _buildSectionHeader('Vergangene Spiele', Icons.history),
      const SizedBox(height: 12),
      if (pastGames.isEmpty)
        _buildEmptyCard('Keine vergangenen Spiele.')
      else
        ...pastGames.take(20).map(_buildGameCard),
    ];
  }

  Widget _buildSummaryRow() {
    final pendingSignOffs = _allAssignedGames.where((g) {
      final status = _signOffStatus[g['id']];
      return status == null || status['delegateSigned'] != true;
    }).length;

    return Row(
      children: [
        Expanded(child: _buildSummaryCard('Zugeordnete Spiele', '${_allAssignedGames.length}', Icons.sports_handball, Colors.blue)),
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
    final gameStatus = game['status'] as String? ?? '';
    final canObserve = gameStatus.contains('inProgress') ||
        gameStatus.contains('completed');

    // Collect referee ids/names from game data
    final referee1Id = game['referee1Id'] as String?;
    final referee2Id = game['referee2Id'] as String?;
    final referee1Name = game['referee1Name'] as String?;
    final referee2Name = game['referee2Name'] as String?;
    final refereeIds = [
      if (referee1Id != null) referee1Id,
      if (referee2Id != null) referee2Id,
    ];
    final refereeNames = [
      if (referee1Name != null) referee1Name,
      if (referee2Name != null) referee2Name,
    ];

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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canObserve)
              IconButton(
                icon: const Icon(Icons.assignment_ind, color: Colors.indigo),
                tooltip: 'Beobachtung',
                onPressed: () => _openObservationForm(
                  gameId: gameId,
                  tournamentId: game['tournamentId'] as String,
                  gameName: '$teamA vs $teamB',
                  game: game,
                  refereeIds: refereeIds,
                  refereeNames: refereeNames,
                ),
              ),
            Chip(
              label: Text(
                isFullySigned ? 'Abgeschlossen' : delegateSigned ? 'Signiert' : 'Ausstehend',
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
              backgroundColor: isFullySigned
                  ? Colors.green
                  : delegateSigned
                      ? Colors.blue
                      : Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openObservationForm({
    required String gameId,
    required String tournamentId,
    required String gameName,
    required Map<String, dynamic> game,
    required List<String> refereeIds,
    required List<String> refereeNames,
  }) async {
    // Resolve referee names if not already present
    List<String> resolvedNames = refereeNames;
    if (resolvedNames.isEmpty && refereeIds.isNotEmpty) {
      resolvedNames = [];
      for (final id in refereeIds) {
        final ref = await _refereeService.getRefereeById(id);
        resolvedNames.add(ref?.fullName ?? id);
      }
    }

    // Check if a draft observation exists for this game by this user
    final existing = await _observationService
        .getObservationsBySubmitter(_currentUser!.id)
        .first
        .then((list) => list
            .where((o) =>
                o.gameId == gameId && o.templateType == 'delegate')
            .toList());

    final scheduledTime = game['scheduledTime'];
    String gameDate = '';
    if (scheduledTime is Timestamp) {
      final d = scheduledTime.toDate();
      gameDate = '${d.day}.${d.month}.${d.year}';
    } else if (scheduledTime is DateTime) {
      gameDate = '${scheduledTime.day}.${scheduledTime.month}.${scheduledTime.year}';
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RefereeObservationFormScreen(
          gameId: gameId,
          tournamentId: tournamentId,
          gameName: gameName,
          gameDate: gameDate,
          refereeIds: refereeIds,
          refereeNames: resolvedNames,
          submitterId: _currentUser!.id,
          submitterName: _currentUser!.fullName,
          submitterRole: 'delegate',
          templateType: 'delegate',
          existingObservation: existing.isNotEmpty ? existing.first : null,
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
