import 'package:flutter/material.dart';
import 'dart:async';
import '../models/game.dart';
import '../models/tournament.dart';
import '../services/game_service.dart';
import '../services/tournament_service.dart';

class LiveGamesTicker extends StatefulWidget {
  const LiveGamesTicker({super.key});

  @override
  State<LiveGamesTicker> createState() => _LiveGamesTickerState();
}

class _LiveGamesTickerState extends State<LiveGamesTicker> {
  final GameService _gameService = GameService();
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
          // Reset to start
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        } else {
          // Scroll forward
          _scrollController.animateTo(
            currentScroll + 300,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  Future<void> _loadGames() async {
    try {
      debugPrint('ðŸŽ® LiveGamesTicker: Loading games...');
      // Get all tournaments
      final tournaments = await _tournamentService.getTournamentsWithCache().first;
      debugPrint('ðŸŽ® LiveGamesTicker: Found ${tournaments.length} tournaments');
      
      // Get ongoing and upcoming tournaments
      final relevantTournaments = tournaments.where((t) => 
        t.approvalStatus == 'approved' &&
        (t.status == 'ongoing' || t.status == 'upcoming')
      ).toList();
      debugPrint('ðŸŽ® LiveGamesTicker: ${relevantTournaments.length} relevant tournaments (approved, ongoing/upcoming)');

      List<GameWithTournament> gamesWithTournaments = [];

      for (final tournament in relevantTournaments) {
        // Get games for this tournament
        final games = await _gameService.getGamesForTournament(tournament.id).first;
        debugPrint('ðŸŽ® LiveGamesTicker: Tournament "${tournament.name}" has ${games.length} games');
        
        // Filter for live and upcoming games (no time limit)
        final relevantGames = games.where((game) {
          final isLive = game.status == GameStatus.inProgress;
          final isUpcoming = game.status == GameStatus.scheduled && game.scheduledTime != null;
          return isLive || isUpcoming;
        }).toList();
        
        debugPrint('ðŸŽ® LiveGamesTicker: ${relevantGames.length} live/upcoming games in "${tournament.name}"');

        for (final game in relevantGames) {
          gamesWithTournaments.add(GameWithTournament(
            game: game,
            tournament: tournament,
          ));
          debugPrint('ðŸŽ® LiveGamesTicker: Added game: ${game.teamAName} vs ${game.teamBName} (${game.status}, scheduled: ${game.scheduledTime})');
        }
      }

      // Sort: live games first, then by scheduled time
      gamesWithTournaments.sort((a, b) {
        final aIsLive = a.game.status == GameStatus.inProgress;
        final bIsLive = b.game.status == GameStatus.inProgress;
        
        if (aIsLive && !bIsLive) return -1;
        if (!aIsLive && bIsLive) return 1;
        
        if (a.game.scheduledTime == null) return 1;
        if (b.game.scheduledTime == null) return -1;
        
        return a.game.scheduledTime!.compareTo(b.game.scheduledTime!);
      });

      debugPrint('ðŸŽ® LiveGamesTicker: Total games to display: ${gamesWithTournaments.length}');

      if (mounted) {
        setState(() {
          _gamesWithTournaments = gamesWithTournaments;
        });
      }
    } catch (e) {
      debugPrint('âŒ LiveGamesTicker: Error loading games: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _gamesWithTournaments.isEmpty
          ? Center(
              child: Text(
                'Keine Live- oder anstehende Spiele',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                ),
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _gamesWithTournaments.length,
              itemBuilder: (context, index) {
                final item = _gamesWithTournaments[index];
                return _buildGameCard(item);
              },
            ),
    );
  }

  Widget _buildGameCard(GameWithTournament item) {
    final game = item.game;
    final tournament = item.tournament;
    final isLive = game.status == GameStatus.inProgress;
    final isFinished = game.status == GameStatus.completed;

    return Container(
      width: 200,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLive 
            ? const Color(0xFF2d4059)
            : const Color(0xFF16213e),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLive 
              ? Colors.red.shade400
              : Colors.grey.shade700,
          width: isLive ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Time/Live indicator and Tournament
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Live indicator or time
              if (isLive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
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
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  _formatGameTime(game.scheduledTime),
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              
              // Tournament name
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade900.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: Colors.orange.shade800,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    tournament.name,
                    style: TextStyle(
                      color: Colors.orange.shade300,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Team A row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  game.teamAName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: isLive ? FontWeight.bold : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isFinished 
                      ? Colors.grey.shade800
                      : const Color(0xFF0f3460),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${game.result?.teamAScore ?? 0}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 4),
          
          // Team B row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  game.teamBName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: isLive ? FontWeight.bold : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isFinished 
                      ? Colors.grey.shade800
                      : const Color(0xFF0f3460),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${game.result?.teamBScore ?? 0}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatGameTime(DateTime? time) {
    if (time == null) return 'BALD';
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final gameDay = DateTime(time.year, time.month, time.day);
    
    if (gameDay == today) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.day}.${time.month}. ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}

class GameWithTournament {
  final Game game;
  final Tournament tournament;

  GameWithTournament({
    required this.game,
    required this.tournament,
  });
}
