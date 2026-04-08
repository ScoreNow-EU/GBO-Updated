import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game.dart';
import '../models/game_event.dart';
import '../models/tournament.dart';
import '../services/live_scoring_service.dart';
import '../services/game_service.dart';
import '../services/game_squad_service.dart';
import '../models/game_squad.dart';

class GameReportScreen extends StatefulWidget {
  final Game game;
  final Tournament tournament;

  const GameReportScreen({
    super.key,
    required this.game,
    required this.tournament,
  });

  @override
  State<GameReportScreen> createState() => _GameReportScreenState();
}

class _GameReportScreenState extends State<GameReportScreen> {
  final LiveScoringService _liveScoringService = LiveScoringService();
  final GameService _gameService = GameService();
  final GameSquadService _gameSquadService = GameSquadService();
  
  List<GameEvent> _events = [];
  bool _isLoading = true;
  GameSquad? _squadA;
  GameSquad? _squadB;

  // Confirmation state
  bool _refereeConfirmed = false;
  DateTime? _refereeConfirmedAt;
  bool _delegateConfirmed = false;
  DateTime? _delegateConfirmedAt;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load game events
      final eventsSnapshot = await FirebaseFirestore.instance
          .collection('gameEvents')
          .where('gameId', isEqualTo: widget.game.id)
          .get();

      _events = eventsSnapshot.docs
          .map((doc) => GameEvent.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
      _events.sort((a, b) => a.gameMinute.compareTo(b.gameMinute));

      // Load squads
      try {
        if (widget.game.teamAId != null) {
          _squadA = await _gameSquadService.getSquadForGame(widget.game.id, widget.game.teamAId!);
        }
        if (widget.game.teamBId != null) {
          _squadB = await _gameSquadService.getSquadForGame(widget.game.id, widget.game.teamBId!);
        }
      } catch (_) {}

      // Load confirmation state
      try {
        final reportDoc = await FirebaseFirestore.instance
            .collection('gameReports')
            .doc(widget.game.id)
            .get();
        if (reportDoc.exists) {
          final data = reportDoc.data()!;
          _refereeConfirmed = data['refereeConfirmed'] ?? false;
          _refereeConfirmedAt = data['refereeConfirmedAt'] != null
              ? DateTime.parse(data['refereeConfirmedAt'])
              : null;
          _delegateConfirmed = data['delegateConfirmed'] ?? false;
          _delegateConfirmedAt = data['delegateConfirmedAt'] != null
              ? DateTime.parse(data['delegateConfirmedAt'])
              : null;
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Error loading game report data: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      floatingActionButton: (!_isLoading && widget.game.teamAId != null && widget.game.teamBId != null)
          ? FloatingActionButton.extended(
              onPressed: _showAddEventDialog,
              icon: const Icon(Icons.add),
              label: const Text('Ereignis'),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            )
          : null,
      appBar: AppBar(
        title: const Text('Spielbericht'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Aktualisieren',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildScoreCard(),
                      const SizedBox(height: 24),
                      if (_squadA != null || _squadB != null) ...[
                        _buildSquadSection(),
                        const SizedBox(height: 24),
                      ],
                      _buildEventsTable(),
                      const SizedBox(height: 24),
                      _buildStatsSection(),
                      const SizedBox(height: 24),
                      _buildConfirmationSection(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    final game = widget.game;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Tournament name
            Text(
              widget.tournament.name,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            // Game type badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _getGameTypeColor(game.gameType).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getGameTypeLabel(game),
                style: TextStyle(
                  color: _getGameTypeColor(game.gameType),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Metadata row
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (game.scheduledTime != null)
                  _buildInfoChip(Icons.calendar_today, _formatDate(game.scheduledTime!)),
                if (game.scheduledTime != null)
                  _buildInfoChip(Icons.access_time, _formatTime(game.scheduledTime!)),
                if (game.courtId != null)
                  _buildInfoChip(Icons.stadium, _getCourtName(game.courtId!)),
                _buildInfoChip(Icons.flag, _getStatusText(game.status)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
      ],
    );
  }

  Widget _buildScoreCard() {
    final game = widget.game;
    final result = game.result;
    final halfTimeA = result?.halfTimeScoreA;
    final halfTimeB = result?.halfTimeScoreB;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                // Team A
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'HEIM',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[500],
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        game.teamAName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: result?.winnerId == game.teamAId ? Colors.green.shade700 : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Score
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        result != null ? result.finalScore : 'vs',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      if (halfTimeA != null && halfTimeB != null)
                        Text(
                          'HZ: $halfTimeA:$halfTimeB',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      if (result?.overtimeScoreA != null)
                        Text(
                          'V: ${result!.overtimeScoreA}:${result.overtimeScoreB}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      if (result?.penaltyScoreA != null)
                        Text(
                          '7m: ${result!.penaltyScoreA}:${result.penaltyScoreB}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
                // Team B
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'GAST',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[500],
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        game.teamBName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: result?.winnerId == game.teamBId ? Colors.green.shade700 : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSquadSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kaderaufstellungen',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_squadA != null)
                  Expanded(child: _buildSquadList(widget.game.teamAName, _squadA!)),
                if (_squadA != null && _squadB != null) const SizedBox(width: 24),
                if (_squadB != null)
                  Expanded(child: _buildSquadList(widget.game.teamBName, _squadB!)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSquadList(String teamName, GameSquad squad) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          teamName,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...squad.selectedPlayers.map((p) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  p.jerseyNumber ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${p.firstName} ${p.lastName}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: p.isStarter ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (p.classification != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    p.classification!,
                    style: const TextStyle(fontSize: 10, color: Colors.blue),
                  ),
                ),
            ],
          ),
        )),
      ],
    );
  }

  // â”€â”€ Events Table â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildEventsTable() {
    // sort: half then minute
    final sorted = [..._events]
      ..sort((a, b) {
        final h = (a.half ?? 1).compareTo(b.half ?? 1);
        return h != 0 ? h : a.gameMinute.compareTo(b.gameMinute);
      });

    // build running score rows
    int sA = 0, sB = 0;
    final rows = sorted.map((event) {
      if (event.points > 0) {
        if (event.teamId == widget.game.teamAId) sA += event.points;
        else sB += event.points;
      }
      return _EventRow(event: event, scoreA: sA, scoreB: sB);
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                const Text(
                  'Spielereignisse',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (widget.game.teamAId != null && widget.game.teamBId != null)
                  ElevatedButton.icon(
                    onPressed: _showAddEventDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Ereignis hinzufÃ¼gen'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            if (sorted.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(Icons.sports_handball, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'Keine Ereignisse eingetragen',
                        style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'FÃ¼gen Sie Ereignisse Ã¼ber den Button oben oder unten rechts hinzu.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              _buildEventsTableContent(rows),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsTableContent(List<_EventRow> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Column Headers
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 62,
                child: Text('Team', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
              ),
              SizedBox(
                width: 58,
                child: Text('Zeit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700]), textAlign: TextAlign.center),
              ),
              SizedBox(
                width: 66,
                child: Text('Spielstand', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700]), textAlign: TextAlign.center),
              ),
              Expanded(
                child: Text('Ereignis', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
              ),
              Expanded(
                child: Text('Person', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
              ),
              const SizedBox(width: 36),
            ],
          ),
        ),
        const SizedBox(height: 4),
        ...rows.map(_buildEventTableRow).toList(),
      ],
    );
  }

  Widget _buildEventTableRow(_EventRow row) {
    final event = row.event;
    final isTeamA = event.teamId == widget.game.teamAId;
    final cfg = _getEventConfig(event.eventType);
    final half = event.half ?? 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isTeamA ? Colors.blue.withOpacity(0.04) : Colors.red.withOpacity(0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Team badge
          SizedBox(
            width: 62,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: isTeamA ? Colors.blue.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isTeamA ? 'Heim' : 'Gast',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isTeamA ? Colors.blue.shade700 : Colors.red.shade700,
                ),
              ),
            ),
          ),
          // Zeit (half + minute)
          SizedBox(
            width: 58,
            child: Text(
              '$half. ${event.gameMinute.toString().padLeft(2, '0')}\' ',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          // Spielstand
          SizedBox(
            width: 66,
            child: event.points > 0
                ? Text(
                    '${row.scoreA}:${row.scoreB}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  )
                : Text(
                    'â€”',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
          ),
          // Ereignis
          Expanded(
            child: Row(
              children: [
                Icon(cfg.icon, size: 14, color: cfg.color),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    cfg.label,
                    style: TextStyle(fontSize: 12, color: cfg.color, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Person
          Expanded(
            child: Text(
              event.playerName.isNotEmpty ? event.playerName : 'â€”',
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Delete
          SizedBox(
            width: 36,
            child: IconButton(
              icon: Icon(Icons.delete_outline, size: 16, color: Colors.red[400]),
              onPressed: () => _showDeleteConfirmation(event),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'LÃ¶schen',
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€ Event Entry Dialog â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _showAddEventDialog() {
    String selectedTeam = 'A';
    GameEventType selectedEventType = GameEventType.goal;
    int selectedHalf = 1;
    final minuteController = TextEditingController();
    final playerController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Ereignis hinzufÃ¼gen'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Team
                  DropdownButtonFormField<String>(
                    value: selectedTeam,
                    decoration: const InputDecoration(
                      labelText: 'Team',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.groups),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'A',
                        child: Row(
                          children: [
                            Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Flexible(child: Text('Heim â€“ ${widget.game.teamAName}', overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'B',
                        child: Row(
                          children: [
                            Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Flexible(child: Text('Gast â€“ ${widget.game.teamBName}', overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (v) => setDlgState(() => selectedTeam = v!),
                  ),
                  const SizedBox(height: 12),

                  // Half
                  DropdownButtonFormField<int>(
                    value: selectedHalf,
                    decoration: const InputDecoration(
                      labelText: 'Halbzeit',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1. Halbzeit')),
                      DropdownMenuItem(value: 2, child: Text('2. Halbzeit')),
                    ],
                    onChanged: (v) => setDlgState(() => selectedHalf = v!),
                  ),
                  const SizedBox(height: 12),

                  // Zeit
                  TextField(
                    controller: minuteController,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      labelText: 'Spielminute',
                      hintText: 'z.B. 13 oder 13:49',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.timer),
                      helperText: 'Minute oder MM:SS eingeben',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Ereignis
                  DropdownButtonFormField<GameEventType>(
                    value: selectedEventType,
                    decoration: const InputDecoration(
                      labelText: 'Ereignis',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.event),
                    ),
                    items: GameEventType.values.map((type) {
                      final cfg = _getEventConfig(type);
                      return DropdownMenuItem(
                        value: type,
                        child: Row(
                          children: [
                            Icon(cfg.icon, size: 16, color: cfg.color),
                            const SizedBox(width: 8),
                            Text(cfg.label),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setDlgState(() => selectedEventType = v!),
                  ),
                  const SizedBox(height: 12),

                  // Person
                  TextField(
                    controller: playerController,
                    decoration: const InputDecoration(
                      labelText: 'Spieler / Person',
                      hintText: 'Name eingeben (optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('HinzufÃ¼gen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final raw = minuteController.text.trim();
                int minute = 0;
                if (raw.contains(':')) {
                  minute = int.tryParse(raw.split(':').first) ?? 0;
                } else {
                  minute = int.tryParse(raw) ?? 0;
                }
                Navigator.of(ctx).pop();
                _addEvent(
                  teamId: selectedTeam == 'A' ? widget.game.teamAId! : widget.game.teamBId!,
                  teamName: selectedTeam == 'A' ? widget.game.teamAName : widget.game.teamBName,
                  eventType: selectedEventType,
                  gameMinute: minute,
                  half: selectedHalf,
                  playerName: playerController.text.trim(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(GameEvent event) {
    final cfg = _getEventConfig(event.eventType);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ereignis lÃ¶schen'),
        content: Text(
          'MÃ¶chten Sie das Ereignis "${cfg.label}"'
          '${event.playerName.isNotEmpty ? ' von ${event.playerName}' : ''}'
          ' wirklich lÃ¶schen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteEvent(event);
            },
            child: const Text('LÃ¶schen'),
          ),
        ],
      ),
    );
  }

  // â”€â”€ Event CRUD â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _addEvent({
    required String teamId,
    required String teamName,
    required GameEventType eventType,
    required int gameMinute,
    required int half,
    required String playerName,
  }) async {
    try {
      final ref = FirebaseFirestore.instance.collection('gameEvents').doc();
      final event = GameEvent(
        id: ref.id,
        gameId: widget.game.id,
        teamId: teamId,
        teamName: teamName,
        eventType: eventType,
        gameMinute: gameMinute,
        half: half,
        playerName: playerName,
        timestamp: DateTime.now(),
      );
      await ref.set(event.toJson());
      await _loadData();
      await _recalculateAndSaveScore();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ereignis hinzugefÃ¼gt'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteEvent(GameEvent event) async {
    try {
      await FirebaseFirestore.instance
          .collection('gameEvents')
          .doc(event.id)
          .delete();
      await _loadData();
      await _recalculateAndSaveScore();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ereignis gelÃ¶scht'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // â”€â”€ Auto Score Calculation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _recalculateAndSaveScore() async {
    final teamAId = widget.game.teamAId;
    final teamBId = widget.game.teamBId;
    if (teamAId == null || teamBId == null) return;

    // Tally goals for each team
    final scoreA = _events
        .where((e) => e.teamId == teamAId && e.points > 0)
        .fold(0, (sum, e) => sum + e.points);
    final scoreB = _events
        .where((e) => e.teamId == teamBId && e.points > 0)
        .fold(0, (sum, e) => sum + e.points);

    // Half-time score (half == 1)
    final halfTimeA = _events
        .where((e) => e.teamId == teamAId && e.points > 0 && (e.half ?? 1) == 1)
        .fold(0, (sum, e) => sum + e.points);
    final halfTimeB = _events
        .where((e) => e.teamId == teamBId && e.points > 0 && (e.half ?? 1) == 1)
        .fold(0, (sum, e) => sum + e.points);

    String? winnerId;
    String winnerName = 'Unentschieden';
    if (scoreA > scoreB) {
      winnerId = teamAId;
      winnerName = widget.game.teamAName;
    } else if (scoreB > scoreA) {
      winnerId = teamBId;
      winnerName = widget.game.teamBName;
    }

    final result = GameResult(
      teamAScore: scoreA,
      teamBScore: scoreB,
      winnerId: winnerId,
      winnerName: winnerName,
      halfTimeScoreA: halfTimeA,
      halfTimeScoreB: halfTimeB,
    );

    // Persist updated result â†’ also marks the game as completed
    final updatedGame = widget.game.copyWith(
      result: result,
      status: GameStatus.completed,
      updatedAt: DateTime.now(),
    );
    await _gameService.updateGame(updatedGame);
  }

  Widget _buildStatsSection() {
    if (_events.isEmpty) return const SizedBox.shrink();

    // Calculate stats per team
    final teamAId = widget.game.teamAId;
    final teamBId = widget.game.teamBId;

    int goalsA = _events.where((e) => e.teamId == teamAId && (e.eventType == GameEventType.goal || e.eventType == GameEventType.sevenMeterHit)).length;
    int goalsB = _events.where((e) => e.teamId == teamBId && (e.eventType == GameEventType.goal || e.eventType == GameEventType.sevenMeterHit)).length;
    int sevenMHitA = _events.where((e) => e.teamId == teamAId && e.eventType == GameEventType.sevenMeterHit).length;
    int sevenMHitB = _events.where((e) => e.teamId == teamBId && e.eventType == GameEventType.sevenMeterHit).length;
    int sevenMMissA = _events.where((e) => e.teamId == teamAId && e.eventType == GameEventType.sevenMeterMiss).length;
    int sevenMMissB = _events.where((e) => e.teamId == teamBId && e.eventType == GameEventType.sevenMeterMiss).length;
    int yellowA = _events.where((e) => e.teamId == teamAId && e.eventType == GameEventType.yellowCard).length;
    int yellowB = _events.where((e) => e.teamId == teamBId && e.eventType == GameEventType.yellowCard).length;
    int twoMinA = _events.where((e) => e.teamId == teamAId && e.eventType == GameEventType.twoMinuteSuspension).length;
    int twoMinB = _events.where((e) => e.teamId == teamBId && e.eventType == GameEventType.twoMinuteSuspension).length;
    int redA = _events.where((e) => e.teamId == teamAId && e.eventType == GameEventType.redCard).length;
    int redB = _events.where((e) => e.teamId == teamBId && e.eventType == GameEventType.redCard).length;
    int blueA = _events.where((e) => e.teamId == teamAId && e.eventType == GameEventType.blueCard).length;
    int blueB = _events.where((e) => e.teamId == teamBId && e.eventType == GameEventType.blueCard).length;
    int timeoutA = _events.where((e) => e.teamId == teamAId && e.eventType == GameEventType.timeout).length;
    int timeoutB = _events.where((e) => e.teamId == teamBId && e.eventType == GameEventType.timeout).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistik',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStatRow('Tore', goalsA, goalsB),
            _buildStatRow('7m (Treffer/Gesamt)', sevenMHitA, sevenMHitB,
                subA: '${sevenMHitA}/${sevenMHitA + sevenMMissA}',
                subB: '${sevenMHitB}/${sevenMHitB + sevenMMissB}'),
            _buildStatRow('Verwarnungen', yellowA, yellowB),
            _buildStatRow('2-Min Strafen', twoMinA, twoMinB),
            _buildStatRow('Rote Karten', redA, redB),
            if (blueA > 0 || blueB > 0) _buildStatRow('Blaue Karten', blueA, blueB),
            _buildStatRow('Auszeiten', timeoutA, timeoutB),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, int valueA, int valueB, {String? subA, String? subB}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              subA ?? valueA.toString(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                // Bar comparison
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FractionallySizedBox(
                          widthFactor: valueA + valueB > 0 ? valueA / (valueA + valueB) : 0.5,
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: valueA + valueB > 0 ? valueB / (valueA + valueB) : 0.5,
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              subB ?? valueB.toString(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Offizielle BestÃ¤tigung',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Referee confirmation
            _buildConfirmationTile(
              icon: Icons.sports,
              title: 'Schiedsrichter',
              isConfirmed: _refereeConfirmed,
              confirmedAt: _refereeConfirmedAt,
              onConfirm: () => _confirmReport('referee'),
              onRevoke: () => _revokeConfirmation('referee'),
            ),
            const SizedBox(height: 8),

            // Delegate confirmation
            _buildConfirmationTile(
              icon: Icons.verified_user,
              title: 'Delegierter',
              isConfirmed: _delegateConfirmed,
              confirmedAt: _delegateConfirmedAt,
              onConfirm: () => _confirmReport('delegate'),
              onRevoke: () => _revokeConfirmation('delegate'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationTile({
    required IconData icon,
    required String title,
    required bool isConfirmed,
    DateTime? confirmedAt,
    required VoidCallback onConfirm,
    required VoidCallback onRevoke,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isConfirmed ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isConfirmed ? Colors.green.shade300 : Colors.orange.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isConfirmed ? Colors.green.shade700 : Colors.orange.shade700,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isConfirmed ? Colors.green.shade800 : Colors.orange.shade800,
                  ),
                ),
                if (isConfirmed && confirmedAt != null)
                  Text(
                    'BestÃ¤tigt am ${_formatDate(confirmedAt)} um ${_formatTime(confirmedAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade600),
                  )
                else
                  Text(
                    'Noch nicht bestÃ¤tigt',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade600),
                  ),
              ],
            ),
          ),
          if (isConfirmed)
            TextButton(
              onPressed: onRevoke,
              child: const Text('Widerrufen', style: TextStyle(color: Colors.red)),
            )
          else
            ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('BestÃ¤tigen'),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmReport(String role) async {
    final pin = await _showPinDialog(role);
    if (pin == null) return;

    try {
      final now = DateTime.now();
      final data = <String, dynamic>{};
      if (role == 'referee') {
        data['refereeConfirmed'] = true;
        data['refereeConfirmedAt'] = now.toIso8601String();
        data['refereePin'] = pin;
      } else {
        data['delegateConfirmed'] = true;
        data['delegateConfirmedAt'] = now.toIso8601String();
        data['delegatePin'] = pin;
      }

      await FirebaseFirestore.instance
          .collection('gameReports')
          .doc(widget.game.id)
          .set(data, SetOptions(merge: true));

      setState(() {
        if (role == 'referee') {
          _refereeConfirmed = true;
          _refereeConfirmedAt = now;
        } else {
          _delegateConfirmed = true;
          _delegateConfirmedAt = now;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  Future<void> _revokeConfirmation(String role) async {
    try {
      final data = <String, dynamic>{};
      if (role == 'referee') {
        data['refereeConfirmed'] = false;
        data['refereeConfirmedAt'] = null;
      } else {
        data['delegateConfirmed'] = false;
        data['delegateConfirmedAt'] = null;
      }

      await FirebaseFirestore.instance
          .collection('gameReports')
          .doc(widget.game.id)
          .set(data, SetOptions(merge: true));

      setState(() {
        if (role == 'referee') {
          _refereeConfirmed = false;
          _refereeConfirmedAt = null;
        } else {
          _delegateConfirmed = false;
          _delegateConfirmedAt = null;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  Future<String?> _showPinDialog(String role) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${role == 'referee' ? 'Schiedsrichter' : 'Delegierter'}-BestÃ¤tigung'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Bitte geben Sie Ihren PIN-Code ein, um den Spielbericht zu bestÃ¤tigen.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'PIN-Code',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.of(ctx).pop(controller.text);
              }
            },
            child: const Text('BestÃ¤tigen'),
          ),
        ],
      ),
    );
  }

  // Helper methods

  _EventConfig _getEventConfig(GameEventType type) {
    switch (type) {
      case GameEventType.goal:
        return _EventConfig(Icons.sports_handball, Colors.green.shade700, 'Tor');
      case GameEventType.sevenMeterHit:
        return _EventConfig(Icons.gps_fixed, Colors.green.shade600, '7m Tor');
      case GameEventType.sevenMeterMiss:
        return _EventConfig(Icons.gps_not_fixed, Colors.grey, '7m ohne Tor');
      case GameEventType.yellowCard:
        return _EventConfig(Icons.square, Colors.amber.shade700, 'Verwarnung');
      case GameEventType.twoMinuteSuspension:
        return _EventConfig(Icons.timer, Colors.orange.shade800, '2 Minuten');
      case GameEventType.redCard:
        return _EventConfig(Icons.square, Colors.red.shade700, 'Rote Karte');
      case GameEventType.blueCard:
        return _EventConfig(Icons.square, Colors.blue.shade700, 'Blaue Karte');
      case GameEventType.timeout:
        return _EventConfig(Icons.pause_circle, Colors.grey.shade700, 'Auszeit');
      case GameEventType.substitution:
        return _EventConfig(Icons.swap_horiz, Colors.teal, 'Wechsel');
    }
  }

  Color _getGameTypeColor(GameType type) {
    switch (type) {
      case GameType.pool:
        return Colors.blue;
      case GameType.elimination:
        return Colors.purple;
      case GameType.friendly:
        return Colors.teal;
    }
  }

  String _getGameTypeLabel(Game game) {
    switch (game.gameType) {
      case GameType.pool:
        return 'Gruppe ${game.poolId?.toUpperCase() ?? ''}';
      case GameType.elimination:
        return 'K.O.-Phase';
      case GameType.friendly:
        return 'Freundschaftsspiel';
    }
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _getCourtName(String courtId) {
    try {
      return widget.tournament.courts.firstWhere((c) => c.id == courtId).name;
    } catch (_) {
      return courtId;
    }
  }

  String _getStatusText(GameStatus status) {
    switch (status) {
      case GameStatus.scheduled:
        return 'Geplant';
      case GameStatus.inProgress:
        return 'LÃ¤uft';
      case GameStatus.completed:
        return 'Beendet';
      case GameStatus.cancelled:
        return 'Abgesagt';
    }
  }
}

class _EventConfig {
  final IconData icon;
  final Color color;
  final String label;
  _EventConfig(this.icon, this.color, this.label);
}

/// Pairs a [GameEvent] with the running score snapshot after that event.
class _EventRow {
  final GameEvent event;
  final int scoreA;
  final int scoreB;
  const _EventRow({required this.event, required this.scoreA, required this.scoreB});
}
