import 'package:flutter/material.dart';
import '../models/tournament.dart';
import '../services/tournament_service.dart';
import '../services/referee_service.dart';
import '../screens/tournament_detail_screen.dart';
import '../utils/responsive_helper.dart';
import 'tournament_timeline.dart';

class TournamentOverview extends StatefulWidget {
  const TournamentOverview({super.key});

  @override
  State<TournamentOverview> createState() => _TournamentOverviewState();
}

class _TournamentOverviewState extends State<TournamentOverview> {
  final TournamentService _tournamentService = TournamentService();
  final RefereeService _refereeService = RefereeService();
  String selectedCategory = 'Alle';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _tournamentService.initializeSampleData();
    await _refereeService.initializeSampleData();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isMobile = ResponsiveHelper.isMobile(screenWidth);
        
        return Container(
          padding: EdgeInsets.all(ResponsiveHelper.getContentPadding(screenWidth)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with category filter - responsive layout
              isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Turniere - Zeitleisten-Ansicht',
                          style: TextStyle(
                            fontSize: 24 * ResponsiveHelper.getFontScale(screenWidth),
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: _buildCategoryDropdown(),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Text(
                          'Turniere - Zeitleisten-Ansicht',
                          style: TextStyle(
                            fontSize: 28 * ResponsiveHelper.getFontScale(screenWidth),
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        _buildCategoryDropdown(),
                      ],
                    ),
              const SizedBox(height: 24),

              // Timeline View (only view now)
              Expanded(
                child: TournamentTimeline(selectedCategory: selectedCategory),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedCategory,
          isExpanded: ResponsiveHelper.isMobile(MediaQuery.of(context).size.width),
          items: const [
            DropdownMenuItem(
              value: 'Alle',
              child: Text('Kategorie: Alle'),
            ),
            DropdownMenuItem(
              value: 'GBO Juniors Cup',
              child: Text('Kategorie: Juniors'),
            ),
            DropdownMenuItem(
              value: 'GBO Seniors Cup',
              child: Text('Kategorie: Seniors'),
            ),
          ],
          onChanged: (value) {
            setState(() {
              selectedCategory = value!;
            });
          },
        ),
      ),
    );
  }
} 