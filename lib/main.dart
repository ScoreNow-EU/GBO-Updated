import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:toastification/toastification.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart';

import 'firebase_config.dart';
import 'screens/home_screen.dart';
import 'screens/obs_graphics_screen.dart';
import 'services/preloader_service.dart';
import 'utils/app_colors.dart';
import 'utils/version_helper.dart';
import 'utils/web_helper.dart';
import 'utils/debug_filter.dart';
import 'utils/route_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize debug filter to silence unwanted messages
  DebugFilter.initialize();
  
  // Note: Can't override print directly in Dart, relying on DebugFilter and JavaScript filter instead
  
  // Initialize Firebase with platform check
  if (FirebaseConfig.shouldInitializeFirebase) {
    try {
      await Firebase.initializeApp(
        options: FirebaseConfig.currentPlatform,
      );
      debugPrint('Firebase initialized successfully');
    } catch (e) {
      debugPrint('Firebase initialization error: $e');
      // For now, continue without Firebase but show error
      debugPrint('App will continue but Firebase features may not work');
    }
  } else {
    debugPrint('Firebase initialization skipped for this platform');
  }
  
  // Preload essential data for faster loading (only if Firebase is working)
  try {
    final preloader = PreloaderService();
    preloader.preloadEssentialData(); // Don't await - let it load in background
  } catch (e) {
    debugPrint('Preloader error: $e - continuing without preloading');
  }
  
  // Update web version display (only on web platform)
  if (kIsWeb) {
    try {
      final version = await VersionHelper.getAppVersion();
      WebHelper.updateVersionDisplay(version);
    } catch (e) {
      debugPrint('Error updating web version display: $e');
    }
  }
  
  runApp(const RHBLApp());
}

class RHBLApp extends StatelessWidget {
  const RHBLApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static FirebaseAnalytics? analytics;
  static FirebaseAnalyticsObserver? observer;

  static void initializeAnalytics() {
    try {
      analytics = FirebaseAnalytics.instance;
      observer = FirebaseAnalyticsObserver(analytics: analytics!);
      debugPrint('Analytics initialized successfully');
    } catch (e) {
      debugPrint('Analytics initialization error: $e');
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
        navigatorKey: navigatorKey,
        title: 'Rollstuhlhandball Bundesliga',
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
        initialRoute: '/',
        routes: {
          '/': (context) => const HomeScreen(),
          '/obs-graphics': (context) => _buildOBSGraphicsScreen(context),
        },
        navigatorObservers: [
          RouteLogger(), // Debug: Zeigt aktuelle Route in Konsole
          if (observer != null) observer!,
        ],
      ),
    );
  }

  static Widget _buildOBSGraphicsScreen(BuildContext context) {
    // Parse URL parameters for OBS graphics configuration
    final uri = Uri.base;
    final tournamentId = uri.queryParameters['tournamentId'];
    final gameId = uri.queryParameters['gameId'];
    final overlayType = uri.queryParameters['overlayType'];

    return OBSGraphicsScreen(
      tournamentId: tournamentId,
      gameId: gameId,
      overlayType: overlayType,
    );
  }
}
