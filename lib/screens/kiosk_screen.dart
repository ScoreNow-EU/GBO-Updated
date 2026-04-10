import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game.dart';
import '../models/game_event.dart';
import '../models/tournament.dart';
import '../services/game_service.dart';
import '../services/tournament_stats_service.dart';
import '../utils/app_colors.dart';

/// Full-screen kiosk display for venue TVs: auto-rotates live games, schedule, standings
class KioskScreen extends StatefulWidget {
  final String? tournamentId;
  const KioskScreen({super.key, this.tournamentId});

  @override
  State<KioskScreen> createState() => _KioskScreenState();
}

class _KioskScreenState extends State<KioskScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GameService _gameService = GameService();
  final TournamentStatsService _statsService = TournamentStatsService();

  Tournament? _tournament;
  List<Game> _games = [];
  List<TeamTournamentStats> _standings = [];
  bool _isLoading = true;
  String? _error;

  // Live game state data (scores, time, events) per gameId
  Map<String, GameState> _liveStates = {};
  Timer? _livePollingTimer;

  int _currentView = 0; // 0=live, 1=schedule, 2=standings
  Timer? _rotateTimer;
  Timer? _standingsTimer;
  Timer? _clockTimer;
  StreamSubscription<List<Game>>? _gamesSubscription;

  // Auto-scroll controller for the schedule view
  final ScrollController _scheduleScrollController = ScrollController();

  static const _rotationInterval = Duration(seconds: 8);
  static const _standingsRefreshInterval = Duration(seconds: 60);
  static const _livePollingInterval = Duration(seconds: 10);

  /// Dynamic view count: 4 when tournament has sponsor logos, otherwise 3
  int get _viewCount => (_tournament?.sponsorLogos.isNotEmpty == true) ? 4 : 3;

  @override
  void initState() {
    super.initState();
    _loadData();
    _rotateTimer = Timer.periodic(_rotationInterval, (_) => _rotateView());
    _standingsTimer = Timer.periodic(_standingsRefreshInterval, (_) => _refreshStandings());
    _livePollingTimer = Timer.periodic(_livePollingInterval, (_) => _pollLiveStates());
    // Update clock every second for the header
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _rotateTimer?.cancel();
    _standingsTimer?.cancel();
    _livePollingTimer?.cancel();
    _clockTimer?.cancel();
    _gamesSubscription?.cancel();
    _scheduleScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final tId = widget.tournamentId;
    if (tId == null || tId.isEmpty) {
      setState(() {
        _error = 'Keine Turnier-ID. Verwende /kiosk?t={tournamentId}';
        _isLoading = false;
      });
      return;
    }

    try {
      final doc = await _firestore.collection('tournaments').doc(tId).get();
      if (!doc.exists) {
        setState(() { _error = 'Turnier nicht gefunden.'; _isLoading = false; });
        return;
      }
      _tournament = Tournament.fromMap({...doc.data()!, 'id': doc.id});
      _standings = await _statsService.getOverallTeamStats(tId);

      // Subscribe to real-time game updates
      _gamesSubscription = _gameService.getGamesForTournament(tId).listen((games) {
        if (mounted) {
          setState(() => _games = games);
          _pollLiveStates();
        }
      });
    } catch (e) {
      _error = 'Fehler: $e';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  /// Poll Firestore for live game scores, time, events every 10s
  Future<void> _pollLiveStates() async {
    final liveGames = _games.where((g) => g.status == GameStatus.inProgress).toList();
    if (liveGames.isEmpty) {
      if (_liveStates.isNotEmpty && mounted) setState(() => _liveStates = {});
      return;
    }
    final Map<String, GameState> newStates = {};
    for (final game in liveGames) {
      try {
        final stateDoc = await _firestore.collection('gameStates').doc(game.id).get();
        final eventsSnap = await _firestore
            .collection('gameEvents')
            .where('gameId', isEqualTo: game.id)
            .get();
        final events = eventsSnap.docs
            .map((d) => GameEvent.fromJson({...d.data(), 'id': d.id}))
            .toList();
        events.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        GameTime gameTime = GameTime();
        bool isRunning = false;
        int currentHalf = 1;
        if (stateDoc.exists) {
          final data = stateDoc.data()!;
          gameTime = GameTime(
            minutes: data['minutes'] ?? 0,
            seconds: data['seconds'] ?? 0,
            currentPeriod: data['currentPeriod'] ?? 1,
            halfDurationMinutes: data['halfDurationMinutes'] ?? 15,
          );
          isRunning = data['isRunning'] ?? false;
          currentHalf = data['currentHalf'] ?? 1;
        }
        newStates[game.id] = GameState(
          gameId: game.id,
          currentHalf: currentHalf,
          gameTime: gameTime,
          isRunning: isRunning,
          events: events,
        );
      } catch (_) {}
    }
    if (mounted) setState(() => _liveStates = newStates);
  }

  Future<void> _refreshStandings() async {
    if (_tournament == null) return;
    try {
      final standings = await _statsService.getOverallTeamStats(_tournament!.id);
      if (mounted) setState(() => _standings = standings);
    } catch (_) {}
  }

  void _rotateView() {
    if (!mounted) return;
    setState(() => _currentView = (_currentView + 1) % _viewCount);
    // When switching to schedule view, start auto-scroll from top
    if (_currentView == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _currentView != 1) return;
        if (!_scheduleScrollController.hasClients) return;
        _scheduleScrollController.jumpTo(0);
        _startAutoScroll();
      });
    }
  }

  void _startAutoScroll() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || _currentView != 1) return;
      if (!_scheduleScrollController.hasClients) return;
      final maxExtent = _scheduleScrollController.position.maxScrollExtent;
      if (maxExtent <= 0) return;
      _scheduleScrollController.animateTo(
        maxExtent,
        duration: Duration(milliseconds: (_rotationInterval.inMilliseconds * 0.8).round()),
        curve: Curves.linear,
      );
    });
  }

  List<Game> get _liveGames => _games.where((g) => g.status == GameStatus.inProgress).toList();

  /// All games sorted: upcoming first (by time asc), then completed (by time desc)
  List<Game> get _scheduleGames {
    final upcoming = _games
        .where((g) => g.status == GameStatus.scheduled)
        .toList()
      ..sort((a, b) => (a.scheduledTime ?? DateTime(2099)).compareTo(b.scheduledTime ?? DateTime(2099)));
    final completed = _games
        .where((g) => g.status == GameStatus.completed)
        .toList()
      ..sort((a, b) => (b.scheduledTime ?? DateTime(0)).compareTo(a.scheduledTime ?? DateTime(0)));
    return [...upcoming, ...completed];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryColor)),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text(_error!, style: const TextStyle(color: Colors.black54, fontSize: 24)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
            child: Row(
              children: [
                Text(
                  _tournament?.name ?? '',
                  style: const TextStyle(color: AppColors.onPrimary, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ...List.generate(_viewCount, (i) => Container(
                  width: 10, height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _currentView ? Colors.white : Colors.white38,
                  ),
                )),
                const SizedBox(width: 16),
                Text(
                  _timeString(),
                  style: TextStyle(color: AppColors.onPrimary.withValues(alpha: 0.7), fontSize: 20),
                ),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: _buildCurrentView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_currentView) {
      case 0:
        return _buildLiveView();
      case 1:
        return _buildScheduleView();
      case 2:
        return _buildStandingsView();
      case 3:
        return _buildSponsorsView();
      default:
        return _buildLiveView();
    }
  }

  // ─── LIVE VIEW ───────────────────────────────────────────────────────────

  Widget _buildLiveView() {
    final games = _liveGames;
    if (games.isEmpty) {
      return Container(
        key: const ValueKey('live-empty'),
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('LIVE', Colors.red),
            Expanded(
              child: Center(
                child: Text('Kein Spiel läuft gerade',
                    style: TextStyle(color: Colors.black.withValues(alpha: 0.3), fontSize: 28)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: const ValueKey('live'),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('LIVE', Colors.red),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: games.map((g) => _buildLiveGameCard(g)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveGameCard(Game game) {
    final state = _liveStates[game.id];
    final teamAId = game.teamAId ?? '';
    final teamBId = game.teamBId ?? '';
    final scoreA = state?.getTeamScore(teamAId) ?? 0;
    final scoreB = state?.getTeamScore(teamBId) ?? 0;
    final gameTime = state?.gameTime;
    final half = state?.currentHalf ?? 1;

    // Count 2-min suspensions per team
    final suspensionsA = state?.events
        .where((e) => e.teamId == teamAId && e.eventType == GameEventType.twoMinuteSuspension)
        .length ?? 0;
    final suspensionsB = state?.events
        .where((e) => e.teamId == teamBId && e.eventType == GameEventType.twoMinuteSuspension)
        .length ?? 0;

    // Recent penalty events (last 3)
    final recentPenalties = state?.events
        .where((e) => e.isPenalty)
        .toList()
      ?..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final lastPenalties = recentPenalties?.take(3).toList() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Time + Half indicator top center
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              if (gameTime != null)
                Text(
                  '$half. HZ  ${gameTime.displayTime}',
                  style: TextStyle(color: Colors.black.withValues(alpha: 0.5), fontSize: 18, fontWeight: FontWeight.w500),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Main scoreboard row
          Row(
            children: [
              // Team A
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(game.teamAName,
                        style: const TextStyle(color: Colors.black87, fontSize: 28, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (suspensionsA > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.timer, color: Colors.orange.shade700, size: 16),
                            const SizedBox(width: 4),
                            Text('$suspensionsA\u00d7 2 Min',
                                style: TextStyle(color: Colors.orange.shade700, fontSize: 14, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // Score
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$scoreA : $scoreB',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
              ),
              // Team B
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(game.teamBName,
                        style: const TextStyle(color: Colors.black87, fontSize: 28, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (suspensionsB > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.timer, color: Colors.orange.shade700, size: 16),
                            const SizedBox(width: 4),
                            Text('$suspensionsB\u00d7 2 Min',
                                style: TextStyle(color: Colors.orange.shade700, fontSize: 14, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          // Recent penalties feed
          if (lastPenalties.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: Colors.grey.shade300),
            const SizedBox(height: 4),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: lastPenalties.map((e) {
                final icon = _penaltyIcon(e.eventType);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon.$1, color: icon.$2, size: 16),
                    const SizedBox(width: 4),
                    Text("${e.gameMinute}' ${e.playerName} (${e.teamName})",
                        style: TextStyle(color: Colors.black.withValues(alpha: 0.6), fontSize: 13)),
                  ],
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  (IconData, Color) _penaltyIcon(GameEventType type) {
    switch (type) {
      case GameEventType.yellowCard:
        return (Icons.square, Colors.amber);
      case GameEventType.twoMinuteSuspension:
        return (Icons.timer, Colors.orange);
      case GameEventType.redCard:
        return (Icons.square, Colors.red);
      case GameEventType.blueCard:
        return (Icons.square, Colors.blue);
      default:
        return (Icons.info, Colors.grey);
    }
  }

  // ─── SCHEDULE VIEW (upcoming + completed merged) ─────────────────────────

  Widget _buildScheduleView() {
    final games = _scheduleGames;
    if (games.isEmpty) {
      return Container(
        key: const ValueKey('schedule-empty'),
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('SPIELPLAN', AppColors.primaryColorAlt),
            Expanded(
              child: Center(
                child: Text('Keine Spiele',
                    style: TextStyle(color: Colors.black.withValues(alpha: 0.3), fontSize: 24)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: const ValueKey('schedule'),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('SPIELPLAN', AppColors.primaryColorAlt),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              controller: _scheduleScrollController,
              itemCount: games.length,
              itemBuilder: (_, i) => _buildScheduleCard(games[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(Game game) {
    final isCompleted = game.status == GameStatus.completed;
    final result = game.result;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.grey.shade100 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Time column
          SizedBox(
            width: 60,
            child: Text(
              _formatTime(game.scheduledTime),
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.5),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Team A
          Expanded(
            child: Text(game.teamAName,
                style: TextStyle(
                    color: Colors.black87,
                    fontSize: 20,
                    fontWeight: isCompleted ? FontWeight.w500 : FontWeight.w600),
                textAlign: TextAlign.right,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          // Score or vs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green.withValues(alpha: 0.1) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isCompleted && result != null ? result.finalScore : 'vs',
              style: TextStyle(
                color: isCompleted ? Colors.green.shade800 : Colors.black54,
                fontSize: isCompleted ? 22 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Team B
          Expanded(
            child: Text(game.teamBName,
                style: TextStyle(
                    color: Colors.black87,
                    fontSize: 20,
                    fontWeight: isCompleted ? FontWeight.w500 : FontWeight.w600),
                textAlign: TextAlign.left,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          // Status indicator
          SizedBox(
            width: 30,
            child: isCompleted
                ? Icon(Icons.check_circle, color: Colors.green.shade400, size: 18)
                : Icon(Icons.schedule, color: Colors.grey.shade400, size: 18),
          ),
        ],
      ),
    );
  }

  // ─── STANDINGS VIEW ─────────────────────────────────────────────────────

  Widget _buildStandingsView() {
    if (_standings.isEmpty) {
      return Center(
        key: const ValueKey('standings-empty'),
        child: Text('Keine Tabellendaten',
            style: TextStyle(color: Colors.black.withValues(alpha: 0.3), fontSize: 24)),
      );
    }

    return Container(
      key: const ValueKey('standings'),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('TABELLE', AppColors.primaryColor),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Table(
                columnWidths: const {
                  0: FixedColumnWidth(50),
                  1: FlexColumnWidth(),
                  2: FixedColumnWidth(50),
                  3: FixedColumnWidth(50),
                  4: FixedColumnWidth(50),
                  5: FixedColumnWidth(50),
                  6: FixedColumnWidth(100),
                  7: FixedColumnWidth(70),
                },
                children: [
                  TableRow(
                    children: ['#', 'Team', 'Sp', 'S', 'U', 'N', 'Tore', 'Pkt']
                        .map((h) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(h,
                                  style: TextStyle(
                                      color: AppColors.primaryColorAlt,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center),
                            ))
                        .toList(),
                  ),
                  ..._standings.asMap().entries.map((e) {
                    final i = e.key;
                    final t = e.value;
                    final ts = TextStyle(color: Colors.black.withValues(alpha: 0.85), fontSize: 20);
                    return TableRow(
                      decoration: BoxDecoration(
                        color: i.isEven ? Colors.grey.shade50 : Colors.transparent,
                      ),
                      children: [
                        _kioskCell('${i + 1}', ts),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(t.teamName,
                              style: ts.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        _kioskCell('${t.played}', ts),
                        _kioskCell('${t.won}', ts),
                        _kioskCell('${t.drawn}', ts),
                        _kioskCell('${t.lost}', ts),
                        _kioskCell('${t.goalsFor}:${t.goalsAgainst}', ts),
                        _kioskCell('${t.points}', ts.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryColorAlt)),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SPONSORS VIEW ───────────────────────────────────────────────────

  Widget _buildSponsorsView() {
    final logos = _tournament?.sponsorLogos ?? [];
    if (logos.isEmpty) {
      return Container(
        key: const ValueKey('sponsors-empty'),
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('SPONSOREN', Colors.teal),
            Expanded(
              child: Center(
                child: Text('Keine Sponsoren',
                    style: TextStyle(color: Colors.black.withValues(alpha: 0.3), fontSize: 28)),
              ),
            ),
          ],
        ),
      );
    }

    final count = logos.length;

    return Container(
      key: const ValueKey('sponsors'),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('SPONSOREN', Colors.teal),
          const SizedBox(height: 24),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                final availableHeight = constraints.maxHeight;
                const maxLogoWidth = 300.0;
                const spacing = 24.0;
                const aspectRatio = 16 / 9;

                // Calculate columns based on available width and max logo size
                final crossAxisCount = (availableWidth / maxLogoWidth).floor().clamp(1, 100);
                // Calculate how many rows fill the height
                final cellWidth = (availableWidth - (crossAxisCount - 1) * spacing) / crossAxisCount;
                final cellHeight = cellWidth / aspectRatio;
                final rowCount = ((availableHeight + spacing) / (cellHeight + spacing)).ceil().clamp(1, 100);
                final totalItems = rowCount * crossAxisCount;

                return GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                    childAspectRatio: aspectRatio,
                  ),
                  itemCount: totalItems,
                  itemBuilder: (_, i) {
                    final row = i ~/ crossAxisCount;
                    final col = i % crossAxisCount;
                    final logoIndex = (row + col) % count;
                    return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Image.network(
                      logos[logoIndex],
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.broken_image,
                        size: 48,
                        color: Colors.grey.shade300,
                      ),
                    ),
                  ),
                );
              },
            );
          }),
          ),
        ],
      ),
    );
  }

  // ─── SHARED HELPERS ─────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(width: 6, height: 32, color: color),
        const SizedBox(width: 12),
        Text(title,
            style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2)),
      ],
    );
  }

  Widget _kioskCell(String text, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(text, style: style, textAlign: TextAlign.center),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '\u2014';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _timeString() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}
