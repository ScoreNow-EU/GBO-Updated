import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'firebase_config.dart';
import 'screens/home_screen.dart';
import 'services/preloader_service.dart';
import 'services/referee_invitation_monitoring_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase on all platforms
  try {
    await Firebase.initializeApp(
      options: FirebaseConfig.currentPlatform,
    );
    print('Firebase initialized successfully');
  } catch (e) {
    print('Firebase initialization error: $e');
    // For now, continue without Firebase but show error
    print('App will continue but Firebase features may not work');
  }
  
  // Preload essential data for faster loading (only if Firebase is working)
  try {
    final preloader = PreloaderService();
    preloader.preloadEssentialData(); // Don't await - let it load in background
  } catch (e) {
    print('Preloader error: $e - continuing without preloading');
  }
  
  // Initialize internal monitoring service for referee invitations
  try {
    await RefereeInvitationMonitoringService.initialize();
  } catch (e) {
    print('Monitoring service initialization error: $e');
  }
  
  runApp(const GBOApp());
}

class GBOApp extends StatelessWidget {
  const GBOApp({super.key});

  static FirebaseAnalytics? analytics;
  static FirebaseAnalyticsObserver? observer;

  static void initializeAnalytics() {
    try {
      analytics = FirebaseAnalytics.instance;
      observer = FirebaseAnalyticsObserver(analytics: analytics!);
      print('Analytics initialized successfully');
    } catch (e) {
      print('Analytics initialization error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Initialize analytics only if Firebase is available
    if (analytics == null) {
      initializeAnalytics();
    }

    return MaterialApp(
      title: 'German Beach Open',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFffd665), // Golden theme matching the new design
          brightness: Brightness.light,
          primary: const Color(0xFFffd665),
          secondary: Colors.black87,
          surface: Colors.white,
          onPrimary: Colors.black87,
          onSecondary: Colors.white,
          onSurface: Colors.black87,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFffd665),
          foregroundColor: Colors.black87,
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black87,
            foregroundColor: Colors.white,
            elevation: 4,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.black87,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Colors.black87,
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.all(Colors.black87),
          checkColor: WidgetStateProperty.all(Colors.white),
        ),
      ),
      home: const HomeScreen(),
      navigatorObservers: observer != null ? <NavigatorObserver>[observer!] : <NavigatorObserver>[],
    );
  }
}
