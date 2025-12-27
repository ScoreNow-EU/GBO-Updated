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
  String selectedCategory = 'Alle'; // Filter for Seniors/Juniors
  List<Tournament> tournaments = [];
  bool isLoading = true;

  // Available seasons
  final List<String> availableSeasons = ['2025', '2026', '2027'];
  
  // Available categories for filtering
  final List<String> availableCategories = [
    'Alle', 
    'GBO Seniors Cup', 
    'GBO Juniors Cup', 
    'Seniors Kombination', 
    'Juniors Kombination'
  ];

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
            .where((tournament) => 
                selectedCategory == 'Alle' || 
                tournament.categories.contains(selectedCategory) ||
                (selectedCategory == 'Seniors Kombination' && tournament.categories.length > 1 && tournament.isSeniors) ||
                (selectedCategory == 'Juniors Kombination' && tournament.categories.length > 1 && tournament.isJuniors)
            )
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
    
    // Check if any division has results with points
    if (tournament.results == null) return false;
    
    for (final divisionResults in tournament.results!.values) {
      for (final teamResult in divisionResults) {
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

          // Season and Category Navigation Bar
          _buildSeasonAndCategoryNavigationBar(),
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

  Widget _buildSeasonAndCategoryNavigationBar() {
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
          
          const SizedBox(height: 12),
          
          // Category Selection
          Row(
            children: availableCategories.map((category) {
              final isSelected = category == selectedCategory;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        selectedCategory = category;
                      });
                      _loadTournaments();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected ? Colors.green : Colors.white,
                      foregroundColor: isSelected ? Colors.white : Colors.green,
                      side: BorderSide(
                        color: isSelected ? Colors.green : Colors.grey.shade300,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      category == 'Alle' ? 'Alle' : 
                      category == 'GBO Seniors Cup' ? 'Seniors' : 
                      category == 'GBO Juniors Cup' ? 'Juniors' : 
                      category == 'Seniors Kombination' ? 'Seniors Kombination' : 
                      'Juniors Kombination',
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
              Icons.sports_volleyball,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Keine Turniere für Saison $selectedSeason gefunden',
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
                      '${tournament.location} • ${tournament.startDate.toString().split(' ')[0]}',
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
                  icon: Icons.category,
                  label: 'Kategorie',
                  value: tournament.category,
                ),
              ),
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
                  label: const Text('Punkte überschreiben'),
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

  int _getMaxPoints(String category) {
    // For now, return a reasonable default based on category
    // In a real implementation, this should be calculated based on tournament criteria
    switch (category) {
      case 'GBO Supercup':
        return 1600; // Supercup points - can be much higher based on criteria
      case 'GBO Beachcup':
        return 800; // Beachcup points - can be higher based on criteria
      case 'GBO 4Fun-Cup':
        return 400; // 4Fun-Cup points - can be higher based on criteria
      default:
        return 800; // Default Beachcup points
    }
  }

  int _getCalculatedTournamentPoints(Tournament tournament) {
    // If tournament has manually set points, use those
    if (tournament.points > 0) {
      return tournament.points;
    }
    
    // Calculate points based on tournament criteria
    if (tournament.criteria != null) {
      return tournament.criteria!.totalPoints;
    }
    
    // Fallback to category-based points if no criteria
    return _getMaxPoints(tournament.category);
  }

  bool _hasManualPoints(Tournament tournament) {
    // Check if points have been manually set (different from criteria-based calculation)
    if (tournament.criteria != null) {
      return tournament.points != tournament.criteria!.totalPoints;
    }
    return tournament.points != _getMaxPoints(tournament.category);
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
                  icon: Icons.assessment,
                  label: 'Kriterien Punkte',
                  value: _getCriteriaPoints(tournament).toString(),
                ),
              ),
              Expanded(
                child: _buildCriteriaItem(
                  icon: Icons.check_circle,
                  label: 'Ausgewählte Teams',
                  value: _getSelectedTeamsCount(tournament).toString(),
                ),
              ),
            ],
          ),
          if (tournament.criteria != null) ...[
            const SizedBox(height: 8),
            Text(
              'Kriterien: ${_getCriteriaDescription(tournament)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade700,
              ),
            ),
          ],
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
    // Calculate points based on tournament criteria
    if (tournament.criteria != null) {
      return tournament.criteria!.totalPoints;
    }
    return 0;
  }

  int _getSelectedTeamsCount(Tournament tournament) {
    // Count teams that have been selected/confirmed for the tournament
    return tournament.teamIds.length;
  }

  String _getCriteriaDescription(Tournament tournament) {
    if (tournament.criteria == null) return 'Keine Kriterien definiert';
    
    List<String> fulfilledCriteria = [];
    
    // MUST Criteria
    if (tournament.criteria!.officialBeachhandballRules) fulfilledCriteria.add('Offizielle Regeln');
    if (tournament.criteria!.twoRefereesPerGame) fulfilledCriteria.add('2 Schiedsrichter');
    if (tournament.criteria!.cleanZone) fulfilledCriteria.add('Clean Zone');
    if (tournament.criteria!.ausspielenPlatz1To8) fulfilledCriteria.add('Platz 1-8');
    
    // CAN Criteria - Referees
    if (tournament.criteria!.ehfKaderReferees > 0) fulfilledCriteria.add('EHF Kader');
    if (tournament.criteria!.dhbEliteKaderReferees > 0) fulfilledCriteria.add('DHB Elite');
    if (tournament.criteria!.dhbStammKaderReferees > 0) fulfilledCriteria.add('DHB Stamm');
    
    // CAN Criteria - Officials
    if (tournament.criteria!.ebtDelegate) fulfilledCriteria.add('EBT Delegate');
    if (tournament.criteria!.dhbNationalDelegate) fulfilledCriteria.add('DHB Delegate');
    
    // CAN Criteria - Other
    if (tournament.criteria!.technicalMeeting) fulfilledCriteria.add('Techn. Meeting');
    if (tournament.criteria!.gboOnlineSchedule) fulfilledCriteria.add('GBO Schedule');
    if (tournament.criteria!.gboScoringSystem) fulfilledCriteria.add('GBO Scoring');
    if (tournament.criteria!.sanitaeterdienst) fulfilledCriteria.add('Sanitäter');
    if (tournament.criteria!.sitztribuene) fulfilledCriteria.add('Sitztribüne');
    if (tournament.criteria!.spielfeldumrandung) fulfilledCriteria.add('Umrandung');
    if (tournament.criteria!.alleBeachplaetzeOffiziellesMasse) fulfilledCriteria.add('Offizielle Maße');
    if (tournament.criteria!.elektronischeAnzeigetafeln) fulfilledCriteria.add('E-Anzeigen');
    if (tournament.criteria!.zeitnehmerGestellt) fulfilledCriteria.add('Zeitnehmer');
    if (tournament.criteria!.waterForPlayers) fulfilledCriteria.add('Wasser');
    if (tournament.criteria!.arenaCommentator) fulfilledCriteria.add('Kommentator');
    if (tournament.criteria!.tournierauszeichnungen) fulfilledCriteria.add('Auszeichnungen');
    if (tournament.criteria!.tournamentInTownCenter) fulfilledCriteria.add('Stadtzentrum');
    if (tournament.criteria!.tournamentDays > 1) fulfilledCriteria.add('Mehrere Tage');
    
    return fulfilledCriteria.isEmpty ? 'Keine Kriterien erfüllt' : fulfilledCriteria.join(', ');
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
      text: tournament.points.toString(),
    );
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Punkte überschreiben - ${tournament.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aktuelle Punkte: ${tournament.points}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
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
                  'Hinweis: Diese Änderung überschreibt die automatisch berechneten Punkte.',
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
                  _showErrorToast('Bitte geben Sie eine gültige Zahl ein');
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
      _showSuccessToast('Punkte für ${tournament.name} auf $newPoints gesetzt');
      
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
  String selectedDivision = 'Alle';
  List<String> availableDivisions = ['Alle'];
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
      
      // Get available divisions from the participating teams
      final divisions = participatingTeams.map((team) => team.division).toSet().toList();
      divisions.sort();
      
      setState(() {
        tournamentTeams = participatingTeams;
        availableDivisions = ['Alle', ...divisions];
        isLoading = false;
      });
      
      _filterTeams();
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorToast('Fehler beim Laden der Teams: $e');
    }
  }

  void _filterTeams() {
    if (selectedDivision == 'Alle') {
      filteredTeams = List.from(tournamentTeams);
    } else {
      filteredTeams = tournamentTeams.where((team) => team.division == selectedDivision).toList();
    }
    
    // Sort by best 3 total points (descending)
    filteredTeams.sort((a, b) {
      final best3PointsA = _calculateBest3TotalPoints(a.pointsHistory);
      final best3PointsB = _calculateBest3TotalPoints(b.pointsHistory);
      return best3PointsB.compareTo(best3PointsA);
    });
    
    setState(() {});
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

  void _onDivisionChanged(String division) {
    setState(() {
      selectedDivision = division;
    });
    _filterTeams();
  }

  Color _getDivisionColor(String division) {
    if (division.contains('Women')) {
      if (division.contains('FUN')) return Colors.pink;
      if (division.contains('U14')) return Colors.purple;
      if (division.contains('U16')) return Colors.deepPurple;
      if (division.contains('U18')) return Colors.indigo;
      return Colors.blue; // Women's Seniors
    } else {
      if (division.contains('FUN')) return Colors.orange;
      if (division.contains('U14')) return Colors.green;
      if (division.contains('U16')) return Colors.teal;
      if (division.contains('U18')) return Colors.cyan;
      return Colors.red; // Men's Seniors
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
          // Division Filter
          _buildDivisionFilter(),
          
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

  Widget _buildDivisionFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Division auswählen:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.emoji_events,
                      size: 14,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Nur Turnier-Teams',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableDivisions.map((division) {
              final isSelected = selectedDivision == division;
              final divisionColor = division == 'Alle' ? AppColors.primaryColor : _getDivisionColor(division);
              
              return GestureDetector(
                onTap: () => _onDivisionChanged(division),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? divisionColor : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? divisionColor : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    division,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
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
            selectedDivision == 'Alle' 
                ? 'Dieses Turnier hat noch keine Teilnehmer'
                : 'Keine Teams in der Division "$selectedDivision"',
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
        final divisionColor = _getDivisionColor(team.division);
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
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: divisionColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: divisionColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          team.division,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: divisionColor,
                          ),
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