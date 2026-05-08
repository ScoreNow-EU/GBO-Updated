import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/suspension.dart';
import '../models/team.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/player_service.dart';
import '../services/player_stats_service.dart';
import '../services/tournament_stats_service.dart';
import '../utils/app_colors.dart';
import 'team_detail_screen.dart';

/// Read-only profile view for any player. Photo upload is restricted to
/// admins / team managers.
class PlayerProfileScreen extends StatefulWidget {
  final String playerId;

  const PlayerProfileScreen({super.key, required this.playerId});

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  final PlayerService _playerService = PlayerService();
  final PlayerStatsService _statsService = PlayerStatsService();
  final AuthService _authService = AuthService();

  bool _isLoading = true;
  bool _isUploading = false;
  Player? _player;
  Team? _team;
  PlayerTournamentStats? _stats;
  List<Suspension> _suspensions = [];
  bool _canEdit = false;

  // ── Team-color theming (with RHD fallback) ─────────────────────────
  Color get _teamPrimary => _team?.primaryColor != null
      ? Color(_team!.primaryColor!)
      : _teamPrimary;
  Color get _teamSecondary => _team?.secondaryColor != null
      ? Color(_team!.secondaryColor!)
      : AppColors.gradientColors[3];
  bool get _hasOwnColors =>
      _team?.primaryColor != null || _team?.secondaryColor != null;
  LinearGradient get _teamGradient => _hasOwnColors
      ? LinearGradient(colors: [_teamPrimary, _teamSecondary])
      : AppColors.primaryGradient;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _playerService.getPlayerById(widget.playerId),
        _statsService.findCurrentTeam(widget.playerId),
        _statsService.getCareerStats(widget.playerId),
        _statsService.getSuspensions(widget.playerId),
        _authService.getCurrentUser(),
      ]);
      final player = results[0] as Player?;
      final team = results[1] as Team?;
      final stats = results[2] as PlayerTournamentStats?;
      final suspensions = results[3] as List<Suspension>;
      final user = results[4] as User?;

      final canEdit = user != null &&
          (user.roles.contains(UserRole.admin) ||
              user.roles.contains(UserRole.teamManager));

      if (!mounted) return;
      setState(() {
        _player = player;
        _team = team;
        _stats = stats;
        _suspensions = suspensions;
        _canEdit = canEdit;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Laden: $e')),
      );
    }
  }

  Future<void> _changePhoto() async {
    if (_player == null) return;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;

      // Client-side size guard: 5 MB.
      if (file.bytes!.lengthInBytes > 5 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bild zu groß (max. 5 MB).')),
        );
        return;
      }

      setState(() => _isUploading = true);
      await _playerService.uploadPlayerPhoto(
        playerId: _player!.id,
        bytes: file.bytes!,
        extension: (file.extension ?? 'jpg').toLowerCase(),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload fehlgeschlagen: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _uploadSecondary() async {
    if (_player == null) return;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;
      if (file.bytes!.lengthInBytes > 5 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bild zu groß (max. 5 MB).')),
        );
        return;
      }
      setState(() => _isUploading = true);
      await _playerService.uploadPlayerSecondaryPhoto(
        playerId: _player!.id,
        bytes: file.bytes!,
        extension: (file.extension ?? 'jpg').toLowerCase(),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload fehlgeschlagen: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _removeSecondary() async {
    if (_player == null) return;
    try {
      await _playerService.removePlayerSecondaryPhoto(
        _player!.id,
        currentUrl: _player!.secondaryPhotoUrl,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Entfernen fehlgeschlagen: $e')),
      );
    }
  }

  Future<void> _openSecondaryDialog() async {
    if (_player == null) return;
    double opacity = _player!.secondaryPhotoOpacity;
    final hasImage = (_player!.secondaryPhotoUrl ?? '').isNotEmpty;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a1a),
          title: const Text('Zweitbild',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                hasImage
                    ? 'Aktuelles Zweitbild ersetzen oder Transparenz anpassen.'
                    : 'Lade ein Bild hoch, das anstelle des Teamlogos erscheint.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              if (hasImage) ...[
                const Text('Transparenz',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                Slider(
                  value: opacity,
                  min: 0.05,
                  max: 1.0,
                  divisions: 19,
                  label: '${(opacity * 100).round()}%',
                  activeColor: _teamPrimary,
                  onChanged: (v) => setLocal(() => opacity = v),
                ),
              ],
            ],
          ),
          actions: [
            if (hasImage)
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _removeSecondary();
                },
                child: const Text('Entfernen',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _uploadSecondary();
              },
              child: Text(hasImage ? 'Ersetzen' : 'Hochladen',
                  style: const TextStyle(color: Colors.white)),
            ),
            if (hasImage)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _teamPrimary),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _playerService.updatePlayerSecondaryOpacity(
                      _player!.id, opacity);
                  await _load();
                },
                child: const Text('Speichern'),
              )
            else
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Abbrechen',
                    style: TextStyle(color: Colors.white54)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_player == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Spielerprofil')),
        body: const Center(child: Text('Spieler nicht gefunden')),
      );
    }
    final p = _player!;
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0a),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.45),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: const BackButton(color: Colors.white),
        ),
        actions: [
          if (_canEdit)
            Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: IconButton(
                onPressed: _isUploading ? null : _openSecondaryDialog,
                icon: const Icon(Icons.image_outlined,
                    color: Colors.white, size: 20),
                tooltip: 'Zweitbild',
              ),
            ),
          if (_canEdit)
            Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: IconButton(
                onPressed: _isUploading ? null : _changePhoto,
                icon: _isUploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.camera_alt_outlined,
                        color: Colors.white, size: 20),
                tooltip: 'Foto ändern',
              ),
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHero(p)),
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFF0a0a0a),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuickStatsBar(),
                  if (p.classification != null) _buildClassificationBanner(p),
                  _buildInfoSection(p),
                  _buildStatsSection(),
                  _buildSuspensionsSection(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Cinematic full-bleed hero ─────────────────────────────────────────

  Widget _buildHero(Player p) {
    final hasPhoto = p.photoUrl != null && p.photoUrl!.isNotEmpty;
    final hasSecondary =
        p.secondaryPhotoUrl != null && p.secondaryPhotoUrl!.isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        // Massive name — scales with width but capped.
        final lastNameSize = (w / 6.5).clamp(72.0, 160.0).toDouble();
        // Player image: fixed 600 x 400 box. The natural image is cropped
        // (cover, top-aligned) — never shrunk — so a tall portrait shows only
        // its top portion, and the lower edge fades into the name.
        const imgWidth = 600.0;
        const imgHeight = 400.0;
        // Bottom block reserves room for the name + accent.
        final bottomBlockHeight = lastNameSize + 160;
        // Image overlaps slightly into the name area for the "coming out of name" feel.
        final totalHeight = imgHeight + bottomBlockHeight - lastNameSize * 0.25;

        return SizedBox(
          height: totalHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Base black
              const ColoredBox(color: Color(0xFF0a0a0a)),
              // Diagonal mood lighting from top-left (team or RHD fallback)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _teamPrimary.withOpacity(0.55),
                        _teamPrimary.withOpacity(0.25),
                        _teamSecondary.withOpacity(0.10),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.25, 0.5, 0.85],
                    ),
                  ),
                ),
              ),
              // Diagonal slash overlay (HBL signature)
              Positioned.fill(child: CustomPaint(painter: _DiagonalSlashPainter())),
              // Vignette for depth
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.6, -0.4),
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
              // ── Player image (top-aligned, capped at 400 tall, fades into name) ──
              Positioned(
                top: 8,
                left: 24,
                width: imgWidth,
                height: imgHeight,
                child: ShaderMask(
                  shaderCallback: (rect) => LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: const [
                      Colors.black,
                      Colors.black,
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.65, 1.0],
                  ).createShader(rect),
                  blendMode: BlendMode.dstIn,
                  child: hasPhoto
                      ? Image.network(
                          p.photoUrl!,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/placeholder-player.png',
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                          ),
                        )
                      : Image.asset(
                          'assets/placeholder-player.png',
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        ),
                ),
              ),
              // Faded team logo watermark — huge, very low opacity, gradient fade.
              if (!hasSecondary && _team != null && _team!.logoUrl != null && _team!.logoUrl!.isNotEmpty)
                Positioned(
                  right: -120,
                  top: -60,
                  width: 760,
                  height: 760,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.09,
                      child: ShaderMask(
                        shaderCallback: (rect) => RadialGradient(
                          center: Alignment.center,
                          radius: 0.7,
                          colors: [
                            Colors.black,
                            Colors.black.withOpacity(0.6),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ).createShader(rect),
                        blendMode: BlendMode.dstIn,
                        child: Image.network(
                          _team!.logoUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),
              // Secondary full-height accent image (replaces team logo).
              if (hasSecondary)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: p.secondaryPhotoOpacity.clamp(0.0, 1.0),
                      child: ShaderMask(
                        shaderCallback: (rect) => const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.transparent,
                            Colors.black,
                            Colors.black,
                          ],
                          stops: [0.0, 0.45, 1.0],
                        ).createShader(rect),
                        blendMode: BlendMode.dstIn,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Image.network(
                            p.secondaryPhotoUrl!,
                            fit: BoxFit.fitHeight,
                            alignment: Alignment.centerRight,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // Massive jersey number / initials watermark — high up, more visible.
              Positioned(
                right: -30,
                top: -lastNameSize * 0.25,
                child: IgnorePointer(
                  child: Text(
                    (p.jerseyNumber != null && p.jerseyNumber!.trim().isNotEmpty)
                        ? p.jerseyNumber!
                        : _playerInitials(p),
                    style: TextStyle(
                      fontFamily: 'MyriadPro',
                      fontSize: lastNameSize * 2.6,
                      fontWeight: FontWeight.w900,
                      color: Colors.white.withOpacity(0.16),
                      height: 0.85,
                      letterSpacing: -12,
                    ),
                  ),
                ),
              ),
              // Bottom dark fade so name reads cleanly over the image
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: bottomBlockHeight + 80,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF0a0a0a).withOpacity(0.95),
                        const Color(0xFF0a0a0a),
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
              ),
              // Top red gradient line
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: _teamGradient),
                ),
              ),
              // Team chip top-left — more opaque, moved upward
              if (_team != null)
                Positioned(
                  top: 24,
                  left: 24,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => TeamDetailScreen(teamId: _team!.id),
                    )),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.85),
                        border: Border.all(
                            color: _teamPrimary.withOpacity(0.8)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                              width: 6,
                              height: 6,
                              color: _teamPrimary),
                          const SizedBox(width: 8),
                          Text(
                            _team!.name.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // ── Bottom name block + team logo ──
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Name block
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // First name — light, tracked
                            Text(
                              p.firstName.toUpperCase(),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.55),
                                fontSize: 20,
                                fontWeight: FontWeight.w300,
                                letterSpacing: 8,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Last name — MASSIVE, tight
                            ShaderMask(
                              shaderCallback: (rect) => const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Colors.white, Color(0xFFf5f5f5)],
                              ).createShader(rect),
                              child: Text(
                                p.lastName.toUpperCase(),
                                style: TextStyle(
                                  fontFamily: 'MyriadPro',
                                  color: Colors.white,
                                  fontSize: lastNameSize,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -4,
                                  height: 0.88,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Red underline accent
                            Container(
                              height: 4,
                              width: 96,
                              decoration: BoxDecoration(
                                gradient: _teamGradient,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Team logo bottom-right — natural aspect, large
                      if (!hasSecondary && _team != null) ...[
                        const SizedBox(width: 24),
                        _buildTeamLogoBadge(_team!),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTeamLogoBadge(Team team) {
    final hasLogo = team.logoUrl != null && team.logoUrl!.isNotEmpty;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TeamDetailScreen(teamId: team.id),
      )),
      child: hasLogo
          ? ConstrainedBox(
              // Allow the logo to keep its natural aspect ratio.
              // Height drives size; width is unconstrained up to 220px.
              constraints: const BoxConstraints(
                maxHeight: 140,
                maxWidth: 220,
                minHeight: 100,
              ),
              child: Image.network(
                team.logoUrl!,
                fit: BoxFit.contain,
                alignment: Alignment.bottomRight,
                errorBuilder: (_, __, ___) => _teamLogoFallback(team),
              ),
            )
          : _teamLogoFallback(team),
    );
  }

  String _playerInitials(Player p) {
    final f = p.firstName.trim();
    final l = p.lastName.trim();
    final fi = f.isNotEmpty ? f[0] : '';
    final li = l.isNotEmpty ? l[0] : '';
    final s = '$fi$li'.toUpperCase();
    return s.isEmpty ? '00' : s;
  }

  Widget _teamLogoFallback(Team team) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        border: Border.all(
          color: _teamPrimary.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          team.name.isNotEmpty ? team.name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontFamily: 'MyriadPro',
            color: Colors.white,
            fontSize: 48,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }

  // ── Quick stats strip pinned below hero ───────────────────────────────

  Widget _buildQuickStatsBar() {
    final s = _stats;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.025),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.06)),
          bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _quickStat(
              'SPIELE',
              s == null ? '—' : '${s.gamesPlayed}',
            ),
          ),
          Container(width: 1, height: 50, color: Colors.white.withOpacity(0.06)),
          Expanded(
            child: _quickStat(
              'TORE',
              s == null ? '—' : '${s.totalGoals}',
              isAccent: true,
            ),
          ),
          Container(width: 1, height: 50, color: Colors.white.withOpacity(0.06)),
          Expanded(
            child: _quickStat(
              'STRAFEN',
              s == null
                  ? '—'
                  : '${s.yellowCards + s.twoMinuteSuspensions + s.redCards}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickStat(String label, String value, {bool isAccent = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'MyriadPro',
              color: isAccent ? _teamPrimary : Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 10,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassificationBanner(Player p) {
    return Container(
      color: const Color(0xFF0a0a0a),
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _teamPrimary.withOpacity(0.14),
          border: Border.all(color: _teamPrimary.withOpacity(0.35)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          p.classification!.toUpperCase(),
          style: TextStyle(
            color: _teamPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  // ── Info section ─────────────────────────────────────────────────────

  Widget _buildInfoSection(Player p) {
    final rows = <_InfoEntry>[];
    rows.add(_InfoEntry('Geschlecht', p.gender));
    if (p.jerseyNumber != null)
      rows.add(_InfoEntry('Trikotnummer', '#${p.jerseyNumber}'));
    if (p.spielerpassNummer != null)
      rows.add(_InfoEntry('Spielerpass', p.spielerpassNummer!));
    if (p.birthDate != null)
      rows.add(_InfoEntry(
          'Geburtsdatum',
          '${p.birthDate!.day.toString().padLeft(2, '0')}.'
              '${p.birthDate!.month.toString().padLeft(2, '0')}.'
              '${p.birthDate!.year}'));
    if (p.email != null && p.email!.isNotEmpty)
      rows.add(_InfoEntry('E-Mail', p.email!));

return Container(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Informationen'),
          const SizedBox(height: 8),
          ...rows.asMap().entries.map((e) {
            final isLast = e.key == rows.length - 1;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 140,
                        child: Text(
                          e.value.label.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          e.value.value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Container(height: 1, color: Colors.white.withOpacity(0.06)),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ── Stats section ────────────────────────────────────────────────────

  Widget _buildStatsSection() {
    final s = _stats;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 44, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Karrierestatistik'),
          const SizedBox(height: 18),
          if (s == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Noch keine erfassten Spielereignisse.',
                  style: TextStyle(color: Colors.white.withOpacity(0.4))),
            )
          else ...[
            // Big primary stat: Tore
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 22),
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
                    '${s.totalGoals}',
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
                        'TORE',
                        style: TextStyle(
                          color: _teamPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Gesamt',
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
            const SizedBox(height: 1),
            // Three-row breakdown
            _statRow('Spiele', '${s.gamesPlayed}'),
            _statRow('Feldtore', '${s.goals}'),
            _statRow('7-Meter', '${s.sevenMeterGoals} / ${s.sevenMeterTotal}'),
            _statRow('Gelbe Karten', '${s.yellowCards}'),
            _statRow('2-Minuten', '${s.twoMinuteSuspensions}'),
            _statRow('Rote Karten', '${s.redCards}'),
            _statRow('Blaue Karten', '${s.blueCards}', isLast: true),
          ],
        ],
      ),
    );
  }

  Widget _statRow(String label, String value, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 22),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(isLast ? 0 : 0.06),
            width: 1,
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Suspensions section ───────────────────────────────────────────────

  Widget _buildSuspensionsSection() {
    if (_suspensions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 44, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Aktive Sperren'),
          const SizedBox(height: 14),
          ..._suspensions.map((s) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _teamPrimary.withOpacity(0.1),
                  border: Border(
                    left: BorderSide(
                        color: _teamPrimary, width: 3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.block,
                        color: _teamPrimary, size: 20),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.reason,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.expiresAt != null
                                ? 'gültig bis ${s.expiresAt!.day}.${s.expiresAt!.month}.${s.expiresAt!.year}'
                                : 'unbefristet',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────

  Widget _sectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _hasOwnColors
                  ? [_teamPrimary, _teamSecondary]
                  : const [Color(0xFFe63946), Color(0xFFffd765)],
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

class _InfoEntry {
  final String label;
  final String value;
  const _InfoEntry(this.label, this.value);
}

// ── Diagonal slash painter (HBL signature) ───────────────────────────────────

class _DiagonalSlashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;
    const spacing = 22.0;
    for (double x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DiagonalSlashPainter old) => false;
}
