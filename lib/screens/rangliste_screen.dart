import 'package:flutter/material.dart';
import '../models/team.dart';
import '../services/team_service.dart';
import '../utils/responsive_helper.dart';
import '../utils/app_colors.dart';
import 'package:toastification/toastification.dart';
import 'team_details_screen.dart';

class RanglisteScreen extends StatefulWidget {
  const RanglisteScreen({super.key});

  @override
  State<RanglisteScreen> createState() => _RanglisteScreenState();
}

class _RanglisteScreenState extends State<RanglisteScreen> {
  final TeamService _teamService = TeamService();
  
  List<Team> allTeams = [];
  List<Team> filteredTeams = [];
  String selectedSeason = DateTime.now().year.toString();
  bool isLoading = true;
  Set<String> expandedTeams = {}; // Track which teams are expanded
  bool _seasonAutoDetected = false;

  // Available seasons - dynamically populated from data
  List<String> availableSeasons = [];

  void _openDrawer() {
    // Find the parent Scaffold and open its drawer
    final scaffoldState = Scaffold.of(context);
    if (scaffoldState.hasDrawer) {
      scaffoldState.openDrawer();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    setState(() => isLoading = true);
    
    try {
      // Load all teams
      allTeams = await _teamService.getAllTeams();
      
      // Build available seasons from data and auto-detect current season
      _buildAvailableSeasons();
      if (!_seasonAutoDetected) {
        _autoDetectSeason();
        _seasonAutoDetected = true;
      }
      
      _filterTeams();
      
    } catch (e) {
      _showErrorToast('Fehler beim Laden der Teams: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// Build the list of available seasons from all teams' pointsHistory dates
  void _buildAvailableSeasons() {
    final Set<String> years = {};
    final currentYear = DateTime.now().year.toString();
    
    for (final team in allTeams) {
      for (final entry in team.pointsHistory) {
        final dateStr = entry['date'] as String? ?? '';
        if (dateStr.isEmpty) continue;
        try {
          final date = DateTime.parse(dateStr);
          years.add(date.year.toString());
        } catch (_) {}
      }
    }
    
    // Always include the current year
    years.add(currentYear);
    
    // Sort descending (newest first)
    availableSeasons = years.toList()..sort((a, b) => b.compareTo(a));
  }

  /// Auto-detect which season to show:
  /// If any points exist in the current year, show current year.
  /// Otherwise, show the previous year.
  void _autoDetectSeason() {
    final currentYear = DateTime.now().year;
    final currentYearStr = currentYear.toString();
    
    // Check if any team has points in the current year
    final hasCurrentYearPoints = allTeams.any((team) {
      return team.pointsHistory.any((entry) {
        final dateStr = entry['date'] as String? ?? '';
        if (dateStr.isEmpty) return false;
        try {
          return DateTime.parse(dateStr).year == currentYear;
        } catch (_) {
          return false;
        }
      });
    });
    
    if (hasCurrentYearPoints) {
      selectedSeason = currentYearStr;
    } else {
      // Fall back to previous year if it exists in available seasons
      final previousYear = (currentYear - 1).toString();
      if (availableSeasons.contains(previousYear)) {
        selectedSeason = previousYear;
      } else {
        // If no previous year data either, use the most recent available
        selectedSeason = availableSeasons.isNotEmpty ? availableSeasons.first : currentYearStr;
      }
    }
  }

  void _onSeasonChanged(String season) {
    setState(() {
      selectedSeason = season;
    });
    _filterTeams();
  }

  void _filterTeams() {
    // Filter teams by season first
    List<Team> seasonFilteredTeams = allTeams.where((team) {
      // Check if team has any tournament results from the selected season
      return team.pointsHistory.any((result) {
        final tournamentDate = result['date'] as String? ?? '';
        if (tournamentDate.isEmpty) return false;
        
        try {
          final date = DateTime.parse(tournamentDate);
          return date.year.toString() == selectedSeason;
        } catch (e) {
          return false;
        }
      });
    }).toList();

    filteredTeams = seasonFilteredTeams.where((team) => team.pointsHistory.isNotEmpty).toList();
    
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

  void _toggleTeamExpansion(String teamId) {
    setState(() {
      if (expandedTeams.contains(teamId)) {
        expandedTeams.remove(teamId);
      } else {
        expandedTeams.add(teamId);
      }
    });
  }

  List<Map<String, dynamic>> _getSortedTournamentResults(Team team) {
    // Sort tournament results by points (descending)
    final sortedResults = List<Map<String, dynamic>>.from(team.pointsHistory);
    sortedResults.sort((a, b) {
      final pointsA = a['points'] as int? ?? 0;
      final pointsB = b['points'] as int? ?? 0;
      return pointsB.compareTo(pointsA); // Descending order
    });
    return sortedResults;
  }

  void _navigateToTeamDetails(Team team) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TeamDetailsScreen(team: team),
      ),
    );
  }

  void _showErrorToast(String message) {
    toastification.show(
      context: context,
      title: Text('Fehler'),
      description: Text(message),
      type: ToastificationType.error,
      style: ToastificationStyle.fillColored,
      autoCloseDuration: const Duration(seconds: 5),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = ResponsiveHelper.isTablet(screenWidth);
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final isMobile = screenWidth < 768;
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: (isIOS || isMobile) ? AppBar(
        title: const Text(
          'Rangliste',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black87),
          onPressed: _openDrawer,
        ),
      ) : AppBar(
        title: const Text(
          'Rangliste',
          style: TextStyle(
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
            // Season Filter
            _buildSeasonFilter(),
          
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

  Widget _buildSeasonFilter() {
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
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Rangliste $selectedSeason',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButton<String>(
              value: selectedSeason,
              underline: Container(),
              items: availableSeasons.map((season) {
                return DropdownMenuItem<String>(
                  value: season,
                  child: Text(
                    'Saison $season',
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  _onSeasonChanged(value);
                }
              },
            ),
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
            'Keine Teams in Saison $selectedSeason',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Es sind noch keine Teams verfügbar, die in der Saison $selectedSeason an Turnieren teilgenommen haben.',
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
        
        return _buildTeamCard(team, placement, isTablet);
      },
    );
  }

  Widget _buildTeamCard(Team team, int placement, bool isTablet) {
    final categoryColor = AppColors.primaryColor;
    final isExpanded = expandedTeams.contains(team.id);
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    if (isIOS || isMobile) {
      return _buildIOSTeamCard(team, placement, categoryColor, isExpanded);
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main Team Card (Clickable)
          InkWell(
            onTap: () => _toggleTeamExpansion(team.id),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Placement Badge
                  _buildPlacementBadge(placement),
                  
                  const SizedBox(width: 16),
                  
                  // Color Indicator
                  Container(
                    width: 6,
                    height: 50,
                    decoration: BoxDecoration(
                      color: categoryColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Team Logo/Avatar
                  _buildTeamAvatar(team),
                  
                  const SizedBox(width: 16),
                  
                  // Team Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          team.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${team.city}, ${team.bundesland}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: categoryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: categoryColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            team.city,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: categoryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Points Display
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_calculateBest3TotalPoints(team.pointsHistory)} Pkt',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${team.pointsHistory.length} Turniere',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  
                  // Expand/Collapse Icon
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade600,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          
          // Expanded Content
          if (isExpanded) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Team Details Button
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _navigateToTeamDetails(team),
                          icon: const Icon(Icons.info_outline, size: 16),
                          label: const Text('Team Details'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Tournament Results
                  Text(
                    'Turnier Ergebnisse (Sortiert nach Punkten)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  _buildTournamentResultsList(team),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlacementBadge(int placement) {
    Color badgeColor;
    IconData? icon;
    
    switch (placement) {
      case 1:
        badgeColor = const Color(0xFFFFD700); // Gold
        icon = Icons.emoji_events;
        break;
      case 2:
        badgeColor = const Color(0xFFC0C0C0); // Silver
        icon = Icons.emoji_events;
        break;
      case 3:
        badgeColor = const Color(0xFFCD7F32); // Bronze
        icon = Icons.emoji_events;
        break;
      default:
        badgeColor = AppColors.primaryColor;
        break;
    }
    
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: badgeColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: badgeColor.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: icon != null
            ? Icon(
                icon,
                color: Colors.white,
                size: 24,
              )
            : Text(
                placement.toString(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildTeamAvatar(Team team) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: AppColors.primaryColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: team.logoUrl != null && team.logoUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(23),
              child: Image.network(
                team.logoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildGeneratedTeamLogo(team);
                },
              ),
            )
          : _buildGeneratedTeamLogo(team),
    );
  }

  Widget _buildDefaultTeamIcon() {
    return const Icon(
      Icons.sports_handball,
      color: AppColors.primaryColor,
      size: 28,
    );
  }

  Widget _buildGeneratedTeamLogo(Team team) {
    // Generate initials from team name
    final words = team.name.split(' ');
    String initials = '';
    
    if (words.length >= 2) {
      initials = '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (words.isNotEmpty) {
      initials = words[0].substring(0, words[0].length > 2 ? 2 : words[0].length).toUpperCase();
    }
    
    final categoryColor = AppColors.primaryColor;
    
    return Container(
      decoration: BoxDecoration(
        color: categoryColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: categoryColor.withOpacity(0.6),
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: categoryColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildIOSTeamCard(Team team, int placement, Color categoryColor, bool isExpanded) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Main Team Card (Clickable)
          InkWell(
            onTap: () => _toggleTeamExpansion(team.id),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Placement Badge (smaller for iOS)
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: placement <= 3 ? Colors.amber : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        '$placement',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: placement <= 3 ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Team Logo/Avatar (smaller for iOS)
                  Container(
                    width: 40,
                    height: 40,
                    child: team.logoUrl != null && team.logoUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.network(
                              team.logoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildGeneratedTeamLogo(team);
                              },
                            ),
                          )
                        : _buildGeneratedTeamLogo(team),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Team Info (compact for iOS)
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${team.city}, ${team.bundesland}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: categoryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            team.city,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: categoryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Points Display (compact for iOS)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_calculateBest3TotalPoints(team.pointsHistory)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${team.pointsHistory.length}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  
                  // Expand/Collapse Icon
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade600,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          
          // Expanded Content for iOS
          if (isExpanded) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Team Details Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToTeamDetails(team),
                      icon: const Icon(Icons.info_outline, size: 16),
                      label: const Text('Team Details'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Tournament Results
                  Text(
                    'Turnierergebnisse',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Tournament Results List (compact for iOS)
                  _buildIOSTournamentResultsList(team),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIOSTournamentResultsList(Team team) {
    final sortedResults = _getSortedTournamentResults(team);
    
    if (sortedResults.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          'Noch keine Turniere gespielt',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: [
        ...sortedResults.asMap().entries.map((entry) {
          final index = entry.key;
          final result = entry.value;
          final points = result['points'] as int? ?? 0;
          final tournamentName = result['tournamentName'] as String? ?? 'Unbekanntes Turnier';
          final placement = result['placement'] as int? ?? 0;
          final date = result['date'] as String? ?? '';
          final isTop3 = index < 3;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isTop3 ? Colors.blue.shade50 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isTop3 ? Colors.blue.shade200 : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                // Rank
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isTop3 ? Colors.blue : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      (index + 1).toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Tournament Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tournamentName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$date â€¢ Platz $placement',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Points
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isTop3 ? Colors.blue : Colors.grey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$points Pkt',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        
        // Divider after top 3
        if (sortedResults.length > 3) ...[
          const SizedBox(height: 8),
          Container(
            height: 1,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 8),
          Text(
            'Nur die besten 3 Turniere zählen zur Gesamtwertung',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildTournamentResultsList(Team team) {
    final sortedResults = _getSortedTournamentResults(team);
    
    if (sortedResults.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          'Noch keine Turniere gespielt',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: sortedResults.asMap().entries.map((entry) {
        final index = entry.key;
        final result = entry.value;
        final points = result['points'] as int? ?? 0;
        final tournamentName = result['tournamentName'] as String? ?? 'Unbekanntes Turnier';
        final placement = result['placement'] as int? ?? 0;
        final date = result['date'] as String? ?? '';
        final isTop3 = index < 3;
        
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isTop3 ? Colors.blue.shade50 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isTop3 ? Colors.blue.shade200 : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  // Rank
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: isTop3 ? Colors.blue : Colors.grey,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Center(
                      child: Text(
                        (index + 1).toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Tournament Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tournamentName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Platzierung: $placement',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (date.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Datum: $date',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Points
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isTop3 ? Colors.blue : Colors.grey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$points Pkt',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Divider after top 3 results
            if (index == 2 && sortedResults.length > 3) ...[
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                height: 1,
                color: Colors.grey.shade300,
                child: const Center(
                  child: Text(
                    'Nur die besten 3 Ergebnisse zählen zur Rangliste',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      }).toList(),
    );
  }
}