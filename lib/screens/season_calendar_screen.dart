import 'package:flutter/material.dart';
import '../widgets/season_calendar_view.dart';

/// Top-level screen shown via the sidebar entry "Saisonkalender".
/// Aggregates all games of the active season across tournaments.
class SeasonCalendarScreen extends StatelessWidget {
  const SeasonCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade50,
      child: const SeasonCalendarView(),
    );
  }
}
