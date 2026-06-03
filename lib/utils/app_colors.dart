import 'package:flutter/material.dart';

class AppColors {
  // === RHD Brand Colors (Branding Guide v1.1) ===
  
  /// RHD Black – Fließtext, Überschriften, Kontrasttext
  static const Color rhdBlack = Color(0xFF050505);
  
  /// RHD Red – Regelwerk, Spielordnung, Entscheidungen
  static const Color primaryColor = Color(0xFFF23329);
  
  /// RHD Gold – Eyebrow-Zeilen, Kommunikations-Dokumente
  static const Color rhdGold = Color(0xFFFFD321);
  
  /// Text Grey – Unterzeilen, Metadaten, Verwaltungsdokumente
  static const Color textGrey = Color(0xFF4D5158);
  
  /// Light Grey – Hintergrundflächen, ruhige Akzente
  static const Color lightGrey = Color(0xFFF2F4F7);

  // === Gradient ===
  
  /// Navbar/primary gradient – RHD Red → RHD Gold
  static const List<Color> gradientColors = [
    Color(0xFFF23329), // RHD Red
    Color(0xFFFFD321), // RHD Gold
  ];

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: gradientColors,
  );

  // === Semantic / Role Colors ===
  
  /// Alternative primary (= RHD Gold)
  static const Color primaryColorAlt = rhdGold;
  
  /// Light version for backgrounds
  static Color primaryColorLight = primaryColor.withOpacity(0.2);
  
  /// Gradient decoration for selected items
  static BoxDecoration selectedItemDecoration = BoxDecoration(
    gradient: primaryGradient,
    borderRadius: BorderRadius.circular(8),
  );
  
  /// Text/icons on primary (red) backgrounds
  static const Color onPrimary = Colors.white;
  
  /// Secondary color (RHD Black)
  static const Color secondary = rhdBlack;
  
  /// Text on secondary backgrounds
  static const Color onSecondary = Colors.white;

  // === Font Weights (edit here to adjust globally) ===
  static const FontWeight headlineWeight = FontWeight.w100;
  static const FontWeight titleWeight = FontWeight.w100;
  static const FontWeight bodyWeight = FontWeight.w100;
  static const FontWeight labelWeight = FontWeight.w100;
} 