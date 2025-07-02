import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../models/user.dart' as app_user;
import '../models/referee.dart';
import '../models/tournament.dart';
import '../services/referee_service.dart';
import '../services/tournament_service.dart';
import '../widgets/referee_invitation_dialog.dart';

class RefereeDashboardScreen extends StatefulWidget {
  final app_user.User currentUser;

  const RefereeDashboardScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<RefereeDashboardScreen> createState() => _RefereeDashboardScreenState();
}

class _RefereeDashboardScreenState extends State<RefereeDashboardScreen> {
  final RefereeService _refereeService = RefereeService();
  final TournamentService _tournamentService = TournamentService();
  Referee? _refereeProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRefereeProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check for pending invitations after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForPendingInvitations();
    });
  }

  Future<void> _loadRefereeProfile() async {
    if (widget.currentUser.refereeId != null) {
      try {
        _refereeProfile = await _refereeService.getRefereeById(widget.currentUser.refereeId!);
      } catch (e) {
        print('Error loading referee profile: $e');
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _checkForPendingInvitations() async {
    if (_refereeProfile == null) return;

    try {
      // Get pending tournaments
      final pendingStream = _tournamentService.getPendingInvitationsForReferee(_refereeProfile!.id);
      final pendingTournaments = await pendingStream.first;

      if (pendingTournaments.isNotEmpty && mounted) {
        // Show the invitation dialog
        await showDialog(
          context: context,
          barrierDismissible: false, // User must respond
          builder: (context) => RefereeInvitationDialog(
            pendingTournaments: pendingTournaments,
            refereeId: _refereeProfile!.id,
            onCompleted: () {
              // Refresh the dashboard data after responding to invitations
              setState(() {});
            },
          ),
        );
      }
    } catch (e) {
      print('Error checking for pending invitations: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.sports_hockey,
                  color: Colors.orange.shade700,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Schiedsrichter Dashboard',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Willkommen, ${widget.currentUser.fullName}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Referee Profile Card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, color: Colors.blue.shade600),
                      const SizedBox(width: 8),
                      const Text(
                        'Mein Profil',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  if (_refereeProfile != null) ...[
                    _buildProfileRow('Name', _refereeProfile!.fullName),
                    _buildProfileRow('E-Mail', _refereeProfile!.email),
                    _buildProfileRow('Lizenz', _refereeProfile!.licenseType),
                    _buildProfileRow('Registriert seit', 
                        '${_refereeProfile!.createdAt.day}.${_refereeProfile!.createdAt.month}.${_refereeProfile!.createdAt.year}'),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange.shade600),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Schiedsrichter-Profil konnte nicht geladen werden. Bitte kontaktieren Sie den Administrator.',
                              style: TextStyle(color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Quick Actions
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.dashboard, color: Colors.green.shade600),
                      const SizedBox(width: 8),
                      const Text(
                        'Schnellzugriff',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionCard(
                          icon: Icons.schedule,
                          title: 'Meine Einsätze',
                          subtitle: 'Kommende Spiele',
                          color: Colors.blue,
                          onTap: () => _showUpcomingAssignments(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActionCard(
                          icon: Icons.history,
                          title: 'Einsatz-Historie',
                          subtitle: 'Vergangene Spiele',
                          color: Colors.purple,
                          onTap: () => _showComingSoon('Einsatz-Historie'),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionCard(
                          icon: Icons.assessment,
                          title: 'Bewertungen',
                          subtitle: 'Meine Bewertungen',
                          color: Colors.orange,
                          onTap: () => _showComingSoon('Bewertungen'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActionCard(
                          icon: Icons.settings,
                          title: 'Einstellungen',
                          subtitle: 'Profil bearbeiten',
                          color: Colors.grey,
                          onTap: () => _showComingSoon('Einstellungen'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Statistics Card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bar_chart, color: Colors.indigo.shade600),
                      const SizedBox(width: 8),
                      const Text(
                        'Statistiken',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          title: 'Gesamt Einsätze',
                          value: '24',
                          icon: Icons.sports_volleyball,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Diese Saison',
                          value: '8',
                          icon: Icons.calendar_today,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Durchschnittsbewertung',
                          value: '4.7',
                          icon: Icons.star,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Upcoming Assignments Section
          if (_refereeProfile != null) _buildUpcomingAssignmentsSection(),
        ],
      ),
    );
  }

  Widget _buildUpcomingAssignmentsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Meine Einsätze',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<Tournament>>(
              stream: _tournamentService.getAcceptedTournamentsForReferee(_refereeProfile!.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red.shade600),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Fehler beim Laden der Einsätze.',
                            style: TextStyle(color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                final tournaments = snapshot.data ?? [];
                
                if (tournaments.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey.shade600),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Keine kommenden Einsätze geplant.',
                            style: TextStyle(color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return Column(
                  children: tournaments.take(3).map((tournament) => 
                    _buildTournamentAssignmentCard(tournament)
                  ).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTournamentAssignmentCard(Tournament tournament) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
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
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tournament.categoryDisplayNames,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.grey.shade600, size: 16),
              const SizedBox(width: 4),
              Text(
                tournament.location,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.calendar_today, color: Colors.grey.shade600, size: 16),
              const SizedBox(width: 4),
              Text(
                tournament.dateString,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showUpcomingAssignments() {
    // This method can be used to show a detailed view of all assignments
    // For now, we're displaying them directly in the dashboard
    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.fillColored,
      title: const Text('Meine Einsätze'),
      description: const Text('Hier sind Ihre kommenden Turnier-Einsätze zu sehen.'),
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showComingSoon(String feature) {
    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.fillColored,
      title: Text('$feature - Coming Soon!'),
      description: const Text('Diese Funktion wird bald verfügbar sein.'),
      autoCloseDuration: const Duration(seconds: 3),
    );
  }
} 