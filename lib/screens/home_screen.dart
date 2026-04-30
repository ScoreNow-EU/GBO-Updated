import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/tournament_overview.dart';
import '../widgets/live_games_ticker.dart';
import '../models/user.dart' as app_user;
import '../services/auth_service.dart';
import '../services/face_id_service.dart';
import '../services/referee_service.dart';
import '../services/tournament_service.dart';
import '../widgets/admin_face_id_overlay.dart';
import '../widgets/mixed_font_title.dart';
import '../screens/login_screen.dart';
import '../screens/tournament_management_screen.dart';
import '../screens/team_management_screen.dart';
import '../screens/referee_management_screen.dart';
import '../screens/kampfgericht_management_screen.dart';
import '../screens/delegate_management_screen.dart';
import '../screens/team_manager_management_screen.dart';
import '../screens/player_management_screen.dart';
import '../screens/preset_management_screen.dart';
import '../screens/team_detail_screen.dart';
import '../screens/custom_notification_screen.dart';
import '../screens/user_role_management_screen.dart';
import '../screens/managed_account_screen.dart';
import '../screens/profile_settings_screen.dart';
import '../screens/scoring_tablet_screen.dart';
import '../screens/season_management_screen.dart';
import '../screens/rangliste_screen.dart';
import '../screens/public_teams_screen.dart';
import '../screens/season_calendar_screen.dart';
import '../screens/city_migration_screen.dart';
import '../screens/tournament_creation_wizard.dart';
import '../screens/tournament_edit_screen.dart';
import '../screens/tournament_approval_screen.dart';
import '../screens/demo_data_screen.dart';
import '../screens/to_software_screen.dart';
import '../screens/donation_screen.dart';
import '../screens/admin_donation_management_screen.dart';
import '../screens/app_store_splash_screen.dart';
import '../screens/generate_sign_in_codes_screen.dart';
import '../screens/admin_data_management_screen.dart';
import '../screens/kanban_board_screen.dart';
import '../services/managed_account_service.dart';
import '../models/managed_account.dart';
import '../screens/referee_dashboard_screen.dart';
import '../screens/delegate_dashboard_screen.dart';
import '../screens/commissioner_dashboard_screen.dart';
import '../screens/suspension_management_screen.dart';
import '../screens/fine_management_screen.dart';
import '../screens/player_dashboard_screen.dart';
import '../screens/protest_list_screen.dart';
import '../screens/venue_management_screen.dart';
import '../screens/player_transfer_screen.dart';
import '../screens/document_management_screen.dart';
import '../widgets/offline_banner.dart';
import '../services/web_notification_service.dart';

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
  final TournamentService _tournamentService = TournamentService();
  final ManagedAccountService _managedAccountService = ManagedAccountService();
  final WebNotificationService _webNotificationService = WebNotificationService();
  app_user.User? _currentUser;
  bool _isScoringTablet = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _listenToAuthChanges();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _listenToAuthChanges() {
    _authService.currentUser.listen((user) async {
      if (user == null) {
        // User logged out, reset to default section
        setState(() {
          _currentUser = null;
          selectedSection = 'turniere';
        });
      } else {
        // User logged in, check if scoring tablet and update current user
        bool isScoringTablet = false;
        try {
          final allAccounts = await _managedAccountService.getAllManagedAccounts().first;
          final managedAccount = allAccounts.firstWhere(
            (account) => account.email == user.email && account.type == ManagedAccountType.scoringTablet,
            orElse: () => throw Exception('Not a managed account'),
          );
          isScoringTablet = true;
        } catch (e) {
          // Not a scoring tablet
          isScoringTablet = false;
        }
        
        setState(() {
          _currentUser = user;
          _isScoringTablet = isScoringTablet;
        });
      }
    });
  }

  Future<void> _loadCurrentUser() async {
    final firebaseUser = _authService.currentFirebaseUser;
    if (firebaseUser != null) {
      final user = await _authService.getUserById(firebaseUser.uid);
      
      // Check if this is a scoring tablet user
      bool isScoringTablet = false;
      if (user != null) {
        try {
          final allAccounts = await _managedAccountService.getAllManagedAccounts().first;
          final managedAccount = allAccounts.firstWhere(
            (account) => account.email == user.email && account.type == ManagedAccountType.scoringTablet,
            orElse: () => throw Exception('Not a managed account'),
          );
          isScoringTablet = true;
        } catch (e) {
          // Not a scoring tablet
          isScoringTablet = false;
        }
      }
      
      setState(() {
        _currentUser = user;
        _isScoringTablet = isScoringTablet;
      });

      // Prompt for web notifications after user is authenticated
      _promptWebNotifications();
    } else {
      // No user, ensure we're on the default section
      setState(() {
        _currentUser = null;
        selectedSection = 'turniere';
      });
    }
  }

  /// Prompt user for browser notification permission (web only, once per session)
  Future<void> _promptWebNotifications() async {
    if (!_webNotificationService.isSupported) return;
    if (_webNotificationService.permissionStatus != 'default') return;

    // Small delay so the UI is settled before showing the prompt
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final shouldPrompt = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Benachrichtigungen'),
        content: const Text(
          'Möchtest du Benachrichtigungen über Spielstände erhalten?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Nein, danke'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ja, aktivieren'),
          ),
        ],
      ),
    );

    if (shouldPrompt == true) {
      await _webNotificationService.requestPermission();
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
      'city_migration',
      'generate_sign_in_codes',
      'admin_data_management',
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
    // Show specialized scoring tablet interface if user is a scoring tablet
    if (_isScoringTablet && _currentUser != null) {
      return ScoringTabletScreen(user: _currentUser!);
    }
    
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
            // Check if device has biometrics available before showing overlay
            final biometricAvailable = await _faceIdService.isBiometricAvailable();
            final availableBiometrics = await _faceIdService.getAvailableBiometrics();
            
            debugPrint('[HomeScreen] Face ID enabled, biometric available: $biometricAvailable, available biometrics count: ${availableBiometrics.length}');
            
            if (!biometricAvailable || availableBiometrics.isEmpty) {
              debugPrint('[HomeScreen] Device does not have available biometrics, skipping Face ID and navigating directly to section');
              // Device doesn't have biometrics, skip Face ID and go directly to section
              setState(() {
                selectedSection = section;
              });
              
              // If navigating to a team section, ensure we show the overview by default
              if (section.startsWith('team_') && !section.contains('_overview') && !section.contains('_tournaments') && !section.contains('_settings')) {
                setState(() {
                  selectedSection = '${section}_overview';
                });
              }
              return;
            }
            
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
        // But exclude admin management screens
        if (section.startsWith('team_') && 
            !section.contains('_overview') && 
            !section.contains('_tournaments') && 
            !section.contains('_settings') &&
            section != 'team_management' &&
            section != 'team_manager_management') {
          setState(() {
            selectedSection = '${section}_overview';
          });
        }
      },
      title: _getScreenTitle(),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: _buildMainContent()),
        ],
      ),
      ticker: (selectedSection == 'turniere' || selectedSection == 'rangliste') 
          ? const LiveGamesTicker() 
          : null,
      currentUser: _currentUser,
      onUserUpdated: () {
        // Refresh current user after auto-linking
        print('🔄 User updated, refreshing current user...');
        _loadCurrentUser();
      },
      hideAppBar: selectedSection == 'rangliste', // Hide AppBar for rangliste since it has its own
    );
  }

  dynamic _getScreenTitle() {
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
      case 'teams':
        return 'Teams';
      case 'saisonkalender':
        return 'Saisonkalender';
      case 'preset_management':
        return 'Preset Verwaltung';
      case 'tournament_management':
        return 'Tournament Management';
      case 'tournament_approval':
        return 'Turnier-Freigaben';
      case 'team_management':
        return 'Team Management';
      case 'referee_management':
        return 'Schiedsrichter Verwaltung';
      case 'kampfgericht_management':
        return 'Kampfgericht Verwaltung';
      case 'delegate_management':
        return 'Delegierte Verwaltung';
      case 'team_manager_management':
        return 'Team Manager Verwaltung';
      case 'player_management':
        return 'Kader Verwaltung';
      case 'custom_notifications':
        return 'Benachrichtigungen senden';
      case 'user_role_management':
        return 'Benutzer-Rollen-Verwaltung';
      case 'season_management':
        return 'Saison Management';
      case 'city_migration':
        return 'Städte Migration';
      case 'new_tournament':
        return 'Neues Turnier';
      case 'generate_sign_in_codes':
        return 'Einmalige Anmeldecodes erstellen';
      case 'demo_data':
        return 'Demo Daten Erstellen';
      case 'referee_dashboard':
        return 'Schiedsrichter Dashboard';
      case 'referee_games':
        return 'Meine Spiele';
      case 'delegate_dashboard':
        return 'Delegierten Dashboard';
      case 'commissioner_dashboard':
        return 'Kommissar Dashboard';
      case 'suspension_management':
        return 'Sperren-Verwaltung';
      case 'fine_management':
        return 'Strafen & Bußgelder';
      case 'player_dashboard':
        return 'Spieler Dashboard';
      case 'protest_list':
        return 'Proteste';
      case 'venue_management':
        return 'Hallenbörse';
      case 'player_transfers':
        return 'Spielertransfers';
      case 'document_management':
        return 'Dokumentenverwaltung';
      case 'scoring_tablet':
        return 'Live Scoring';
      case 'kanban_board':
        return 'Kanban Board';
      default:
        // Handle team detail sections
        if (selectedSection.startsWith('team_')) {
          return 'Team Details';
        }
        return const MixedFontTitle();
    }
  }

  Widget _buildMainContent() {
    // Handle specific admin sections first (before generic team_ handling)
    switch (selectedSection) {
      case 'login':
        return const LoginScreen();
      case 'turniere':
        return const TournamentOverview();
      case 'rangliste':
        return const RanglisteScreen();
      case 'teams':
        return const PublicTeamsScreen();
      case 'saisonkalender':
        return const SeasonCalendarScreen();
      case 'preset_management':
        return const PresetManagementScreen();
      case 'tournament_management':
        return TournamentManagementScreen(currentUser: _currentUser);
      case 'tournament_approval':
        return _currentUser != null
            ? TournamentApprovalScreen(currentUser: _currentUser!)
            : const Center(child: Text('Bitte melden Sie sich an.'));
      case 'team_management':
        return const TeamManagementScreen();
      case 'referee_management':
        return const RefereeManagementScreen();
      case 'kampfgericht_management':
        return const KampfgerichtManagementScreen();
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
      case 'season_management':
        return const SeasonManagementScreen();
      case 'city_migration':
        return const CityMigrationScreen();
      case 'managed_accounts':
        return const ManagedAccountScreen();
      case 'profile_settings':
        return const ProfileSettingsScreen();
      case 'new_tournament':
        return const TournamentCreationWizard();
      // Donation routes disabled for Apple App Store submission
      // case 'donation':
      //   return const DonationScreen();
      // case 'admin_donation_management':
      //   return const AdminDonationManagementScreen();
      case 'generate_sign_in_codes':
        return const GenerateSignInCodesScreen();
      case 'admin_data_management':
        return const AdminDataManagementScreen();
      case 'app_store_splash':
        return AppStoreSplashScreen(
          onComplete: () {
            Navigator.of(context).pop();
          },
        );
      case 'demo_data':
        return const DemoDataScreen();
      // Phase 3: Role-specific dashboards
      case 'referee_dashboard':
        return const RefereeDashboardScreen();
      case 'referee_games':
        return const RefereeDashboardScreen();
      case 'delegate_dashboard':
        return const DelegateDashboardScreen();
      case 'commissioner_dashboard':
        return const CommissionerDashboardScreen();
      case 'suspension_management':
        return const SuspensionManagementScreen();
      case 'fine_management':
        return const FineManagementScreen();
      case 'player_dashboard':
        return const PlayerDashboardScreen();
      case 'protest_list':
        return const ProtestListScreen(tournamentId: '');
      case 'venue_management':
        return const VenueManagementScreen();
      case 'player_transfers':
        return const PlayerTransferScreen();
      case 'document_management':
        return const DocumentManagementScreen();
      case 'scoring_tablet':
        return _currentUser != null
            ? ScoringTabletScreen(user: _currentUser!)
            : const Center(child: Text('Bitte melden Sie sich an.'));
      case 'kanban_board':
        return const KanbanBoardScreen();
    }

    // Handle referee tournament sections
    if (selectedSection.startsWith('referee_tournament_')) {
      final prefix = 'referee_tournament_';
      final suffix = selectedSection.substring(prefix.length);

      String? tournamentId;
      if (suffix.endsWith('_overview')) {
        tournamentId = suffix.substring(0, suffix.length - '_overview'.length);
      } else if (suffix.endsWith('_games')) {
        tournamentId = suffix.substring(0, suffix.length - '_games'.length);
      } else {
        tournamentId = suffix;
      }

      if (tournamentId.isNotEmpty) {
        return RefereeDashboardScreen(key: ValueKey('referee_$tournamentId'));
      }
    }

    // Handle team detail sections (after specific admin sections)
    if (selectedSection.startsWith('team_') && 
        !selectedSection.startsWith('team_management') && 
        !selectedSection.startsWith('team_manager_management')) {
      final parts = selectedSection.split('_');
      print('🏠 HomeScreen - selectedSection: $selectedSection');
      print('🏠 HomeScreen - parts: $parts');
      if (parts.length >= 2) {
        final teamId = parts[1];
        final subSection = parts.length > 2 ? parts[2] : 'overview';
        print('🏠 HomeScreen - teamId: $teamId, subSection: $subSection');
        return TeamDetailContent(teamId: teamId, subSection: subSection);
      }
    }

    // Handle organizer tournament sections
    if (selectedSection.startsWith('organizer_tournament_')) {
      print('Handling organizer tournament section: $selectedSection');
      
      // More robust parsing that handles special characters in tournament ID
      final prefix = 'organizer_tournament_';
      final suffix = selectedSection.substring(prefix.length);
      
      // Check for specific subsections to avoid issues with underscores in tournament ID
      String? tournamentId;
      String? subSection;
      
      if (suffix.endsWith('_to_software')) {
        tournamentId = suffix.substring(0, suffix.length - '_to_software'.length);
        subSection = 'to_software';
      } else if (suffix.endsWith('_edit')) {
        tournamentId = suffix.substring(0, suffix.length - '_edit'.length);
        subSection = 'edit';
      }
      
      if (tournamentId != null && subSection != null) {
        
        print('Tournament ID: $tournamentId, SubSection: $subSection');
        
        if (subSection == 'edit') {
          // Navigate to tournament edit screen as full screen
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _navigateToTournamentEdit(tournamentId!);
          });
          // Return a placeholder while navigation happens
          return const Center(
            child: Text('Weiterleitung zum Turnier Editor...'),
          );
        } else if (subSection == 'to_software') {
          print('Navigating to TO Software for tournament: $tournamentId');
          // Navigate to TO Software screen as full screen
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _navigateToTOSoftware(tournamentId!);
          });
          // Return a placeholder while navigation happens
          return const Center(
            child: Text('Weiterleitung zur TO Software...'),
          );
        }
      }
    }

    // Default fallback
    return const TournamentOverview();
  }

  void _navigateToTournamentEdit(String tournamentId) async {
    try {
      final tournament = await _tournamentService.getTournamentById(tournamentId);
      if (tournament != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TournamentEditScreen(tournament: tournament),
            settings: const RouteSettings(name: 'TournamentEditScreen'),
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Turnier nicht gefunden'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Laden des Turniers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToTOSoftware(String tournamentId) async {
    print('_navigateToTOSoftware called with tournamentId: $tournamentId');
    try {
      final tournament = await _tournamentService.getTournamentById(tournamentId);
      print('Tournament found: ${tournament?.name}');
      if (tournament != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TOSoftwareScreen(tournament: tournament),
            settings: const RouteSettings(name: 'TOSoftwareScreen'),
          ),
        );
      } else {
        print('Tournament not found for ID: $tournamentId');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Turnier nicht gefunden'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error in _navigateToTOSoftware: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Laden des Turniers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


} 