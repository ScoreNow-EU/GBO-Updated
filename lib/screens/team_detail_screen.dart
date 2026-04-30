import 'package:flutter/material.dart';
import '../models/team.dart';
import '../models/tournament.dart';
import '../services/team_service.dart';
import '../services/tournament_service.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/season_calendar_view.dart';
import '../widgets/team_logo_section.dart';
import '../widgets/team_profile_view.dart';
import 'team_games_view.dart';

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
      debugPrint('Error loading team: $e');
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
        onSectionChanged: _handleSectionChanged,
        title: 'Team wird geladen...',
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_team == null) {
      return ResponsiveLayout(
        selectedSection: 'team_${widget.teamId}_${widget.subSection}',
        onSectionChanged: _handleSectionChanged,
        title: 'Team nicht gefunden',
        body: const Center(
          child: Text('Team konnte nicht geladen werden'),
        ),
      );
    }

    return ResponsiveLayout(
      selectedSection: 'team_${widget.teamId}_${widget.subSection}',
      onSectionChanged: _handleSectionChanged,
      title: _getScreenTitle(),
      body: _getContentForSection(_selectedSubSection),
    );
  }

  /// Side-nav callback. Same-team sub-sections swap locally; anything else
  /// pops back to the root (HomeScreen) so the user can navigate freely.
  void _handleSectionChanged(String section) {
    final prefix = 'team_${widget.teamId}_';
    if (section.startsWith(prefix)) {
      setState(() {
        _selectedSubSection = section.substring(prefix.length);
      });
      return;
    }
    // Leave the pushed team-detail route entirely.
    Navigator.of(context).popUntil((r) => r.isFirst);
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
      case 'games':
        return 'Spiele & Kader';
      case 'calendar':
        return 'Kalender';
      case 'profile':
        return 'Profil';
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
      case 'games':
        return _buildGamesContent();
      case 'calendar':
        return SeasonCalendarView(teamId: widget.teamId);
      case 'profile':
        return TeamProfileView(team: _team!);
      case 'settings':
        return _buildSettingsContent();
      default:
        return _buildOverviewContent();
    }
  }

  Widget _buildGamesContent() {
    return TeamGamesView(team: _team!);
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
                            _team!.city,
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
                        const Icon(Icons.sports_handball, size: 32, color: Colors.blue),
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
              const Icon(Icons.sports_handball, color: Colors.black87),
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
                  
                  _buildTournamentItem('RHBL Meisterschaft 2024', '25.-27. Mai 2024', 'Hamburg'),
                  _buildTournamentItem('Nord Cup 2024', '15.-16. Juni 2024', 'Bremen'),
                  _buildTournamentItem('Summer Beach Tournament', '20.-22. Juli 2024', 'Rostock'),
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Anmeldung für $name gestartet'),
                  backgroundColor: Colors.green,
                ),
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

          // T43 — Team logo upload/display
          TeamLogoSection(
            team: _team!,
            canEdit: true,
            onLogoChanged: _loadTeam,
          ),

          const SizedBox(height: 16),

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
                  _buildSettingItem('Stadt', _team!.city),
                  _buildSettingItem('Stadt', _team!.city),
                  _buildSettingItem('Bundesland', _team!.bundesland),
                  if (_team!.teamManager != null)
                    _buildSettingItem('Team Manager', _team!.teamManager!),
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
}

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
      debugPrint('Error loading team: $e');
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
      debugPrint('Error loading tournaments: $e');
      if (mounted) {
        setState(() {
          _tournamentsLoading = false;
        });
      }
    }
  }

  bool _isTeamEligibleForTournament(Tournament tournament) {
    if (_team == null) return false;
    // With categories removed, all teams are potentially eligible
    return true;
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
    debugPrint('ðŸŽ¯ TeamDetailContent - Getting content for section: $section');
    switch (section) {
      case 'overview':
        debugPrint('ðŸ“Š Showing overview');
        return _buildOverviewContent();
      case 'tournaments':
        debugPrint('ðŸ† Showing tournaments');
        return _buildTournamentRegistrationContent();
      case 'games':
        debugPrint('ðŸ‘¥ Showing games content');
        return _buildGamesContent();
      case 'roster':
        debugPrint('ðŸ‘¥ Showing roster/games content');
        return _buildGamesContent();
      case 'calendar':
        debugPrint('📅 Showing team calendar');
        return SeasonCalendarView(teamId: widget.teamId);
      case 'profile':
        debugPrint('ðŸªª Showing team profile');
        return TeamProfileView(team: _team!);
      case 'settings':
        debugPrint('âš™ï¸ Showing settings');
        return _buildSettingsContent();
      default:
        debugPrint('âŒ Unknown section: $section, defaulting to overview');
        return _buildOverviewContent();
    }
  }

  Widget _buildGamesContent() {
    debugPrint('ðŸŽ¯ Building games content for team: ${_team?.name}');
    if (_team == null) {
      return const Center(child: Text('Team wird geladen...'));
    }
    return TeamGamesView(team: _team!);
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
                            _team!.city,
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
                  Text('â€¢ Team Name: ${_team!.name}'),
                  Text('â€¢ Stadt: ${_team!.city}'),
                  Text('â€¢ Bundesland: ${_team!.bundesland}'),
                  if (_team!.teamManager != null)
                    Text('â€¢ Team Manager: ${_team!.teamManager}'),
                  Text('â€¢ Erstellt am: ${_team!.createdAt.day}.${_team!.createdAt.month}.${_team!.createdAt.year}'),
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
              const Icon(Icons.sports_handball, color: Colors.black87),
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
                        ? 'Aktuell sind keine Turniere für ${_team!.city} Teams verfügbar.'
                        : 'Aktuell sind keine Turniere verfügbar.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_team != null) ...[
                      Text(
                        'â€¢ Senior Teams (Men\'s, Women\'s, Seniors, FUN) können sich für "RHBL Spieltag" Turniere anmelden',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'â€¢ Junior Teams (U14, U16, U18) können sich für "RHBL Spieltag" Turniere anmelden',
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
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Anmeldung für "${tournament.name}" - Coming Soon!'),
                            backgroundColor: Colors.blue,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D5016),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('Anmelden'),
                    ),
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

          // T43 — Team logo upload/display
          TeamLogoSection(
            team: _team!,
            canEdit: true,
            onLogoChanged: _loadTeam,
          ),

          const SizedBox(height: 16),

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
                  _buildSettingItem('Stadt', _team!.city),
                  _buildSettingItem('Stadt', _team!.city),
                  _buildSettingItem('Bundesland', _team!.bundesland),
                  if (_team!.teamManager != null)
                    _buildSettingItem('Team Manager', _team!.teamManager!),
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
} 