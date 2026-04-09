import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/suspension_service.dart';
import '../services/fine_service.dart';
import '../services/protest_service.dart';
import '../services/tournament_service.dart';
import '../models/user.dart' as app_user;
import '../models/suspension.dart';
import '../models/fine.dart';
import '../models/protest.dart';

class CommissionerDashboardScreen extends StatefulWidget {
  const CommissionerDashboardScreen({super.key});

  @override
  State<CommissionerDashboardScreen> createState() => _CommissionerDashboardScreenState();
}

class _CommissionerDashboardScreenState extends State<CommissionerDashboardScreen> {
  final AuthService _authService = AuthService();
  final SuspensionService _suspensionService = SuspensionService();
  final FineService _fineService = FineService();
  final ProtestService _protestService = ProtestService();
  final TournamentService _tournamentService = TournamentService();

  app_user.User? _currentUser;
  int _activeSuspensions = 0;
  int _unpaidFines = 0;
  double _totalUnpaidAmount = 0;
  int _openProtests = 0;
  int _totalTournaments = 0;
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

      // Load summary counts
      final suspensions = await _suspensionService.getAllActiveSuspensions();
      _activeSuspensions = suspensions.length;

      final unpaidFines = await _fineService.getUnpaidFines();
      _unpaidFines = unpaidFines.length;
      _totalUnpaidAmount = unpaidFines.fold<double>(0, (sum, f) => sum + f.amount);

      // Count open protests across all tournaments
      final tournaments = await _tournamentService.getTournaments().first;
      _totalTournaments = tournaments.length;
      int openProtests = 0;
      for (final t in tournaments) {
        final protests = await _protestService.getProtestsForTournament(t.id);
        openProtests += protests.where((p) => p.status == ProtestStatus.filed || p.status == ProtestStatus.underReview).length;
      }
      _openProtests = openProtests;
    } catch (e) {
      debugPrint('Error loading commissioner dashboard: $e');
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
            _buildWelcomeCard(),
            const SizedBox(height: 24),
            _buildDashboardGrid(),
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
          colors: [Colors.deepPurple.shade600, Colors.deepPurple.shade800],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Hallo, ${_currentUser?.fullName ?? 'Kommissar'}',
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
            'Leitende Stelle · Übersicht',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 800 ? 3 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.4,
          children: [
            _buildDashboardCard(
              'Sperren',
              '$_activeSuspensions aktive',
              Icons.block,
              Colors.red,
              'Spieler-Sperren verwalten, neue Sperren erstellen oder bestehende aufheben.',
              'suspension_management',
            ),
            _buildDashboardCard(
              'Strafen / Bußgelder',
              '$_unpaidFines offen · ${_totalUnpaidAmount.toStringAsFixed(2)} €',
              Icons.euro,
              Colors.orange,
              'Bußgelder verwalten, neue Strafen erstellen, Zahlungen verfolgen.',
              'fine_management',
            ),
            _buildDashboardCard(
              'Proteste',
              '$_openProtests offen',
              Icons.warning_amber,
              Colors.amber.shade700,
              'Eingereichte Proteste prüfen und entscheiden.',
              'protest_list',
            ),
            _buildDashboardCard(
              'Turniere',
              '$_totalTournaments gesamt',
              Icons.emoji_events,
              Colors.blue,
              'Alle Turniere der Saison überwachen.',
              'tournament_management',
            ),
            _buildDashboardCard(
              'Saison',
              'Verwalten',
              Icons.calendar_today,
              Colors.teal,
              'Spieltage, Saisonformat und teilnehmende Teams.',
              'season_management',
            ),
            _buildDashboardCard(
              'Spieler',
              'Kader',
              Icons.people,
              Colors.green,
              'Spielerpässe, Kaderverwaltung und Spielerlisten.',
              'player_management',
            ),
          ],
        );
      },
    );
  }

  Widget _buildDashboardCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    String description,
    String sectionKey,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Navigate via the side navigation system
          // Find the HomeScreen's section changer
          _navigateToSection(sectionKey);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToSection(String sectionKey) {
    // Walk up the widget tree to find the HomeScreen and change section
    // This works by finding the SideNavigation callback pattern
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.hasDrawer) {
      Navigator.of(context).pop(); // Close drawer if open
    }
    // Use the navigation callback pattern from the app
    // The commissioner dashboard is rendered inside HomeScreen which manages selectedSection
    // We need to communicate the section change upward
    _sectionChangeNotifier?.call(sectionKey);
  }

  // This will be set by the parent when navigation callback is available
  Function(String)? _sectionChangeNotifier;

  /// Set the navigation callback for section changes
  void setNavigationCallback(Function(String) callback) {
    _sectionChangeNotifier = callback;
  }
}
