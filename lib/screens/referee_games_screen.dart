import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game.dart';
import '../models/tournament.dart';
import '../models/referee.dart';
import '../models/court.dart';
import '../services/game_service.dart';
import '../services/tournament_service.dart';
import '../services/referee_service.dart';
import '../utils/responsive_helper.dart';

class RefereeGamesScreen extends StatefulWidget {
  final String refereeId;
  final String? tournamentId;

  const RefereeGamesScreen({
    super.key,
    required this.refereeId,
    this.tournamentId,
  });

  @override
  State<RefereeGamesScreen> createState() => _RefereeGamesScreenState();
}

class _RefereeGamesScreenState extends State<RefereeGamesScreen> {
  final TournamentService _tournamentService = TournamentService();
  final GameService _gameService = GameService();
  final RefereeService _refereeService = RefereeService();

  bool _isLoading = true;
  List<Tournament> _tournaments = [];
  Map<String, List<Game>> _gamesByTournament = {};
  Referee? _referee;
  Map<String, Map<String, dynamic>> _gespannDetails = {}; // tournament ID -> Gespann details
  Map<String, Referee> _refereeCache = {}; // Cache for referee details

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load referee details
      _referee = await _refereeService.getRefereeById(widget.refereeId);

      // Get all tournaments
      _tournaments = await _tournamentService.getTournaments().first;

      // Filter tournaments and find referee's Gespanne
      final Map<String, String> refereeGespannIds = {}; // tournament ID -> Gespann ID
      final Map<String, Map<String, dynamic>> gespannDetails = {}; // tournament ID -> Gespann details
      
      _tournaments = _tournaments.where((tournament) {
        // Look through all Gespanne in this tournament
        for (final gespann in tournament.refereeGespanne) {
          final referee1Id = gespann['referee1Id'] as String?;
          final referee2Id = gespann['referee2Id'] as String?;
          
          // If this referee is part of this Gespann
          if (referee1Id == widget.refereeId || referee2Id == widget.refereeId) {
            // Create the combined ID
            final gespannId = '${referee1Id}_${referee2Id}';
            refereeGespannIds[tournament.id] = gespannId;
            gespannDetails[tournament.id] = gespann;
            return true;
          }
        }
        return false;
      }).toList();

      // Filter to only show tournament-specific games if tournamentId is provided
      if (widget.tournamentId != null) {
        _tournaments = _tournaments.where((t) => t.id == widget.tournamentId).toList();
      }

      // Load games for each tournament
      for (final tournament in _tournaments) {
        final gespannId = refereeGespannIds[tournament.id];
        if (gespannId != null) {
          final games = await _gameService.getGamesForTournament(tournament.id).first;
          
          // Filter games for this referee's Gespann
          final refereeGames = games.where((game) => 
            game.refereeGespannId == gespannId
          ).toList();
          
          // Sort games by scheduled time
          refereeGames.sort((a, b) {
            if (a.scheduledTime == null && b.scheduledTime == null) return 0;
            if (a.scheduledTime == null) return 1;
            if (b.scheduledTime == null) return -1;
            return a.scheduledTime!.compareTo(b.scheduledTime!);
          });
          
          if (refereeGames.isNotEmpty) {
            _gamesByTournament[tournament.id] = refereeGames;
          }
        }
      }

      // Store gespann details for display
      _gespannDetails = gespannDetails;

    } catch (e) {
      print('Error loading referee games: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<String> _getRefereeGespannDisplayName(String tournamentId) async {
    final gespannData = _gespannDetails[tournamentId];
    if (gespannData == null) return 'Schiedsrichter Gespann';

    final referee1Id = gespannData['referee1Id'] as String?;
    final referee2Id = gespannData['referee2Id'] as String?;

    if (referee1Id == null || referee2Id == null) return 'Schiedsrichter Gespann';

    // Get referee names from cache or fetch them
    String referee1Name = 'Schiedsrichter 1';
    String referee2Name = 'Schiedsrichter 2';

    try {
      if (!_refereeCache.containsKey(referee1Id)) {
        final referee1 = await _refereeService.getRefereeById(referee1Id);
        if (referee1 != null) {
          _refereeCache[referee1Id] = referee1;
        }
      }
      if (!_refereeCache.containsKey(referee2Id)) {
        final referee2 = await _refereeService.getRefereeById(referee2Id);
        if (referee2 != null) {
          _refereeCache[referee2Id] = referee2;
        }
      }

      referee1Name = _refereeCache[referee1Id]?.fullName ?? 'Schiedsrichter 1';
      referee2Name = _refereeCache[referee2Id]?.fullName ?? 'Schiedsrichter 2';
    } catch (e) {
      print('Error fetching referee names: $e');
    }

    return '$referee1Name & $referee2Name';
  }

  String _formatGameTime(DateTime? scheduledTime) {
    if (scheduledTime == null) {
      return 'ZEIT NOCH NICHT FESTGELEGT';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final gameDate = DateTime(scheduledTime.year, scheduledTime.month, scheduledTime.day);
    final daysDifference = gameDate.difference(today).inDays;

    final timeString = '${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')} UHR';

    // German weekday names
    final weekdays = [
      'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 
      'Freitag', 'Samstag', 'Sonntag'
    ];

    if (daysDifference == 0) {
      // Today
      return 'HEUTE (${weekdays[scheduledTime.weekday - 1]}) $timeString';
    } else if (daysDifference == 1) {
      // Tomorrow
      return 'MORGEN (${weekdays[scheduledTime.weekday - 1]}) $timeString';
    } else if (daysDifference < 7) {
      // Within a week - show weekday name
      return '${weekdays[scheduledTime.weekday - 1].toUpperCase()} $timeString';
    } else {
      // More than a week - show date
      return '${scheduledTime.day}.${scheduledTime.month}.${scheduledTime.year} $timeString';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tournaments.isEmpty
              ? const Center(
                  child: Text(
                    'Keine Spiele gefunden.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _tournaments.map((tournament) {
                      final games = _gamesByTournament[tournament.id] ?? [];
                      if (games.isEmpty) return const SizedBox.shrink();
                      
                      return _buildTournamentSection(tournament, games);
                    }).toList(),
                  ),
                ),
    );
  }

  Widget _buildContent() {
    if (_tournaments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_handball_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Keine Spiele zugewiesen',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tournaments.length,
      itemBuilder: (context, index) {
        final tournament = _tournaments[index];
        final games = _gamesByTournament[tournament.id] ?? [];
        
        // Sort games by scheduled time
        games.sort((a, b) {
          if (a.scheduledTime == null) return 1;
          if (b.scheduledTime == null) return -1;
          return a.scheduledTime!.compareTo(b.scheduledTime!);
        });

        return _buildTournamentSection(tournament, games);
      },
    );
  }

  Widget _buildTournamentSection(Tournament tournament, List<Game> games) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tournament header
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tournament.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${tournament.startDate.day}.${tournament.startDate.month}.${tournament.startDate.year}${tournament.endDate != null ? ' - ${tournament.endDate!.day}.${tournament.endDate!.month}.${tournament.endDate!.year}' : ''}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        
        // Games as cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: games.map((game) => _buildGameCard(game, tournament)).toList(),
          ),
        ),
        
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildGameCard(Game game, Tournament tournament) {
    final courtId = game.courtId;
    final courtName = courtId != null 
        ? tournament.courts.firstWhere(
            (c) => c.id == courtId,
            orElse: () => Court(
              id: courtId,
              name: 'Platz $courtId',
              description: '',
              latitude: 0,
              longitude: 0,
              createdAt: DateTime.now(),
            ),
          ).name
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time and court info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatGameTime(game.scheduledTime),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (courtName != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      courtName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Game title
            Text(
              '${game.gameType == GameType.pool ? 'POOL' : 'KO'} SPIEL ${game.gameType == GameType.pool ? (game.poolId?.toUpperCase() ?? '') : (game.bracketRound?.toString() ?? '')}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Teams
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      // Team 1
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              game.teamAName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            game.result?.teamASetWins?.toString() ?? '0',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Team 2
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              game.teamBName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            game.result?.teamBSetWins?.toString() ?? '0',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Referee info
            FutureBuilder<String>(
              future: _getRefereeGespannDisplayName(tournament.id),
              builder: (context, snapshot) {
                return Row(
                  children: [
                    const Icon(
                      Icons.people,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      snapshot.data ?? 'Lade Schiedsrichter...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
} 