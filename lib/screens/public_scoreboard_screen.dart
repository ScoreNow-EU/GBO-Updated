import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game.dart';
import '../models/tournament.dart';
import '../services/game_service.dart';
import '../services/tournament_stats_service.dart';

/// Public scoreboard screen — accessible without login at /public?t={tournamentId}
class PublicScoreboardScreen extends StatefulWidget {
  final String? tournamentId;
  const PublicScoreboardScreen({super.key, this.tournamentId});

  @override
  State<PublicScoreboardScreen> createState() => _PublicScoreboardScreenState();
}

class _PublicScoreboardScreenState extends State<PublicScoreboardScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GameService _gameService = GameService();
  final TournamentStatsService _statsService = TournamentStatsService();

  Tournament? _tournament;
  bool _isLoading = true;
  String? _error;
  List<PlayerTournamentStats> _topScorers = [];
  List<TeamTournamentStats> _standings = [];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTournament();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTournament() async {
    final tId = widget.tournamentId;
    if (tId == null || tId.isEmpty) {
      setState(() {
        _error = 'Keine Turnier-ID angegeben. Verwende /public?t={tournamentId}';
        _isLoading = false;
      });
      return;
    }

    try {
      final doc = await _firestore.collection('tournaments').doc(tId).get();
      if (!doc.exists) {
        setState(() {
          _error = 'Turnier nicht gefunden.';
          _isLoading = false;
        });
        return;
      }
      _tournament = Tournament.fromJson({...doc.data()!, 'id': doc.id});

      // Load stats
      _topScorers = await _statsService.getTopScorers(tId);
      _standings = await _statsService.getOverallTeamStats(tId);
    } catch (e) {
      _error = 'Fehler beim Laden: $e';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        title: Text(_tournament?.name ?? 'Live Scoreboard'),
        backgroundColor: const Color(0xFF16213e),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: _tournament != null
            ? TabBar(
                controller: _tabController,
                indicatorColor: Colors.amber,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                tabs: const [
                  Tab(icon: Icon(Icons.scoreboard), text: 'Live'),
                  Tab(icon: Icon(Icons.emoji_events), text: 'Tabelle'),
                  Tab(icon: Icon(Icons.star), text: 'Torjäger'),
                ],
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.amber),
                        const SizedBox(height: 16),
                        Text(_error!,
                            style: const TextStyle(color: Colors.white70, fontSize: 16),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLiveTab(),
                    _buildStandingsTab(),
                    _buildTopScorersTab(),
                  ],
                ),
    );
  }

  Widget _buildLiveTab() {
    return StreamBuilder<List<Game>>(
      stream: _gameService.getGamesForTournament(_tournament!.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.amber));
        }
        final games = snapshot.data ?? [];

        final liveGames = games.where((g) => g.status == GameStatus.inProgress).toList();
        final upcoming = games
            .where((g) => g.status == GameStatus.scheduled)
            .toList()
          ..sort((a, b) => (a.scheduledTime ?? DateTime(2099)).compareTo(b.scheduledTime ?? DateTime(2099)));
        final completed = games
            .where((g) => g.status == GameStatus.completed)
            .toList()
          ..sort((a, b) => (b.scheduledTime ?? DateTime(0)).compareTo(a.scheduledTime ?? DateTime(0)));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (liveGames.isNotEmpty) ...[
              _sectionHeader('LIVE', Colors.red),
              ...liveGames.map(_buildGameCard),
              const SizedBox(height: 24),
            ],
            if (upcoming.isNotEmpty) ...[
              _sectionHeader('NÄCHSTE SPIELE', Colors.amber),
              ...upcoming.take(6).map(_buildGameCard),
              const SizedBox(height: 24),
            ],
            if (completed.isNotEmpty) ...[
              _sectionHeader('ERGEBNISSE', Colors.green),
              ...completed.take(10).map(_buildGameCard),
            ],
            if (games.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 64),
                  child: Column(
                    children: [
                      Icon(Icons.sports_handball, size: 64, color: Colors.white.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text('Noch keine Spiele geplant',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(width: 4, height: 20, color: color),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        ],
      ),
    );
  }

  Widget _buildGameCard(Game game) {
    final result = game.result;
    final isLive = game.status == GameStatus.inProgress;

    return Card(
      color: const Color(0xFF16213e),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isLive ? Colors.red.withValues(alpha: 0.5) : Colors.transparent),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Team A
            Expanded(
              child: Text(game.teamAName,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
            // Score
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isLive
                    ? Colors.red.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  if (isLive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('LIVE',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  Text(
                    result != null ? result.finalScore : _formatTime(game.scheduledTime),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: result != null ? 22 : 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (result?.halfTimeScore != null)
                    Text('HZ: ${result!.halfTimeScore}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
                ],
              ),
            ),
            // Team B
            Expanded(
              child: Text(game.teamBName,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.left,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandingsTab() {
    if (_standings.isEmpty) {
      return Center(
        child: Text('Keine Tabellendaten verfügbar',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: const Color(0xFF16213e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Table(
            columnWidths: const {
              0: FixedColumnWidth(28),
              1: FlexColumnWidth(),
              2: FixedColumnWidth(28),
              3: FixedColumnWidth(28),
              4: FixedColumnWidth(28),
              5: FixedColumnWidth(28),
              6: FixedColumnWidth(48),
              7: FixedColumnWidth(36),
              8: FixedColumnWidth(36),
            },
            children: [
              TableRow(
                children: ['#', 'Team', 'Sp', 'S', 'U', 'N', 'Tore', 'Diff', 'Pkt']
                    .map((h) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(h,
                              style: TextStyle(
                                  color: Colors.amber.shade300,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center),
                        ))
                    .toList(),
              ),
              ..._standings.asMap().entries.map((e) {
                final i = e.key;
                final t = e.value;
                final textStyle = TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12);
                return TableRow(
                  decoration: BoxDecoration(
                    color: i.isEven ? Colors.white.withValues(alpha: 0.03) : Colors.transparent,
                  ),
                  children: [
                    _tableText('${i + 1}', textStyle),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(t.teamName,
                          style: textStyle.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    _tableText('${t.played}', textStyle),
                    _tableText('${t.won}', textStyle),
                    _tableText('${t.drawn}', textStyle),
                    _tableText('${t.lost}', textStyle),
                    _tableText('${t.goalsFor}:${t.goalsAgainst}', textStyle),
                    _tableText('${t.goalDifference}', textStyle),
                    _tableText('${t.points}',
                        textStyle.copyWith(fontWeight: FontWeight.bold, color: Colors.amber)),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tableText(String text, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(text, style: style, textAlign: TextAlign.center),
    );
  }

  Widget _buildTopScorersTab() {
    final scorers = _topScorers.where((s) => s.totalGoals > 0).toList();
    if (scorers.isEmpty) {
      return Center(
        child: Text('Keine Torschützendaten verfügbar',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: scorers.length.clamp(0, 20),
      itemBuilder: (context, index) {
        final s = scorers[index];
        return Card(
          color: const Color(0xFF16213e),
          margin: const EdgeInsets.only(bottom: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: index < 3
                  ? [Colors.amber, Colors.grey.shade400, Colors.brown.shade300][index]
                  : Colors.white.withValues(alpha: 0.1),
              child: Text('${index + 1}',
                  style: TextStyle(
                      color: index < 3 ? Colors.black87 : Colors.white70,
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            title: Text(s.playerName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(s.teamName,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${s.totalGoals}',
                    style: const TextStyle(
                        color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)),
                Text('Tore', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
