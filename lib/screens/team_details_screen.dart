import 'package:flutter/material.dart';
import '../models/team.dart';
import '../models/player.dart';
import '../models/club.dart';
import '../services/player_service.dart';
import '../services/club_service.dart';
import '../utils/responsive_helper.dart';
import '../utils/app_colors.dart';
import 'package:toastification/toastification.dart';

class TeamDetailsScreen extends StatefulWidget {
  final Team team;

  const TeamDetailsScreen({
    super.key,
    required this.team,
  });

  @override
  State<TeamDetailsScreen> createState() => _TeamDetailsScreenState();
}

class _TeamDetailsScreenState extends State<TeamDetailsScreen> {
  final PlayerService _playerService = PlayerService();
  final ClubService _clubService = ClubService();
  
  Club? teamClub;
  List<Player> rosterPlayers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeamDetails();
  }

  Future<void> _loadTeamDetails() async {
    setState(() => isLoading = true);
    
    try {
      // Load club details if team has a club
      if (widget.team.clubId != null) {
        teamClub = await _clubService.getClub(widget.team.clubId!);
      }
      
      // Load roster players
      if (widget.team.rosterPlayerIds.isNotEmpty) {
        for (String playerId in widget.team.rosterPlayerIds) {
          final player = await _playerService.getPlayerById(playerId);
          if (player != null) {
            rosterPlayers.add(player);
          }
        }
      }
      
    } catch (e) {
      _showErrorToast('Fehler beim Laden der Team-Details: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showErrorToast(String message) {
    toastification.show(
      context: context,
      title: const Text('Fehler'),
      description: Text(message),
      type: ToastificationType.error,
      style: ToastificationStyle.fillColored,
      autoCloseDuration: const Duration(seconds: 5),
    );
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveHelper.isMobile(screenWidth);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          widget.team.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Team Header
                  _buildTeamHeader(),
                  const SizedBox(height: 24),
                  
                  // Team Information
                  _buildTeamInformation(),
                  const SizedBox(height: 24),
                  
                  // Club Information
                  if (teamClub != null) ...[
                    _buildClubInformation(),
                    const SizedBox(height: 24),
                  ],
                  
                  // Roster
                  if (rosterPlayers.isNotEmpty) ...[
                    _buildRosterSection(),
                    const SizedBox(height: 24),
                  ],
                  
                  // Tournament History
                  _buildTournamentHistory(),
                ],
              ),
            ),
    );
  }

  Widget _buildTeamHeader() {
    final divisionColor = _getDivisionColor(widget.team.division);
    
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          // Team Logo
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: AppColors.primaryColor.withOpacity(0.3),
                width: 3,
              ),
            ),
            child: widget.team.logoUrl != null && widget.team.logoUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(37),
                    child: Image.network(
                      widget.team.logoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildDefaultTeamIcon();
                      },
                    ),
                  )
                : _buildDefaultTeamIcon(),
          ),
          
          const SizedBox(width: 20),
          
          // Team Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.team.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: divisionColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: divisionColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    widget.team.division,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: divisionColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.team.city}, ${widget.team.bundesland}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Total Points
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.team.totalPoints} Pkt',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Gesamtpunkte',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamInformation() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Team Informationen',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildInfoRow('Team Manager', widget.team.teamManager ?? 'Nicht angegeben'),
          if (widget.team.coachName != null) _buildInfoRow('Trainer', widget.team.coachName!),
          if (widget.team.coachEmail != null) _buildInfoRow('Trainer E-Mail', widget.team.coachEmail!),
          _buildInfoRow('Erstellt am', '${widget.team.createdAt.day}.${widget.team.createdAt.month}.${widget.team.createdAt.year}'),
          _buildInfoRow('Turniere gespielt', '${widget.team.pointsHistory.length}'),
        ],
      ),
    );
  }

  Widget _buildClubInformation() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verein',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildInfoRow('Name', teamClub!.name),
          _buildInfoRow('Standort', '${teamClub!.city}, ${teamClub!.bundesland}'),
          if (teamClub!.contactEmail != null) _buildInfoRow('E-Mail', teamClub!.contactEmail!),
          if (teamClub!.contactPhone != null) _buildInfoRow('Telefon', teamClub!.contactPhone!),
          if (teamClub!.website != null) _buildInfoRow('Website', teamClub!.website!),
        ],
      ),
    );
  }

  Widget _buildRosterSection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kader (${rosterPlayers.length} Spieler)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          ...rosterPlayers.map((player) => _buildPlayerCard(player)),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(Player player) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Player Avatar
          Container(
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
            child: const Icon(
              Icons.person,
              color: AppColors.primaryColor,
              size: 28,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Player Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${player.firstName} ${player.lastName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                if (player.position != null) ...[
                  Text(
                    'Position: ${player.position}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                if (player.jerseyNumber != null) ...[
                  Text(
                    'Trikotnummer: ${player.jerseyNumber}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  'E-Mail: ${player.email}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentHistory() {
    final sortedResults = List<Map<String, dynamic>>.from(widget.team.pointsHistory);
    sortedResults.sort((a, b) {
      final pointsA = a['points'] as int? ?? 0;
      final pointsB = b['points'] as int? ?? 0;
      return pointsB.compareTo(pointsA); // Descending order
    });

    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Turnier Historie',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          if (sortedResults.isEmpty)
            Text(
              'Noch keine Turniere gespielt',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ...sortedResults.asMap().entries.map((entry) {
              final index = entry.key;
              final result = entry.value;
              final isTop3 = index < 3;
              
              return Column(
                children: [
                  _buildTournamentResult(result, index + 1, isTop3),
                  if (index == 2 && sortedResults.length > 3) ...[
                    const SizedBox(height: 12),
                    Container(
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
                    const SizedBox(height: 12),
                  ],
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTournamentResult(Map<String, dynamic> result, int rank, bool isTop3) {
    final points = result['points'] as int? ?? 0;
    final tournamentName = result['tournamentName'] as String? ?? 'Unbekanntes Turnier';
    final placement = result['placement'] as int? ?? 0;
    final date = result['date'] as String? ?? '';
    
    return Container(
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
                rank.toString(),
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
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultTeamIcon() {
    return const Icon(
      Icons.sports_volleyball,
      color: AppColors.primaryColor,
      size: 40,
    );
  }
} 