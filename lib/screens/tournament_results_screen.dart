import 'package:flutter/material.dart';
import '../models/tournament.dart';
import '../utils/responsive_helper.dart';
import '../utils/season_points.dart';
import 'package:toastification/toastification.dart';
import '../services/team_service.dart';
import '../services/tournament_service.dart';
import '../models/team.dart';

class TournamentResultsScreen extends StatefulWidget {
  final Tournament tournament;

  const TournamentResultsScreen({
    super.key,
    required this.tournament,
  });

  @override
  State<TournamentResultsScreen> createState() => _TournamentResultsScreenState();
}

class _TournamentResultsScreenState extends State<TournamentResultsScreen> {
  List<TournamentResult> results = [];
  bool isLoading = true;
  List<Team> availableTeams = [];
  List<Team> rankedTeams = [];
  final TeamService _teamService = TeamService();
  final TournamentService _tournamentService = TournamentService();

  Tournament? _currentTournament;

  @override
  void initState() {
    super.initState();
    debugPrint('Ã°Å¸â€Â Init: Tournament ID: ${widget.tournament.id}');
    debugPrint('Ã°Å¸â€Â Init: Tournament results keys: ${widget.tournament.results?.keys}');
    _currentTournament = widget.tournament;
    _refreshTournamentAndLoadResults();
  }

  Future<void> _refreshTournamentAndLoadResults() async {
    try {
      debugPrint('Ã°Å¸â€Â Refresh: Getting latest tournament from database...');
      
      // Get the latest tournament data from database
      final latestTournament = await _tournamentService.getTournamentById(widget.tournament.id);
      
      if (latestTournament != null) {
        debugPrint('Ã°Å¸â€Â Refresh: Latest tournament results keys: ${latestTournament.results?.keys}');
        _currentTournament = latestTournament;
      } else {
        debugPrint('Ã¢ÂÅ’ Refresh: Could not load tournament from database');
        _currentTournament = widget.tournament;
      }
      
      // Now load results with the refreshed tournament
      await _loadResults();
      
    } catch (e) {
      debugPrint('Ã¢ÂÅ’ Refresh: Error refreshing tournament: $e');
      // Fall back to original tournament
      _currentTournament = widget.tournament;
      await _loadResults();
    }
  }

  Future<void> _loadResults() async {
    try {
      // Check if widget is still mounted before proceeding
      if (!mounted) return;

      // Set loading state only if mounted
      setState(() {
        isLoading = true;
        availableTeams.clear();
        rankedTeams.clear();
      });

      // Fetch ALL teams and filter to only those registered for this tournament
      List<Team> allTeams = await _teamService.getAllTeams();
      
      // Filter to only teams that are registered for this tournament
      List<Team> tournamentTeams = allTeams.where((team) => 
        widget.tournament.teamIds.contains(team.id)
      ).toList();

      // Check if widget is still mounted
      if (!mounted) return;

      // Prepare available teams
      setState(() {
        // All teams participate (no category filter)
        availableTeams = tournamentTeams;
        
        // Check if there are saved results for this tournament
        final savedResults = _currentTournament?.results?['All'];

        // Reset ranked teams
        rankedTeams.clear();
      });

      // Load ranked teams asynchronously if results exist
      if (_currentTournament?.results?['All'] != null) {
        final List<Team> loadedRankedTeams = [];
        final savedResults = _currentTournament!.results!['All']!;

        // Sort results by placement
        final sortedResults = List.from(savedResults)
          ..sort((a, b) => (a['placement'] ?? 0).compareTo(b['placement'] ?? 0));

        for (var result in sortedResults) {
          final teamId = result['teamId'];
          if (teamId != null) {
            try {
              // Fetch team by ID
              final team = await _teamService.getTeamById(teamId);
              
              // Check if widget is still mounted before updating
              if (!mounted) return;

              if (team != null) {
                // Update state to add team to ranked teams and remove from available teams
                setState(() {
                  loadedRankedTeams.add(team);
                  availableTeams.removeWhere((t) => t.id == teamId);
                });
              }
            } catch (e) {
              debugPrint('Error loading team $teamId: $e');
              continue;
            }
          }
        }

        // Final update of ranked teams if still mounted
        if (mounted) {
          setState(() {
            rankedTeams = loadedRankedTeams;
            isLoading = false;
          });
        }
      } else {
        // No saved results
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    } catch (e) {
      // Check if widget is still mounted before updating state
      if (!mounted) return;

      setState(() {
        isLoading = false;
        _showErrorToast('Fehler beim Laden der Ergebnisse: $e');
      });
    }
  }

  List<TournamentResult> _createSampleResults() {
    // Create sample results for demonstration
    return [
      TournamentResult(
        teamId: 'team1',
        teamName: 'Team Alpha',
        placement: 1,
        points: _calculatePoints(1, totalTeams: 8),
      ),
      TournamentResult(
        teamId: 'team2',
        teamName: 'Team Beta',
        placement: 2,
        points: _calculatePoints(2, totalTeams: 8),
      ),
      TournamentResult(
        teamId: 'team3',
        teamName: 'Team Gamma',
        placement: 3,
        points: _calculatePoints(3, totalTeams: 8),
      ),
      TournamentResult(
        teamId: 'team4',
        teamName: 'Team Delta',
        placement: 4,
        points: _calculatePoints(4, totalTeams: 8),
      ),
      TournamentResult(
        teamId: 'team5',
        teamName: 'Team Epsilon',
        placement: 5,
        points: _calculatePoints(5, totalTeams: 8),
      ),
      TournamentResult(
        teamId: 'team6',
        teamName: 'Team Zeta',
        placement: 6,
        points: _calculatePoints(6, totalTeams: 8),
      ),
      TournamentResult(
        teamId: 'team7',
        teamName: 'Team Eta',
        placement: 7,
        points: _calculatePoints(7, totalTeams: 8),
      ),
      TournamentResult(
        teamId: 'team8',
        teamName: 'Team Theta',
        placement: 8,
        points: _calculatePoints(8, totalTeams: 8),
      ),
    ];
  }

  int _calculatePoints(int placement, {int? totalTeams}) {
    // RHBL dynamic placement points: 1st = N, 2nd = N-1, ..., last = 1
    final teamCount = totalTeams ?? rankedTeams.length;
    if (placement <= 0 || placement > teamCount) return 0;
    return teamCount - placement + 1;
  }

  int _getCalculatedTournamentPoints(Tournament tournament) {
    // RHBL: max points = number of participating teams (1st place gets this many)
    return tournament.teamIds.length;
  }

  bool _arePointsDistributed() {
    // Check if any teams have points from this tournament
    for (final team in rankedTeams) {
      final hasPointsFromThisTournament = team.pointsHistory.any((entry) => 
        entry['tournamentId'] == widget.tournament.id
      );
      if (hasPointsFromThisTournament) {
        return true;
      }
    }
    return false;
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

          // Results Management Area
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildResultsManagementArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Row(
      children: [
        // Back button
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'ZurÃƒÂ¼ck',
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey.shade100,
            padding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.emoji_events,
            color: Colors.green.shade700,
            size: 32,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Turnier Ergebnisse',
                style: TextStyle(
                  fontSize: isMobile ? 20 : 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                widget.tournament.name,
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '${widget.tournament.location} Ã¢â‚¬Â¢ ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    'Teams: ${widget.tournament.teamIds.length} Ã¢â‚¬Â¢ 1. Platz = ${widget.tournament.teamIds.length} Pkt',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 16),
                    tooltip: 'Punkte manuell anpassen',
                    onPressed: _adjustTournamentPoints,
                    color: Colors.green.shade700,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  if (_arePointsDistributed()) ...[
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
                            'Verteilt',
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
        ),
                 Row(
           children: [
             ElevatedButton.icon(
               onPressed: _generatePoints,
               icon: const Icon(Icons.stars),
               label: const Text('Punkte Generieren'),
               style: ElevatedButton.styleFrom(
                 backgroundColor: Colors.purple,
                 foregroundColor: Colors.white,
               ),
             ),
             const SizedBox(width: 8),
             ElevatedButton.icon(
               onPressed: _saveResults,
               icon: const Icon(Icons.save),
               label: const Text('Speichern'),
               style: ElevatedButton.styleFrom(
                 backgroundColor: Colors.green,
                 foregroundColor: Colors.white,
               ),
             ),
           ],
         ),
      ],
    );
  }





  Widget _buildResultsManagementArea() {
    return Row(
      children: [
        // Left Section - Available Teams
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.people, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Angemeldete Teams',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: availableTeams.length,
                    itemBuilder: (context, index) {
                      final team = availableTeams[index];
                      final teamColor = _getBundeslandColor(team.bundesland);
                      
                      return Draggable<Team>(
                        data: team,
                        feedback: Material(
                          elevation: 4,
                          child: Container(
                            width: 250,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: teamColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: teamColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: teamColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(
                                    Icons.sports_basketball,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        team.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        team.city,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        childWhenDragging: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade400,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(
                                  Icons.sports_basketball,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      team.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade500,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      team.city,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade400,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: teamColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(
                                  Icons.sports_basketball,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      team.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      team.city,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.drag_indicator, color: Colors.grey[400], size: 14),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Right Section - Rankings
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.emoji_events, color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Platzierungen',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: DragTarget<Team>(
                    onWillAccept: (data) => data != null,
                    onAccept: (team) {
                      setState(() {
                        if (!rankedTeams.contains(team)) {
                          rankedTeams.add(team);
                          availableTeams.remove(team);
                        }
                      });
                    },
                    builder: (context, candidateData, rejectedData) {
                      return ListView.builder(
                        itemCount: rankedTeams.length,
                        itemBuilder: (context, index) {
                          final team = rankedTeams[index];
                          final placement = index + 1;
                          return Draggable<Team>(
                            data: team,
                            feedback: Material(
                              elevation: 4,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getPlacementColor(placement),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$placement',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          team.name,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          team.city,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            childWhenDragging: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade500,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$placement',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        team.name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                      Text(
                                        team.city,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getPlacementColor(placement),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$placement',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: _getBundeslandColor(team.bundesland),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(
                                      Icons.sports_basketball,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          team.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          team.city,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Points Display
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.green.shade300),
                                    ),
                                    child: Text(
                                      '${_calculatePoints(placement, totalTeams: rankedTeams.length)} Pkt',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Up Arrow Button
                                  IconButton(
                                    onPressed: index > 0 ? () {
                                      setState(() {
                                        // Swap current team with the one above
                                        final temp = rankedTeams[index - 1];
                                        rankedTeams[index - 1] = rankedTeams[index];
                                        rankedTeams[index] = temp;
                                      });
                                    } : null,
                                    icon: Icon(
                                      Icons.arrow_upward, 
                                      color: index > 0 ? Colors.blue : Colors.grey,
                                      size: 20,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Nach oben verschieben',
                                  ),
                                  // Down Arrow Button
                                  IconButton(
                                    onPressed: index < rankedTeams.length - 1 ? () {
                                      setState(() {
                                        // Swap current team with the one below
                                        final temp = rankedTeams[index + 1];
                                        rankedTeams[index + 1] = rankedTeams[index];
                                        rankedTeams[index] = temp;
                                      });
                                    } : null,
                                    icon: Icon(
                                      Icons.arrow_downward, 
                                      color: index < rankedTeams.length - 1 ? Colors.blue : Colors.grey,
                                      size: 20,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Nach unten verschieben',
                                  ),
                                  // Remove Button
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        rankedTeams.remove(team);
                                        availableTeams.add(team);
                                      });
                                    },
                                    icon: const Icon(Icons.remove_circle, color: Colors.red, size: 16),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _getPlacementColor(int placement) {
    switch (placement) {
      case 1:
        return Colors.amber.shade700; // Gold
      case 2:
        return Colors.grey.shade600; // Silver
      case 3:
        return Colors.orange.shade700; // Bronze
      default:
        return Colors.grey.shade600;
    }
  }









  Color _getBundeslandColor(String bundesland) {
    return Colors.blue;
  }

  int _calculateBest3TotalPoints(List<Map<String, dynamic>> pointsHistory) =>
      computeBest3Points(pointsHistory);

  Future<void> _generatePoints() async {
    if (rankedTeams.isEmpty) {
      _showErrorToast('Keine Teams in der Platzierung. Bitte Teams hinzufÃƒÂ¼gen.');
      return;
    }

    try {
      setState(() => isLoading = true);
      
      // Update each ranked team with points
      for (int i = 0; i < rankedTeams.length; i++) {
        final team = rankedTeams[i];
        final placement = i + 1;
        final points = _calculatePoints(placement, totalTeams: rankedTeams.length);
        
        // Create points history entry
        final pointsEntry = {
          'tournamentId': widget.tournament.id,
          'tournamentName': widget.tournament.name,
          'placement': placement,
          'points': points,
          'date': DateTime.now().toIso8601String(),
          // category removed
        };
        
        // Update team's points history and total points
        final updatedPointsHistory = List<Map<String, dynamic>>.from(team.pointsHistory);
        
        // Remove any existing entry for this tournament
        updatedPointsHistory.removeWhere((entry) => entry['tournamentId'] == widget.tournament.id);
        
        // Add new entry
        updatedPointsHistory.add(pointsEntry);
        
        // Calculate new total points (only best 3 results count)
        final newTotalPoints = _calculateBest3TotalPoints(updatedPointsHistory);
        
        // Create updated team object with null safety
        final updatedTeam = Team(
          id: team.id,
          name: team.name,
          teamManager: team.teamManager,
          logoUrl: team.logoUrl,
          city: team.city,
          bundesland: team.bundesland,
          coachName: team.coachName,
          coachEmail: team.coachEmail,
          rosterPlayerIds: team.rosterPlayerIds,
          totalPoints: newTotalPoints,
          pointsHistory: updatedPointsHistory,
          createdAt: team.createdAt,
        );
        
        // Save to database
        try {
          await _teamService.updateTeam(team.id, updatedTeam);
          
          // Update local list
          rankedTeams[i] = updatedTeam;
        } catch (updateError) {
          throw Exception('Fehler beim Aktualisieren von Team ${team.name}: $updateError');
        }
      }
      
              if (mounted) {
          setState(() => isLoading = false);
        }
        _showSuccessToast('Punkte wurden erfolgreich generiert und gespeichert!');
      
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorToast('Fehler beim Generieren der Punkte: $e');
    }
  }

  Future<void> _saveResults() async {
    try {
      setState(() => isLoading = true);
      
      // Prepare results data for the current category
      List<Map<String, dynamic>> tournamentResults = [];
      
      for (int i = 0; i < rankedTeams.length; i++) {
        final team = rankedTeams[i];
        final placement = i + 1;
        final points = _calculatePoints(placement, totalTeams: rankedTeams.length);
        
        tournamentResults.add({
          'teamId': team.id,
          'teamName': team.name,
          'placement': placement,
          'points': points,
          'division': team.city,
          'city': team.city,
          'savedAt': DateTime.now().toIso8601String(),
        });
      }
      
      // Update tournament results
      final tournamentToUpdate = _currentTournament ?? widget.tournament;
      final currentResults = tournamentToUpdate.results != null 
          ? Map<String, List<Map<String, dynamic>>>.from(tournamentToUpdate.results!)
          : <String, List<Map<String, dynamic>>>{};
      // Single league - always use 'All' as key
      currentResults['All'] = tournamentResults;
      
      // Create updated tournament
      final updatedTournament = tournamentToUpdate.copyWith(
        results: currentResults,
      );
      
      // Save to database
      await _tournamentService.updateTournament(updatedTournament);
      
      // Update our current tournament reference
      _currentTournament = updatedTournament;
      
      setState(() => isLoading = false);
      _showSuccessToast('Ergebnisse erfolgreich gespeichert!');
      
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorToast('Fehler beim Speichern der Ergebnisse: $e');
    }
  }

  // Method to manually adjust tournament points
  Future<void> _adjustTournamentPoints() async {
    final TextEditingController pointsController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Turnierpunkte manuell anpassen'),
          content: TextField(
            controller: pointsController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Maximale Punkte',
              hintText: 'z.B. ${widget.tournament.teamIds.length} fÃƒÂ¼r dieses Turnier',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () async {
                final int? points = int.tryParse(pointsController.text);
                if (points != null && points > 0) {
                  try {
                    // Only update state if still mounted
                    if (!mounted) return;
                    setState(() => isLoading = true);
                    
                    // Create an updated tournament with new results
                    final updatedTournament = widget.tournament;
                    
                    // Update tournament in Firestore
                    await _tournamentService.updateTournament(updatedTournament);
                    
                    // Reload the tournament to get updated data
                    final latestTournament = await _tournamentService.getTournamentById(widget.tournament.id);
                    
                    // Check mounting status before updating
                    if (!mounted) return;
                    
                    if (latestTournament != null) {
                      // Update current tournament reference
                      _currentTournament = latestTournament;
                      
                      // Reload results to reflect changes
                      await _loadResults();
                      
                      // Show success toast if still mounted
                      if (mounted) {
                        _showSuccessToast('Turnierpunkte erfolgreich aktualisiert');
                      }
                    } else {
                      // Show error toast if still mounted
                      if (mounted) {
                        _showErrorToast('Fehler beim Aktualisieren des Turniers');
                      }
                    }
                    
                    // Close dialog if still mounted
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  } catch (e) {
                    // Show error toast if still mounted
                    if (mounted) {
                      _showErrorToast('Fehler: ${e.toString()}');
                    }
                  } finally {
                    // Reset loading state if still mounted
                    if (mounted) {
                      setState(() => isLoading = false);
                    }
                  }
                } else {
                  _showErrorToast('Bitte gÃƒÂ¼ltige Punktzahl eingeben');
                }
              },
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    );
  }
}

class TournamentResult {
  final String teamId;
  final String teamName;
  final int placement;
  final int points;

  TournamentResult({
    required this.teamId,
    required this.teamName,
    required this.placement,
    required this.points,
  });
} 
