import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/auth_service.dart';
import '../services/tournament_service.dart';
import '../services/player_service.dart';
import '../models/user.dart' as app_user;
import '../models/tournament.dart';
import '../models/player.dart';
import '../models/team.dart';

class PlayerDashboardScreen extends StatefulWidget {
  const PlayerDashboardScreen({super.key});

  @override
  State<PlayerDashboardScreen> createState() => _PlayerDashboardScreenState();
}

class _PlayerDashboardScreenState extends State<PlayerDashboardScreen> {
  final AuthService _authService = AuthService();
  final TournamentService _tournamentService = TournamentService();
  final PlayerService _playerService = PlayerService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  app_user.User? _currentUser;
  Player? _playerProfile;
  Team? _team;
  List<Tournament> _upcomingTournaments = [];
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

      // Try to find player profile by email
      if (_currentUser?.email != null) {
        final playerSnap = await _firestore
            .collection('players')
            .where('email', isEqualTo: _currentUser!.email!.toLowerCase())
            .limit(1)
            .get();
        if (playerSnap.docs.isNotEmpty) {
          _playerProfile = Player.fromFirestore(playerSnap.docs.first);
        }
      }

      // Find team that contains this player
      if (_playerProfile != null) {
        final teamsSnap = await _firestore
            .collection('teams')
            .where('rosterPlayerIds', arrayContains: _playerProfile!.id)
            .limit(1)
            .get();
        if (teamsSnap.docs.isNotEmpty) {
          _team = Team.fromFirestore(teamsSnap.docs.first);
        }
      }

      // Load upcoming tournaments for the player's team
      if (_team != null) {
        final allTournaments = await _tournamentService.getTournaments().first;
        _upcomingTournaments = allTournaments.where((t) {
          return t.teamIds.contains(_team!.id) &&
              t.startDate.isAfter(DateTime.now().subtract(const Duration(days: 1)));
        }).toList()
          ..sort((a, b) => a.startDate.compareTo(b.startDate));
      }
    } catch (e) {
      debugPrint('Error loading player dashboard: $e');
    }
    if (mounted) setState(() => _isLoading = false);
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
            _buildProfileCard(),
            const SizedBox(height: 24),

            // Spielerpass section
            if (_playerProfile != null) ...[
              _buildSpielerpassCard(),
              const SizedBox(height: 24),
            ],

            // Upcoming tournaments
            _buildSectionHeader('Nächste Turniere', Icons.emoji_events),
            const SizedBox(height: 12),
            if (_upcomingTournaments.isEmpty)
              _buildEmptyCard('Keine anstehenden Turniere.')
            else
              ..._upcomingTournaments.map(_buildTournamentCard),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade600, Colors.green.shade800],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _playerProfile != null
                      ? '${_playerProfile!.firstName} ${_playerProfile!.lastName}'
                      : _currentUser?.fullName ?? 'Spieler',
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
          if (_team != null)
            Text(
              _team!.name,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
              ),
            ),
          if (_playerProfile?.classification != null && _playerProfile!.classification!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Klasse: ${_playerProfile!.classification}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSpielerpassCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.badge, color: Colors.blue.shade700, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Mein Spielerpass',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow('Name', '${_playerProfile!.firstName} ${_playerProfile!.lastName}'),
            _buildInfoRow('Team', _team?.name ?? '-'),
            _buildInfoRow('Spielerpass-Nr.', _playerProfile!.spielerpassNummer ?? 'Nicht vergeben'),
            _buildInfoRow('Klassifizierung', _playerProfile!.classification ?? '-'),
            if (_playerProfile!.jerseyNumber != null)
              _buildInfoRow('Trikotnummer', '${_playerProfile!.jerseyNumber}'),

            // QR Code for Spielerpass
            if (_playerProfile!.spielerpassNummer != null &&
                _playerProfile!.spielerpassNummer!.isNotEmpty) ...[
              const Divider(height: 24),
              Center(
                child: Column(
                  children: [
                    Text(
                      'Spielerpass QR-Code',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: QrImageView(
                        data: 'SPIELERPASS:${_playerProfile!.spielerpassNummer}',
                        version: QrVersions.auto,
                        size: 160,
                        gapless: true,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _playerProfile!.spielerpassNummer!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildEmptyCard(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(message, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        ),
      ),
    );
  }

  Widget _buildTournamentCard(Tournament tournament) {
    final daysUntil = tournament.startDate.difference(DateTime.now()).inDays;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: Icon(Icons.emoji_events, color: Colors.green.shade700),
        ),
        title: Text(tournament.name),
        subtitle: Text(
          '${tournament.startDate.day}.${tournament.startDate.month}.${tournament.startDate.year} · ${tournament.location}',
        ),
        trailing: daysUntil >= 0
            ? Chip(
                label: Text(
                  daysUntil == 0 ? 'Heute' : 'in $daysUntil Tag${daysUntil == 1 ? '' : 'en'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: daysUntil == 0 ? Colors.white : Colors.green.shade700,
                  ),
                ),
                backgroundColor: daysUntil == 0 ? Colors.green : Colors.green.shade50,
              )
            : null,
      ),
    );
  }
}
