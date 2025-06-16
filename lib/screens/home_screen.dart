import 'package:flutter/material.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/tournament_overview.dart';
import 'tournament_management_screen.dart';
import 'team_management_screen.dart';
import 'preset_management_screen.dart';
import 'referee_management_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedSection = 'turniere'; // Default to Turniere section

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      selectedSection: selectedSection,
      onSectionChanged: (section) {
        setState(() {
          selectedSection = section;
        });
      },
      title: _getScreenTitle(),
      body: _buildMainContent(),
    );
  }

  String _getScreenTitle() {
    switch (selectedSection) {
      case 'login':
        return 'Login';
      case 'turniere':
        return 'Turniere';
      case 'rangliste':
        return 'Rangliste';
      case 'preset_management':
        return 'Preset Verwaltung';
      case 'tournament_management':
        return 'Tournament Management';
      case 'team_management':
        return 'Team Management';
      case 'referee_management':
        return 'Schiedsrichter Verwaltung';
      default:
        return 'German Beach Open';
    }
  }

  Widget _buildMainContent() {
    switch (selectedSection) {
      case 'login':
        return const Center(
          child: Text(
            'Login Page - Coming Soon',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        );
      case 'turniere':
        return const TournamentOverview();
      case 'rangliste':
        return const Center(
          child: Text(
            'Rangliste (Rankings) - Coming Soon',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        );
      case 'preset_management':
        return const PresetManagementScreen();
      case 'tournament_management':
        return const TournamentManagementScreen();
      case 'team_management':
        return const TeamManagementScreen();
      case 'referee_management':
        return const RefereeManagementScreen();
      default:
        return const TournamentOverview();
    }
  }
} 