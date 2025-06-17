import 'package:flutter/material.dart';
import '../models/game.dart';
import '../models/tournament.dart';
import '../services/game_service.dart';

class TournamentGamesScreen extends StatefulWidget {
  final Tournament tournament;

  const TournamentGamesScreen({
    super.key,
    required this.tournament,
  });

  @override
  State<TournamentGamesScreen> createState() => _TournamentGamesScreenState();
}

class _TournamentGamesScreenState extends State<TournamentGamesScreen> {
  final GameService _gameService = GameService();
  String _selectedFilter = 'Alle';
  String _selectedStatus = 'Alle';

  @override
  void initState() {
    super.initState();
    // Debug Firebase structure
    _gameService.debugFirebaseStructure(widget.tournament.id);
    // Preload games for this tournament to ensure cache is populated
    _gameService.preloadGames(widget.tournament.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.tournament.name,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Alle Spiele und Ergebnisse',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      'Tournament ID: ${widget.tournament.id}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () async {
                    await _gameService.forceRefreshGames(widget.tournament.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Spiele wurden aktualisiert')),
                    );
                  },
                  child: const Text('Aktualisieren'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    await _gameService.debugFirebaseStructure(widget.tournament.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Debug info logged to console')),
                    );
                  },
                  child: const Text('Debug Firebase'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _showSchedulingSummary(),
                  child: const Text('Zeitplan Übersicht'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Filters
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedFilter,
                    decoration: InputDecoration(
                      labelText: 'Spieltyp filtern',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: ['Alle', 'Gruppenphase', 'Elimination'].map((String type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedFilter = newValue;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: InputDecoration(
                      labelText: 'Status filtern',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: ['Alle', 'Geplant', 'Laufend', 'Beendet', 'Abgesagt'].map((String status) {
                      return DropdownMenuItem<String>(
                        value: status,
                        child: Text(status),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedStatus = newValue;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Statistics Section
            _buildStatisticsSection(),
            const SizedBox(height: 24),

            // Games List
            Expanded(
              child: StreamBuilder<List<Game>>(
                stream: _gameService.getGamesForTournament(widget.tournament.id),
                builder: (context, snapshot) {
                  print('🎮 UI: StreamBuilder state - connection: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, hasError: ${snapshot.hasError}');
                  
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    print('❌ UI: StreamBuilder error: ${snapshot.error}');
                    return Center(
                      child: Text(
                        'Fehler: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  // Get games for this tournament directly
                  List<Game> games = snapshot.data ?? [];
                  print('🎮 UI: Received ${games.length} games from stream');

                  // Apply filters
                  games = _applyFilters(games);
                  print('🎮 UI: After filtering: ${games.length} games');

                  if (games.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Keine Spiele gefunden.',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Turnier ID: ${widget.tournament.id}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return _buildGamesList(games);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return StreamBuilder<List<Game>>(
      stream: _gameService.getGamesForTournament(widget.tournament.id),
      builder: (context, snapshot) {
        final tournamentGames = snapshot.data ?? [];
        
        final stats = {
          'total': tournamentGames.length,
          'completed': tournamentGames.where((g) => g.status == GameStatus.completed).length,
          'scheduled': tournamentGames.where((g) => g.status == GameStatus.scheduled).length,
          'inProgress': tournamentGames.where((g) => g.status == GameStatus.inProgress).length,
        };
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text(
                    'Spiel Statistiken',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildStatCard('Gesamt', stats['total'].toString(), Colors.blue),
                  const SizedBox(width: 16),
                  _buildStatCard('Beendet', stats['completed'].toString(), Colors.green),
                  const SizedBox(width: 16),
                  _buildStatCard('Geplant', stats['scheduled'].toString(), Colors.orange),
                  const SizedBox(width: 16),
                  _buildStatCard('Laufend', stats['inProgress'].toString(), Colors.red),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGamesList(List<Game> games) {
    // Group games by type
    final poolGames = games.where((g) => g.gameType == GameType.pool).toList();
    final eliminationGames = games.where((g) => g.gameType == GameType.elimination).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pool Games
          if (poolGames.isNotEmpty) ...[
            const Text(
              'Gruppenphase',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            ...poolGames.map((game) => _buildGameCard(game)),
            const SizedBox(height: 32),
          ],

          // Elimination Games
          if (eliminationGames.isNotEmpty) ...[
            const Text(
              'K.O.-Phase',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            ...eliminationGames.map((game) => _buildGameCard(game)),
          ],
        ],
      ),
    );
  }

  Widget _buildGameCard(Game game) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(game.status).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Game Header
            Row(
              children: [
                // Game Type Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: game.gameType == GameType.pool 
                        ? Colors.blue.withOpacity(0.2) 
                        : Colors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    game.gameType == GameType.pool 
                        ? 'Gruppe ${game.poolId?.toUpperCase() ?? ''}' 
                        : _getCustomMatchName(game),
                    style: TextStyle(
                      color: game.gameType == GameType.pool 
                          ? Colors.blue.shade700 
                          : Colors.purple.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(game.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(game.status),
                    style: TextStyle(
                      color: _getStatusColor(game.status),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

                            // Teams and Result
                Row(
                  children: [
                    // Team A
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatTeamName(game.teamAName),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: game.result?.winnerId == game.teamAId 
                                  ? Colors.green.shade700 
                                  : Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (game.isPlaceholder) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Wird automatisch bestimmt',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                // Score/Result
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      if (game.result != null) ...[
                        // Final Score
                        Text(
                          game.result!.finalScore,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Set Results
                        ...game.result!.sets.map((set) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            'Satz ${set.setNumber}: ${set.score}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        )),
                        // Shootout
                        if (game.result!.hasShootout) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Shootout: ${game.result!.shootout!.score}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ] else ...[
                        Text(
                          game.status == GameStatus.scheduled ? 'vs' : 'Läuft...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Team B
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatTeamName(game.teamBName),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: game.result?.winnerId == game.teamBId 
                              ? Colors.green.shade700 
                              : Colors.black87,
                        ),
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (game.isPlaceholder) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Wird automatisch bestimmt',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Scheduling Information
            if (game.scheduledTime != null || game.courtId != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    if (game.scheduledTime != null) ...[
                      Icon(Icons.schedule, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 4),
                      Text(
                        '${game.scheduledTime!.day}.${game.scheduledTime!.month}.${game.scheduledTime!.year} ${game.scheduledTime!.hour.toString().padLeft(2, '0')}:${game.scheduledTime!.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (game.scheduledTime != null && game.courtId != null) ...[
                      const SizedBox(width: 16),
                      Container(
                        width: 1,
                        height: 16,
                        color: Colors.blue.shade300,
                      ),
                      const SizedBox(width: 16),
                    ],
                    if (game.courtId != null) ...[
                      Icon(Icons.sports_tennis, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Feld ${game.courtId}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Game Actions
            if (!game.isPlaceholder) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Spacer(),
                  if (game.status != GameStatus.completed) ...[
                    TextButton.icon(
                      onPressed: () => _showResultDialog(game),
                      icon: const Icon(Icons.edit_note, size: 16),
                      label: const Text('Ergebnis eingeben'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue,
                      ),
                    ),
                  ],
                  if (game.status == GameStatus.completed) ...[
                    TextButton.icon(
                      onPressed: () => _showResultDialog(game),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Bearbeiten'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Game> _applyFilters(List<Game> games) {
    List<Game> filteredGames = games;

    // Filter by type
    if (_selectedFilter != 'Alle') {
      if (_selectedFilter == 'Gruppenphase') {
        filteredGames = filteredGames.where((g) => g.gameType == GameType.pool).toList();
      } else if (_selectedFilter == 'Elimination') {
        filteredGames = filteredGames.where((g) => g.gameType == GameType.elimination).toList();
      }
    }

    // Filter by status
    if (_selectedStatus != 'Alle') {
      GameStatus? statusFilter;
      switch (_selectedStatus) {
        case 'Geplant':
          statusFilter = GameStatus.scheduled;
          break;
        case 'Laufend':
          statusFilter = GameStatus.inProgress;
          break;
        case 'Beendet':
          statusFilter = GameStatus.completed;
          break;
        case 'Abgesagt':
          statusFilter = GameStatus.cancelled;
          break;
      }
      if (statusFilter != null) {
        filteredGames = filteredGames.where((g) => g.status == statusFilter).toList();
      }
    }

    return filteredGames;
  }

  Color _getStatusColor(GameStatus status) {
    switch (status) {
      case GameStatus.scheduled:
        return Colors.orange;
      case GameStatus.inProgress:
        return Colors.blue;
      case GameStatus.completed:
        return Colors.green;
      case GameStatus.cancelled:
        return Colors.red;
    }
  }

  String _getStatusText(GameStatus status) {
    switch (status) {
      case GameStatus.scheduled:
        return 'Geplant';
      case GameStatus.inProgress:
        return 'Laufend';
      case GameStatus.completed:
        return 'Beendet';
      case GameStatus.cancelled:
        return 'Abgesagt';
    }
  }

  String _getCustomMatchName(Game game) {
    // Extract node title from game ID format: tournamentId_match_nodeTitle_team1_team2
    if (game.id.contains('_match_')) {
      final parts = game.id.split('_match_');
      if (parts.length > 1) {
        final afterMatch = parts[1];
        // Split by underscore and take all parts except the last two (team IDs)
        final titleParts = afterMatch.split('_');
        if (titleParts.length >= 3) {
          // Join all parts except the last two (which are team IDs)
          final nodeTitle = titleParts.sublist(0, titleParts.length - 2).join('_');
          return nodeTitle;
        }
      }
    }
    
    // Fallback to generic round names for non-custom bracket games
    return _gameService.getBracketRoundName(game.bracketRound ?? 1, 4);
  }

  void _showResultDialog(Game game) {
    // Implementation for entering/editing results
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ergebnis ${game.result != null ? 'bearbeiten' : 'eingeben'}'),
        content: const Text('Ergebniseingabe Funktionalität kommt bald...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatTeamName(String teamName) {
    // Shorten long placeholder names for better display
    if (teamName.startsWith('Sieger:')) {
      // For "Sieger: 1. aus Pool A vs 2. aus Pool B" -> "Sieger Pool A vs Pool B Spiel"
      String content = teamName.substring(8); // Remove "Sieger: "
      if (content.contains(' vs ')) {
        List<String> parts = content.split(' vs ');
        if (parts.length == 2) {
          String teamA = parts[0].replaceAll('. aus Pool ', '').replaceAll('1', '1.').replaceAll('2', '2.').replaceAll('3', '3.').replaceAll('4', '4.');
          String teamB = parts[1].replaceAll('. aus Pool ', '').replaceAll('1', '1.').replaceAll('2', '2.').replaceAll('3', '3.').replaceAll('4', '4.');
          return 'Sieger $teamA vs $teamB';
        }
      }
      return 'Sieger vorheriges Spiel';
    }
    
    // For direct pool placeholders like "1. aus Pool A"
    if (teamName.contains('. aus Pool ')) {
      return teamName.replaceAll('. aus Pool ', ' Pool ');
    }
    
    return teamName;
  }

  void _showSchedulingSummary() async {
    final games = await _gameService.getGamesForTournament(widget.tournament.id).first;
    final scheduledGames = games.where((g) => g.scheduledTime != null || g.courtId != null).toList();
    
    if (scheduledGames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keine Spiele sind eingeplant')),
      );
      return;
    }

    // Sort by scheduled time
    scheduledGames.sort((a, b) {
      if (a.scheduledTime == null && b.scheduledTime == null) return 0;
      if (a.scheduledTime == null) return 1;
      if (b.scheduledTime == null) return -1;
      return a.scheduledTime!.compareTo(b.scheduledTime!);
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zeitplan Übersicht'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: Column(
            children: [
              Text('${scheduledGames.length} von ${games.length} Spielen eingeplant'),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: scheduledGames.length,
                  itemBuilder: (context, index) {
                    final game = scheduledGames[index];
                    return ListTile(
                      title: Text('${game.teamAName} vs ${game.teamBName}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (game.scheduledTime != null)
                            Text('Zeit: ${game.scheduledTime!.day}.${game.scheduledTime!.month} ${game.scheduledTime!.hour.toString().padLeft(2, '0')}:${game.scheduledTime!.minute.toString().padLeft(2, '0')}'),
                          if (game.courtId != null)
                            Text('Feld: ${game.courtId}'),
                        ],
                      ),
                      leading: CircleAvatar(
                        backgroundColor: game.gameType == GameType.pool ? Colors.blue : Colors.purple,
                        child: Text(
                          game.gameType == GameType.pool ? 'G' : 'K',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _gameService.dispose();
    super.dispose();
  }
} 