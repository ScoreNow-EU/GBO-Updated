import 'package:flutter/material.dart';
import '../widgets/side_navigation.dart';
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
    return Scaffold(
      body: Row(
        children: [
          // Left Navigation Panel
          SideNavigation(
            selectedSection: selectedSection,
            onSectionChanged: (section) {
              setState(() {
                selectedSection = section;
              });
            },
          ),
          // Main Content Area
          Expanded(
            child: Container(
              color: Colors.grey[100],
              child: _buildMainContent(),
            ),
          ),
        ],
      ),
    );
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