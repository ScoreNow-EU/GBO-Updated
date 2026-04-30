import 'package:flutter/material.dart';
import '../models/season.dart';
import '../services/season_stats_service.dart';
import '../services/tournament_stats_service.dart';
import 'player_profile_screen.dart';
import 'team_detail_screen.dart';

/// Cross-tournament statistics for a single season:
/// top scorers, team standings, discipline.
class SeasonStatsScreen extends StatefulWidget {
  final Season season;

  const SeasonStatsScreen({super.key, required this.season});

  @override
  State<SeasonStatsScreen> createState() => _SeasonStatsScreenState();
}

class _SeasonStatsScreenState extends State<SeasonStatsScreen>
    with SingleTickerProviderStateMixin {
  final SeasonStatsService _service = SeasonStatsService();
  late TabController _tabController;

  bool _isLoading = true;
  List<PlayerTournamentStats> _topScorers = [];
  List<TeamTournamentStats> _teamStandings = [];
  List<PlayerTournamentStats> _discipline = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final scorers = await _service.getSeasonTopScorers(widget.season.id);
      final teams = await _service.getSeasonTeamStandings(widget.season.id);
      final discipline = await _service.getSeasonDiscipline(widget.season.id);
      if (!mounted) return;
      setState(() {
        _topScorers = scorers;
        _teamStandings = teams;
        _discipline = discipline;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Laden der Saisonstatistik: $e')),
      );
    }
  }

  void _openPlayerProfile(String playerId) {
    if (playerId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerProfileScreen(playerId: playerId),
      ),
    );
  }

  void _openTeamProfile(String teamId) {
    if (teamId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TeamDetailScreen(teamId: teamId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Saisonstatistik – ${widget.season.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Aktualisieren',
            onPressed: () {
              _service.invalidateCache(widget.season.id);
              _load();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Torschützen'),
            Tab(text: 'Tabelle'),
            Tab(text: 'Disziplin'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildScorersTab(),
                _buildTeamTab(),
                _buildDisciplineTab(),
              ],
            ),
    );
  }

  Widget _buildScorersTab() {
    final players = _topScorers.where((s) => s.totalGoals > 0).toList();
    if (players.isEmpty) {
      return const _EmptyState(
        icon: Icons.emoji_events_outlined,
        message: 'Keine Tore in dieser Saison erfasst',
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('#')),
              DataColumn(label: Text('Spieler')),
              DataColumn(label: Text('Team')),
              DataColumn(label: Text('Sp'), numeric: true),
              DataColumn(label: Text('Tore'), numeric: true),
              DataColumn(label: Text('7m'), numeric: true),
            ],
            rows: List.generate(players.length, (i) {
              final p = players[i];
              return DataRow(cells: [
                DataCell(Text('${i + 1}')),
                DataCell(
                  InkWell(
                    onTap: () => _openPlayerProfile(p.playerId),
                    child: Text(
                      p.playerName,
                      style: const TextStyle(
                        decoration: TextDecoration.underline,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),
                DataCell(Text(p.teamName)),
                DataCell(Text('${p.gamesPlayed}')),
                DataCell(Text(
                  '${p.totalGoals}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                )),
                DataCell(Text('${p.sevenMeterGoals}')),
              ]);
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamTab() {
    if (_teamStandings.isEmpty) {
      return const _EmptyState(
        icon: Icons.table_chart_outlined,
        message: 'Keine abgeschlossenen Spiele in dieser Saison',
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('#')),
              DataColumn(label: Text('Team')),
              DataColumn(label: Text('Sp'), numeric: true),
              DataColumn(label: Text('S'), numeric: true),
              DataColumn(label: Text('U'), numeric: true),
              DataColumn(label: Text('N'), numeric: true),
              DataColumn(label: Text('Tore')),
              DataColumn(label: Text('Diff'), numeric: true),
              DataColumn(label: Text('Pkt'), numeric: true),
            ],
            rows: List.generate(_teamStandings.length, (i) {
              final t = _teamStandings[i];
              return DataRow(cells: [
                DataCell(Text('${i + 1}')),
                DataCell(
                  InkWell(
                    onTap: () => _openTeamProfile(t.teamId),
                    child: Text(
                      t.teamName,
                      style: const TextStyle(
                        decoration: TextDecoration.underline,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),
                DataCell(Text('${t.played}')),
                DataCell(Text('${t.won}')),
                DataCell(Text('${t.drawn}')),
                DataCell(Text('${t.lost}')),
                DataCell(Text('${t.goalsFor}:${t.goalsAgainst}')),
                DataCell(Text(t.goalDifference >= 0
                    ? '+${t.goalDifference}'
                    : '${t.goalDifference}')),
                DataCell(Text(
                  '${t.points}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                )),
              ]);
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildDisciplineTab() {
    if (_discipline.isEmpty) {
      return const _EmptyState(
        icon: Icons.gavel_outlined,
        message: 'Keine Strafen in dieser Saison',
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Spieler')),
              DataColumn(label: Text('Team')),
              DataColumn(label: Text('Gelb'), numeric: true),
              DataColumn(label: Text('2\'', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text('Rot'), numeric: true),
              DataColumn(label: Text('Blau'), numeric: true),
            ],
            rows: _discipline.map((p) {
              return DataRow(cells: [
                DataCell(
                  InkWell(
                    onTap: () => _openPlayerProfile(p.playerId),
                    child: Text(
                      p.playerName,
                      style: const TextStyle(
                        decoration: TextDecoration.underline,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),
                DataCell(Text(p.teamName)),
                DataCell(Text('${p.yellowCards}')),
                DataCell(Text('${p.twoMinuteSuspensions}')),
                DataCell(Text('${p.redCards}')),
                DataCell(Text('${p.blueCards}')),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: Colors.grey),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
