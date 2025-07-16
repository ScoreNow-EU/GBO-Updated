import 'package:flutter/material.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/tournament_overview.dart';
import '../models/user.dart' as app_user;
import '../services/auth_service.dart';
import 'tournament_management_screen.dart';
import 'team_management_screen.dart';
import 'preset_management_screen.dart';
import 'referee_management_screen.dart';
import 'referee_dashboard_screen.dart';
import 'delegate_management_screen.dart';
import 'team_manager_management_screen.dart';
import 'player_management_screen.dart';
import 'live_notifications_screen.dart';
import 'team_detail_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedSection = 'turniere'; // Default to Turniere section
  final AuthService _authService = AuthService();
  app_user.User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authService.currentUser.listen((user) {
      if (user == null) {
        // User logged out, reset to default section
        setState(() {
          _currentUser = null;
          selectedSection = 'turniere';
        });
      } else {
        // User logged in, update current user
        setState(() {
          _currentUser = user;
          // Set default section based on user role
          if (user.role == app_user.UserRole.referee) {
            selectedSection = 'referee_dashboard';
          }
        });
      }
    });
  }

  Future<void> _loadCurrentUser() async {
    final firebaseUser = _authService.currentFirebaseUser;
    if (firebaseUser != null) {
      final user = await _authService.getUserById(firebaseUser.uid);
      setState(() {
        _currentUser = user;
        // Set default section based on user role
        if (user?.role == app_user.UserRole.referee) {
          selectedSection = 'referee_dashboard';
        }
      });
    } else {
      // No user, ensure we're on the default section
      setState(() {
        _currentUser = null;
        selectedSection = 'turniere';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Handle login screen specially to preserve its blue background
    if (selectedSection == 'login') {
      return LoginScreen(
        onNavigateBack: () {
          setState(() {
            selectedSection = 'turniere';
          });
        },
      );
    }
    
    // Team detail sections are handled in the main ResponsiveLayout now
    
    return ResponsiveLayout(
      selectedSection: selectedSection,
      onSectionChanged: (section) {
        // Prevent unauthorized access to referee dashboard
        if (section == 'referee_dashboard') {
          if (_currentUser == null || _currentUser!.role != app_user.UserRole.referee) {
            // Redirect to login or home if not authorized
            section = _currentUser == null ? 'login' : 'turniere';
          }
        }
        
        setState(() {
          selectedSection = section;
        });
        
        // If navigating to a team section, ensure we show the overview by default
        if (section.startsWith('team_') && !section.contains('_overview') && !section.contains('_tournaments') && !section.contains('_settings')) {
          setState(() {
            selectedSection = '${section}_overview';
          });
        }
      },
      title: _getScreenTitle(),
      body: _buildMainContent(),
      currentUser: _currentUser,
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
      case 'delegate_management':
        return 'Delegierte Verwaltung';
      case 'team_manager_management':
        return 'Team Manager Verwaltung';
      case 'player_management':
        return 'Kader Verwaltung';
      case 'live_notifications':
        return 'Live Notifications';
      case 'referee_dashboard':
        return 'Schiedsrichter Dashboard';
      default:
        // Handle team detail sections
        if (selectedSection.startsWith('team_')) {
          return 'Team Details';
        }
        return 'German Beach Open';
    }
  }

  Widget _buildMainContent() {
    // Handle team detail sections
    if (selectedSection.startsWith('team_')) {
      final parts = selectedSection.split('_');
      if (parts.length >= 2) {
        final teamId = parts[1];
        final subSection = parts.length > 2 ? parts[2] : 'overview';
        return TeamDetailContent(teamId: teamId, subSection: subSection);
      }
    }
    
    switch (selectedSection) {
      case 'login':
        return const LoginScreen();
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
      case 'delegate_management':
        return const DelegateManagementScreen();
      case 'team_manager_management':
        return const TeamManagerManagementScreen();
      case 'player_management':
        return const PlayerManagementScreen();
      case 'live_notifications':
        return const LiveNotificationsScreen();
      case 'referee_dashboard':
        return _currentUser != null 
            ? RefereeDashboardScreen(currentUser: _currentUser!)
            : const Center(child: Text('Bitte melden Sie sich an.'));
      default:
        return const TournamentOverview();
    }
  }
} 