import 'package:flutter/material.dart';
import 'dart:async';
import '../models/game.dart';
import '../models/team.dart';
import '../models/tournament.dart';
import '../services/game_service.dart';
import '../services/team_service.dart';
import '../services/tournament_service.dart';

class LiveGamesTicker extends StatefulWidget {
  const LiveGamesTicker({super.key});

  @override
  State<LiveGamesTicker> createState() => _LiveGamesTickerState();
}

class _LiveGamesTickerState extends State<LiveGamesTicker> {
  final GameService _gameService = GameService();
  final TeamService _teamService = TeamService();
  final TournamentService _tournamentService = TournamentService();
  final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;
  List<GameWithTournament> _gamesWithTournaments = [];

  @override
  void initState() {
    super.initState();
    _loadGames();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.offset;
        if (currentScroll >= maxScroll) {
          _scrollController.animateTo(0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut);
        } else {
          _scrollController.animateTo(currentScroll + 300,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut);
        }
      }
    });
  }

  Future<void> _loadGames() async {
    try {
      final results = await Future.wait([
        _tournamentService.getTournamentsWithCache().first,
        _teamService.getTeamsWithCache().first,
      ]);
      final tournaments = results[0] as List<Tournament>;
      final teams = {for (final t in results[1] as List<Team>) t.id: t};

      final relevantTournaments = tournaments
          .where((t) =>
              t.approvalStatus == 'approved' &&
              (t.status == 'ongoing' || t.status == 'upcoming'))
          .toList();

      final List<GameWithTournament> result = [];
      for (final tournament in relevantTournaments) {
        final games =
            await _gameService.getGamesForTournament(tournament.id).first;
        for (final game in games) {
          final isLive = game.status == GameStatus.inProgress;
          final isUpcoming =
              game.status == GameStatus.scheduled && game.scheduledTime != null;
          if (isLive || isUpcoming) {
            result.add(GameWithTournament(
              game: game,
              tournament: tournament,
              teamALogoUrl: game.teamAId != null ? teams[game.teamAId]?.logoUrl : null,
              teamBLogoUrl: game.teamBId != null ? teams[game.teamBId]?.logoUrl : null,
            ));
          }
        }
      }

      result.sort((a, b) {
        final aLive = a.game.status == GameStatus.inProgress;
        final bLive = b.game.status == GameStatus.inProgress;
        if (aLive && !bLive) return -1;
        if (!aLive && bLive) return 1;
        if (a.game.scheduledTime == null) return 1;
        if (b.game.scheduledTime == null) return -1;
        return a.game.scheduledTime!.compareTo(b.game.scheduledTime!);
      });

      if (mounted) setState(() => _gamesWithTournaments = result);
    } catch (e) {
      debugPrint('LiveGamesTicker: Error loading games: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      color: const Color(0xFF0e1120),
      child: _gamesWithTournaments.isEmpty
          ? Center(
              child: Text(
                'Keine Live- oder anstehende Spiele',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _gamesWithTournaments.length,
              itemBuilder: (context, index) =>
                  _buildGameCard(_gamesWithTournaments[index]),
            ),
    );
  }

  Widget _buildGameCard(GameWithTournament item) {
    final game = item.game;
    final isLive = game.status == GameStatus.inProgress;
    final hasScore =
        isLive || game.status == GameStatus.completed;

    final scoreA = hasScore ? (game.result?.teamAScore ?? 0) : null;
    final scoreB = hasScore ? (game.result?.teamBScore ?? 0) : null;
    final aLeading =
        scoreA != null && scoreB != null && scoreA > scoreB;
    final bLeading =
        scoreA != null && scoreB != null && scoreB > scoreA;

    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161b2e),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLive
              ? const Color(0xFFe53935)
              : const Color(0xFF252c42),
          width: isLive ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tournament header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: const BoxDecoration(
              color: Color(0xFF0e1120),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Text(
              item.tournament.name,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Teams
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              children: [
                _TeamRow(
                    name: game.teamAName,
                    logoUrl: item.teamALogoUrl,
                    score: scoreA,
                    bold: aLeading || isLive),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: _StatusRow(
                      isLive: isLive,
                      scheduledTime: game.scheduledTime),
                ),
                _TeamRow(
                    name: game.teamBName,
                    logoUrl: item.teamBLogoUrl,
                    score: scoreB,
                    bold: bLeading),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _TeamRow extends StatelessWidget {
  final String name;
  final String? logoUrl;
  final int? score;
  final bool bold;

  const _TeamRow(
      {required this.name, this.logoUrl, required this.score, this.bold = false});

  static String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return '';
    if (words.length == 1) {
      return words[0]
          .substring(0, words[0].length.clamp(0, 2))
          .toUpperCase();
    }
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  Widget _initialsWidget() {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF252c42),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials(name),
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: logoUrl != null && logoUrl!.isNotEmpty
              ? Image.network(
                  logoUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => _initialsWidget(),
                )
              : _initialsWidget(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              color: bold ? Colors.white : Colors.white60,
              fontSize: 12,
              fontWeight:
                  bold ? FontWeight.w700 : FontWeight.w400,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (score != null) ...[
          const SizedBox(width: 6),
          Text(
            '$score',
            style: TextStyle(
              color: bold ? Colors.white : Colors.white60,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _StatusRow extends StatelessWidget {
  final bool isLive;
  final DateTime? scheduledTime;

  const _StatusRow(
      {required this.isLive, required this.scheduledTime});

  String _formatTime(DateTime? time) {
    if (time == null) return 'BALD';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final gameDay =
        DateTime(time.year, time.month, time.day);
    if (gameDay == today) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    return '${time.day}.${time.month}. ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
              color: Colors.grey.shade800,
              thickness: 0.5,
              endIndent: 6),
        ),
        if (isLive)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFe53935),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          )
        else
          Text(
            _formatTime(scheduledTime),
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        Expanded(
          child: Divider(
              color: Colors.grey.shade800,
              thickness: 0.5,
              indent: 6),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class GameWithTournament {
  final Game game;
  final Tournament tournament;
  final String? teamALogoUrl;
  final String? teamBLogoUrl;

  GameWithTournament({
    required this.game,
    required this.tournament,
    this.teamALogoUrl,
    this.teamBLogoUrl,
  });
}