import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../models/team.dart';
import '../models/game.dart';
import '../models/tournament.dart';
import '../models/game_squad.dart';
import '../services/game_service.dart';
import '../services/tournament_service.dart';
import '../services/game_squad_service.dart';
import '../services/auth_service.dart';
import 'squad_selection_screen.dart';

class TeamGamesView extends StatefulWidget {
  final Team team;

  const TeamGamesView({super.key, required this.team});

  @override
  State<TeamGamesView> createState() => _TeamGamesViewState();
}

class _TeamGamesViewState extends State<TeamGamesView> {
  final GameService _gameService = GameService();
  final TournamentService _tournamentService = TournamentService();
  final GameSquadService _gameSquadService = GameSquadService();
  final AuthService _authService = AuthService();

  List<Game> _upcomingGames = [];
  List<Tournament> _tournaments = [];
  Map<String, GameSquad> _gameSquads = {}; // gameId -> GameSquad
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    setState(() => _isLoading = true);

    try {
      debugPrint('ðŸŽ¯ Loading games for team: ${widget.team.name} (ID: ${widget.team.id})');
      
      // Load tournaments
      final tournaments = await _tournamentService.getTournamentsWithCache().first;
      debugPrint('ðŸ“… Found ${tournaments.length} total tournaments');
      
      final activeTournaments = tournaments.where((t) => 
        t.status == 'upcoming' || t.status == 'ongoing'
      ).toList();
      debugPrint('ðŸ“… Found ${activeTournaments.length} active tournaments (upcoming or ongoing)');
      
      // Show all tournament statuses for debugging
      final tournamentsByStatus = <String, int>{};
      for (final tournament in tournaments) {
        tournamentsByStatus[tournament.status] = (tournamentsByStatus[tournament.status] ?? 0) + 1;
      }
      debugPrint('ðŸ“… Tournament statuses: $tournamentsByStatus');
      
      for (final tournament in activeTournaments) {
        debugPrint('  - ${tournament.name} (${tournament.status})');
      }

      // Load games for this team across all active tournaments
      final allGames = <Game>[];
      for (final tournament in activeTournaments) {
        debugPrint('ðŸ”„ Force refreshing cache for tournament: ${tournament.name}');
        
        // Force clear cache and get fresh data from Firebase
        await _gameService.forceRefreshGames(tournament.id);
        
        debugPrint('ðŸ”„ Fetching fresh games for tournament: ${tournament.name}');
        final tournamentGames = await _gameService.getGamesForTournament(tournament.id).first;
        debugPrint('ðŸŽ® Tournament "${tournament.name}": ${tournamentGames.length} total games');
        
        // Debug: Show what we're looking for vs what we find
        debugPrint('ðŸ” Looking for team ID: "${widget.team.id}"');
        debugPrint('ðŸ” Checking ${tournamentGames.length} games in tournament...');
        
        for (int i = 0; i < tournamentGames.length; i++) {
          final game = tournamentGames[i];
          final matchesA = game.teamAId == widget.team.id;
          final matchesB = game.teamBId == widget.team.id;
          debugPrint('ðŸ” Game ${i+1}: ${game.displayName}');
          debugPrint('    TeamA ID: "${game.teamAId}" (matches: $matchesA)');
          debugPrint('    TeamB ID: "${game.teamBId}" (matches: $matchesB)');
          debugPrint('    Status: ${game.status}');
          if (matchesA || matchesB) {
            debugPrint('    âœ… MATCH FOUND!');
          }
        }
        
        final teamGames = tournamentGames.where((game) => 
          game.teamAId == widget.team.id || game.teamBId == widget.team.id
        ).toList();
        debugPrint('ðŸŽ® Found ${teamGames.length} games for team "${widget.team.name}"');
        
        for (final game in teamGames) {
          debugPrint('  - ${game.displayName} (Status: ${game.status}, TeamA: ${game.teamAId}, TeamB: ${game.teamBId})');
        }
        
        allGames.addAll(teamGames);
      }

      // Sort by scheduled time, upcoming games first
      allGames.sort((a, b) {
        if (a.scheduledTime == null && b.scheduledTime == null) return 0;
        if (a.scheduledTime == null) return 1;
        if (b.scheduledTime == null) return -1;
        return a.scheduledTime!.compareTo(b.scheduledTime!);
      });

      debugPrint('ðŸŽ® Total games found across all tournaments: ${allGames.length}');

      // Filter out completed games  
      final upcomingGames = allGames.where((game) => 
        game.status != GameStatus.completed
      ).toList();
      debugPrint('ðŸŽ® Games after filtering out completed: ${upcomingGames.length}');

      // Load squad data for each game
      final gameSquads = <String, GameSquad>{};
      for (final game in upcomingGames) {
        final squad = await _gameSquadService.getSquadForGame(game.id, widget.team.id);
        if (squad != null) {
          gameSquads[game.id] = squad;
          debugPrint('ðŸ‘¥ Found existing squad for game: ${game.displayName}');
        }
      }

      debugPrint('ðŸŽ¯ Final result: ${upcomingGames.length} upcoming games for team "${widget.team.name}"');

      setState(() {
        _tournaments = activeTournaments;
        _upcomingGames = upcomingGames;
        _gameSquads = gameSquads;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorToast('Fehler beim Laden der Spiele: $e');
    }
  }

  Future<void> _navigateToSquadSelection(Game game) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => SquadSelectionScreen(
          game: game,
          team: widget.team,
        ),
      ),
    );

    // Reload data if squad was updated
    if (result == true) {
      _loadGames();
    }
  }

  void _showErrorToast(String message) {
    toastification.show(
      context: context,
      title: Text(message),
      type: ToastificationType.error,
      style: ToastificationStyle.flatColored,
      autoCloseDuration: const Duration(seconds: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_upcomingGames.isEmpty) {
      return _buildNoGamesView();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.sports_handball, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'Spiele & Kader-Verwaltung',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Wählen Sie für jedes Spiel Ihren Kader aus (max. 10 Spieler)',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),

          // Games List
          ...List.generate(_upcomingGames.length, (index) {
            final game = _upcomingGames[index];
            final squad = _gameSquads[game.id];
                         final tournament = _tournaments.firstWhere(
               (t) => t.id == game.tournamentId,
               orElse: () => Tournament(
                 id: '', name: 'Unbekanntes Turnier', startDate: DateTime.now(), 
                 endDate: DateTime.now(), location: '', status: 'unknown',
               ),
             );

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              child: InkWell(
                onTap: () => _navigateToSquadSelection(game),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Game header
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              game.displayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _buildSquadStatusBadge(squad),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Tournament info
                      Row(
                        children: [
                          Icon(Icons.event, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            tournament.name,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),

                      // Game time
                      if (game.scheduledTime != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              _formatDateTime(game.scheduledTime!),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Squad info
                      if (squad != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.group, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              '${squad.playerCount}/10 Spieler ausgewählt',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Tippen zum Bearbeiten',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.group_off, size: 16, color: Colors.orange[600]),
                            const SizedBox(width: 4),
                            Text(
                              'Kein Kader ausgewählt',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.orange[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Tippen zum Auswählen',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNoGamesView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sports_handball_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Keine kommenden Spiele',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ihr Team hat derzeit keine geplanten Spiele.\nNeue Spiele werden hier angezeigt, sobald sie geplant sind.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSquadStatusBadge(GameSquad? squad) {
    if (squad == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Kader fehlt',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (squad.isApproved) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'âœ“ Bestätigt',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (squad.isRejected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'âœ— Abgelehnt',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'â³ Wartet',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
} 