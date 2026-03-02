import 'package:flutter/material.dart';
import '../models/tournament.dart';
import '../models/user.dart' as app_user;
import '../services/tournament_service.dart';
import '../services/team_service.dart';
import '../utils/responsive_helper.dart';
import 'tournament_edit_screen.dart';
import 'tournament_creation_wizard.dart';
import 'package:toastification/toastification.dart';

class TournamentManagementScreen extends StatefulWidget {
  final app_user.User? currentUser;
  
  const TournamentManagementScreen({super.key, this.currentUser});

  @override
  State<TournamentManagementScreen> createState() => _TournamentManagementScreenState();
}

class _TournamentManagementScreenState extends State<TournamentManagementScreen> {
  final TournamentService _tournamentService = TournamentService();
  final TeamService _teamService = TeamService();
  
  String _selectedSeason = '2026'; // Default to 2026 season
  
  // Collapsible sections state
  bool _isUpcomingExpanded = true;
  bool _isOngoingExpanded = true;
  bool _isCompletedExpanded = true;

  @override
  void initState() {
    super.initState();
    _updateTournamentStatuses();
  }
  
  // Update tournament statuses based on current date
  Future<void> _updateTournamentStatuses() async {
    try {
      await _tournamentService.updateTournamentStatuses();
    } catch (e) {
      // Silently handle errors - don't show error to user for background update
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
          // Header with responsive layout
          isMobile ? _buildMobileHeader() : _buildDesktopHeader(),
          const SizedBox(height: 12),

          // Tournament List
          Expanded(
            child: StreamBuilder<List<Tournament>>(
              stream: _tournamentService.getTournamentsWithCache(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'Keine Turniere gefunden.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                // Check if user is admin or series organizer
                final isAdminOrOrganizer = widget.currentUser != null && 
                    (widget.currentUser!.roles.contains(app_user.UserRole.admin) ||
                     widget.currentUser!.roles.contains(app_user.UserRole.seriesOrganizer));
                
                // Filter tournaments by season
                List<Tournament> filteredTournaments = snapshot.data!.where((tournament) {
                  // Filter out pending/rejected tournaments for non-admins
                  if (!isAdminOrOrganizer && tournament.approvalStatus != 'approved') {
                    return false;
                  }
                  
                  // Filter by season
                  if (tournament.season != _selectedSeason) {
                    return false;
                  }
                  
                  return true;
                }).toList();

                return _buildTournamentDataTable(filteredTournaments, MediaQuery.of(context).size.width);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Season Filter
        Container(
          constraints: const BoxConstraints(maxWidth: double.infinity),
          child: _buildSeasonDropdown(),
        ),
        const SizedBox(height: 12),
        // New Tournament Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _createNewTournament(),
            icon: const Icon(Icons.add),
            label: const Text('Neues Turnier'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _migrateToSeason2025() async {
    if (!mounted) return;
    
    try {
      final count = await _tournamentService.migrateToSeason2025();
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count Turniere zur Saison 2025 migriert'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fehler bei der Migration'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSeasonDropdown() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSeason,
          items: const [
            DropdownMenuItem(
              value: '2025',
              child: Text('Saison 2025'),
            ),
            DropdownMenuItem(
              value: '2026',
              child: Text('Saison 2026'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedSeason = value;
              });
            }
          },
          icon: Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
          isExpanded: true,
        ),
      ),
    );
  }

  Widget _buildDesktopHeader() {
    return Row(
      children: [
        const Spacer(),
        // Season Filter Dropdown
        Container(
          constraints: const BoxConstraints(maxWidth: 200),
          child: _buildSeasonDropdown(),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: () => _createNewTournament(),
          icon: const Icon(Icons.add),
          label: const Text('Neues Turnier'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black87,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildTournamentDataTable(List<Tournament> tournaments, double screenWidth) {
    final isMobile = ResponsiveHelper.isMobile(screenWidth);
    
    // Group tournaments by status
    List<Tournament> upcomingTournaments = tournaments
        .where((t) => t.status == 'upcoming')
        .toList();
    List<Tournament> ongoingTournaments = tournaments
        .where((t) => t.status == 'ongoing')
        .toList();
    List<Tournament> completedTournaments = tournaments
        .where((t) => t.status == 'completed')
        .toList();
    
    return ListView(
      children: [
        // Completed Tournaments Section
        if (completedTournaments.isNotEmpty)
          _buildCollapsibleSection(
            title: 'Abgeschlossene Turniere',
            icon: Icons.check_circle,
            color: Colors.grey,
            count: completedTournaments.length,
            isExpanded: _isCompletedExpanded,
            onToggle: (expanded) => setState(() => _isCompletedExpanded = expanded),
            tournaments: completedTournaments,
            isMobile: isMobile,
          ),
        
        // Ongoing Tournaments Section
        if (ongoingTournaments.isNotEmpty)
          _buildCollapsibleSection(
            title: 'Laufende Turniere',
            icon: Icons.play_circle,
            color: Colors.green,
            count: ongoingTournaments.length,
            isExpanded: _isOngoingExpanded,
            onToggle: (expanded) => setState(() => _isOngoingExpanded = expanded),
            tournaments: ongoingTournaments,
            isMobile: isMobile,
          ),
        
        // Upcoming Tournaments Section
        if (upcomingTournaments.isNotEmpty)
          _buildCollapsibleSection(
            title: 'Bevorstehende Turniere',
            icon: Icons.schedule,
            color: Colors.blue,
            count: upcomingTournaments.length,
            isExpanded: _isUpcomingExpanded,
            onToggle: (expanded) => setState(() => _isUpcomingExpanded = expanded),
            tournaments: upcomingTournaments,
            isMobile: isMobile,
          ),
      ],
    );
  }

  Widget _buildCollapsibleSection({
    required String title,
    required IconData icon,
    required Color color,
    required int count,
    required bool isExpanded,
    required ValueChanged<bool> onToggle,
    required List<Tournament> tournaments,
    required bool isMobile,
  }) {
    return Column(
      children: [
        ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.only(bottom: 16),
          initiallyExpanded: isExpanded,
          onExpansionChanged: onToggle,
          leading: Icon(icon, color: color, size: 20),
          title: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  height: 1,
                  color: color.withOpacity(0.3),
                ),
              ),
            ],
          ),
          subtitle: Text(
            '$count Turnier${count == 1 ? '' : 'e'}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          children: tournaments.map((tournament) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildTournamentManagementCard(tournament, isMobile),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTournamentManagementCard(Tournament tournament, bool isMobile) {
    // Get status colors for the card border
    Color borderColor;
    switch (tournament.status) {
      case 'upcoming':
        borderColor = Colors.blue.shade600;
        break;
      case 'ongoing':
        borderColor = Colors.green.shade600;
        break;
      case 'completed':
        borderColor = Colors.grey.shade500;
        break;
      default:
        borderColor = Colors.grey.shade300;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: borderColor,
          width: 3,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with tournament name and action buttons
          Row(
            children: [
              // Tournament Logo
              Container(
                width: 60,
                height: 45,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: tournament.imageUrl != null && tournament.imageUrl!.isNotEmpty
                      ? Image.network(
                          tournament.imageUrl!,
                          width: 60,
                          height: 45,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildGeneratedImage(tournament);
                          },
                        )
                      : _buildGeneratedImage(tournament),
                ),
              ),
              const SizedBox(width: 16),
              // Tournament name and status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tournament.name,
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildProminentStatusBadge(tournament.status),
                        // Show approval status badge for admins
                        if (tournament.approvalStatus == 'pending_approval')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.shade300, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.pending, size: 14, color: Colors.orange.shade700),
                                const SizedBox(width: 4),
                                Text(
                                  'Entwurf',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (tournament.approvalStatus == 'rejected')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade300, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cancel, size: 14, color: Colors.red.shade700),
                                const SizedBox(width: 4),
                                Text(
                                  'Abgelehnt',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                      ],
                    ),
                  ],
                ),
              ),
              // Action buttons - responsive
              isMobile ? 
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editTournament(tournament);
                    } else if (value == 'delete') {
                      _deleteTournament(tournament);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Text('Bearbeiten'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Löschen'),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.more_vert, color: Colors.grey),
                  ),
                ) :
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _editTournament(tournament),
                        tooltip: 'Bearbeiten',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteTournament(tournament),
                        tooltip: 'Löschen',
                      ),
                    ),
                  ],
                ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Tournament details in responsive layout
          isMobile ? _buildMobileDetails(tournament) : _buildDesktopDetails(tournament),
        ],
      ),
    );
  }

  Widget _buildMobileDetails(Tournament tournament) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date and location
        Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                tournament.dateString,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                tournament.location,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopDetails(Tournament tournament) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date and location column
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tournament.dateString,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tournament.location,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGeneratedImage(Tournament tournament) {
    // Generate colors based on tournament name
    int nameHash = tournament.name.hashCode;
    
    List<Color> colors = [
      Color((nameHash & 0xFF6B73FF) | 0xFF000000),
      Color((nameHash & 0xFF4ECDC4) | 0xFF000000),
      Color((nameHash & 0xFF45B7D1) | 0xFF000000),
    ];
    
    return Container(
      width: 60,
      height: 45,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors.take(2).toList(),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          tournament.name.isNotEmpty ? tournament.name[0].toUpperCase() : 'T',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildProminentStatusBadge(String status) {
    MaterialColor color;
    String label;
    IconData icon;
    
    switch (status) {
      case 'upcoming':
        color = Colors.blue;
        label = 'Geplant';
        icon = Icons.schedule;
        break;
      case 'ongoing':
        color = Colors.green;
        label = 'Aktiv';
        icon = Icons.play_circle;
        break;
      case 'completed':
        color = Colors.grey;
        label = 'Beendet';
        icon = Icons.check_circle;
        break;
      default:
        color = Colors.grey;
        label = status;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.shade600,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.shade800,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _createNewTournament() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TournamentCreationWizard()),
    );
  }

  void _editTournament(Tournament tournament) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TournamentEditScreen(tournament: tournament),
      ),
    );
  }

  void _deleteTournament(Tournament tournament) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Turnier löschen'),
          content: Text('Sind Sie sicher, dass Sie "${tournament.name}" löschen möchten?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _tournamentService.deleteTournament(tournament.id);
                  Navigator.of(context).pop();
                  toastification.show(
                    context: context,
                    type: ToastificationType.success,
                    style: ToastificationStyle.fillColored,
                    title: const Text('Erfolg'),
                    description: const Text('Turnier erfolgreich gelöscht'),
                    alignment: Alignment.topRight,
                    autoCloseDuration: const Duration(seconds: 3),
                    showProgressBar: false,
                  );
                  // Reload after deletion
                } catch (e) {
                  Navigator.of(context).pop();
                  toastification.show(
                    context: context,
                    type: ToastificationType.error,
                    style: ToastificationStyle.fillColored,
                    title: const Text('Fehler'),
                    description: Text('Fehler beim Löschen: $e'),
                    alignment: Alignment.topRight,
                    autoCloseDuration: const Duration(seconds: 4),
                    showProgressBar: false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Löschen', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
} 