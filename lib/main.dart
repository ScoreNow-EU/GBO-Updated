import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'firebase_config.dart';
import 'screens/home_screen.dart';
import 'services/preloader_service.dart';

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
          seedColor: const Color(0xFF1976D2), // Blue theme matching the logo
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
      navigatorObservers: observer != null ? <NavigatorObserver>[observer!] : <NavigatorObserver>[],
    );
  }
}
