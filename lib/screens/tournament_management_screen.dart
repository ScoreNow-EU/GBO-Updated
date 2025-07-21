import 'package:flutter/material.dart';
import '../models/tournament.dart';
import '../services/tournament_service.dart';
import '../services/team_service.dart';
import '../utils/responsive_helper.dart';
import 'tournament_edit_screen.dart';
import 'package:toastification/toastification.dart';

class TournamentManagementScreen extends StatefulWidget {
  const TournamentManagementScreen({super.key});

  @override
  State<TournamentManagementScreen> createState() => _TournamentManagementScreenState();
}

class _TournamentManagementScreenState extends State<TournamentManagementScreen> {
  final TournamentService _tournamentService = TournamentService();
  final TeamService _teamService = TeamService();
  
  // Available divisions for filtering
  final List<String> _availableDivisions = [
    'Women\'s U14',
    'Women\'s U16', 
    'Women\'s U18',
    'Women\'s Seniors',
    'Women\'s FUN',
    'Men\'s U14',
    'Men\'s U16',
    'Men\'s U18', 
    'Men\'s Seniors',
    'Men\'s FUN',
  ];
  
  List<String> _selectedDivisions = [];
  Map<String, List<String>> _tournamentDivisions = {}; // tournamentId -> divisions
  
  // Collapsible sections state
  bool _isUpcomingExpanded = true;
  bool _isOngoingExpanded = true;
  bool _isCompletedExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadTournamentDivisions();
    _updateTournamentStatuses();
    _syncRefereeInvitations();
  }

  // Sync referee pending invitations count
  Future<void> _syncRefereeInvitations() async {
    try {
      await _tournamentService.syncAllRefereesPendingInvitationsCount();
    } catch (e) {
      print('Error syncing referee invitations: $e');
    }
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

                // Filter tournaments by selected divisions
                List<Tournament> filteredTournaments = snapshot.data!;
                if (_selectedDivisions.isNotEmpty) {
                  filteredTournaments = snapshot.data!.where((tournament) {
                    final tournamentDivisions = _tournamentDivisions[tournament.id] ?? [];
                    return _selectedDivisions.any((selectedDiv) => 
                        tournamentDivisions.contains(selectedDiv));
                  }).toList();
                }

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
        // Division Filter
        Container(
          constraints: const BoxConstraints(maxWidth: double.infinity),
          child: _buildDivisionFilterDropdown(),
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

  Widget _buildDesktopHeader() {
    return Row(
      children: [
        const Spacer(),
        // Division Filter Dropdown
        Container(
          constraints: const BoxConstraints(maxWidth: 280),
          child: _buildDivisionFilterDropdown(),
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
            final tournamentDivisions = _tournamentDivisions[tournament.id] ?? [];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildTournamentManagementCard(tournament, tournamentDivisions, isMobile),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTournamentManagementCard(Tournament tournament, List<String> divisions, bool isMobile) {
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${tournament.points} Punkte',
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
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
          isMobile ? _buildMobileDetails(tournament, divisions) : _buildDesktopDetails(tournament, divisions),
        ],
      ),
    );
  }

  Widget _buildMobileDetails(Tournament tournament, List<String> divisions) {
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
        const SizedBox(height: 12),
        // Divisions
        if (divisions.isNotEmpty) ...[
          _buildDivisionChips(divisions),
        ],
      ],
    );
  }

  Widget _buildDesktopDetails(Tournament tournament, List<String> divisions) {
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
        
        // Divisions column
        Expanded(
          flex: 3,
          child: divisions.isNotEmpty
              ? _buildDivisionChips(divisions)
              : Container(),
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

  Widget _buildDivisionChips(List<String> divisions) {
    if (divisions.isEmpty) {
      return Text(
        'Keine Teams',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: divisions.map((division) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _getDivisionColor(division).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _getDivisionColor(division).withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Text(
            division,
            style: TextStyle(
              color: _getDivisionColor(division).shade700,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
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
      MaterialPageRoute(builder: (context) => const TournamentEditScreen()),
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
                  // Reload divisions after deletion
                  _loadTournamentDivisions();
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

  void _loadTournamentDivisions() async {
    try {
      final teams = await _teamService.getTeams().first;
      final tournaments = await _tournamentService.getTournaments().first;
      
      Map<String, List<String>> tournamentDivs = {};
      
      for (Tournament tournament in tournaments) {
        Set<String> divisions = {};
        
        // Get divisions from teams in this tournament
        for (String teamId in tournament.teamIds) {
          try {
            final team = teams.firstWhere((t) => t.id == teamId);
            divisions.add(team.division);
          } catch (e) {
            // Team not found, skip it
            continue;
          }
        }
        
        tournamentDivs[tournament.id] = divisions.toList();
      }
      
      setState(() {
        _tournamentDivisions = tournamentDivs;
      });
    } catch (e) {
      print('Error loading tournament divisions: $e');
    }
  }

  Widget _buildDivisionFilterDropdown() {
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
          hint: Row(
            children: [
              Icon(Icons.filter_list, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                _selectedDivisions.isEmpty 
                    ? 'Alle Divisionen'
                    : '${_selectedDivisions.length} ausgewählt',
                style: TextStyle(
                  color: _selectedDivisions.isEmpty ? Colors.grey.shade600 : Colors.blue.shade700,
                  fontSize: 14,
                  fontWeight: _selectedDivisions.isEmpty ? FontWeight.normal : FontWeight.w500,
                ),
              ),
            ],
          ),
          items: [
            // "Alle auswählen" option
            DropdownMenuItem<String>(
              value: '__select_all__',
              child: Row(
                children: [
                  Icon(
                    _selectedDivisions.length == _availableDivisions.length 
                        ? Icons.check_box 
                        : Icons.check_box_outline_blank,
                    size: 16,
                    color: Colors.blue.shade600,
                  ),
                  const SizedBox(width: 8),
                  const Text('Alle auswählen', style: TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            // "Alle abwählen" option
            if (_selectedDivisions.isNotEmpty)
              DropdownMenuItem<String>(
                value: '__clear_all__',
                child: Row(
                  children: [
                    Icon(Icons.clear, size: 16, color: Colors.red.shade600),
                    const SizedBox(width: 8),
                    const Text('Alle abwählen', style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            // Divider
            const DropdownMenuItem<String>(
              value: '__divider__',
              enabled: false,
              child: Divider(height: 1),
            ),
            // Division options
            ..._availableDivisions.map((division) {
              final isSelected = _selectedDivisions.contains(division);
              return DropdownMenuItem<String>(
                value: division,
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 16,
                      color: isSelected ? _getDivisionColor(division).shade600 : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      division,
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected ? _getDivisionColor(division).shade700 : Colors.black87,
                        fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
          onChanged: (String? value) {
            if (value == null || value == '__divider__') return;
            
            setState(() {
              if (value == '__select_all__') {
                _selectedDivisions = List.from(_availableDivisions);
              } else if (value == '__clear_all__') {
                _selectedDivisions.clear();
              } else {
                if (_selectedDivisions.contains(value)) {
                  _selectedDivisions.remove(value);
                } else {
                  _selectedDivisions.add(value);
                }
              }
            });
          },
          icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          iconSize: 20,
          isExpanded: true,
        ),
      ),
    );
  }

  MaterialColor _getDivisionColor(String division) {
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
} 