import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/responsive_helper.dart';
import 'side_navigation.dart';

class ResponsiveLayout extends StatefulWidget {
  final String selectedSection;
  final Function(String) onSectionChanged;
  final String title;
  final Widget body;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const ResponsiveLayout({
    super.key,
    required this.selectedSection,
    required this.onSectionChanged,
    required this.title,
    required this.body,
    this.showBackButton = false,
    this.onBackPressed,
  });

  @override
  State<ResponsiveLayout> createState() => _ResponsiveLayoutState();
}

class _ResponsiveLayoutState extends State<ResponsiveLayout> {
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    
    // Listen to auth state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        
        if (ResponsiveHelper.shouldUseDrawer(screenWidth)) {
          // Mobile layout with drawer
          return Scaffold(
            appBar: AppBar(
              title: Text(
                widget.title,
                style: TextStyle(
                  fontSize: 18 * ResponsiveHelper.getFontScale(screenWidth),
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 1,
              leading: widget.showBackButton 
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: widget.onBackPressed ?? () => Navigator.of(context).pop(),
                    tooltip: 'Zurück',
                  )
                : Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      tooltip: 'Menü öffnen',
                    ),
                  ),
              actions: widget.showBackButton 
                ? [
                    Builder(
                      builder: (context) => IconButton(
                        icon: const Icon(Icons.menu),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                        tooltip: 'Menü öffnen',
                      ),
                    ),
                  ]
                : null,
            ),
            drawer: _buildNavigationDrawer(screenWidth),
            body: Container(
              color: Colors.grey[100],
              child: Padding(
                padding: EdgeInsets.all(ResponsiveHelper.getContentPadding(screenWidth)),
                child: widget.body,
              ),
            ),
          );
        } else {
          // Desktop/Tablet layout with side navigation
          return Scaffold(
            body: Row(
              children: [
                SideNavigation(
                  selectedSection: widget.selectedSection,
                  onSectionChanged: widget.onSectionChanged,
                ),
                Expanded(
                  child: Container(
                    color: Colors.grey[100],
                    child: Column(
                      children: [
                        if (widget.showBackButton)
                          Container(
                            height: 60,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                              ),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                                  onPressed: widget.onBackPressed ?? () => Navigator.of(context).pop(),
                                  tooltip: 'Zurück',
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    widget.title,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(ResponsiveHelper.getContentPadding(screenWidth)),
                            child: widget.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildNavigationDrawer(double screenWidth) {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Header
            Container(
              height: 160,
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2),
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'logo.png',
                    height: 60,
                    width: 90,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'German Beach Open',
                    style: TextStyle(
                      fontSize: 16 * ResponsiveHelper.getFontScale(screenWidth),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // Navigation Menu
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // User Profile or Login
                  _currentUser != null ? _buildDrawerUserProfile(screenWidth) : _buildDrawerItem(
                    icon: Icons.person,
                    title: 'Login',
                    key: 'login',
                    isSelected: widget.selectedSection == 'login',
                    screenWidth: screenWidth,
                  ),
                  _buildDrawerItem(
                    icon: Icons.sports_volleyball,
                    title: 'Turniere',
                    key: 'turniere',
                    isSelected: widget.selectedSection == 'turniere',
                    screenWidth: screenWidth,
                  ),
                  _buildDrawerItem(
                    icon: Icons.leaderboard,
                    title: 'Rangliste',
                    key: 'rangliste',
                    isSelected: widget.selectedSection == 'rangliste',
                    screenWidth: screenWidth,
                  ),
                  
                  const Divider(height: 32),
                  
                  // Admin Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'ADMIN BEREICH',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12 * ResponsiveHelper.getFontScale(screenWidth),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  _buildDrawerItem(
                    icon: Icons.architecture,
                    title: 'Preset Verwaltung',
                    key: 'preset_management',
                    isSelected: widget.selectedSection == 'preset_management',
                    screenWidth: screenWidth,
                    isAdmin: true,
                  ),
                  _buildDrawerItem(
                    icon: Icons.settings,
                    title: 'Tournament Management',
                    key: 'tournament_management',
                    isSelected: widget.selectedSection == 'tournament_management',
                    screenWidth: screenWidth,
                    isAdmin: true,
                  ),
                  _buildDrawerItem(
                    icon: Icons.group,
                    title: 'Team Management',
                    key: 'team_management',
                    isSelected: widget.selectedSection == 'team_management',
                    screenWidth: screenWidth,
                    isAdmin: true,
                  ),
                  _buildDrawerItem(
                    icon: Icons.sports_hockey,
                    title: 'Schiedsrichter Verwaltung',
                    key: 'referee_management',
                    isSelected: widget.selectedSection == 'referee_management',
                    screenWidth: screenWidth,
                    isAdmin: true,
                  ),
                  _buildDrawerItem(
                    icon: Icons.person_pin_circle,
                    title: 'Delegierte Verwaltung',
                    key: 'delegate_management',
                    isSelected: widget.selectedSection == 'delegate_management',
                    screenWidth: screenWidth,
                    isAdmin: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

    Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String key,
    required bool isSelected,
    required double screenWidth,
    bool isAdmin = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected 
          ? (isAdmin ? const Color(0xFF4A5568).withOpacity(0.2) : Colors.blue.withOpacity(0.1))
          : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Builder(
        builder: (context) => ListTile(
          dense: true,
          leading: Icon(
            icon,
            color: isSelected 
              ? (isAdmin ? const Color(0xFF4A5568) : Colors.blue.shade700)
              : (isAdmin ? const Color(0xFF4A5568).withOpacity(0.7) : Colors.grey.shade600),
            size: 20,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: isSelected 
                ? (isAdmin ? const Color(0xFF4A5568) : Colors.blue.shade700)
                : (isAdmin ? const Color(0xFF4A5568).withOpacity(0.8) : Colors.black87),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 14 * ResponsiveHelper.getFontScale(screenWidth),
            ),
          ),
          onTap: () {
            widget.onSectionChanged(key);
            Navigator.of(context).pop(); // Close drawer after selection
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
      ),
    );
  }

  Widget _buildDrawerUserProfile(double screenWidth) {
    if (_currentUser == null) return Container();
    
    final displayName = _currentUser!.displayName ?? 'Benutzer';
    final email = _currentUser!.email ?? '';
    final photoUrl = _currentUser!.photoURL;
    
    // Generate initials from display name
    String getInitials(String name) {
      List<String> nameParts = name.trim().split(' ');
      if (nameParts.length >= 2) {
        return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
      } else if (nameParts.isNotEmpty) {
        return nameParts[0][0].toUpperCase();
      }
      return 'U';
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // User Info Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Profile Picture or Initials
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1976D2),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: photoUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Text(
                                  getInitials(displayName),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : Center(
                          child: Text(
                            getInitials(displayName),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                
                // User Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 14 * ResponsiveHelper.getFontScale(screenWidth),
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 12 * ResponsiveHelper.getFontScale(screenWidth),
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Logout Button
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: TextButton.icon(
              onPressed: () async {
                Navigator.of(context).pop(); // Close drawer first
                await FirebaseAuth.instance.signOut();
                widget.onSectionChanged('turniere'); // Navigate to tournaments after logout
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red.shade600,
                backgroundColor: Colors.red.shade50,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: Icon(Icons.logout, size: 16, color: Colors.red.shade600),
              label: Text(
                'Abmelden',
                style: TextStyle(
                  fontSize: 12 * ResponsiveHelper.getFontScale(screenWidth),
                  fontWeight: FontWeight.w500,
                  color: Colors.red.shade600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 