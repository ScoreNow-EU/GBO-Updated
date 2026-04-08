import 'package:flutter/material.dart';
import '../models/tournament.dart';
import '../services/tournament_stats_service.dart';
import '../services/disciplinary_service.dart';
import '../services/tournament_export_service.dart';

class TournamentStatsScreen extends StatefulWidget {
  final Tournament tournament;

  const TournamentStatsScreen({super.key, required this.tournament});

  @override
  State<TournamentStatsScreen> createState() => _TournamentStatsScreenState();
}

class _TournamentStatsScreenState extends State<TournamentStatsScreen>
    with SingleTickerProviderStateMixin {
  final TournamentStatsService _statsService = TournamentStatsService();
  final DisciplinaryService _disciplinaryService = DisciplinaryService();
  final TournamentExportService _exportService = TournamentExportService();
  late TabController _tabController;

  List<PlayerTournamentStats> _topScorers = [];
  List<DisciplinaryRecord> _disciplineRecords = [];
  List<TeamTournamentStats> _teamStats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final scorers = await _statsService.getTopScorers(widget.tournament.id);
      final discipline =
          await _disciplinaryService.getDisciplinaryRecords(widget.tournament.id);
      final teams =
          await _statsService.getOverallTeamStats(widget.tournament.id);
      if (!mounted) return;
      setState(() {
        _topScorers = scorers;
        _disciplineRecords = discipline;
        _teamStats = teams;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('âŒ Stats load error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleExport(String type) async {
    final id = widget.tournament.id;
    final name = widget.tournament.name.replaceAll(RegExp(r'[^\w\s-]'), '');
    try {
      switch (type) {
        case 'scorers':
          await _exportService.exportTopScorers(id, name);
          break;
        case 'table':
          await _exportService.exportTeamTable(id, name);
          break;
        case 'discipline':
          await _exportService.exportDiscipline(id, name);
          break;
        case 'games':
          await _exportService.exportGames(id, name);
          break;
        case 'full':
          await _exportService.exportFullReport(id, name);
          break;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export erfolgreich heruntergeladen')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export fehlgeschlagen: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Row(
            children: [
              const Icon(Icons.bar_chart, color: Colors.blue, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Turnierstatistiken',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: const Icon(Icons.download),
                tooltip: 'Exportieren',
                onSelected: (value) => _handleExport(value),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'scorers',
                    child: ListTile(
                      leading: Icon(Icons.emoji_events, size: 20),
                      title: Text('TorschÃ¼tzen (CSV)'),
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'table',
                    child: ListTile(
                      leading: Icon(Icons.table_chart, size: 20),
                      title: Text('Tabelle (CSV)'),
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'discipline',
                    child: ListTile(
                      leading: Icon(Icons.gavel, size: 20),
                      title: Text('Disziplin (CSV)'),
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'games',
                    child: ListTile(
                      leading: Icon(Icons.sports_handball, size: 20),
                      title: Text('Alle Spiele (CSV)'),
                      dense: true,
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'full',
                    child: ListTile(
                      leading: Icon(Icons.summarize, size: 20),
                      title: Text('Gesamtbericht (CSV)'),
                      dense: true,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: _loadStats,
                icon: const Icon(Icons.refresh),
                tooltip: 'Aktualisieren',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Tab Bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey[700],
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Spielerstatistiken'),
              Tab(text: 'Tabelle'),
              Tab(text: 'Disziplin'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Tab content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTopScorersTab(),
                    _buildTeamTableTab(),
                    _buildDisciplineTab(),
                  ],
                ),
        ),
      ],
    );
  }

  // â”€â”€ Player Stats Tab (consolidated) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildTopScorersTab() {
    if (_topScorers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outlined,
        message: 'Noch keine Spielerstatistiken vorhanden',
        subtitle: 'Statistiken werden automatisch aus den Spielberichten aggregiert.',
      );
    }

    // Show all players that have any stat (goals, cards, penalties)
    final players = _topScorers.where((s) =>
        s.totalGoals > 0 ||
        s.yellowCards > 0 ||
        s.twoMinuteSuspensions > 0 ||
        s.redCards > 0).toList();
    if (players.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outlined,
        message: 'Noch keine Spielerstatistiken',
      );
    }

    // Sort primarily by total goals desc, then by name
    players.sort((a, b) {
      final goalCmp = b.totalGoals.compareTo(a.totalGoals);
      if (goalCmp != 0) return goalCmp;
      return a.playerName.compareTo(b.playerName);
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
              columnSpacing: 16,
              columns: const [
                DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Spieler', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Team', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Tore', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                DataColumn(label: Text('7m', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                DataColumn(label: Text('Zeitstr.', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                DataColumn(label: Text('Gelb', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                DataColumn(label: Text('Rot', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              ],
              rows: List.generate(players.length, (index) {
                final p = players[index];
                final rank = index + 1;
                final isTop3 = rank <= 3;
                Color? rowColor;
                if (rank == 1) rowColor = const Color(0xFFFFF8E1);
                else if (rank == 2) rowColor = Colors.grey[50];
                else if (rank == 3) rowColor = const Color(0xFFFFF3E0);
                return DataRow(
                  color: isTop3 ? WidgetStateProperty.all(rowColor) : null,
                  cells: [
                    DataCell(Text(
                      '$rank',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: rank == 1 ? const Color(0xFFFFD700)
                             : rank == 2 ? const Color(0xFFC0C0C0)
                             : rank == 3 ? const Color(0xFFCD7F32)
                             : Colors.grey[600],
                      ),
                    )),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          p.playerName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: isTop3 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(
                          p.teamName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ),
                    ),
                    DataCell(Text(
                      '${p.totalGoals}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: p.totalGoals > 0 ? Colors.blue : Colors.grey,
                      ),
                    )),
                    DataCell(Text(
                      '${p.sevenMeterGoals}',
                      style: TextStyle(color: p.sevenMeterGoals > 0 ? Colors.teal : Colors.grey[400]),
                    )),
                    DataCell(Text(
                      '${p.twoMinuteSuspensions}',
                      style: TextStyle(
                        color: p.twoMinuteSuspensions > 0 ? Colors.orange[800] : Colors.grey[400],
                        fontWeight: p.twoMinuteSuspensions > 0 ? FontWeight.w600 : FontWeight.normal,
                      ),
                    )),
                    DataCell(Text(
                      '${p.yellowCards}',
                      style: TextStyle(
                        color: p.yellowCards > 0 ? Colors.amber[800] : Colors.grey[400],
                        fontWeight: p.yellowCards > 0 ? FontWeight.w600 : FontWeight.normal,
                      ),
                    )),
                    DataCell(Text(
                      '${p.redCards}',
                      style: TextStyle(
                        color: p.redCards > 0 ? Colors.red : Colors.grey[400],
                        fontWeight: p.redCards > 0 ? FontWeight.bold : FontWeight.normal,
                      ),
                    )),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  // â”€â”€ Team Table Tab â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildTeamTableTab() {
    if (_teamStats.isEmpty) {
      return _buildEmptyState(
        icon: Icons.table_chart_outlined,
        message: 'Noch keine Teamstatistiken',
        subtitle:
            'Statistiken werden aus abgeschlossenen Spielen berechnet.',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
              columnSpacing: 20,
              columns: const [
                DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Team', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Sp', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                DataColumn(label: Text('S', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                DataColumn(label: Text('U', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                DataColumn(label: Text('N', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                DataColumn(label: Text('Tore', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                DataColumn(label: Text('Diff', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                DataColumn(label: Text('Pkt', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              ],
              rows: List.generate(_teamStats.length, (index) {
                final team = _teamStats[index];
                final isTop = index == 0;
                return DataRow(
                  color: isTop
                      ? WidgetStateProperty.all(Colors.green[50])
                      : null,
                  cells: [
                    DataCell(Text(
                      '${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Text(
                          team.teamName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight:
                                isTop ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text('${team.played}')),
                    DataCell(Text('${team.won}',
                        style: const TextStyle(color: Colors.green))),
                    DataCell(Text('${team.drawn}')),
                    DataCell(Text('${team.lost}',
                        style: const TextStyle(color: Colors.red))),
                    DataCell(Text('${team.goalsFor}:${team.goalsAgainst}')),
                    DataCell(Text(
                      team.goalDifference >= 0
                          ? '+${team.goalDifference}'
                          : '${team.goalDifference}',
                      style: TextStyle(
                        color: team.goalDifference >= 0
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    )),
                    DataCell(Text(
                      '${team.points}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    )),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  // â”€â”€ Discipline Tab â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildDisciplineTab() {
    if (_disciplineRecords.isEmpty) {
      return _buildEmptyState(
        icon: Icons.gavel_outlined,
        message: 'Keine Strafen erfasst',
        subtitle: 'Karten und Zeitstrafen werden hier zusammengefasst.',
      );
    }

    // Count tournament-banned players (blue card only)
    final suspendedCount = _disciplineRecords.where((r) => r.isSuspended).length;
    // Count red cards (disqualified from their game, not next)
    final redCardCount = _disciplineRecords.where((r) => r.redCards > 0).length;

    return Column(
      children: [
        if (suspendedCount > 0)
          Container(
            margin: const EdgeInsets.fromLTRB(24, 8, 24, 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.block, color: Colors.blue[800]),
                const SizedBox(width: 12),
                Text(
                  '$suspendedCount Spieler Turniersperre (Blaue Karte)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ],
            ),
          ),
        if (redCardCount > 0)
          Container(
            margin: const EdgeInsets.fromLTRB(24, 4, 24, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red),
                const SizedBox(width: 12),
                Text(
                  '$redCardCount Spieler Rote Karte (nur akt. Spiel)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            itemCount: _disciplineRecords.length,
            itemBuilder: (context, index) {
              final record = _disciplineRecords[index];
              return _buildDisciplineCard(record);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDisciplineCard(DisciplinaryRecord record) {
    final bool hasTournamentBan = record.isSuspended; // Blaue Karte only
    final bool hasRedCard = record.redCards > 0;
    final bool tripleTwo = record.twoMinuteSuspensions >= 3;

    Color borderColor = Colors.transparent;
    Color iconBg = Colors.yellow[50]!;
    Color iconColor = Colors.amber[700]!;
    IconData iconData = Icons.info_outline;
    if (hasTournamentBan) {
      borderColor = Colors.blue[800]!;
      iconBg = Colors.blue[50]!;
      iconColor = Colors.blue[800]!;
      iconData = Icons.block;
    } else if (hasRedCard || tripleTwo) {
      borderColor = Colors.red[200]!;
      iconBg = Colors.red[50]!;
      iconColor = Colors.red;
      iconData = Icons.warning_amber_rounded;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: hasTournamentBan ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: hasTournamentBan || hasRedCard || tripleTwo
            ? BorderSide(color: borderColor, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Warning icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, color: iconColor, size: 22),
                ),
                const SizedBox(width: 16),
                // Player info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.playerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        record.teamName,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (hasTournamentBan) ...[
                      _buildStatusBadge('TURNIERSPERRE', Colors.blue[800]!),
                      if (record.suspensionReason != null) ...[
                        const SizedBox(height: 4),
                        Text(record.suspensionReason!,
                            style: TextStyle(fontSize: 10, color: Colors.blue[300])),
                      ],
                    ] else if (tripleTwo)
                      _buildStatusBadge('3x2min = ROT', Colors.red)
                    else if (hasRedCard)
                      _buildStatusBadge('Akt. Spiel', Colors.red[400]!),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Penalty chips
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (record.yellowCards > 0)
                  _buildPenaltyChip(Icons.square, Colors.amber,
                      '${record.yellowCards}x Gelb (Verwarnung)'),
                if (record.twoMinuteSuspensions > 0)
                  _buildPenaltyChip(
                    Icons.timer,
                    record.twoMinuteSuspensions >= 3 ? Colors.red : Colors.orange,
                    '${record.twoMinuteSuspensions}x 2min'
                        '${record.twoMinuteSuspensions >= 3 ? " â†’ Rote Karte" : ""}',
                  ),
                if (record.redCards > 0)
                  _buildPenaltyChip(Icons.square, Colors.red,
                      '${record.redCards}x Rot (nur akt. Spiel)'),
                if (record.blueCards > 0)
                  _buildPenaltyChip(Icons.square, Colors.blue[800]!,
                      '${record.blueCards}x Blau (Sperre + Bericht)'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPenaltyChip(IconData icon, Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€ Empty State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    String? subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[400],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
