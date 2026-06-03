import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../services/player_service.dart';
import '../services/team_stats_service.dart';
import '../utils/app_colors.dart';
import '../utils/season_points.dart';
import '../screens/player_profile_screen.dart';

/// Premium "Profile" panel for a team.
class TeamProfileView extends StatefulWidget {
  final Team team;

  const TeamProfileView({super.key, required this.team});

  @override
  State<TeamProfileView> createState() => _TeamProfileViewState();
}

class _TeamProfileViewState extends State<TeamProfileView>
    with SingleTickerProviderStateMixin {
  final TeamStatsService _service = TeamStatsService();
  final PlayerService _playerService = PlayerService();
  bool _loading = true;
  TeamCareerStats? _stats;
  List<Player> _players = [];
  Object? _error;
  late final AnimationController _anim;
  late final Animation<double> _fade;

  // Team accent (primary/secondary) with RHD fallback.
  Color get _teamPrimary => widget.team.primaryColor != null
      ? Color(widget.team.primaryColor!)
      : AppColors.primaryColor;
  Color get _teamSecondary => widget.team.secondaryColor != null
      ? Color(widget.team.secondaryColor!)
      : AppColors.gradientColors[3];
  bool get _hasOwnColors =>
      widget.team.primaryColor != null || widget.team.secondaryColor != null;
  LinearGradient get _teamGradient => _hasOwnColors
      ? LinearGradient(colors: [_teamPrimary, _teamSecondary])
      : AppColors.primaryGradient;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _load();
  }

  @override
  void didUpdateWidget(covariant TeamProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.team.id != widget.team.id) _load();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ids = widget.team.rosterPlayerIds;
      final results = await Future.wait([
        _service.getTeamCareerStats(widget.team.id),
        if (ids.isNotEmpty)
          _playerService.getPlayersByIds(ids.take(20).toList())
        else
          Future.value(<Player>[]),
      ]);
      if (!mounted) return;
      final players = results[1] as List<Player>;
      players.sort((a, b) {
        final an = int.tryParse(a.jerseyNumber ?? '');
        final bn = int.tryParse(b.jerseyNumber ?? '');
        if (an == null && bn == null) {
          return '${a.lastName} ${a.firstName}'
              .toLowerCase()
              .compareTo('${b.lastName} ${b.firstName}'.toLowerCase());
        }
        if (an == null) return 1;
        if (bn == null) return -1;
        return an.compareTo(bn);
      });
      setState(() {
        _stats = results[0] as TeamCareerStats;
        _players = players;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0a0a0a),
      child: CustomScrollView(
        slivers: [
          _buildHeroSliver(),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                  child: Text('Fehler: $_error',
                      style: const TextStyle(color: Colors.white70))),
            )
          else
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fade,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_players.isNotEmpty) _buildKaderStrip(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 36, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(),
                          const SizedBox(height: 36),
                          if (_stats != null) _buildCareerStats(_stats!),
                          const SizedBox(height: 36),
                          if (_stats != null && _stats!.topScorers.isNotEmpty)
                            _buildTopScorers(_stats!),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────

  SliverToBoxAdapter _buildHeroSliver() {
    final t = widget.team;
    final hasLogo = t.logoUrl != null && t.logoUrl!.isNotEmpty;
    return SliverToBoxAdapter(
      child: Container(
        height: 380,
        color: const Color(0xFF0a0a0a),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Diagonal mood lighting in team's primary/secondary (RHD fallback)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _teamPrimary.withOpacity(0.65),
                      _teamPrimary.withOpacity(0.30),
                      _teamSecondary.withOpacity(0.10),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.3, 0.55, 0.85],
                  ),
                ),
              ),
            ),
            // Hex pattern overlay
            Positioned.fill(child: CustomPaint(painter: _HexPainter())),
            // Massive blurred logo as backdrop on right
            if (hasLogo)
              Positioned(
                right: -80,
                top: -40,
                bottom: -40,
                child: Opacity(
                  opacity: 0.12,
                  child: Image.network(t.logoUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const SizedBox.shrink()),
                ),
              ),
            // Vignette
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.7, -0.5),
                    radius: 1.4,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.35),
                      Colors.black.withOpacity(0.85),
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),
            // Bottom dark fade
            Positioned(
              left: 0, right: 0, bottom: 0, height: 200,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF0a0a0a).withOpacity(0.85),
                      const Color(0xFF0a0a0a),
                    ],
                  ),
                ),
              ),
            ),
            // Top accent line (team gradient or RHD fallback)
            Positioned(
              top: 0, left: 0, right: 0, height: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: _teamGradient),
              ),
            ),
            // Content
            SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top: TEAM tag + points medallion
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            border: Border.all(
                                color: _teamPrimary.withOpacity(0.6)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                  width: 6,
                                  height: 6,
                                  color: _teamPrimary),
                              const SizedBox(width: 8),
                              const Text(
                                'TEAM',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        _pointsMedallion(computeBest3Points(t.pointsHistory)),
                      ],
                    ),
                    const Spacer(),
                    // Logo + name
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _logoWidget(t, 96),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (t.clubName != null &&
                                  t.clubName!.isNotEmpty)
                                Text(
                                  t.clubName!.toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.55),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w300,
                                    letterSpacing: 4,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                t.name.toUpperCase(),
                                style: const TextStyle(
                                  fontFamily: 'MyriadPro',
                                  color: Colors.white,
                                  fontSize: 38,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.5,
                                  height: 0.95,
                                  shadows: [
                                    Shadow(
                                        color: Colors.black54,
                                        blurRadius: 12,
                                        offset: Offset(0, 3)),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                              Container(
                                height: 4,
                                width: 56,
                                decoration: BoxDecoration(
                                  gradient: _teamGradient,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _heroBadge(Icons.location_on_outlined,
                            '${t.city}, ${t.bundesland}'),
                        _heroBadge(Icons.people_outline,
                            '${t.rosterPlayerIds.length} Spieler'),
                        if (t.coachName != null && t.coachName!.isNotEmpty)
                          _heroBadge(Icons.sports_outlined, t.coachName!),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logoWidget(Team t, double size) {
    final hasLogo = t.logoUrl != null && t.logoUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: hasLogo
          ? Image.network(t.logoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initialsWidget(t, size))
          : _initialsWidget(t, size),
    );
  }

  Widget _initialsWidget(Team t, double size) {
    final words = t.name.split(' ');
    final letters = words.length >= 2
        ? '${words[0][0]}${words[1][0]}'.toUpperCase()
        : t.name.substring(0, t.name.length.clamp(0, 2)).toUpperCase();
    return Center(
      child: Text(letters,
          style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.35,
              fontWeight: FontWeight.w900)),
    );
  }

  Widget _heroBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _pointsMedallion(int points) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.18),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$points',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900),
          ),
          Text('Pkt.',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.75), fontSize: 11)),
        ],
      ),
    );
  }
  // ── Kader strip ──────────────────────────────────────────────────────

  Widget _buildKaderStrip() {
    return Container(
      color: const Color(0xFF0a0a0a),
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(
              children: [
                Expanded(child: _sectionHeader('Kader', light: true)),
                Text(
                  '${_players.length}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final p in _players)
                SizedBox(
                  width: 140,
                  height: 220,
                  child: _PlayerCard(
                    player: p,
                    teamPrimary: _teamPrimary,
                    teamGradient: _teamGradient,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Info row ─────────────────────────────────────────────────────────

  Widget _buildInfoRow() {
    final t = widget.team;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (t.coachName != null && t.coachName!.isNotEmpty)
          _infoChip(Icons.person_outline, 'Trainer', t.coachName!),
        if (t.bundesland.isNotEmpty)
          _infoChip(Icons.map_outlined, 'Bundesland', t.bundesland),
        _infoChip(Icons.sports_handball, 'Kadergröße',
            '${t.rosterPlayerIds.length} Spieler'),
      ],
    );
  }

  Widget _infoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: _teamPrimary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.4,
                  color: Colors.white.withOpacity(0.45),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Career stats grid ────────────────────────────────────────────────

  Widget _buildCareerStats(TeamCareerStats s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Karrierebilanz'),
        const SizedBox(height: 18),
        // Hero punkte block
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _teamPrimary.withOpacity(0.18),
                Colors.transparent,
              ],
            ),
            border: Border(
              left: BorderSide(color: _teamPrimary, width: 3),
            ),
          ),
          child: Row(
            children: [
              Text(
                '${s.points}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  height: 0.95,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'PUNKTE',
                    style: TextStyle(
                      color: _teamPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${s.gamesPlayed} Spiele',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 3-column big stats: W / D / L
        Row(
          children: [
            Expanded(child: _wdlBlock('S', s.wins, const Color(0xFF22c55e))),
            Container(width: 1, height: 64, color: Colors.white.withOpacity(0.06)),
            Expanded(child: _wdlBlock('U', s.draws, const Color(0xFFf59e0b))),
            Container(width: 1, height: 64, color: Colors.white.withOpacity(0.06)),
            Expanded(child: _wdlBlock('N', s.losses, _teamPrimary)),
          ],
        ),
        const SizedBox(height: 24),
        // Goals breakdown
        _statRowDark('Tore erzielt', '${s.goalsFor}'),
        _statRowDark('Tore kassiert', '${s.goalsAgainst}'),
        _statRowDark(
          'Tordifferenz',
          s.goalDifference >= 0
              ? '+${s.goalDifference}'
              : '${s.goalDifference}',
          highlight: s.goalDifference >= 0,
          isLast: true,
        ),
      ],
    );
  }

  Widget _wdlBlock(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRowDark(String label, String value,
      {bool highlight = false, bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(isLast ? 0 : 0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 11,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: highlight
                  ? const Color(0xFF22c55e)
                  : Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Top scorers ───────────────────────────────────────────────────────

  Widget _buildTopScorers(TeamCareerStats s) {
    final scorers = s.topScorers.where((p) => p.totalGoals > 0).take(10).toList();
    if (scorers.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Beste Torschützen'),
        const SizedBox(height: 14),
        ...scorers.asMap().entries.map((e) {
          final idx = e.key;
          final p = e.value;
          return _scorerTile(idx, p);
        }),
      ],
    );
  }

  Widget _scorerTile(int idx, dynamic p) {
    final rank = idx + 1;
    final isTop3 = rank <= 3;
    final rankColors = [
      const Color(0xFFFFD700), // gold
      const Color(0xFFC0C0C0), // silver
      const Color(0xFFCD7F32), // bronze
    ];
    final hasId = (p.playerId as String).isNotEmpty;
    return InkWell(
      onTap: hasId
          ? () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    PlayerProfileScreen(playerId: p.playerId as String),
              ))
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '$rank',
                style: TextStyle(
                  color: isTop3
                      ? rankColors[rank - 1]
                      : Colors.white.withOpacity(0.35),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                p.playerName as String,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: isTop3 ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${p.totalGoals}',
              style: TextStyle(
                color: _teamPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'TORE',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, {bool light = false}) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _hasOwnColors
                  ? [_teamPrimary, _teamSecondary]
                  : const [AppColors.primaryColor, AppColors.rhdGold],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.2,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withOpacity(0.08),
          ),
        ),
      ],
    );
  }
}

// ── Hex pattern painter ───────────────────────────────────────────────────────

class _HexPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const r = 28.0;
    const w = r * 1.732;
    const h = r * 1.5;
    for (double row = 0; row * h < size.height + h * 2; row++) {
      for (double col = 0; col * w < size.width + w * 2; col++) {
        final cx = col * w + (row.toInt().isOdd ? w / 2 : 0) - w;
        final cy = row * h - h;
        _drawHex(canvas, paint, cx, cy, r);
      }
    }
  }

  void _drawHex(Canvas canvas, Paint paint, double cx, double cy, double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = 3.14159 / 180 * (60 * i - 30);
      final x = cx + r * 0.866 * 2 / 1.732 * (i == 0 ? 1 : 1) * (i < 3 ? 1 : -1);
      // Simple approach: just use regular hexagon points
      final px = cx + r * _cos(60 * i + 30);
      final py = cy + r * _sin(60 * i + 30);
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  double _cos(double deg) =>
      _cosDeg(deg);
  double _sin(double deg) =>
      _sinDeg(deg);

  static double _cosDeg(double deg) {
    const pi = 3.14159265358979;
    return _cosRad(deg * pi / 180);
  }

  static double _sinDeg(double deg) {
    const pi = 3.14159265358979;
    return _sinRad(deg * pi / 180);
  }

  static double _cosRad(double rad) {
    // Taylor series approximation
    double x = rad;
    while (x > 3.14159) x -= 6.28318;
    while (x < -3.14159) x += 6.28318;
    return 1 - x * x / 2 + x * x * x * x / 24;
  }

  static double _sinRad(double rad) {
    double x = rad;
    while (x > 3.14159) x -= 6.28318;
    while (x < -3.14159) x += 6.28318;
    return x - x * x * x / 6 + x * x * x * x * x / 120;
  }

  @override
  bool shouldRepaint(_HexPainter old) => false;
}

// ── Premium player card used in kader strip ─────────────────────────────────────

class _PlayerCard extends StatelessWidget {
  final Player player;
  final Color teamPrimary;
  final LinearGradient teamGradient;
  const _PlayerCard({
    required this.player,
    required this.teamPrimary,
    required this.teamGradient,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        player.photoUrl != null && player.photoUrl!.isNotEmpty;
    final fullName = '${player.firstName} ${player.lastName}'.trim();
    final jerseyPart = (player.jerseyNumber != null && player.jerseyNumber!.toString().isNotEmpty)
        ? ', Trikotnummer ${player.jerseyNumber}'
        : '';
    return Semantics(
      button: true,
      label: 'Spieler $fullName$jerseyPart. Profil öffnen.',
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlayerProfileScreen(playerId: player.id),
          ),
        ),
        child: SizedBox(
          width: 140,
        child: Stack(
          children: [
            // Card body
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161616),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Subtle gradient tint (team primary or RHD fallback)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            teamPrimary.withOpacity(0.12),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    // Massive jersey number watermark
                    Positioned(
                      right: -10,
                      top: -20,
                      child: Text(
                        player.jerseyNumber ?? '',
                        style: TextStyle(
                          fontFamily: 'MyriadPro',
                          color: Colors.white.withOpacity(0.07),
                          fontSize: 130,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          letterSpacing: -8,
                        ),
                      ),
                    ),
                    // Player image filling card
                    Positioned.fill(
                      child: ShaderMask(
                        shaderCallback: (rect) => LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black,
                            Colors.black,
                          ],
                          stops: const [0.0, 0.25, 1.0],
                        ).createShader(rect),
                        blendMode: BlendMode.dstIn,
                        child: hasPhoto
                            ? Image.network(
                                player.photoUrl!,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                                errorBuilder: (_, __, ___) =>
                                    Image.asset(
                                  'assets/placeholder-player.png',
                                  fit: BoxFit.contain,
                                  alignment: Alignment.bottomCenter,
                                ),
                              )
                            : Image.asset(
                                'assets/placeholder-player.png',
                                fit: BoxFit.contain,
                                alignment: Alignment.bottomCenter,
                              ),
                      ),
                    ),
                    // Bottom dark fade
                    Positioned(
                      left: 0, right: 0, bottom: 0, height: 90,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              const Color(0xFF0d0d0d),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Name
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            player.firstName.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 9,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 1.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            player.lastName.toUpperCase(),
                            style: const TextStyle(
                              fontFamily: 'MyriadPro',
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              height: 1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Top accent strip
            Positioned(
              top: 0, left: 0, right: 0, height: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: teamGradient),
              ),
            ),
            // Jersey badge
            if (player.jerseyNumber != null)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: teamGradient,
                  ),
                  child: Text(
                    player.jerseyNumber!,
                    style: const TextStyle(
                      fontFamily: 'MyriadPro',
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }
}
