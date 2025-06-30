import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../models/team.dart';
import '../models/tournament.dart';
import '../services/team_service.dart';
import '../services/tournament_service.dart';
import '../widgets/responsive_layout.dart';
import 'roster_creation_screen.dart';

class TeamDetailScreen extends StatefulWidget {
  final String teamId;
  final String subSection;
  
  const TeamDetailScreen({super.key, required this.teamId, this.subSection = 'overview'});

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  final TeamService _teamService = TeamService();
  Team? _team;
  bool _isLoading = true;
  late String _selectedSubSection;

  @override
  void initState() {
    super.initState();
    _selectedSubSection = widget.subSection;
    _loadTeam();
  }

  Future<void> _loadTeam() async {
    try {
      final team = await _teamService.getTeamById(widget.teamId);
      if (mounted) {
        setState(() {
          _team = team;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading team: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return ResponsiveLayout(
        selectedSection: 'team_${widget.teamId}_${widget.subSection}',
        onSectionChanged: (section) {},
        title: 'Team wird geladen...',
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_team == null) {
      return ResponsiveLayout(
        selectedSection: 'team_${widget.teamId}_${widget.subSection}',
        onSectionChanged: (section) {},
        title: 'Team nicht gefunden',
        body: const Center(
          child: Text('Team konnte nicht geladen werden'),
        ),
      );
    }

    return ResponsiveLayout(
      selectedSection: 'team_${widget.teamId}_${widget.subSection}',
      onSectionChanged: (section) {
        // Navigation is handled by the parent HomeScreen
      },
      title: _getScreenTitle(),
      body: _getContentForSection(_selectedSubSection),
    );
  }

  String _getScreenTitle() {
    final sectionName = _getSectionName(_selectedSubSection);
    return '${_team!.name} - $sectionName';
  }

  String _getSectionName(String section) {
    switch (section) {
      case 'overview':
        return 'Übersicht';
      case 'tournaments':
        return 'Turnier Anmeldung';
      case 'roster':
        return 'Kader Verwaltung';
      case 'settings':
        return 'Einstellungen';
      default:
        return 'Übersicht';
    }
  }

  Widget _getContentForSection(String section) {
    switch (section) {
      case 'overview':
        return _buildOverviewContent();
      case 'tournaments':
        return _buildTournamentRegistrationContent();
      case 'roster':
        return _buildRosterManagementContent();
      case 'settings':
        return _buildSettingsContent();
      default:
        return _buildOverviewContent();
    }
  }

  Widget _buildOverviewContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Team Info Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D5016),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Icon(
                      Icons.group,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _team!.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFffd665),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _team!.division,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_team!.city}, ${_team!.bundesland}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Header
          Row(
            children: [
              const Icon(Icons.dashboard, color: Colors.black87),
              const SizedBox(width: 8),
              const Text(
                'Team Übersicht',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Stats Cards
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.sports_volleyball, size: 32, color: Colors.blue),
                        const SizedBox(height: 8),
                        const Text(
                          '12',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        Text(
                          'Turniere gespielt',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.emoji_events, size: 32, color: Colors.green),
                        const SizedBox(height: 8),
                        const Text(
                          '8',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          'Siege',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Recent Results
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Letzte Ergebnisse',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildResultItem('vs. Beach Warriors', '2:1', true, '15.03.2024'),
                  _buildResultItem('vs. Sand Kings', '1:2', false, '12.03.2024'),
                  _buildResultItem('vs. Volleyball Pros', '2:0', true, '08.03.2024'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(String opponent, String score, bool won, String date) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: won ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: won ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            won ? Icons.check_circle : Icons.cancel,
            color: won ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              opponent,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            score,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: won ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            date,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentRegistrationContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sports_volleyball, color: Colors.black87),
              const SizedBox(width: 8),
              const Text(
                'Turnier Anmeldung',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Team Division Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.category,
                      color: Colors.purple.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Division: ${_team!.division}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sie können sich nur für Turniere in Ihrer Division anmelden.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Available Tournaments
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Verfügbare Turniere',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  StreamBuilder<List<Tournament>>(
                    stream: _getAvailableTournamentsStream(),
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
                                const Text(
                                  'Fehler beim Laden der Turniere',
                                  style: TextStyle(fontSize: 16),
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
                                const Text(
                                  'Keine verfügbaren Turniere für Ihre Division gefunden.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: tournaments.map((tournament) => _buildRealTournamentItem(tournament)).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Registered Tournaments
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Angemeldete Turniere',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  StreamBuilder<List<Tournament>>(
                    stream: TournamentService().getTournamentsForTeam(_team!.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
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
                                  Icons.event_busy,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Sie sind noch zu keinem Turnier angemeldet.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: tournaments.map((tournament) => _buildRegisteredTournamentItem(tournament)).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentItem(String name, String date, String location) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text('Datum: $date', style: TextStyle(color: Colors.grey[600])),
          Text('Ort: $location', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 12),
                      ElevatedButton(
              onPressed: () {
                toastification.show(
                  context: context,
                  type: ToastificationType.success,
                  style: ToastificationStyle.fillColored,
                  title: Text('Anmeldung für $name gestartet'),
                  autoCloseDuration: const Duration(seconds: 3),
                );
              },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D5016),
              foregroundColor: Colors.white,
            ),
            child: const Text('Anmelden'),
          ),
        ],
      ),
    );
  }

  Widget _buildRealTournamentItem(Tournament tournament) {
    final canRegisterRegular = tournament.canRegisterForDivision(_team!.division, _team!.division);
    final canRegisterFun = _isSeniorsTeam() && tournament.canRegisterForDivision(_getFunDivision(), _team!.division);
    
    final regularRegisteredCount = tournament.getRegisteredTeamsCount(_team!.division);
    final regularMaxTeams = tournament.getMaxTeamsForDivision(_team!.division);
    
    final funRegisteredCount = _isSeniorsTeam() ? tournament.getRegisteredTeamsCount(_getFunDivision()) : 0;
    final funMaxTeams = _isSeniorsTeam() ? tournament.getMaxTeamsForDivision(_getFunDivision()) : 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: (canRegisterRegular || canRegisterFun) ? Colors.green.shade300 : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tournament.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${tournament.points} Punkte',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Datum: ${tournament.dateString}', style: TextStyle(color: Colors.grey[600])),
          Text('Ort: ${tournament.location}', style: TextStyle(color: Colors.grey[600])),
          
          // Division Options for Seniors Teams
          if (_isSeniorsTeam()) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Anmeldungsoptionen für ${_team!.division}:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // A Cup Option
                  Row(
                    children: [
                      Icon(Icons.emoji_events, size: 16, color: Colors.amber[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'A Cup (${_team!.division}): $regularRegisteredCount/$regularMaxTeams Teams',
                          style: TextStyle(color: Colors.grey[700], fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  
                  // Fun Option
                  Row(
                    children: [
                      Icon(Icons.celebration, size: 16, color: Colors.green[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Fun Turnier (${_getFunDivision()}): $funRegisteredCount/$funMaxTeams Teams',
                          style: TextStyle(color: Colors.grey[700], fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            Text('Division: ${_team!.division} ($regularRegisteredCount/$regularMaxTeams Teams)', 
                 style: TextStyle(color: Colors.grey[600])),
          ],
          
          if (tournament.registrationDeadline != null) ...[
            const SizedBox(height: 4),
            Text('Anmeldeschluss: ${tournament.registrationDeadline!.day}.${tournament.registrationDeadline!.month}.${tournament.registrationDeadline!.year}', 
                 style: TextStyle(color: Colors.grey[600])),
          ],
          
          const SizedBox(height: 12),
          
          // Registration Buttons
          if (_isSeniorsTeam() && (canRegisterRegular || canRegisterFun)) ...[
            Column(
              children: [
                if (canRegisterRegular) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _registerForTournament(tournament, _team!.division),
                      icon: Icon(Icons.emoji_events),
                      label: Text('A Cup anmelden (${_team!.division})'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (canRegisterFun) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _registerForTournament(tournament, _getFunDivision()),
                      icon: Icon(Icons.celebration),
                      label: Text('Fun Turnier anmelden (${_getFunDivision()})'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ] else if (!_isSeniorsTeam() && canRegisterRegular) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _registerForTournament(tournament, _team!.division),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D5016),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Jetzt anmelden'),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Anmeldung nicht möglich'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRegisteredTournamentItem(Tournament tournament) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.green.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tournament.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(Icons.check_circle, color: Colors.green.shade600),
            ],
          ),
          const SizedBox(height: 8),
          Text('Datum: ${tournament.dateString}', style: TextStyle(color: Colors.grey[600])),
          Text('Ort: ${tournament.location}', style: TextStyle(color: Colors.grey[600])),
          Row(
            children: [
              Text('Angemeldet für: ', style: TextStyle(color: Colors.grey[600])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: tournament.getTeamDivision(_team!.id)?.contains('FUN') == true 
                      ? Colors.green.shade100 
                      : Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tournament.getTeamDivision(_team!.id)?.contains('FUN') == true 
                      ? 'Fun Turnier (${tournament.getTeamDivision(_team!.id)})' 
                      : 'A Cup (${tournament.getTeamDivision(_team!.id) ?? _team!.division})',
                  style: TextStyle(
                    color: tournament.getTeamDivision(_team!.id)?.contains('FUN') == true 
                        ? Colors.green.shade800 
                        : Colors.amber.shade800,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton(
                onPressed: () => _unregisterFromTournament(tournament),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Anmeldung stornieren'),
              ),
              const SizedBox(width: 12),
              Text(
                'Angemeldet ✓',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper methods for seniors team division choices
  bool _isSeniorsTeam() {
    return _team!.division.contains('Seniors');
  }

  String _getFunDivision() {
    if (_team!.division == 'Women\'s Seniors') {
      return 'Women\'s FUN';
    } else if (_team!.division == 'Men\'s Seniors') {
      return 'Men\'s FUN';
    }
    return _team!.division; // Fallback
  }

  Stream<List<Tournament>> _getAvailableTournamentsStream() {
    return TournamentService().getTournamentsWithCache().map((tournaments) {
      return tournaments.where((tournament) {
        // Check if tournament is open for registration
        if (!tournament.isRegistrationOpen || tournament.status != 'upcoming') {
          return false;
        }
        
        // Check registration deadline
        if (tournament.registrationDeadline != null && 
            DateTime.now().isAfter(tournament.registrationDeadline!)) {
          return false;
        }
        
        // Check if team is already registered
        if (tournament.isTeamRegistered(_team!.id)) {
          return false;
        }
        
        // For seniors teams, check both regular and FUN divisions
        if (_isSeniorsTeam()) {
          return tournament.divisions.contains(_team!.division) || 
                 tournament.divisions.contains(_getFunDivision());
        } else {
          // For non-seniors teams, only check their division
          return tournament.divisions.contains(_team!.division);
        }
      }).toList();
    });
  }

  Future<void> _registerForTournament(Tournament tournament, String selectedDivision) async {
    try {
      final success = await TournamentService().registerTeamForTournament(
        tournament.id,
        _team!.id,
        selectedDivision,
      );

      if (success) {
        final divisionType = selectedDivision.contains('FUN') ? 'Fun Turnier' : 'A Cup';
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          title: Text('${_team!.name} wurde erfolgreich für ${tournament.name} ($divisionType - $selectedDivision) angemeldet.'),
          autoCloseDuration: const Duration(seconds: 4),
        );
      } else {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          title: const Text('Anmeldung fehlgeschlagen. Bitte versuchen Sie es erneut.'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        title: Text('Fehler: $e'),
        autoCloseDuration: const Duration(seconds: 3),
      );
    }
  }

  Future<void> _unregisterFromTournament(Tournament tournament) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Anmeldung stornieren'),
        content: Text('Möchten Sie die Anmeldung von ${_team!.name} für ${tournament.name} wirklich stornieren?'),
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

    try {
      final success = await TournamentService().unregisterTeamFromTournament(
        tournament.id,
        _team!.id,
      );

      if (success) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          title: Text('Die Anmeldung von ${_team!.name} für ${tournament.name} wurde storniert.'),
          autoCloseDuration: const Duration(seconds: 4),
        );
      } else {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          title: const Text('Stornierung fehlgeschlagen. Bitte versuchen Sie es erneut.'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        title: Text('Fehler: $e'),
        autoCloseDuration: const Duration(seconds: 3),
      );
    }
  }

  Widget _buildSettingsContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings, color: Colors.black87),
              const SizedBox(width: 8),
              const Text(
                'Team Einstellungen',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Team Informationen',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildSettingItem('Team Name', _team!.name),
                  _buildSettingItem('Division', _team!.division),
                  _buildSettingItem('Stadt', _team!.city),
                  _buildSettingItem('Bundesland', _team!.bundesland),
                  if (_team!.teamManager != null)
                    _buildSettingItem('Team Manager', _team!.teamManager!),
                  
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      toastification.show(
                        context: context,
                        type: ToastificationType.info,
                        style: ToastificationStyle.fillColored,
                        title: const Text('Team bearbeiten - Coming Soon!'),
                        autoCloseDuration: const Duration(seconds: 3),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D5016),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.edit),
                    label: const Text('Team bearbeiten'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRosterManagementContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people, color: Colors.black87),
              const SizedBox(width: 8),
              const Text(
                'Kader Verwaltung',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Team Roster Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.groups,
                          color: Colors.blue.shade700,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Team: ${_team!.name}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Aktuelle Kadergröße: ${_team!.rosterPlayerIds.length} Spieler',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
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
          ),
          
          const SizedBox(height: 16),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAddPlayerDialog(),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Spieler hinzufügen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D5016),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showBulkAddPlayersDialog(),
                  icon: const Icon(Icons.group_add),
                  label: const Text('Mehrere hinzufügen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Players List
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aktuelle Spieler',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  if (_team!.rosterPlayerIds.isEmpty) 
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Noch keine Spieler im Kader.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Fügen Sie Spieler hinzu, um Ihren Teamkader aufzubauen.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      children: _team!.rosterPlayerIds.map((playerId) => 
                        _buildPlayerListItem(playerId)
                      ).toList(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerListItem(String playerId) {
    // For now, show placeholder - this will be replaced with actual player data
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF2D5016),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Spieler ${playerId.substring(0, 8)}', // Placeholder
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'player@example.com', // Placeholder
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _removePlayerFromRoster(playerId),
            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
          ),
        ],
      ),
    );
  }

  void _showAddPlayerDialog() {
    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.fillColored,
      title: const Text('Spieler hinzufügen - Coming Soon!'),
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  void _showBulkAddPlayersDialog() {
    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.fillColored,
      title: const Text('Mehrere Spieler hinzufügen - Coming Soon!'),
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  void _removePlayerFromRoster(String playerId) {
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.fillColored,
      title: const Text('Spieler aus Kader entfernt'),
      autoCloseDuration: const Duration(seconds: 3),
    );
  }
}

// Content-only widget for use within ResponsiveLayout
class TeamDetailContent extends StatefulWidget {
  final String teamId;
  final String subSection;
  
  const TeamDetailContent({super.key, required this.teamId, this.subSection = 'overview'});

  @override
  State<TeamDetailContent> createState() => _TeamDetailContentState();
}

class _TeamDetailContentState extends State<TeamDetailContent> {
  final TeamService _teamService = TeamService();
  final TournamentService _tournamentService = TournamentService();
  Team? _team;
  List<Tournament> _tournaments = [];
  bool _isLoading = true;
  bool _tournamentsLoading = true;
  late String _selectedSubSection;

  @override
  void initState() {
    super.initState();
    _selectedSubSection = widget.subSection;
    _loadTeam();
  }

  @override
  void didUpdateWidget(TeamDetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subSection != widget.subSection) {
      setState(() {
        _selectedSubSection = widget.subSection;
      });
    }
  }

  Future<void> _loadTeam() async {
    try {
      final team = await _teamService.getTeamById(widget.teamId);
      if (mounted) {
        setState(() {
          _team = team;
          _isLoading = false;
        });
        // Load tournaments after team is loaded
        _loadTournaments();
      }
    } catch (e) {
      print('Error loading team: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadTournaments() async {
    try {
      _tournamentService.getTournamentsWithCache().listen((tournaments) {
        if (mounted) {
          final upcomingTournaments = tournaments.where((t) => t.status == 'upcoming').toList();
          final eligibleTournaments = upcomingTournaments.where((t) => _isTeamEligibleForTournament(t)).toList();
          
          setState(() {
            _tournaments = eligibleTournaments;
            _tournamentsLoading = false;
          });
        }
      });
    } catch (e) {
      print('Error loading tournaments: $e');
      if (mounted) {
        setState(() {
          _tournamentsLoading = false;
        });
      }
    }
  }

  bool _isTeamEligibleForTournament(Tournament tournament) {
    if (_team == null) return false;
    
    // Check if team division matches tournament categories
    String teamDivision = _team!.division.toLowerCase();
    
    // Check if team is a senior team (contains "senior" or adult divisions)
    bool isTeamSenior = teamDivision.contains('senior') || 
                       teamDivision.contains('men') ||
                       teamDivision.contains('women') ||
                       teamDivision.contains('fun');
    
    // Check if team is a junior team (contains age groups)
    bool isTeamJunior = teamDivision.contains('u14') ||
                       teamDivision.contains('u16') ||
                       teamDivision.contains('u18') ||
                       teamDivision.contains('junior');
    
    // Check tournament categories
    for (String category in tournament.categories) {
      String categoryLower = category.toLowerCase();
      
      // Senior teams can register for Senior Cups
      if (isTeamSenior && categoryLower.contains('seniors')) {
        return true;
      }
      
      // Junior teams can register for Junior Cups
      if (isTeamJunior && categoryLower.contains('juniors')) {
        return true;
      }
    }
    
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_team == null) {
      return const Center(
        child: Text('Team konnte nicht geladen werden'),
      );
    }

    return _getContentForSection(_selectedSubSection);
  }

  Widget _getContentForSection(String section) {
    switch (section) {
      case 'overview':
        return _buildOverviewContent();
      case 'tournaments':
        return _buildTournamentRegistrationContent();
      case 'roster':
        return _buildRosterManagementContent();
      case 'settings':
        return _buildSettingsContent();
      default:
        return _buildOverviewContent();
    }
  }

  Widget _buildOverviewContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Team Info Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D5016),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Icon(
                      Icons.group,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _team!.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFffd665),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _team!.division,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_team!.city}, ${_team!.bundesland}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Header
          Row(
            children: [
              const Icon(Icons.dashboard, color: Colors.black87),
              const SizedBox(width: 8),
              const Text(
                'Team Übersicht',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Real data message
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Team Informationen',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hier werden in Zukunft echte Statistiken und Ergebnisse aus der Firestore-Datenbank angezeigt.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aktuell verfügbare Daten:',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('• Team Name: ${_team!.name}'),
                  Text('• Division: ${_team!.division}'),
                  Text('• Stadt: ${_team!.city}'),
                  Text('• Bundesland: ${_team!.bundesland}'),
                  if (_team!.teamManager != null)
                    Text('• Team Manager: ${_team!.teamManager}'),
                  if (_team!.clubId != null)
                    Text('• Verein ID: ${_team!.clubId}'),
                  Text('• Erstellt am: ${_team!.createdAt.day}.${_team!.createdAt.month}.${_team!.createdAt.year}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentRegistrationContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sports_volleyball, color: Colors.black87),
              const SizedBox(width: 8),
              const Text(
                'Turnier Anmeldung',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          if (_tournamentsLoading)
            const Center(child: CircularProgressIndicator())
          else if (_tournaments.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verfügbare Turniere',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _team != null 
                        ? 'Aktuell sind keine Turniere für ${_team!.division} Teams verfügbar.'
                        : 'Aktuell sind keine Turniere verfügbar.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_team != null) ...[
                      Text(
                        '• Senior Teams (Men\'s, Women\'s, Seniors, FUN) können sich für "GBO Seniors Cup" Turniere anmelden',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• Junior Teams (U14, U16, U18) können sich für "GBO Juniors Cup" Turniere anmelden',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verfügbare Turniere (${_tournaments.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ..._tournaments.map((tournament) => _buildTournamentCard(tournament)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTournamentCard(Tournament tournament) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            tournament.location,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '${tournament.startDate.day}.${tournament.startDate.month}.${tournament.startDate.year}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (tournament.endDate != null) ...[
                            const Text(' - '),
                            Text(
                              '${tournament.endDate!.day}.${tournament.endDate!.month}.${tournament.endDate!.year}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: tournament.categories.map((category) =>
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFffd665),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              category,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ).toList(),
                      ),
                      if (tournament.description != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          tournament.description!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D5016),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${tournament.points} Punkte',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildRegistrationButtons(tournament),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings, color: Colors.black87),
              const SizedBox(width: 8),
              const Text(
                'Team Einstellungen',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Team Informationen',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildSettingItem('Team Name', _team!.name),
                  _buildSettingItem('Division', _team!.division),
                  _buildSettingItem('Stadt', _team!.city),
                  _buildSettingItem('Bundesland', _team!.bundesland),
                  if (_team!.teamManager != null)
                    _buildSettingItem('Team Manager', _team!.teamManager!),
                  
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      toastification.show(
                        context: context,
                        type: ToastificationType.info,
                        style: ToastificationStyle.fillColored,
                        title: const Text('Team bearbeiten - Coming Soon!'),
                        autoCloseDuration: const Duration(seconds: 3),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D5016),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.edit),
                    label: const Text('Team bearbeiten'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationButtons(Tournament tournament) {
    if (_team == null) return const SizedBox();

    final canRegisterRegular = tournament.divisions.contains(_team!.division);
    final canRegisterFun = _isSeniorsTeam() && tournament.divisions.contains(_getFunDivision());
    
    // For seniors teams, show both options
    if (_isSeniorsTeam() && (canRegisterRegular || canRegisterFun)) {
      return Column(
        children: [
          if (canRegisterRegular) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _navigateToRosterCreation(tournament, _team!.division),
                icon: const Icon(Icons.emoji_events, size: 16),
                label: const Text('A Cup'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (canRegisterFun) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _navigateToRosterCreation(tournament, _getFunDivision()),
                icon: const Icon(Icons.celebration, size: 16),
                label: const Text('Fun Turnier'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
          ],
        ],
      );
    } else if (canRegisterRegular) {
      // For non-seniors teams, show single button
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _navigateToRosterCreation(tournament, _team!.division),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2D5016),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text('Anmelden'),
        ),
      );
    } else {
      // Registration not available
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text('Nicht verfügbar'),
        ),
      );
    }
  }

  bool _isSeniorsTeam() {
    return _team?.division.contains('Seniors') ?? false;
  }

  String _getFunDivision() {
    if (_team?.division == 'Women\'s Seniors') {
      return 'Women\'s FUN';
    } else if (_team?.division == 'Men\'s Seniors') {
      return 'Men\'s FUN';
    }
    return _team?.division ?? ''; // Fallback
  }

  void _navigateToRosterCreation(Tournament tournament, String selectedDivision) {
    if (_team == null) return;

    Navigator.of(context).push(
             MaterialPageRoute(
         builder: (context) => RosterCreationScreen(
           team: _team!,
           tournament: tournament,
           selectedDivision: selectedDivision,
         ),
       ),
     );
   }

  Widget _buildRosterManagementContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people, color: Colors.black87),
              const SizedBox(width: 8),
              const Text(
                'Kader Verwaltung',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Team Roster Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.groups,
                          color: Colors.blue.shade700,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Team: ${_team!.name}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Aktuelle Kadergröße: ${_team!.rosterPlayerIds.length} Spieler',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
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
          ),
          
          const SizedBox(height: 16),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAddPlayerDialog(),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Spieler hinzufügen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D5016),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showBulkAddPlayersDialog(),
                  icon: const Icon(Icons.group_add),
                  label: const Text('Mehrere hinzufügen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Players List
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aktuelle Spieler',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  if (_team!.rosterPlayerIds.isEmpty) 
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Noch keine Spieler im Kader.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Fügen Sie Spieler hinzu, um Ihren Teamkader aufzubauen.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      children: _team!.rosterPlayerIds.map((playerId) => 
                        _buildPlayerListItem(playerId)
                      ).toList(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPlayerDialog() {
    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.fillColored,
      title: const Text('Spieler hinzufügen - Coming Soon!'),
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  void _showBulkAddPlayersDialog() {
    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.fillColored,
      title: const Text('Mehrere Spieler hinzufügen - Coming Soon!'),
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  void _removePlayerFromRoster(String playerId) {
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.fillColored,
      title: const Text('Spieler aus Kader entfernt'),
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  Widget _buildPlayerListItem(String playerId) {
    // For now, show placeholder - this will be replaced with actual player data
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF2D5016),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Spieler ${playerId.substring(0, 8)}', // Placeholder
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'player@example.com', // Placeholder
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _removePlayerFromRoster(playerId),
            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
          ),
        ],
      ),
    );
  }
} 