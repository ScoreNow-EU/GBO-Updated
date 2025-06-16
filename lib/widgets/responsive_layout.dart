import 'package:flutter/material.dart';
import '../utils/responsive_helper.dart';
import 'side_navigation.dart';

class ResponsiveLayout extends StatelessWidget {
  final String selectedSection;
  final Function(String) onSectionChanged;
  final Widget body;
  final String title;

  const ResponsiveLayout({
    super.key,
    required this.selectedSection,
    required this.onSectionChanged,
    required this.body,
    required this.title,
  });

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
                title,
                style: TextStyle(
                  fontSize: 18 * ResponsiveHelper.getFontScale(screenWidth),
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 1,
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  tooltip: 'Menü öffnen',
                ),
              ),
            ),
            drawer: _buildNavigationDrawer(screenWidth),
            body: Container(
              color: Colors.grey[100],
              child: Padding(
                padding: EdgeInsets.all(ResponsiveHelper.getContentPadding(screenWidth)),
                child: body,
              ),
            ),
          );
        } else {
          // Desktop/Tablet layout with side navigation
          return Scaffold(
            body: Row(
              children: [
                SideNavigation(
                  selectedSection: selectedSection,
                  onSectionChanged: onSectionChanged,
                ),
                Expanded(
                  child: Container(
                    color: Colors.grey[100],
                    child: Padding(
                      padding: EdgeInsets.all(ResponsiveHelper.getContentPadding(screenWidth)),
                      child: body,
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
                  _buildDrawerItem(
                    icon: Icons.person,
                    title: 'Login',
                    key: 'login',
                    isSelected: selectedSection == 'login',
                    screenWidth: screenWidth,
                  ),
                  _buildDrawerItem(
                    icon: Icons.sports_volleyball,
                    title: 'Turniere',
                    key: 'turniere',
                    isSelected: selectedSection == 'turniere',
                    screenWidth: screenWidth,
                  ),
                  _buildDrawerItem(
                    icon: Icons.leaderboard,
                    title: 'Rangliste',
                    key: 'rangliste',
                    isSelected: selectedSection == 'rangliste',
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
                    isSelected: selectedSection == 'preset_management',
                    screenWidth: screenWidth,
                    isAdmin: true,
                  ),
                  _buildDrawerItem(
                    icon: Icons.settings,
                    title: 'Tournament Management',
                    key: 'tournament_management',
                    isSelected: selectedSection == 'tournament_management',
                    screenWidth: screenWidth,
                    isAdmin: true,
                  ),
                  _buildDrawerItem(
                    icon: Icons.group,
                    title: 'Team Management',
                    key: 'team_management',
                    isSelected: selectedSection == 'team_management',
                    screenWidth: screenWidth,
                    isAdmin: true,
                  ),
                  _buildDrawerItem(
                    icon: Icons.sports_hockey,
                    title: 'Schiedsrichter Verwaltung',
                    key: 'referee_management',
                    isSelected: selectedSection == 'referee_management',
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
            onSectionChanged(key);
            Navigator.of(context).pop(); // Close drawer after selection
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
      ),
    );
  }
} 