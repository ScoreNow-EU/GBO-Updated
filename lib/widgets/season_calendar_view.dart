import 'package:flutter/material.dart';
import '../models/game.dart';
import '../models/season.dart';
import '../models/tournament.dart';
import '../services/game_service.dart';
import '../services/season_service.dart';
import '../services/tournament_service.dart';
import '../utils/app_colors.dart';

/// Aggregated calendar of all games across the tournaments of a season.
///
/// - Shows a season selector (defaults to active season).
/// - Optional [teamId] filter restricts rows to games involving that team.
/// - Groups games by calendar date.
class SeasonCalendarView extends StatefulWidget {
  /// When provided, only games where this team plays are shown.
  final String? teamId;

  const SeasonCalendarView({super.key, this.teamId});

  @override
  State<SeasonCalendarView> createState() => _SeasonCalendarViewState();
}

class _CalendarRow {
  final Game game;
  final Tournament tournament;
  _CalendarRow(this.game, this.tournament);
}

class _SeasonCalendarViewState extends State<SeasonCalendarView> {
  final SeasonService _seasonService = SeasonService();
  final TournamentService _tournamentService = TournamentService();
  final GameService _gameService = GameService();

  bool _isLoading = true;
  String? _error;

  List<Season> _seasons = [];
  Season? _selectedSeason;
  List<_CalendarRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final seasons = await _seasonService.getAllSeasons();
      seasons.sort((a, b) => b.startDate.compareTo(a.startDate));
      Season? active;
      try {
        active = seasons.firstWhere((s) => s.isActive);
      } catch (_) {
        active = seasons.isNotEmpty ? seasons.first : null;
      }
      if (!mounted) return;
      setState(() {
        _seasons = seasons;
        _selectedSeason = active;
      });
      if (active != null) {
        await _loadSeason(active);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Saisons konnten nicht geladen werden: $e';
      });
    }
  }

  Future<void> _loadSeason(Season season) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final List<_CalendarRow> rows = [];
      for (final tid in season.spieltageIds) {
        final tournament = await _tournamentService.getTournamentById(tid);
        if (tournament == null) continue;
        final games = await _gameService.getGamesForTournament(tid).first;
        for (final g in games) {
          if (widget.teamId != null &&
              g.teamAId != widget.teamId &&
              g.teamBId != widget.teamId) {
            continue;
          }
          rows.add(_CalendarRow(g, tournament));
        }
      }
      rows.sort((a, b) {
        final at = a.game.scheduledTime;
        final bt = b.game.scheduledTime;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return at.compareTo(bt);
      });
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Spiele konnten nicht geladen werden: $e';
      });
    }
  }

  String _courtName(Tournament t, String? courtId) {
    if (courtId == null) return '—';
    try {
      return t.courts.firstWhere((c) => c.id == courtId).name;
    } catch (_) {
      return courtId;
    }
  }

  Map<DateTime, List<_CalendarRow>> _groupByDay(List<_CalendarRow> rows) {
    final Map<DateTime, List<_CalendarRow>> byDay = {};
    for (final r in rows) {
      final t = r.game.scheduledTime;
      final key = t == null
          ? DateTime(1970)
          : DateTime(t.year, t.month, t.day);
      byDay.putIfAbsent(key, () => []).add(r);
    }
    return byDay;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const Divider(height: 1),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          const Icon(Icons.calendar_month, color: AppColors.primaryColor),
          const SizedBox(width: 10),
          Text(
            widget.teamId == null ? 'Saisonkalender' : 'Kalender',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (_seasons.isNotEmpty)
            DropdownButton<String>(
              value: _selectedSeason?.id,
              underline: const SizedBox.shrink(),
              items: _seasons
                  .map((s) => DropdownMenuItem(
                        value: s.id,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(s.name),
                            if (s.isActive) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.circle,
                                  size: 8, color: AppColors.primaryColor),
                            ],
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (id) {
                if (id == null) return;
                final s = _seasons.firstWhere((season) => season.id == id);
                setState(() => _selectedSeason = s);
                _loadSeason(s);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_selectedSeason == null) {
      return const Center(child: Text('Keine Saison gefunden.'));
    }
    if (_rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            widget.teamId == null
                ? 'Keine Spieltage in dieser Saison.'
                : 'Keine Spiele für dieses Team in dieser Saison.',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final byDay = _groupByDay(_rows);
    final dayKeys = byDay.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      itemCount: dayKeys.length,
      itemBuilder: (context, i) {
        final day = dayKeys[i];
        final games = byDay[day]!;
        return _buildDaySection(day, games);
      },
    );
  }

  Widget _buildDaySection(DateTime day, List<_CalendarRow> games) {
    final isUnscheduled = day.year == 1970;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text(
              isUnscheduled ? 'Ohne Datum' : _formatDayHeader(day),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 0.4,
              ),
            ),
          ),
          ...games.map(_buildRow),
        ],
      ),
    );
  }

  Widget _buildRow(_CalendarRow r) {
    final g = r.game;
    final t = r.tournament;
    final time = g.scheduledTime != null
        ? '${g.scheduledTime!.hour.toString().padLeft(2, '0')}:'
            '${g.scheduledTime!.minute.toString().padLeft(2, '0')}'
        : '—';
    final court = _courtName(t, g.courtId);
    final score = g.result != null ? g.result!.finalScore : null;
    final isHighlighted = widget.teamId != null &&
        (g.teamAId == widget.teamId || g.teamBId == widget.teamId);

    final semanticsLabel = StringBuffer();
    semanticsLabel.write(time == '—' ? 'Ohne Uhrzeit' : 'Uhrzeit $time');
    semanticsLabel.write(', ${g.teamAName} gegen ${g.teamBName}');
    semanticsLabel.write(', Turnier ${t.name}');
    if (court != '—') semanticsLabel.write(', Feld $court');
    if (score != null) {
      semanticsLabel.write(', Endstand $score');
    } else {
      semanticsLabel.write(', ${_statusLabel(g.status)}');
    }

    return Semantics(
      label: semanticsLabel.toString(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Text(
                time,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            Container(
              width: 4,
              height: 32,
              color: g.status == GameStatus.completed
                  ? Colors.grey
                  : (g.status == GameStatus.inProgress
                      ? AppColors.primaryColor
                      : AppColors.primaryColorAlt),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(
                '${g.teamAName}  vs  ${g.teamBName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight:
                      isHighlighted ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                t.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ),
            SizedBox(
              width: 80,
              child: Text(
                court,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ),
            SizedBox(
              width: 60,
              child: Text(
                score ?? _statusLabel(g.status),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: score != null
                      ? Colors.black87
                      : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(GameStatus s) {
    switch (s) {
      case GameStatus.scheduled:
        return 'geplant';
      case GameStatus.inProgress:
        return 'live';
      case GameStatus.completed:
        return 'fertig';
      case GameStatus.cancelled:
        return 'abges.';
      default:
        return '';
    }
  }

  String _formatDayHeader(DateTime d) {
    const days = ['Mo.', 'Di.', 'Mi.', 'Do.', 'Fr.', 'Sa.', 'So.'];
    const months = [
      'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
      'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez',
    ];
    return '${days[d.weekday - 1]} ${d.day}. ${months[d.month - 1]} ${d.year}';
  }
}
