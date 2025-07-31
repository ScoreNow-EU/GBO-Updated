import 'package:flutter/material.dart';

class AppColors {
  // Navbar gradient colors
  static const List<Color> gradientColors = [
    Color(0xFFffb3c8),
    Color(0xFFffafb4),
    Color(0xFFfed1ba),
    Color(0xFFffcbbd),
  ];

  // Primary gradient (same as navbar)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: gradientColors,
  );

  // For single color contexts, use the middle color of the gradient
  static const Color primaryColor = Color(0xFFfed1ba);
  
  // Alternative primary color for variety
  static const Color primaryColorAlt = Color(0xFFffafb4);
  
  // Light version for backgrounds
  static Color primaryColorLight = const Color(0xFFfed1ba).withOpacity(0.2);
  
  // Gradient decoration for selected items
  static BoxDecoration selectedItemDecoration = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        gradientColors[0].withOpacity(0.3),
        gradientColors[1].withOpacity(0.3),
        gradientColors[2].withOpacity(0.3),
        gradientColors[3].withOpacity(0.3),
      ],
    ),
    borderRadius: BorderRadius.circular(8),
  );
  
  // Dark version for text/icons on light backgrounds
  static const Color onPrimary = Colors.black87;
  
  // Secondary colors
  static const Color secondary = Colors.black87;
  static const Color onSecondary = Colors.white;
} 