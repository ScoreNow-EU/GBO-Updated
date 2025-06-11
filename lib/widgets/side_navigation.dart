import 'package:flutter/material.dart';

class SideNavigation extends StatelessWidget {
  final String selectedSection;
  final Function(String) onSectionChanged;

  const SideNavigation({
    super.key,
    required this.selectedSection,
    required this.onSectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Logo Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: Column(
              children: [
                Image.asset(
                  'logo.png',
                  height: 80,
                  width: 120,
                ),
                const SizedBox(height: 8),
                const Text(
                  'German Beach Open',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
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
                _buildNavigationItem(
                  icon: Icons.person,
                  title: 'Login',
                  key: 'login',
                  isSelected: selectedSection == 'login',
                ),
                _buildNavigationItem(
                  icon: Icons.sports_volleyball,
                  title: 'Turniere',
                  key: 'turniere',
                  isSelected: selectedSection == 'turniere',
                ),
                _buildNavigationItem(
                  icon: Icons.leaderboard,
                  title: 'Rangliste',
                  key: 'rangliste',
                  isSelected: selectedSection == 'rangliste',
                ),
                
                const SizedBox(height: 16),
                
                // Admin Section with continuous black background
                _buildAdminSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF4A5568),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Admin Section Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Text(
              'ADMIN BEREICH',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
          
          // Admin Items
          _buildAdminItem(
            icon: Icons.architecture,
            title: 'Preset Verwaltung',
            key: 'preset_management',
            isSelected: selectedSection == 'preset_management',
          ),
          _buildAdminItem(
            icon: Icons.settings,
            title: 'Tournament Management',
            key: 'tournament_management',
            isSelected: selectedSection == 'tournament_management',
          ),
          _buildAdminItem(
            icon: Icons.group,
            title: 'Team Management',
            key: 'team_management',
            isSelected: selectedSection == 'team_management',
          ),
          _buildAdminItem(
            icon: Icons.sports_hockey,
            title: 'Schiedsrichter Verwaltung',
            key: 'referee_management',
            isSelected: selectedSection == 'referee_management',
          ),
        ],
      ),
    );
  }

  Widget _buildAdminItem({
    required IconData icon,
    required String title,
    required String key,
    required bool isSelected,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF2D3748) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.white70,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        onTap: () => onSectionChanged(key),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildNavigationItem({
    required IconData icon,
    required String title,
    required String key,
    required bool isSelected,
    bool hasExpansion = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          color: isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.blue.shade700 : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        trailing: hasExpansion
            ? Icon(
                Icons.chevron_right,
                color: Colors.grey.shade600,
                size: 18,
              )
            : null,
        onTap: () => onSectionChanged(key),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
} 