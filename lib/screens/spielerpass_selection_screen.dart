import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tournament.dart';
import '../models/user.dart' as app_user;
import '../services/auth_service.dart';
import '../services/tournament_service.dart';
import 'spielerpass_check_screen.dart';

/// Lets a delegate pick a game to run a Spielerpass check on.
/// Lists upcoming games (next 14 days) for tournaments where the user is delegate.
class SpielerpassSelectionScreen extends StatefulWidget {
  const SpielerpassSelectionScreen({super.key});

  @override
  State<SpielerpassSelectionScreen> createState() =>
      _SpielerpassSelectionScreenState();
}

class _SpielerpassSelectionScreenState
    extends State<SpielerpassSelectionScreen> {
  final TournamentService _tournamentService = TournamentService();
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _loading = true;
  List<Tournament> _tournaments = [];
  final Map<String, List<Map<String, dynamic>>> _gamesByTournament = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = await _authService.getCurrentUser();
      final all = await _tournamentService.getTournaments().first;
      final isAdmin =
          user?.roles.contains(app_user.UserRole.admin) ?? false;
      final assigned = all
          .where((t) =>
              isAdmin ||
              (user != null && t.delegateIds.contains(user.id)))
          .toList();

      _gamesByTournament.clear();
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day);
      final to = from.add(const Duration(days: 14));

      for (final t in assigned) {
        try {
          final snap = await _firestore
              .collection('tournaments')
              .doc(t.id)
              .collection('games')
              .where('scheduledTime',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(from))
              .where('scheduledTime', isLessThan: Timestamp.fromDate(to))
              .orderBy('scheduledTime')
              .get();
          _gamesByTournament[t.id] = snap.docs
              .map((d) => {...d.data(), 'id': d.id})
              .toList();
        } catch (_) {
          _gamesByTournament[t.id] = [];
        }
      }

      _tournaments = assigned
          .where((t) => (_gamesByTournament[t.id] ?? []).isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('SpielerpassSelection load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tournaments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.badge_outlined,
                  size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'Keine bevorstehenden Spiele',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Es gibt aktuell keine Spiele in den nächsten 14 Tagen,\n'
                'für die du als Delegat zugeordnet bist.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Aktualisieren'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tournaments.length,
        itemBuilder: (context, index) {
          final t = _tournaments[index];
          final games = _gamesByTournament[t.id] ?? [];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.emoji_events, color: Colors.indigo[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.name,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(t.location,
                                style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ...games.map((g) => _GameTile(
                      game: g,
                      tournamentId: t.id,
                    )),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  final Map<String, dynamic> game;
  final String tournamentId;

  const _GameTile({required this.game, required this.tournamentId});

  @override
  Widget build(BuildContext context) {
    final teamA = (game['teamAName'] ?? game['teamA'] ?? '?').toString();
    final teamB = (game['teamBName'] ?? game['teamB'] ?? '?').toString();
    final scheduled = game['scheduledTime'];
    DateTime? when;
    if (scheduled is Timestamp) {
      when = scheduled.toDate();
    } else if (scheduled is DateTime) {
      when = scheduled;
    }
    final timeLabel = when == null
        ? '—'
        : '${when.day.toString().padLeft(2, '0')}.${when.month.toString().padLeft(2, '0')} '
            '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';

    return ListTile(
      leading: const Icon(Icons.sports_handball),
      title: Text('$teamA vs $teamB'),
      subtitle: Text(timeLabel),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SpielerpassCheckScreen(
              gameId: game['id'] as String,
              tournamentId: tournamentId,
              gameDisplayName: '$teamA vs $teamB',
            ),
          ),
        );
      },
    );
  }
}
