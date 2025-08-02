import 'package:flutter/material.dart';

import '../models/user.dart' as app_user;
import 'side_navigation.dart';

class ResponsiveLayout extends StatelessWidget {
  final String selectedSection;
  final Function(String) onSectionChanged;
  final dynamic title;  // Can be String or Widget
  final Widget body;
  final app_user.User? currentUser;
  final VoidCallback? onUserUpdated;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const ResponsiveLayout({
    super.key,
    required this.selectedSection,
    required this.onSectionChanged,
    required this.title,
    required this.body,
    this.currentUser,
    this.onUserUpdated,
    this.showBackButton = false,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    Widget titleWidget;
    if (title is String) {
      titleWidget = Text(
        title as String,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      );
    } else {
      titleWidget = title as Widget;
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: isMobile ? AppBar(
        title: titleWidget,
        backgroundColor: Colors.white,
        elevation: 1,
        leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
            )
          : IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
        actions: showBackButton
          ? [
              IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              ),
            ]
          : null,
      ) : null,
      drawer: isMobile ? SideNavigation(
        selectedSection: selectedSection,
        onSectionChanged: (section) {
          Navigator.pop(context); // Close drawer
          onSectionChanged(section);
        },
        onUserUpdated: onUserUpdated,
      ) : null,
      body: Row(
        children: [
          if (!isMobile)
            SideNavigation(
              selectedSection: selectedSection,
              onSectionChanged: onSectionChanged,
              onUserUpdated: onUserUpdated,
            ),
          Expanded(
            child: Column(
              children: [
                if (!isMobile && showBackButton)
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
                          onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: titleWidget,
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: body,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 