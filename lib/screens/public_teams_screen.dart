import 'package:flutter/material.dart';
import '../models/team.dart';
import '../services/team_service.dart';
import '../utils/app_colors.dart';
import '../utils/season_points.dart';
import 'team_detail_screen.dart';

/// Public-facing teams browser. Shown as a top-level nav item.
/// Designed to look premium: gradient hero, rich cards, search + filter.
class PublicTeamsScreen extends StatefulWidget {
  const PublicTeamsScreen({super.key});

  @override
  State<PublicTeamsScreen> createState() => _PublicTeamsScreenState();
}

class _PublicTeamsScreenState extends State<PublicTeamsScreen>
    with SingleTickerProviderStateMixin {
  final TeamService _teamService = TeamService();
  final TextEditingController _search = TextEditingController();

  List<Team> _all = [];
  List<Team> _filtered = [];
  bool _loading = true;
  String _selectedBundesland = 'Alle';
  late final AnimationController _heroAnim;
  late final Animation<double> _heroFade;

  @override
  void initState() {
    super.initState();
    _heroAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _heroFade = CurvedAnimation(parent: _heroAnim, curve: Curves.easeOut);
    _teamService.getTeams().listen((teams) {
      if (!mounted) return;
      final sorted = List<Team>.from(teams)
        ..sort((a, b) => computeBest3Points(b.pointsHistory)
            .compareTo(computeBest3Points(a.pointsHistory)));
      setState(() {
        _all = sorted;
        _loading = false;
        _applyFilter();
      });
    });
    _search.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _heroAnim.dispose();
    _search.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final q = _search.text.trim().toLowerCase();
    setState(() {
      _filtered = _all.where((t) {
        final matchesSearch = q.isEmpty ||
            t.name.toLowerCase().contains(q) ||
            t.city.toLowerCase().contains(q) ||
            (t.clubName?.toLowerCase().contains(q) ?? false);
        final matchesBL = _selectedBundesland == 'Alle' ||
            t.bundesland == _selectedBundesland;
        return matchesSearch && matchesBL;
      }).toList();
    });
  }

  List<String> get _bundeslaender {
    final set = <String>{'Alle'};
    for (final t in _all) {
      if (t.bundesland.isNotEmpty) set.add(t.bundesland);
    }
    final list = set.toList()..sort();
    // Keep 'Alle' first
    list.remove('Alle');
    return ['Alle', ...list];
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0a0a0a),
      child: CustomScrollView(
        slivers: [
          _buildHero(),
          _buildSearchBar(),
          _buildBundeslandFilter(),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_filtered.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  'Keine Teams gefunden',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
              ),
            )
          else
            _buildGrid(),
        ],
      ),
    );
  }

  // ── Hero ─────────────────────────────────────────────────────────────

  SliverToBoxAdapter _buildHero() {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _heroFade,
        child: Container(
          height: 280,
          color: const Color(0xFF0a0a0a),
          child: Stack(
            children: [
              // Red-gold gradient upper area
              Positioned(
                top: 0, left: 0, right: 0, height: 120,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                  ),
                ),
              ),
              // Pattern overlay
              Positioned(
                top: 0, left: 0, right: 0, height: 120,
                child: CustomPaint(painter: _DiamondPatternPainter()),
              ),
              // Red accent line
              Positioned(
                top: 0, left: 0, right: 0, height: 3,
                child: const DecoratedBox(
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient),
                ),
              ),
              // Fade from gradient to dark
              Positioned(
                top: 60, left: 0, right: 0, height: 60,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, const Color(0xFF111111)],
                    ),
                  ),
                ),
              ),
              // Text content
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const SizedBox(height: 6),
                    const Text(
                      'MANNSCHAFTEN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w300,
                        color: Color(0x88FFFFFF),
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Teams',
                      style: TextStyle(
                        fontFamily: 'MyriadPro',
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -3,
                        height: 0.9,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 4,
                      width: 56,
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_all.length} TEAMS · IM WETTBEWERB',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Search ────────────────────────────────────────────────────────────

  SliverToBoxAdapter _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: TextField(
          controller: _search,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          cursorColor: AppColors.primaryColor,
          decoration: InputDecoration(
            hintText: 'TEAM, STADT ODER VEREIN SUCHEN',
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(Icons.search,
                color: Colors.white.withOpacity(0.5), size: 20),
            suffixIcon: _search.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear,
                        color: Colors.white.withOpacity(0.5)),
                    tooltip: 'Suche zurücksetzen',
                    onPressed: () {
                      _search.clear();
                      _applyFilter();
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(2),
              borderSide:
                  BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(2),
              borderSide:
                  BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(2),
              borderSide: BorderSide(
                  color: AppColors.primaryColor.withOpacity(0.6)),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  // ── Bundesland filter chips ──────────────────────────────────────────

  SliverToBoxAdapter _buildBundeslandFilter() {
    final bls = _bundeslaender;
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 56,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          itemCount: bls.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final bl = bls[i];
            final selected = bl == _selectedBundesland;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedBundesland = bl);
                _applyFilter();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryColor
                      : Colors.white.withOpacity(0.04),
                  border: Border.all(
                    color: selected
                        ? AppColors.primaryColor
                        : Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Center(
                  child: Text(
                    bl.toUpperCase(),
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : Colors.white.withOpacity(0.7),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Grid ─────────────────────────────────────────────────────────────

  SliverPadding _buildGrid() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 60),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, i) => _TeamCard(
            team: _filtered[i],
            rank: _all.indexOf(_filtered[i]) + 1,
          ),
          childCount: _filtered.length,
        ),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 320,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.82,
        ),
      ),
    );
  }
}

// ── Team card ────────────────────────────────────────────────────────────────

class _TeamCard extends StatelessWidget {
  final Team team;
  final int rank;

  const _TeamCard({required this.team, required this.rank});

  @override
  Widget build(BuildContext context) {
    final hasLogo = team.logoUrl != null && team.logoUrl!.isNotEmpty;
    final teamPrimary = team.primaryColor != null
        ? Color(team.primaryColor!)
        : AppColors.gradientColors[0];
    final teamSecondary = team.secondaryColor != null
        ? Color(team.secondaryColor!)
        : AppColors.gradientColors[3];
    final hasOwnColors =
        team.primaryColor != null || team.secondaryColor != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                TeamDetailScreen(teamId: team.id, subSection: 'profile'),
          ),
        ),
        child: Semantics(
          button: true,
          label: 'Team ${team.name}, Rang $rank. Profil öffnen.',
          container: true,
          child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Gradient overlay — top left to bottom right
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        teamPrimary.withOpacity(0.18),
                        teamSecondary.withOpacity(0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Blurred logo as full-card background
              if (hasLogo)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.06,
                    child: Image.network(
                      team.logoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              // Main content column
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top: rank badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: rank == 1
                                ? const Color(0xFFFFD700).withOpacity(0.2)
                                : Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: rank == 1
                                  ? const Color(0xFFFFD700).withOpacity(0.5)
                                  : Colors.white.withOpacity(0.15),
                            ),
                          ),
                          child: Text(
                            '#$rank',
                            style: TextStyle(
                              color: rank == 1
                                  ? const Color(0xFFFFD700)
                                  : Colors.white60,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Points badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: hasOwnColors
                                  ? [teamPrimary, teamSecondary]
                                  : const [
                                      AppColors.primaryColor,
                                      AppColors.primaryColor,
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${computeBest3Points(team.pointsHistory)} Pkt.',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Center: logo
                    Expanded(
                      child: Center(
                        child: hasLogo
                            ? Image.network(
                                team.logoUrl!,
                                width: 72,
                                height: 72,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => _initials(),
                              )
                            : _initials(),
                      ),
                    ),
                    // Bottom: team info
                    if (team.clubName != null && team.clubName!.isNotEmpty)
                      Text(
                        team.clubName!.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 9,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 1.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      team.name,
                      style: const TextStyle(
                        fontFamily: 'MyriadPro',
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        letterSpacing: -0.5,
                        height: 1.05,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 11,
                            color: Colors.white.withOpacity(0.45)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            '${team.city}, ${team.bundesland}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Red top-accent line
              Positioned(
                top: 0, left: 0, right: 0, height: 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: hasOwnColors
                        ? LinearGradient(
                            colors: [teamPrimary, teamSecondary])
                        : AppColors.primaryGradient,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _initials() {
    final words = team.name.split(' ');
    final letters = words.length >= 2
        ? '${words[0][0]}${words[1][0]}'.toUpperCase()
        : team.name.substring(0, team.name.length.clamp(0, 2)).toUpperCase();
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Center(
        child: Text(
          letters,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
      ),
    );
  }
}

// ── Diamond pattern painter ───────────────────────────────────────────────────

class _DiamondPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const spacing = 40.0;
    for (double x = -spacing; x < size.width + spacing; x += spacing) {
      for (double y = -spacing; y < size.height + spacing; y += spacing) {
        final path = Path()
          ..moveTo(x, y - spacing / 2)
          ..lineTo(x + spacing / 2, y)
          ..lineTo(x, y + spacing / 2)
          ..lineTo(x - spacing / 2, y)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DiamondPatternPainter old) => false;
}
