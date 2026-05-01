import 'package:flutter/material.dart';
import '../models/tournament.dart';
import '../models/court.dart';
import '../models/user.dart' as app_user;
import '../services/tournament_service.dart';
import '../utils/app_colors.dart';
import 'scoring_tablet_screen.dart';

class ScoringPickerScreen extends StatefulWidget {
  final app_user.User currentUser;

  const ScoringPickerScreen({super.key, required this.currentUser});

  @override
  State<ScoringPickerScreen> createState() => _ScoringPickerScreenState();
}

class _ScoringPickerScreenState extends State<ScoringPickerScreen> {
  final TournamentService _tournamentService = TournamentService();
  List<Tournament> _tournaments = [];
  bool _isLoading = true;
  Set<String> _expandedTournaments = {};

  @override
  void initState() {
    super.initState();
    _loadTournaments();
  }

  Future<void> _loadTournaments() async {
    setState(() => _isLoading = true);
    try {
      final allTournaments = await _tournamentService.getTournaments().first;
      // Show ongoing and upcoming tournaments that have courts
      final activeTournaments = allTournaments.where((t) =>
        (t.status == 'ongoing' || t.status == 'upcoming') && t.courts.isNotEmpty
      ).toList();

      // Sort: ongoing first, then upcoming, then by start date
      activeTournaments.sort((a, b) {
        if (a.status == 'ongoing' && b.status != 'ongoing') return -1;
        if (a.status != 'ongoing' && b.status == 'ongoing') return 1;
        return a.startDate.compareTo(b.startDate);
      });

      setState(() {
        _tournaments = activeTournaments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Laden der Turniere: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openScoringScreen(Tournament tournament, Court court) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ScoringTabletScreen(
          user: widget.currentUser,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tournaments.isEmpty
              ? _buildEmptyState()
              : _buildTournamentList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.scoreboard_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Keine aktiven Turniere',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Es gibt derzeit keine laufenden oder anstehenden Turniere mit Feldern.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadTournaments,
            icon: const Icon(Icons.refresh),
            label: const Text('Aktualisieren'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentList() {
    return RefreshIndicator(
      onRefresh: _loadTournaments,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tournaments.length + 1, // +1 for header
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildHeader();
          }
          return _buildTournamentCard(_tournaments[index - 1]);
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Scoring System',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Wähle ein Turnier und ein Feld, um das Scoring zu starten.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentCard(Tournament tournament) {
    final isExpanded = _expandedTournaments.contains(tournament.id);
    final isOngoing = tournament.status == 'ongoing';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOngoing ? Colors.green.shade300 : Colors.grey.shade200,
          width: isOngoing ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Tournament header
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedTournaments.remove(tournament.id);
                } else {
                  _expandedTournaments.add(tournament.id);
                }
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Status indicator
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOngoing ? Colors.green : Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Tournament info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tournament.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                tournament.location,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(tournament.startDate),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOngoing ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isOngoing ? 'Laufend' : 'Anstehend',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isOngoing ? Colors.green.shade700 : Colors.orange.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Courts count badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${tournament.courts.length} ${tournament.courts.length == 1 ? 'Feld' : 'Felder'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Expand/collapse icon
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.chevron_right,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Courts list (expanded)
          if (isExpanded) ...[
            Divider(height: 1, color: Colors.grey.shade200),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'Feld auswählen:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  ...tournament.courts.map((court) =>
                    _buildCourtItem(tournament, court),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCourtItem(Tournament tournament, Court court) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openScoringScreen(tournament, court),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.sports_tennis,
                  size: 20,
                  color: Colors.teal.shade700,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        court.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.teal.shade600,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
      'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'
    ];
    return '${date.day}. ${months[date.month - 1]} ${date.year}';
  }
}
