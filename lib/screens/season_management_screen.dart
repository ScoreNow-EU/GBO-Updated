import 'package:flutter/material.dart';
import '../models/tournament.dart';
import '../models/team.dart';
import '../services/tournament_service.dart';
import '../services/team_service.dart';
import '../utils/responsive_helper.dart';
import '../utils/app_colors.dart';
import 'package:toastification/toastification.dart';
import 'tournament_results_screen.dart';

class SeasonManagementScreen extends StatefulWidget {
  const SeasonManagementScreen({super.key});

  @override
  State<SeasonManagementScreen> createState() => _SeasonManagementScreenState();
}

class _SeasonManagementScreenState extends State<SeasonManagementScreen> {
  final TournamentService _tournamentService = TournamentService();
  final TeamService _teamService = TeamService();
  String selectedSeason = '2026';
  List<Tournament> tournaments = [];
  bool isLoading = true;

  // Available seasons
  final List<String> availableSeasons = ['2025', '2026', '2027'];

  @override
  void initState() {
    super.initState();
    _loadTournaments();
  }

  Future<void> _loadTournaments() async {
    setState(() => isLoading = true);
    try {
      final allTournaments = await _tournamentService.getTournaments().first;
      setState(() {
        tournaments = allTournaments
            .where((tournament) => tournament.season == selectedSeason)
            .toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorToast('Fehler beim Laden der Turniere: $e');
    }
  }

  void _showErrorToast(String message) {
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.fillColored,
      title: const Text('Fehler'),
      description: Text(message),
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  void _showSuccessToast(String message) {
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.fillColored,
      title: const Text('Erfolg'),
      description: Text(message),
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  // Check if points have been distributed for a tournament
  bool _arePointsDistributed(Tournament tournament) {
    // Check if the tournament has results and if any teams have points
    if (tournament.results == null || tournament.results!.isEmpty) {
      return false;
    }
    
    // Check if any category has results with points
    if (tournament.results == null) return false;
    
    for (final categoryResults in tournament.results!.values) {
      for (final teamResult in categoryResults) {
        // Check if the team has points from this tournament
        final points = teamResult['points'];
        if (points != null) {
          final pointsValue = points is int ? points : (int.tryParse(points.toString()) ?? 0);
          if (pointsValue > 0) {
            return true;
          }
        }
      }
    }
    
    return false;
  }

  // More comprehensive check that also looks at team points history
  Future<bool> _arePointsDistributedComprehensive(Tournament tournament) async {
    try {
      // First check tournament results
      if (_arePointsDistributed(tournament)) {
        return true;
      }
      
      // If no results in tournament, check if any teams have points from this tournament
      final allTeams = await _teamService.getAllTeams();
      for (final team in allTeams) {
        final hasPointsFromThisTournament = team.pointsHistory.any((entry) => 
          entry['tournamentId'] == tournament.id
        );
        if (hasPointsFromThisTournament) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('Error checking points distribution: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveHelper.isMobile(screenWidth);

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(isMobile),
          const SizedBox(height: 24),

          // Season Navigation Bar
          _buildSeasonNavigationBar(),
          const SizedBox(height: 24),

          // Content
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildTournamentsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.indigo.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.calendar_today,
            color: Colors.indigo.shade700,
            size: 32,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Saison Management',
                style: TextStyle(
                  fontSize: isMobile ? 20 : 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                'Verwalten Sie Turnierergebnisse und Ranglistenpunkte',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSeasonNavigationBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Season Selection
          Row(
            children: availableSeasons.map((season) {
              final isSelected = season == selectedSeason;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        selectedSeason = season;
                      });
                      _loadTournaments();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected ? Colors.indigo : Colors.white,
                      foregroundColor: isSelected ? Colors.white : Colors.indigo,
                      side: BorderSide(
                        color: isSelected ? Colors.indigo : Colors.grey.shade300,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Saison $season',
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentsList() {
    if (tournaments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_handball,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Keine Turniere fÃ¼r Saison $selectedSeason gefunden',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: tournaments.length,
      itemBuilder: (context, index) {
        final tournament = tournaments[index];
        return _buildTournamentCard(tournament);
      },
    );
  }

  Widget _buildTournamentCard(Tournament tournament) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          // Tournament Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tournament.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${tournament.location} â€¢ ${tournament.startDate.toString().split(' ')[0]}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(tournament.status),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getStatusText(tournament.status),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (_arePointsDistributed(tournament)) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Punkte Verteilt',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
                    // Tournament Details
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  icon: Icons.people,
                  label: 'Teams',
                  value: '${tournament.teamIds.length}',
                ),
              ),
                             Expanded(
                 child: _buildDetailItem(
                   icon: _hasManualPoints(tournament) ? Icons.edit : Icons.star,
                   label: _hasManualPoints(tournament) ? 'Manuelle Punkte' : 'Berechnete Punkte',
                   value: _getCalculatedTournamentPoints(tournament).toString(),
                   isManual: _hasManualPoints(tournament),
                 ),
               ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Criteria Points and Selected Teams
          _buildCriteriaAndTeamsInfo(tournament),
          
          const SizedBox(height: 16),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _manageResults(tournament),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Ergebnisse verwalten'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.indigo,
                    side: const BorderSide(color: Colors.indigo),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _overridePoints(tournament),
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('Punkte Ã¼berschreiben'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _viewRankings(tournament),
                  icon: const Icon(Icons.leaderboard, size: 16),
                  label: const Text('Rangliste anzeigen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    bool isManual = false,
  }) {
    final iconColor = isManual ? Colors.orange.shade600 : Colors.grey.shade600;
    final textColor = isManual ? Colors.orange.shade700 : Colors.black87;
    
    return Column(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'upcoming':
        return Colors.blue;
      case 'ongoing':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'upcoming':
        return 'Anstehend';
      case 'ongoing':
        return 'Laufend';
      case 'completed':
        return 'Abgeschlossen';
      default:
        return 'Unbekannt';
    }
  }

  int _getMaxPoints(int teamCount) {
    // RHBL: dynamic placement points â€” 1st place = teamCount pts, 2nd = teamCount-1, etc.
    return teamCount;
  }

  int _getCalculatedTournamentPoints(Tournament tournament) {
    return 0;
  }

  bool _hasManualPoints(Tournament tournament) {
    return false;
  }

  Widget _buildCriteriaAndTeamsInfo(Tournament tournament) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: Colors.blue.shade700, size: 16),
              const SizedBox(width: 8),
              Text(
                'Kriterien & Teams',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildCriteriaItem(
                  icon: Icons.check_circle,
                  label: 'AusgewÃ¤hlte Teams',
                  value: _getSelectedTeamsCount(tournament).toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCriteriaItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.blue.shade600),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.blue.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade700,
          ),
        ),
      ],
    );
  }

  int _getCriteriaPoints(Tournament tournament) {
    return 0;
  }

  int _getSelectedTeamsCount(Tournament tournament) {
    // Count teams that have been selected/confirmed for the tournament
    return tournament.teamIds.length;
  }

  String _getCriteriaDescription(Tournament tournament) {
    return 'Keine Kriterien definiert';
  }

  void _manageResults(Tournament tournament) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TournamentResultsScreen(tournament: tournament),
      ),
    );
  }

  void _overridePoints(Tournament tournament) {
    _showPointsOverrideDialog(tournament);
  }

  void _viewRankings(Tournament tournament) {
    // Navigate to tournament-specific rankings screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TournamentSpecificRankingsScreen(tournament: tournament),
      ),
    );
  }

  void _showPointsOverrideDialog(Tournament tournament) {
    final TextEditingController pointsController = TextEditingController(
      text: '0',
    );
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Punkte Ã¼berschreiben - ${tournament.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Berechnete Punkte: ${_getCalculatedTournamentPoints(tournament)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pointsController,
                decoration: const InputDecoration(
                  labelText: 'Neue Punkte',
                  border: OutlineInputBorder(),
                  hintText: 'Geben Sie die neuen Punkte ein',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(
                  'Hinweis: Diese Ã„nderung Ã¼berschreibt die automatisch berechneten Punkte.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () {
                final newPoints = int.tryParse(pointsController.text);
                if (newPoints != null && newPoints >= 0) {
                  _savePointsOverride(tournament, newPoints);
                  Navigator.of(context).pop();
                } else {
                  _showErrorToast('Bitte geben Sie eine gÃ¼ltige Zahl ein');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    );
  }

  void _savePointsOverride(Tournament tournament, int newPoints) async {
    try {
      // TODO: Save the points override to the database
      // For now, just show a success message
      _showSuccessToast('Punkte fÃ¼r ${tournament.name} auf $newPoints gesetzt');
      
      // Update the local tournament data
      setState(() {
        // In a real implementation, you would update the tournament in the database
        // For now, we'll simulate the update by reloading tournaments
        _loadTournaments();
      });
    } catch (e) {
      _showErrorToast('Fehler beim Speichern der Punkte: $e');
    }
  }
}

// Tournament-specific rankings screen that shows only teams from a specific tournament
class TournamentSpecificRankingsScreen extends StatefulWidget {
  final Tournament tournament;

  const TournamentSpecificRankingsScreen({super.key, required this.tournament});

  @override
  State<TournamentSpecificRankingsScreen> createState() => _TournamentSpecificRankingsScreenState();
}

class _TournamentSpecificRankingsScreenState extends State<TournamentSpecificRankingsScreen> {
  final TeamService _teamService = TeamService();
  List<Team> tournamentTeams = [];
  List<Team> filteredTeams = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTournamentTeams();
  }

  Future<void> _loadTournamentTeams() async {
    setState(() => isLoading = true);
    try {
      // Get all teams
      final allTeams = await _teamService.getAllTeams();
      
      // Filter teams that participated in this tournament
      final participatingTeams = allTeams.where((team) => 
        widget.tournament.teamIds.contains(team.id)
      ).toList();
      
      // Sort by best 3 total points (descending)
      participatingTeams.sort((a, b) {
        final best3PointsA = _calculateBest3TotalPoints(a.pointsHistory);
        final best3PointsB = _calculateBest3TotalPoints(b.pointsHistory);
        return best3PointsB.compareTo(best3PointsA);
      });
      
      setState(() {
        tournamentTeams = participatingTeams;
        filteredTeams = participatingTeams;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorToast('Fehler beim Laden der Teams: $e');
    }
  }

  int _calculateBest3TotalPoints(List<Map<String, dynamic>> pointsHistory) {
    // Sort points history by points in descending order
    final sortedPoints = List<Map<String, dynamic>>.from(pointsHistory);
    sortedPoints.sort((a, b) {
      final pointsA = a['points'] as int? ?? 0;
      final pointsB = b['points'] as int? ?? 0;
      return pointsB.compareTo(pointsA); // Descending order
    });
    
    // Take only the best 3 results
    final best3Results = sortedPoints.take(3).toList();
    
    // Sum up the points from the best 3 results
    return best3Results.fold<int>(
      0,
      (sum, entry) => sum + (entry['points'] as int? ?? 0),
    );
  }

  void _showErrorToast(String message) {
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.fillColored,
      title: const Text('Fehler'),
      description: Text(message),
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = ResponsiveHelper.isTablet(screenWidth);
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Rangliste - ${widget.tournament.name}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Rankings List
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : filteredTeams.isEmpty
                    ? _buildEmptyState()
                    : _buildRankingsList(isTablet),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Keine Teams gefunden',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Dieses Turnier hat noch keine Teilnehmer',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRankingsList(bool isTablet) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredTeams.length,
      itemBuilder: (context, index) {
        final team = filteredTeams[index];
        final placement = index + 1;
        final best3Points = _calculateBest3TotalPoints(team.pointsHistory);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Placement
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: placement <= 3 ? Colors.amber : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      '$placement',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: placement <= 3 ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Team Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        team.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        team.city,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),

                    ],
                  ),
                ),
                
                // Points
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$best3Points Pkt',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 