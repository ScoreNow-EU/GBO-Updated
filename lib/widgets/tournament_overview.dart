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
          padding: EdgeInsets.all(isMobile ? 8.0 : ResponsiveHelper.getContentPadding(screenWidth)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category filter - responsive layout
              isMobile
                  ? Container(
                      width: double.infinity,
                      child: _buildCategoryDropdown(),
                    )
                  : Row(
                      children: [
                        const Spacer(),
                        _buildCategoryDropdown(),
                      ],
                    ),
              SizedBox(height: isMobile ? 12 : 24),

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
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedCategory,
          isExpanded: true,
          items: const [
            DropdownMenuItem(
              value: 'Alle',
              child: Text('Kategorie: Alle', overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: 'GBO Juniors Cup',
              child: Text('Kategorie: Juniors', overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: 'GBO Seniors Cup',
              child: Text('Kategorie: Seniors', overflow: TextOverflow.ellipsis),
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