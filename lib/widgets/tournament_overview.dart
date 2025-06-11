import 'package:flutter/material.dart';
import '../models/tournament.dart';
import '../services/tournament_service.dart';
import '../screens/tournament_detail_screen.dart';
import 'tournament_timeline.dart';

class TournamentOverview extends StatefulWidget {
  const TournamentOverview({super.key});

  @override
  State<TournamentOverview> createState() => _TournamentOverviewState();
}

class _TournamentOverviewState extends State<TournamentOverview> {
  final TournamentService _tournamentService = TournamentService();
  String selectedCategory = 'Alle';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _tournamentService.initializeSampleData();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with category filter
          Row(
            children: [
              const Text(
                'Turniere - Zeitleisten-Ansicht',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              // Category Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedCategory,
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
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Timeline View (only view now)
          Expanded(
            child: TournamentTimeline(selectedCategory: selectedCategory),
          ),
        ],
      ),
    );
  }
} 