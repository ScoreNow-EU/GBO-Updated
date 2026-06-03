import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_colors.dart';

import '../models/user.dart' as app_user;
import 'side_navigation.dart';

class ResponsiveLayout extends StatefulWidget {
  final String selectedSection;
  final Function(String) onSectionChanged;
  final dynamic title;  // Can be String or Widget
  final Widget body;
  final app_user.User? currentUser;
  final VoidCallback? onUserUpdated;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final bool hideAppBar; // New parameter to hide AppBar when body has its own
  final Widget? ticker; // Optional ticker widget to show at top (desktop only)
  final Color? appBarBackgroundColor; // Custom AppBar background (mobile)
  final Color? appBarForegroundColor; // Custom AppBar foreground/icons (mobile)

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
    this.hideAppBar = false,
    this.ticker,
    this.appBarBackgroundColor,
    this.appBarForegroundColor,
  });

  @override
  State<ResponsiveLayout> createState() => _ResponsiveLayoutState();
}

class _ResponsiveLayoutState extends State<ResponsiveLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    Widget titleWidget;
    if (widget.title is String) {
      titleWidget = Text(
        widget.title as String,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: widget.appBarForegroundColor ?? Colors.black87,
        ),
      );
    } else {
      titleWidget = widget.title as Widget;
    }

    final appBarBg = widget.appBarBackgroundColor ?? Colors.white;
    final appBarFg = widget.appBarForegroundColor ?? Colors.black87;
    final statusBarBrightness = ThemeData.estimateBrightnessForColor(appBarBg) == Brightness.dark
        ? Brightness.light
        : Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.lightGrey,
      appBar: (isMobile && !widget.hideAppBar) ? AppBar(
        title: titleWidget,
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        elevation: 1,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarBrightness: statusBarBrightness == Brightness.light ? Brightness.dark : Brightness.light,
          statusBarIconBrightness: statusBarBrightness,
        ),
        iconTheme: IconThemeData(color: appBarFg),
        leading: widget.showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: widget.onBackPressed ?? () => Navigator.of(context).pop(),
            )
          : IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                _scaffoldKey.currentState?.openDrawer();
              },
            ),
        actions: widget.showBackButton
          ? [
              IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
            ]
          : null,
      ) : null,
      drawer: isMobile ? SideNavigation(
        selectedSection: widget.selectedSection,
        onSectionChanged: (section) {
          Navigator.pop(context); // Close drawer
          widget.onSectionChanged(section);
        },
        onUserUpdated: widget.onUserUpdated,
      ) : null,

      body: Row(
        children: [
          if (!isMobile)
            SideNavigation(
              selectedSection: widget.selectedSection,
              onSectionChanged: widget.onSectionChanged,
              onUserUpdated: widget.onUserUpdated,
            ),
          Expanded(
            child: Column(
              children: [
                if (!isMobile && widget.ticker != null)
                  widget.ticker!,
                if (!isMobile && widget.showBackButton)
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
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: titleWidget,
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: widget.body,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 