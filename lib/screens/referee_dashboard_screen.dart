import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/referee.dart';
import '../models/tournament.dart';
import '../services/referee_service.dart';
import '../services/tournament_service.dart';
import '../services/auth_service.dart';
import '../models/user.dart' as app_user;
import 'referee_observation_list_screen.dart';

class RefereeDashboardScreen extends StatefulWidget {
  const RefereeDashboardScreen({super.key});

  @override
  State<RefereeDashboardScreen> createState() => _RefereeDashboardScreenState();
}

class _RefereeDashboardScreenState extends State<RefereeDashboardScreen> {
  final RefereeService _refereeService = RefereeService();
  final TournamentService _tournamentService = TournamentService();
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Referee? _referee;
  app_user.User? _currentUser;
  List<Tournament> _assignedTournaments = [];
  List<Tournament> _upcomingTournaments = [];
  List<Map<String, dynamic>> _todaysGames = [];
  Map<String, String> _availabilityStatus = {}; // tournamentId -> status
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _currentUser = await _authService.getCurrentUser();
      if (_currentUser?.refereeId != null) {
        _referee = await _refereeService.getRefereeById(_currentUser!.refereeId!);
      }

      // Load all tournaments
      final allTournaments = await _tournamentService.getTournaments().first;

      // Assigned tournaments (where referee is accepted)
      _assignedTournaments = allTournaments.where((t) {
        return t.refereeIds.contains(_currentUser?.refereeId);
      }).toList();

      // Upcoming tournaments (future, sorted by date)
      _upcomingTournaments = allTournaments.where((t) {
        return t.startDate.isAfter(DateTime.now().subtract(const Duration(days: 1)));
      }).toList()
        ..sort((a, b) => a.startDate.compareTo(b.startDate));

      // Load availability status for each upcoming tournament
      await _loadAvailabilityStatus();

      // Load today's games for this referee
      await _loadTodaysGames();
    } catch (e) {
      debugPrint('Error loading referee dashboard: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadAvailabilityStatus() async {
    if (_currentUser?.refereeId == null) return;
    final statusMap = <String, String>{};
    for (final tournament in _upcomingTournaments) {
      // Check refereeInvitations for this referee's status
      for (final inv in tournament.refereeInvitations) {
        if (inv.refereeId == _currentUser!.refereeId!) {
          statusMap[tournament.id] = inv.status;
          break;
        }
      }
    }
    _availabilityStatus = statusMap;
  }

  Future<void> _loadTodaysGames() async {
    if (_currentUser?.refereeId == null) return;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final games = <Map<String, dynamic>>[];
    for (final tournament in _assignedTournaments) {
      try {
        final gamesSnap = await _firestore
            .collection('tournaments')
            .doc(tournament.id)
            .collection('games')
            .where('scheduledTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('scheduledTime', isLessThan: Timestamp.fromDate(endOfDay))
            .get();

        for (final doc in gamesSnap.docs) {
          final data = doc.data();
          // Check if this referee is assigned to this game
          final refereeIds = List<String>.from(data['refereeIds'] ?? []);
          if (refereeIds.contains(_currentUser!.refereeId)) {
            games.add({
              ...data,
              'id': doc.id,
              'tournamentName': tournament.name,
              'tournamentId': tournament.id,
            });
          }
        }
      } catch (e) {
        debugPrint('Error loading games for tournament ${tournament.id}: $e');
      }
    }
    _todaysGames = games;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome header
            _buildWelcomeCard(),
            const SizedBox(height: 24),

            // Today's games
            _buildSectionHeader('Meine Spiele heute', Icons.today),
            const SizedBox(height: 12),
            if (_todaysGames.isEmpty)
              _buildEmptyCard('Keine Spiele für heute eingeteilt.')
            else
              ..._todaysGames.map(_buildGameCard),

            const SizedBox(height: 24),

            // Upcoming schedule (calendar-style)
            _buildSectionHeader('Turnierkalender', Icons.calendar_month),
            const SizedBox(height: 12),
            _buildCalendarView(),

            const SizedBox(height: 24),

            // Assigned tournaments with availability toggle
            _buildSectionHeader('Meine Turnier-Verfügbarkeit', Icons.event_available),
            const SizedBox(height: 12),
            if (_upcomingTournaments.isEmpty)
              _buildEmptyCard('Keine anstehenden Turniere.')
            else
              ..._upcomingTournaments.map(_buildAvailabilityCard),

            const SizedBox(height: 24),

            // Referee observations
            _buildSectionHeader('Meine Beobachtungen', Icons.assignment_ind),
            const SizedBox(height: 12),
            if (_referee != null)
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.assignment_ind, color: Colors.indigo),
                  title: const Text('Beobachtungen anzeigen'),
                  subtitle: const Text('Bewertungen durch Delegates'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RefereeObservationListScreen(
                        refereeId: _referee!.id,
                        title: 'Meine Beobachtungen',
                      ),
                    ),
                  ),
                ),
              )
            else
              _buildEmptyCard('Schiedsrichter-Profil nicht verknüpft.'),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade600, Colors.orange.shade800],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sports_hockey, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Hallo, ${_referee?.fullName ?? _currentUser?.fullName ?? 'Schiedsrichter'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_todaysGames.length} Spiel${_todaysGames.length == 1 ? '' : 'e'} heute · ${_assignedTournaments.length} Turnier${_assignedTournaments.length == 1 ? '' : 'e'}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
            ),
          ),
          if (_referee?.licenseType != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Lizenz: ${_referee!.licenseType}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            message,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildGameCard(Map<String, dynamic> game) {
    final teamA = game['teamAName'] ?? 'Team A';
    final teamB = game['teamBName'] ?? 'Team B';
    final court = game['court'] ?? '';
    final time = game['scheduledTime'] as Timestamp?;
    final tournamentName = game['tournamentName'] ?? '';
    final scoreA = game['scoreTeamA'] ?? 0;
    final scoreB = game['scoreTeamB'] ?? 0;
    final status = game['status'] ?? 'scheduled';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: status == 'live'
              ? Colors.green
              : status == 'completed'
                  ? Colors.grey
                  : Colors.orange,
          child: Icon(
            status == 'live'
                ? Icons.play_arrow
                : status == 'completed'
                    ? Icons.check
                    : Icons.schedule,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text('$teamA vs $teamB'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (time != null)
              Text(
                '${time.toDate().hour.toString().padLeft(2, '0')}:${time.toDate().minute.toString().padLeft(2, '0')} Uhr${court.isNotEmpty ? ' · Feld $court' : ''}',
              ),
            Text(tournamentName, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
        trailing: status == 'live' || status == 'completed'
            ? Text(
                '$scoreA : $scoreB',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              )
            : null,
      ),
    );
  }

  Widget _buildTournamentCard(Tournament tournament) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.shade100,
          child: Icon(Icons.emoji_events, color: Colors.orange.shade700),
        ),
        title: Text(tournament.name),
        subtitle: Text(
          '${tournament.startDate.day}.${tournament.startDate.month}.${tournament.startDate.year}',
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  /// Calendar-style view of upcoming tournaments
  Widget _buildCalendarView() {
    if (_upcomingTournaments.isEmpty) {
      return _buildEmptyCard('Keine anstehenden Turniere.');
    }

    // Group tournaments by month
    final grouped = <String, List<Tournament>>{};
    for (final t in _upcomingTournaments) {
      final key = '${t.startDate.year}-${t.startDate.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(t);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: grouped.entries.map((entry) {
            final parts = entry.key.split('-');
            final monthNames = ['', 'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
            final monthLabel = '${monthNames[int.parse(parts[1])]} ${parts[0]}';
            final isAssigned = entry.value.any((t) => _assignedTournaments.any((a) => a.id == t.id));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    monthLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                ...entry.value.map((t) {
                  final assigned = _assignedTournaments.any((a) => a.id == t.id);
                  final status = _availabilityStatus[t.id];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: assigned
                          ? Colors.green.shade50
                          : status == 'declined'
                              ? Colors.red.shade50
                              : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: assigned
                            ? Colors.green.shade200
                            : status == 'declined'
                                ? Colors.red.shade200
                                : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          alignment: Alignment.center,
                          child: Text(
                            '${t.startDate.day}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: assigned ? Colors.green.shade700 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                              Text(t.location, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                        if (assigned)
                          Chip(
                            label: const Text('Eingeteilt', style: TextStyle(fontSize: 11)),
                            backgroundColor: Colors.green.shade100,
                            side: BorderSide.none,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          )
                        else if (status == 'declined')
                          Chip(
                            label: const Text('Abgesagt', style: TextStyle(fontSize: 11)),
                            backgroundColor: Colors.red.shade100,
                            side: BorderSide.none,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),
                  );
                }),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Availability card with toggle and decline button
  Widget _buildAvailabilityCard(Tournament tournament) {
    final status = _availabilityStatus[tournament.id];
    final isAssigned = _assignedTournaments.any((a) => a.id == tournament.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isAssigned
                  ? Colors.green.shade100
                  : status == 'declined'
                      ? Colors.red.shade100
                      : Colors.orange.shade100,
              child: Icon(
                isAssigned
                    ? Icons.check_circle
                    : status == 'declined'
                        ? Icons.cancel
                        : Icons.emoji_events,
                color: isAssigned
                    ? Colors.green.shade700
                    : status == 'declined'
                        ? Colors.red.shade700
                        : Colors.orange.shade700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tournament.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    '${tournament.startDate.day}.${tournament.startDate.month}.${tournament.startDate.year} · ${tournament.location}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (isAssigned)
              TextButton.icon(
                onPressed: () => _declineAssignment(tournament),
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: const Text('Absagen'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              )
            else if (status != 'declined')
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Verfügbar',
                    icon: Icon(Icons.thumb_up_alt,
                        color: status == 'accepted' ? Colors.green : Colors.grey),
                    onPressed: () => _setAvailability(tournament.id, 'accepted'),
                  ),
                  IconButton(
                    tooltip: 'Nicht verfügbar',
                    icon: Icon(Icons.thumb_down_alt,
                        color: status == 'declined' ? Colors.red : Colors.grey),
                    onPressed: () => _setAvailability(tournament.id, 'declined'),
                  ),
                ],
              )
            else
              TextButton(
                onPressed: () => _setAvailability(tournament.id, 'accepted'),
                child: const Text('Doch verfügbar'),
              ),
          ],
        ),
      ),
    );
  }

  /// Update availability status for a tournament
  Future<void> _setAvailability(String tournamentId, String newStatus) async {
    if (_currentUser?.refereeId == null) return;
    try {
      await _tournamentService.setRefereeAvailability(
        tournamentId,
        _currentUser!.refereeId!,
        newStatus,
      );
      setState(() {
        _availabilityStatus[tournamentId] = newStatus;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'accepted'
                ? 'Verfügbarkeit bestätigt'
                : 'Als nicht verfügbar markiert'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error setting availability: $e');
    }
  }

  /// Decline an existing assignment and notify admin
  Future<void> _declineAssignment(Tournament tournament) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zuweisung absagen'),
        content: Text('Möchten Sie die Zuweisung für "${tournament.name}" wirklich absagen? Der Admin wird benachrichtigt.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Absagen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      // Update invitation status to declined
      await _setAvailability(tournament.id, 'declined');

      // Notify admin users
      final adminUsers = await _firestore
          .collection('users')
          .where('role', whereIn: ['admin', 'teamRHD'])
          .get();

      final batch = _firestore.batch();
      for (final admin in adminUsers.docs) {
        final notifRef = _firestore.collection('custom_notifications').doc();
        batch.set(notifRef, {
          'title': 'Schiedsrichter-Absage',
          'message': '${_referee?.fullName ?? 'Ein Schiedsrichter'} hat die Zuweisung für "${tournament.name}" abgesagt.',
          'userId': admin.id,
          'sentAt': FieldValue.serverTimestamp(),
          'type': 'referee_decline',
          'status': 'sent',
          'isTimeSensitive': true,
          'tournamentId': tournament.id,
        });
      }
      await batch.commit();

      await _loadData(); // Refresh
    } catch (e) {
      debugPrint('Error declining assignment: $e');
    }
  }
}
