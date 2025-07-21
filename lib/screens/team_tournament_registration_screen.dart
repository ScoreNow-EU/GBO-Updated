import 'package:flutter/material.dart';
import '../models/tournament.dart';
import '../models/team.dart';
import '../services/tournament_service.dart';
import '../services/team_service.dart';
import '../services/team_manager_service.dart';
import '../services/custom_notification_service.dart';
import '../widgets/responsive_layout.dart';
import '../utils/responsive_helper.dart';
import 'package:toastification/toastification.dart';

class TeamTournamentRegistrationScreen extends StatefulWidget {
  final Team team;

  const TeamTournamentRegistrationScreen({
    super.key,
    required this.team,
  });

  @override
  State<TeamTournamentRegistrationScreen> createState() => _TeamTournamentRegistrationScreenState();
}

class _TeamTournamentRegistrationScreenState extends State<TeamTournamentRegistrationScreen> {
  final TournamentService _tournamentService = TournamentService();
  final TeamService _teamService = TeamService();
  final TeamManagerService _teamManagerService = TeamManagerService();
  final CustomNotificationService _notificationService = CustomNotificationService();
  
  bool _isLoading = false;
  String _selectedFilter = 'Verfügbar'; // Verfügbar, Angemeldet, Alle

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      selectedSection: 'teams',
      onSectionChanged: (section) {
        Navigator.of(context).pop();
      },
      title: 'Turnier-Anmeldung - ${widget.team.name}',
      showBackButton: true,
      onBackPressed: () => Navigator.of(context).pop(),
      body: _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveHelper.isMobile(screenWidth);
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTeamInfoCard(isMobile),
          SizedBox(height: isMobile ? 16 : 24),
          _buildFilterButtons(isMobile),
          SizedBox(height: isMobile ? 16 : 24),
          _buildTournamentsList(isMobile),
        ],
      ),
    );
  }

  Widget _buildTeamInfoCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
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
      child: Row(
        children: [
          // Team Avatar/Logo
          Container(
            width: isMobile ? 60 : 80,
            height: isMobile ? 60 : 80,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: widget.team.logoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        widget.team.logoUrl!,
                        width: isMobile ? 60 : 80,
                        height: isMobile ? 60 : 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.sports_volleyball,
                            size: isMobile ? 30 : 40,
                            color: Colors.blue.shade600,
                          );
                        },
                      ),
                    )
                  : Icon(
                      Icons.sports_volleyball,
                      size: isMobile ? 30 : 40,
                      color: Colors.blue.shade600,
                    ),
            ),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.team.name,
                  style: TextStyle(
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.team.city}, ${widget.team.bundesland}',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.team.division,
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 14,
                      color: Colors.purple.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButtons(bool isMobile) {
    final filters = ['Verfügbar', 'Angemeldet', 'Alle'];
    
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedFilter = filter;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  vertical: isMobile ? 12 : 16,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  filter,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? Colors.black87 : Colors.grey[600],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTournamentsList(bool isMobile) {
    return StreamBuilder<List<Tournament>>(
      stream: _getFilteredTournaments(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Fehler beim Laden der Turniere',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.red[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final tournaments = snapshot.data ?? [];

        if (tournaments.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.sports_volleyball,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _getEmptyStateMessage(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: tournaments.map((tournament) => _buildTournamentCard(tournament, isMobile)).toList(),
        );
      },
    );
  }

  Widget _buildTournamentCard(Tournament tournament, bool isMobile) {
    final isRegistered = tournament.isTeamRegistered(widget.team.id);
    final canRegister = tournament.canRegisterForDivision(widget.team.division, widget.team.division);
    final registeredCount = tournament.getRegisteredTeamsCount(widget.team.division);
    final maxTeams = tournament.getMaxTeamsForDivision(widget.team.division);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRegistered 
              ? Colors.green.shade300 
              : canRegister 
                  ? Colors.blue.shade300 
                  : Colors.grey.shade300,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
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
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tournament.location,
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (tournament.imageUrl != null)
                  Container(
                    width: isMobile ? 60 : 80,
                    height: isMobile ? 60 : 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        tournament.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: Icon(
                              Icons.sports_volleyball,
                              size: isMobile ? 30 : 40,
                              color: Colors.grey[400],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Tournament Info
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  tournament.dateString,
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${tournament.points} Punkte',
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 14,
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            
            if (tournament.divisions.contains(widget.team.division)) ...[
              const SizedBox(height: 12),
              
              // Division Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Division: ${widget.team.division}',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.purple.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Angemeldet: $registeredCount / $maxTeams Teams',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 14,
                        color: Colors.purple.shade700,
                      ),
                    ),
                    if (tournament.registrationDeadline != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Anmeldeschluss: ${tournament.registrationDeadline!.day}.${tournament.registrationDeadline!.month}.${tournament.registrationDeadline!.year}',
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 14,
                          color: Colors.purple.shade700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Action Button
              SizedBox(
                width: double.infinity,
                child: _buildActionButton(tournament, isRegistered, canRegister),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dieses Turnier akzeptiert keine Anmeldungen für ${widget.team.division}',
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(Tournament tournament, bool isRegistered, bool canRegister) {
    if (isRegistered) {
      return ElevatedButton.icon(
        onPressed: _isLoading ? null : () => _unregisterFromTournament(tournament),
        icon: _isLoading 
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.cancel),
        label: const Text('Anmeldung stornieren'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      );
    } else if (canRegister) {
      return ElevatedButton.icon(
        onPressed: _isLoading ? null : () => _registerForTournament(tournament),
        icon: _isLoading 
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.app_registration),
        label: const Text('Jetzt anmelden'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      );
    } else {
      String reason = 'Anmeldung nicht möglich';
      if (!tournament.isRegistrationOpen) {
        reason = 'Anmeldung geschlossen';
      } else if (tournament.registrationDeadline != null && 
                 DateTime.now().isAfter(tournament.registrationDeadline!)) {
        reason = 'Anmeldeschluss überschritten';
      } else if (tournament.getRegisteredTeamsCount(widget.team.division) >= 
                 tournament.getMaxTeamsForDivision(widget.team.division)) {
        reason = 'Division ist voll';
      }
      
      return ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.block),
        label: Text(reason),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade400,
          foregroundColor: Colors.grey.shade700,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      );
    }
  }

  Stream<List<Tournament>> _getFilteredTournaments() {
    switch (_selectedFilter) {
      case 'Verfügbar':
        return _tournamentService.getTournamentsForTeamRegistration(widget.team.division);
      case 'Angemeldet':
        return _tournamentService.getTournamentsForTeam(widget.team.id);
      case 'Alle':
      default:
        return _tournamentService.getTournamentsWithCache().map((tournaments) => 
            tournaments.where((tournament) => 
                tournament.divisions.contains(widget.team.division) ||
                tournament.isTeamRegistered(widget.team.id)
            ).toList());
    }
  }

  String _getEmptyStateMessage() {
    switch (_selectedFilter) {
      case 'Verfügbar':
        return 'Keine verfügbaren Turniere für Ihre Division gefunden.';
      case 'Angemeldet':
        return 'Sie sind noch zu keinem Turnier angemeldet.';
      case 'Alle':
      default:
        return 'Keine Turniere gefunden.';
    }
  }

  Future<void> _registerForTournament(Tournament tournament) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _tournamentService.registerTeamForTournament(
        tournament.id,
        widget.team.id,
        widget.team.division,
      );

      if (success) {
        // Send notification to team manager if one exists
        if (widget.team.teamManager != null) {
          // Get team manager's email
          final teamManager = await _teamManagerService.getTeamManagerByName(widget.team.teamManager!);
          if (teamManager != null) {
            await _notificationService.sendCustomNotification(
              title: 'Team hat sich für Turnier angemeldet',
              message: '${widget.team.name} hat sich für ${tournament.name} angemeldet.',
              userEmail: teamManager.email,
            );
          }
        }

        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          title: const Text('Anmeldung erfolgreich'),
          description: Text('${widget.team.name} wurde erfolgreich für ${tournament.name} angemeldet.'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 4),
          showProgressBar: false,
        );
      } else {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          title: const Text('Anmeldung fehlgeschlagen'),
          description: const Text('Die Anmeldung konnte nicht durchgeführt werden. Bitte versuchen Sie es erneut.'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 4),
          showProgressBar: false,
        );
      }
    } catch (e) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        title: const Text('Fehler'),
        description: Text('Ein Fehler ist aufgetreten: $e'),
        alignment: Alignment.topRight,
        autoCloseDuration: const Duration(seconds: 4),
        showProgressBar: false,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _unregisterFromTournament(Tournament tournament) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Anmeldung stornieren'),
        content: Text('Möchten Sie die Anmeldung von ${widget.team.name} für ${tournament.name} wirklich stornieren?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Stornieren', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _tournamentService.unregisterTeamFromTournament(
        tournament.id,
        widget.team.id,
      );

      if (success) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          title: const Text('Anmeldung storniert'),
          description: Text('Die Anmeldung von ${widget.team.name} für ${tournament.name} wurde storniert.'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 4),
          showProgressBar: false,
        );
      } else {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          title: const Text('Stornierung fehlgeschlagen'),
          description: const Text('Die Stornierung konnte nicht durchgeführt werden. Bitte versuchen Sie es erneut.'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 4),
          showProgressBar: false,
        );
      }
    } catch (e) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        title: const Text('Fehler'),
        description: Text('Ein Fehler ist aufgetreten: $e'),
        alignment: Alignment.topRight,
        autoCloseDuration: const Duration(seconds: 4),
        showProgressBar: false,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
} 