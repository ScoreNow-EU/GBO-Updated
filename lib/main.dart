import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:toastification/toastification.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_config.dart';
import 'screens/home_screen.dart';
import 'services/preloader_service.dart';
import 'services/referee_invitation_monitoring_service.dart';
import 'utils/app_colors.dart';

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

    return ToastificationWrapper(
      child: MaterialApp(
        title: 'German Beach Open',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('de'),
          Locale('en'),
        ],
        locale: const Locale('de'),
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primaryColor, // Using gradient colors
            brightness: Brightness.light,
            primary: AppColors.primaryColor,
            secondary: AppColors.secondary,
            surface: Colors.white,
            onPrimary: AppColors.onPrimary,
            onSecondary: AppColors.onSecondary,
            onSurface: Colors.black87,
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
          appBarTheme: AppBarTheme(
            backgroundColor: AppColors.primaryColor,
            foregroundColor: AppColors.onPrimary,
            elevation: 2,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: AppColors.onSecondary,
              elevation: 4,
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryColor,
            ),
          ),
          iconTheme: IconThemeData(
            color: AppColors.onPrimary,
          ),
          checkboxTheme: CheckboxThemeData(
            fillColor: WidgetStateProperty.all(AppColors.primaryColor),
            checkColor: WidgetStateProperty.all(AppColors.onPrimary),
          ),
        ),
        home: const HomeScreen(),
        navigatorObservers: observer != null ? <NavigatorObserver>[observer!] : <NavigatorObserver>[],
      ),
    );
  }
}
