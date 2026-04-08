import 'package:flutter/material.dart';
import '../services/tournament_service.dart';
import '../services/auth_service.dart';
import '../utils/responsive_helper.dart';
import 'tournament_timeline.dart';

class TournamentOverview extends StatefulWidget {
  const TournamentOverview({super.key});

  @override
  State<TournamentOverview> createState() => _TournamentOverviewState();
}

class _TournamentOverviewState extends State<TournamentOverview> {
  final TournamentService _tournamentService = TournamentService();
  final AuthService _authService = AuthService();
  String selectedSeason = '2026'; // Default to 2026 season

  @override
  void initState() {
    super.initState();
    _initializeData();
    _loadUserPreferences();
  }

  Future<void> _initializeData() async {
    await _tournamentService.initializeSampleData();
  }

  Future<void> _loadUserPreferences() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        // User is logged in - use their preferences
        setState(() {
          selectedSeason = user.defaultSeason ?? '2026';
        });
      } else {
        setState(() {
          selectedSeason = '2026';
        });
      }
    } catch (e) {
      debugPrint('Error loading user preferences: $e');
      setState(() {
        selectedSeason = '2026';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isMobile = ResponsiveHelper.isMobile(screenWidth);
        
        return Container(
          padding: EdgeInsets.all(isMobile ? 8.0 : ResponsiveHelper.getContentPadding(screenWidth)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filters - responsive layout
              if (isMobile) ...[
                // Season filter
                Container(
                  width: double.infinity,
                  child: _buildSeasonDropdown(),
                ),
              ] else ...[
                Row(
                  children: [
                    const Spacer(),
                    // Season filter
                    Container(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: _buildSeasonDropdown(),
                    ),
                  ],
                ),
              ],
              SizedBox(height: isMobile ? 12 : 24),

              // Timeline View
              Expanded(
                child: TournamentTimeline(
                  selectedSeason: selectedSeason,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSeasonDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedSeason,
          isExpanded: true,
          items: const [
            DropdownMenuItem(
              value: '2025',
              child: Text('Saison 2025'),
            ),
            DropdownMenuItem(
              value: '2026',
              child: Text('Saison 2026'),
            ),
          ],
          onChanged: (value) {
            setState(() {
              selectedSeason = value!;
            });
          },
        ),
      ),
    );
  }


} 