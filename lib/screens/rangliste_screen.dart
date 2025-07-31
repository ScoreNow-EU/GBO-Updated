import 'package:flutter/material.dart';
import '../models/team.dart';
import '../services/team_service.dart';
import '../utils/responsive_helper.dart';
import '../utils/app_colors.dart';
import 'package:toastification/toastification.dart';

class RanglisteScreen extends StatefulWidget {
  const RanglisteScreen({super.key});

  @override
  State<RanglisteScreen> createState() => _RanglisteScreenState();
}

class _RanglisteScreenState extends State<RanglisteScreen> {
  final TeamService _teamService = TeamService();
  
  List<Team> allTeams = [];
  List<Team> filteredTeams = [];
  List<String> availableDivisions = [];
  String selectedDivision = '';
  bool isLoading = true;

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
      
      // Get unique divisions
      Set<String> divisionsSet = {};
      for (Team team in allTeams) {
        if (team.division.isNotEmpty) {
          divisionsSet.add(team.division);
        }
      }
      availableDivisions = divisionsSet.toList()..sort();
      
      // Set initial filter
      if (availableDivisions.isNotEmpty) {
        selectedDivision = availableDivisions.first;
      }
      
      _filterTeams();
      
    } catch (e) {
      _showErrorToast('Fehler beim Laden der Teams: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _filterTeams() {
    if (selectedDivision.isEmpty) {
      filteredTeams = List.from(allTeams);
    } else {
      filteredTeams = allTeams.where((team) => team.division == selectedDivision).toList();
    }
    
    // Sort by total points (descending)
    filteredTeams.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
    
    setState(() {});
  }

  void _onDivisionChanged(String division) {
    setState(() {
      selectedDivision = division;
    });
    _filterTeams();
  }

  Color _getDivisionColor(String division) {
    switch (division.toLowerCase()) {
      case 'men\'s seniors':
      case 'mens seniors':
        return Colors.blue;
      case 'women\'s seniors':
      case 'womens seniors':
        return Colors.pink;
      case 'men\'s u18':
      case 'mens u18':
        return Colors.green;
      case 'women\'s u18':
      case 'womens u18':
        return Colors.purple;
      case 'men\'s u16':
      case 'mens u16':
        return Colors.orange;
      case 'women\'s u16':
      case 'womens u16':
        return Colors.teal;
      case 'men\'s u14':
      case 'mens u14':
        return Colors.red;
      case 'women\'s u14':
      case 'womens u14':
        return Colors.indigo;
      case 'fun':
        return Colors.amber;
      default:
        return Colors.grey;
    }
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
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
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
          const Text(
            'Division auswählen:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableDivisions.map((division) {
              final isSelected = selectedDivision == division;
              final divisionColor = _getDivisionColor(division);
              
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
            'Keine Teams in dieser Division',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Es sind noch keine Teams für die ausgewählte Division verfügbar.',
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
    final divisionColor = _getDivisionColor(team.division);
    
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Placement Badge
            _buildPlacementBadge(placement),
            
            const SizedBox(width: 16),
            
            // Division Color Indicator
            Container(
              width: 6,
              height: 50,
              decoration: BoxDecoration(
                color: divisionColor,
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
                      color: divisionColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: divisionColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      team.division,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: divisionColor,
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
                    '${team.totalPoints} Pkt',
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
          ],
        ),
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
                  return _buildDefaultTeamIcon();
                },
              ),
            )
          : _buildDefaultTeamIcon(),
    );
  }

  Widget _buildDefaultTeamIcon() {
    return const Icon(
      Icons.sports_volleyball,
      color: AppColors.primaryColor,
      size: 28,
    );
  }
}