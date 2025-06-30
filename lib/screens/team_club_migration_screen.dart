import 'package:flutter/material.dart';
import '../models/team.dart';
import '../models/club.dart';
import '../services/team_service.dart';
import '../services/club_service.dart';
import '../utils/responsive_helper.dart';
import '../data/german_cities.dart';

class TeamClubMigrationScreen extends StatefulWidget {
  const TeamClubMigrationScreen({super.key});

  @override
  State<TeamClubMigrationScreen> createState() => _TeamClubMigrationScreenState();
}

class _TeamClubMigrationScreenState extends State<TeamClubMigrationScreen> {
  final TeamService _teamService = TeamService();
  final ClubService _clubService = ClubService();
  
  List<Team> _orphanedTeams = [];
  List<Club> _clubs = [];
  Map<String, String> _teamClubAssignments = {}; // teamId -> clubId
  bool _isLoading = true;
  bool _isMigrating = false;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final teams = await _teamService.getTeams().first;
      final clubs = await _clubService.getClubs().first;
      
      // Find teams without clubs
      final orphanedTeams = teams.where((team) => team.clubId == null).toList();
      
      setState(() {
        _orphanedTeams = orphanedTeams;
        _clubs = clubs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Fehler beim Laden der Daten: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Teams zu Vereinen migrieren'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildContent() {
    if (_orphanedTeams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.green,
            ),
            const SizedBox(height: 24),
            Text(
              'Migration abgeschlossen!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Alle Teams sind bereits Vereinen zugeordnet.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: ResponsiveHelper.isDesktop(MediaQuery.of(context).size.width)
              ? _buildDesktopLayout()
              : _buildMobileLayout(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.transfer_within_a_station, color: Colors.orange, size: 28),
              const SizedBox(width: 12),
              Text(
                'Teams zu Vereinen migrieren',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Ordnen Sie ${_orphanedTeams.length} Teams ohne Verein den entsprechenden Vereinen zu.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _teamClubAssignments.length / _orphanedTeams.length,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
          const SizedBox(height: 8),
          Text(
            '${_teamClubAssignments.length} von ${_orphanedTeams.length} Teams zugeordnet',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Teams list
        Expanded(
          flex: 2,
          child: _buildTeamsList(),
        ),
        // Assignments overview
        Expanded(
          flex: 1,
          child: _buildAssignmentsOverview(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return _buildTeamsList();
  }

  Widget _buildTeamsList() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Icon(Icons.group, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Teams ohne Verein',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _orphanedTeams.length,
              itemBuilder: (context, index) {
                final team = _orphanedTeams[index];
                return _buildTeamCard(team);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard(Team team) {
    final assignedClubId = _teamClubAssignments[team.id];
    final assignedClub = assignedClubId != null 
        ? _clubs.firstWhere((club) => club.id == assignedClubId, orElse: () => Club(
            id: '', name: '', city: '', bundesland: '', createdAt: DateTime.now()
          ))
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: assignedClub != null ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: assignedClub != null ? Colors.green.shade200 : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Team info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        team.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${team.city}, ${team.bundesland}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        team.division,
                        style: TextStyle(
                          color: Colors.blue[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Assignment status
                if (assignedClub != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Zugeordnet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Offen',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            
            if (assignedClub != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.business, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            assignedClub.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.green.shade700,
                            ),
                          ),
                          Text(
                            '${assignedClub.city}, ${assignedClub.bundesland}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.clear, color: Colors.red, size: 20),
                      onPressed: () {
                        setState(() {
                          _teamClubAssignments.remove(team.id);
                        });
                      },
                      tooltip: 'Zuordnung entfernen',
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Verein auswählen',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                value: null,
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text('-- Verein auswählen --'),
                  ),
                  ..._clubs.map((club) => DropdownMenuItem<String>(
                    value: club.id,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          club.name,
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${club.city}, ${club.bundesland}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )),
                ],
                onChanged: (clubId) {
                  if (clubId != null) {
                    setState(() {
                      _teamClubAssignments[team.id] = clubId;
                    });
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentsOverview() {
    if (!ResponsiveHelper.isDesktop(MediaQuery.of(context).size.width)) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.grey.shade50,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Icon(Icons.assignment_turned_in, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Zuordnungen',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _teamClubAssignments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Noch keine Zuordnungen',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _teamClubAssignments.length,
                    itemBuilder: (context, index) {
                      final entry = _teamClubAssignments.entries.elementAt(index);
                      final teamId = entry.key;
                      final clubId = entry.value;
                      
                      final team = _orphanedTeams.firstWhere(
                        (t) => t.id == teamId,
                        orElse: () => Team(
                          id: teamId,
                          name: 'Unknown Team',
                          city: '',
                          bundesland: '',
                          division: '',
                          createdAt: DateTime.now(),
                        ),
                      );
                      
                      final club = _clubs.firstWhere(
                        (c) => c.id == clubId,
                        orElse: () => Club(
                          id: clubId,
                          name: 'Unknown Club',
                          city: '',
                          bundesland: '',
                          createdAt: DateTime.now(),
                        ),
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              team.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    club.name,
                                    style: TextStyle(
                                      color: Colors.blue[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _teamClubAssignments.clear();
                });
              },
              child: const Text('Alle zurücksetzen'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _teamClubAssignments.isNotEmpty && !_isMigrating
                  ? _performMigration
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isMigrating
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('Migration läuft...'),
                      ],
                    )
                  : Text('${_teamClubAssignments.length} Teams migrieren'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performMigration() async {
    setState(() {
      _isMigrating = true;
    });

    try {
      int successCount = 0;
      int errorCount = 0;

      for (final entry in _teamClubAssignments.entries) {
        final teamId = entry.key;
        final clubId = entry.value;

        // Update team with clubId
        final team = _orphanedTeams.firstWhere((t) => t.id == teamId);
        final updatedTeam = Team(
          id: team.id,
          name: team.name,
          teamManager: team.teamManager,
          logoUrl: team.logoUrl,
          city: team.city,
          bundesland: team.bundesland,
          division: team.division,
          clubId: clubId,
          createdAt: team.createdAt,
        );

        final teamSuccess = await _teamService.updateTeam(teamId, updatedTeam);
        
        if (teamSuccess) {
          // Add team to club's teamIds
          final clubSuccess = await _clubService.addTeamToClub(clubId, teamId);
          
          if (clubSuccess) {
            successCount++;
          } else {
            errorCount++;
          }
        } else {
          errorCount++;
        }
      }

      setState(() {
        _isMigrating = false;
      });

      if (errorCount == 0) {
        _showSuccess('Migration erfolgreich! $successCount Teams wurden zugeordnet.');
        await _loadData(); // Reload to show updated state
      } else {
        _showError('Migration teilweise erfolgreich. $successCount erfolgreich, $errorCount Fehler.');
      }
    } catch (e) {
      setState(() {
        _isMigrating = false;
      });
      _showError('Fehler bei der Migration: $e');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}