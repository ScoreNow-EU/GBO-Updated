import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game.dart';
import '../models/tournament.dart';
import '../services/game_service.dart';
import '../services/tournament_stats_service.dart';

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

  int _currentView = 0; // 0=live, 1=upcoming, 2=standings, 3=results
  Timer? _rotateTimer;
  Timer? _refreshTimer;

  static const _rotationInterval = Duration(seconds: 15);
  static const _refreshInterval = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _loadData();
    _rotateTimer = Timer.periodic(_rotationInterval, (_) => _rotateView());
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => _refreshData());
  }

  @override
  void dispose() {
    _rotateTimer?.cancel();
    _refreshTimer?.cancel();
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
      _tournament = Tournament.fromJson({...doc.data()!, 'id': doc.id});
      _games = await _gameService.getGamesForTournament(tId).first;
      _standings = await _statsService.getOverallTeamStats(tId);
    } catch (e) {
      _error = 'Fehler: $e';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _refreshData() async {
    if (_tournament == null) return;
    try {
      _games = await _gameService.getGamesForTournament(_tournament!.id).first;
      _standings = await _statsService.getOverallTeamStats(_tournament!.id);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _rotateView() {
    if (!mounted) return;
    setState(() => _currentView = (_currentView + 1) % 4);
  }

  List<Game> get _liveGames => _games.where((g) => g.status == GameStatus.inProgress).toList();
  List<Game> get _upcomingGames => _games
      .where((g) => g.status == GameStatus.scheduled)
      .toList()
    ..sort((a, b) => (a.scheduledTime ?? DateTime(2099)).compareTo(b.scheduledTime ?? DateTime(2099)));
  List<Game> get _completedGames => _games
      .where((g) => g.status == GameStatus.completed)
      .toList()
    ..sort((a, b) => (b.scheduledTime ?? DateTime(0)).compareTo(a.scheduledTime ?? DateTime(0)));

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0a0a1a),
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0a0a1a),
        body: Center(
          child: Text(_error!, style: const TextStyle(color: Colors.white70, fontSize: 24)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0a0a1a),
      body: Column(
        children: [
          // Header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            color: const Color(0xFF16213e),
            child: Row(
              children: [
                Text(
                  _tournament?.name ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                // View indicators
                ...List.generate(4, (i) => Container(
                  width: 10, height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _currentView ? Colors.amber : Colors.white24,
                  ),
                )),
                const SizedBox(width: 16),
                Text(
                  _timeString(),
                  style: const TextStyle(color: Colors.white70, fontSize: 20),
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
        return _buildUpcomingView();
      case 2:
        return _buildStandingsView();
      case 3:
        return _buildResultsView();
      default:
        return _buildLiveView();
    }
  }

  Widget _buildLiveView() {
    final games = _liveGames;
    return _buildGamesPanel(
      key: const ValueKey('live'),
      title: 'LIVE',
      titleColor: Colors.red,
      games: games,
      emptyText: 'Kein Spiel läuft gerade',
    );
  }

  Widget _buildUpcomingView() {
    return _buildGamesPanel(
      key: const ValueKey('upcoming'),
      title: 'NÄCHSTE SPIELE',
      titleColor: Colors.amber,
      games: _upcomingGames.take(8).toList(),
      emptyText: 'Keine weiteren Spiele geplant',
    );
  }

  Widget _buildResultsView() {
    return _buildGamesPanel(
      key: const ValueKey('results'),
      title: 'ERGEBNISSE',
      titleColor: Colors.green,
      games: _completedGames.take(8).toList(),
      emptyText: 'Noch keine Ergebnisse',
    );
  }

  Widget _buildGamesPanel({
    required Key key,
    required String title,
    required Color titleColor,
    required List<Game> games,
    required String emptyText,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 6, height: 32, color: titleColor),
              const SizedBox(width: 12),
              Text(title,
                  style: TextStyle(
                      color: titleColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2)),
            ],
          ),
          const SizedBox(height: 24),
          if (games.isEmpty)
            Expanded(
              child: Center(
                child: Text(emptyText,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 24)),
              ),
            )
          else
            Expanded(
              child: ListView(
                children: games.map((g) => _buildKioskGameCard(g)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKioskGameCard(Game game) {
    final result = game.result;
    final isLive = game.status == GameStatus.inProgress;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF16213e),
        borderRadius: BorderRadius.circular(16),
        border: isLive ? Border.all(color: Colors.red.withValues(alpha: 0.6), width: 2) : null,
      ),
      child: Row(
        children: [
          if (game.courtId != null) ...[
            Text(game.courtId!,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14)),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Text(game.teamAName,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                textAlign: TextAlign.right,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: isLive ? Colors.red.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              result != null ? result.finalScore : _formatTime(game.scheduledTime),
              style: TextStyle(
                color: Colors.white,
                fontSize: result != null ? 32 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(game.teamBName,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                textAlign: TextAlign.left,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildStandingsView() {
    if (_standings.isEmpty) {
      return Center(
        key: const ValueKey('standings-empty'),
        child: Text('Keine Tabellendaten',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 24)),
      );
    }

    return Container(
      key: const ValueKey('standings'),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 6, height: 32, color: Colors.blue),
              const SizedBox(width: 12),
              const Text('TABELLE',
                  style: TextStyle(
                      color: Colors.blue, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2)),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Table(
                columnWidths: const {
                  0: FixedColumnWidth(40),
                  1: FlexColumnWidth(),
                  2: FixedColumnWidth(40),
                  3: FixedColumnWidth(40),
                  4: FixedColumnWidth(40),
                  5: FixedColumnWidth(40),
                  6: FixedColumnWidth(80),
                  7: FixedColumnWidth(60),
                },
                children: [
                  TableRow(
                    children: ['#', 'Team', 'Sp', 'S', 'U', 'N', 'Tore', 'Pkt']
                        .map((h) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(h,
                                  style: TextStyle(
                                      color: Colors.amber.shade300,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center),
                            ))
                        .toList(),
                  ),
                  ..._standings.asMap().entries.map((e) {
                    final i = e.key;
                    final t = e.value;
                    final ts = TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 18);
                    return TableRow(
                      decoration: BoxDecoration(
                        color: i.isEven ? Colors.white.withValues(alpha: 0.03) : Colors.transparent,
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
                        _kioskCell('${t.points}', ts.copyWith(fontWeight: FontWeight.bold, color: Colors.amber)),
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

  Widget _kioskCell(String text, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(text, style: style, textAlign: TextAlign.center),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _timeString() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}
