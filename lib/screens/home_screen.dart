import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/tournament_overview.dart';
import '../models/user.dart' as app_user;
import '../services/auth_service.dart';
import '../services/face_id_service.dart';
import '../services/referee_service.dart';
import '../services/referee_invitation_monitoring_service.dart';
import '../widgets/admin_face_id_overlay.dart';
import '../screens/login_screen.dart';
import '../screens/tournament_management_screen.dart';
import '../screens/tournament_detail_screen.dart';
import '../screens/team_management_screen.dart';
import '../screens/referee_management_screen.dart';
import '../screens/referee_dashboard_screen.dart';
import '../screens/delegate_management_screen.dart';
import '../screens/team_manager_management_screen.dart';
import '../screens/player_management_screen.dart';
import '../screens/preset_management_screen.dart';
import '../screens/team_detail_screen.dart';
import '../screens/custom_notification_screen.dart';
import '../screens/user_role_management_screen.dart';
import '../screens/referee_games_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedSection = 'turniere'; // Default to Turniere section
  final AuthService _authService = AuthService();
  final FaceIdService _faceIdService = FaceIdService();
  final RefereeService _refereeService = RefereeService();
  app_user.User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _listenToAuthChanges();
  }

  @override
  void dispose() {
    // Stop monitoring when app is closed
    RefereeInvitationMonitoringService.stopMonitoring();
    super.dispose();
  }

  void _listenToAuthChanges() {
    _authService.currentUser.listen((user) async {
      if (user == null) {
        // User logged out, stop monitoring and reset to default section
        print('🔴 User logged out, stopping monitoring');
        await RefereeInvitationMonitoringService.stopMonitoring();
        setState(() {
          _currentUser = null;
          selectedSection = 'turniere';
        });
      } else {
        // User logged in, update current user
        setState(() {
          _currentUser = user;
          // Set default section based on user role
          if (user.roles.contains(app_user.UserRole.referee)) {
            selectedSection = 'referee_dashboard';
          }
        });
        
        // Start monitoring if user is a referee
        if (user.roles.contains(app_user.UserRole.referee) && user.refereeId != null) {
          try {
            print('🟢 Referee logged in, starting monitoring');
            final referee = await _refereeService.getRefereeById(user.refereeId!);
            if (referee != null) {
              await RefereeInvitationMonitoringService.startMonitoring(referee.id);
              print('🔔 Monitoring started for referee: ${referee.fullName}');
            } else {
              print('❌ Could not find referee profile for ID: ${user.refereeId}');
            }
          } catch (e) {
            print('❌ Error starting monitoring: $e');
          }
        }
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
        if (user?.roles.contains(app_user.UserRole.referee) == true) {
          selectedSection = 'referee_dashboard';
        }
      });
      
      // Start monitoring if user is a referee and app is starting up
      if (user?.roles.contains(app_user.UserRole.referee) == true && user?.refereeId != null) {
        try {
          print('🟢 App startup: Referee found, starting monitoring');
          final referee = await _refereeService.getRefereeById(user!.refereeId!);
          if (referee != null) {
            await RefereeInvitationMonitoringService.startMonitoring(referee.id);
            print('🔔 Monitoring started for referee: ${referee.fullName}');
          } else {
            print('❌ Could not find referee profile for ID: ${user.refereeId}');
          }
        } catch (e) {
          print('❌ Error starting monitoring on startup: $e');
        }
      }
    } else {
      // No user, ensure we're on the default section
      setState(() {
        _currentUser = null;
        selectedSection = 'turniere';
      });
    }
  }

  /// Check if a section is an admin section that requires Face ID
  bool _isAdminSection(String section) {
    final adminSections = [
      'tournament_management',
      'team_management',
      'referee_management',
      'delegate_management',
      'team_manager_management',
      'player_management',
      'preset_management',
      'custom_notifications',
      'user_role_management',
    ];
    
    return adminSections.contains(section);
  }

  void _showErrorToast(String message) {
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.fillColored,
      title: const Text('Fehler'),
      description: Text(message),
      alignment: Alignment.topRight,
      autoCloseDuration: const Duration(seconds: 4),
      showProgressBar: false,
    );
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
      onSectionChanged: (section) async {
        // Prevent unauthorized access to referee dashboard
        if (section == 'referee_dashboard') {
          if (_currentUser == null || !_currentUser!.roles.contains(app_user.UserRole.referee)) {
            // Redirect to login or home if not authorized
            section = _currentUser == null ? 'login' : 'turniere';
          }
        }
        
        // Check if this is an admin section that requires Face ID
        if (_isAdminSection(section)) {
          // Ensure user is logged in before checking Face ID
          if (_currentUser == null) {
            // User not logged in, redirect to login
            setState(() {
              selectedSection = 'login';
            });
            return;
          }
          
          // Check if user has admin role
          if (!_currentUser!.roles.contains(app_user.UserRole.admin)) {
            // User doesn't have admin role, redirect to home
            setState(() {
              selectedSection = 'turniere';
            });
            return;
          }
          
          final faceIdEnabled = await _faceIdService.isFaceIdEnabled();
          
          if (faceIdEnabled) {
            // Show Face ID authentication overlay
            await showAdminFaceIdOverlay(
              context,
              onAuthenticationComplete: (success, message) {
                Navigator.of(context).pop(); // Close the overlay
                
                if (success) {
                  // Authentication successful - navigate to the section
                  setState(() {
                    selectedSection = section;
                  });
                  
                  // If navigating to a team section, ensure we show the overview by default
                  if (section.startsWith('team_') && !section.contains('_overview') && !section.contains('_tournaments') && !section.contains('_settings')) {
                    setState(() {
                      selectedSection = '${section}_overview';
                    });
                  }
                  
                  if (message != null) {
                    // Don't show success toast as it's redundant for admin access
                  }
                } else {
                  // Authentication failed - show error and don't navigate
                  if (message != null) {
                    _showErrorToast(message);
                  }
                }
              },
              onCancel: () {
                Navigator.of(context).pop(); // Close the overlay
                // Stay on current section, don't navigate
              },
            );
            
            // Return early - navigation will happen in the callback
            return;
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
      onUserUpdated: () {
        // Refresh current user after auto-linking
        print('🔄 User updated, refreshing current user...');
        _loadCurrentUser();
      },
    );
  }

  String _getScreenTitle() {
    // Handle referee tournament sections
    if (selectedSection.startsWith('referee_tournament_')) {
      final parts = selectedSection.split('_');
      if (parts.length >= 3) {
        final tournamentId = parts[2];
        final subSection = parts.length > 3 ? parts[3] : 'overview';
        if (subSection == 'games') {
          return 'Spielplan';
        }
      }
    }

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
      case 'custom_notifications':
        return 'Benachrichtigungen senden';
      case 'referee_dashboard':
        return 'Schiedsrichter Dashboard';
      case 'referee_games':
        return 'Meine Spiele';
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

    // Handle referee tournament sections
    if (selectedSection.startsWith('referee_tournament_')) {
      final parts = selectedSection.split('_');
      if (parts.length >= 3) {
        final tournamentId = parts[2];
        final subSection = parts.length > 3 ? parts[3] : 'overview';
        if (subSection == 'games') {
          return _currentUser?.refereeId != null
              ? RefereeGamesScreen(refereeId: _currentUser!.refereeId!, tournamentId: tournamentId)
              : const Center(child: Text('Bitte melden Sie sich an.'));
        }
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
      case 'custom_notifications':
        return const CustomNotificationScreen();
      case 'user_role_management':
        return const UserRoleManagementScreen();
      case 'referee_dashboard':
        return _currentUser != null 
            ? RefereeDashboardScreen(currentUser: _currentUser!)
            : const Center(child: Text('Bitte melden Sie sich an.'));
      case 'referee_games':
        return _currentUser?.refereeId != null
            ? RefereeGamesScreen(refereeId: _currentUser!.refereeId!)
            : const Center(child: Text('Bitte melden Sie sich an.'));
      default:
        return const TournamentOverview();
    }
  }
} 