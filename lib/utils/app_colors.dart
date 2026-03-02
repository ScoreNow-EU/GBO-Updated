import 'package:flutter/material.dart';

class AppColors {
  // Navbar gradient colors - Red to Yellow (German flag inspired)
  static const List<Color> gradientColors = [
    Color(0xFFc10003), // German flag red
    Color(0xFFe63946), // Brighter red
    Color(0xFFfaa307), // Orange-yellow transition
    Color(0xFFffd765), // German flag yellow
  ];

  // Primary gradient (same as navbar)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: gradientColors,
  );

  // For single color contexts, use the middle color of the gradient
  static const Color primaryColor = Color(0xFFe63946);
  
  // Alternative primary color for variety
  static const Color primaryColorAlt = Color(0xFFfaa307);
  
  // Light version for backgrounds
  static Color primaryColorLight = const Color(0xFFe63946).withOpacity(0.2);
  
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