import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/coach_auth_request.dart';

class CoachAuthMonitoringService {
  static const String _prefKeyLastCheck = 'lastCoachAuthCheck';
  static const String _prefKeyPendingRequests = 'pendingCoachAuthRequests';
  static const String _prefKeyCurrentCoachEmail = 'currentCoachEmail';
  static const String _channelId = 'coach_auth_requests';
  
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  static Timer? _periodicTimer;
  static String? _currentCoachEmail;
  static bool _isInitialized = false;
  
  /// Initialize the monitoring service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      _isInitialized = true;
      print('✅ Coach auth monitoring service initialized');
    } catch (e) {
      print('❌ Error initializing coach auth monitoring service: $e');
    }
  }
  
  /// Start monitoring for a specific coach email
  static Future<void> startMonitoring(String coachEmail) async {
    try {
      _currentCoachEmail = coachEmail;
      
      // Save coach email to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyCurrentCoachEmail, coachEmail);
      
      // Start foreground periodic check (no native background needed)
      _startPeriodicCheck();
      
      print('🔔 Started coach auth monitoring for: $coachEmail');
    } catch (e) {
      print('❌ Error starting coach auth monitoring: $e');
    }
  }
  
  /// Stop monitoring
  static Future<void> stopMonitoring() async {
    try {
      _currentCoachEmail = null;
      _periodicTimer?.cancel();
      _periodicTimer = null;
      
      // Clear preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyCurrentCoachEmail);
      await prefs.remove(_prefKeyPendingRequests);
      await prefs.remove(_prefKeyLastCheck);
      
      print('🔴 Stopped coach auth monitoring');
    } catch (e) {
      print('❌ Error stopping coach auth monitoring: $e');
    }
  }
  
  /// Initialize local notifications
  static Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      'Trainer Freigabe Anfragen',
      description: 'Benachrichtigungen für Trainer Kader-Freigabe Anfragen',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }
  
  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    print('🔔 Coach auth notification tapped: ${response.payload}');
    // TODO: Navigate to appropriate screen or show overlay
  }
  
  /// Start periodic check for pending requests
  static void _startPeriodicCheck() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (_currentCoachEmail != null) {
        await checkForPendingRequests(_currentCoachEmail!);
      }
    });
  }
  
  /// Check for pending requests for a coach
  static Future<List<CoachAuthRequest>> checkForPendingRequests(String coachEmail) async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Simple query by coachEmail only to avoid index requirements
      final querySnapshot = await firestore
          .collection('coach_auth_requests')
          .where('coachEmail', isEqualTo: coachEmail)
          .get();
      
      // Filter and sort in memory
      final allRequests = querySnapshot.docs
          .map((doc) => CoachAuthRequest.fromFirestore(doc))
          .toList();
      
      // Filter for pending requests that haven't expired
      final requests = allRequests
          .where((request) => 
              request.status == CoachAuthStatus.pending && 
              !request.isExpired)
          .toList();
      
      // Sort by urgency (expiration time) then by request time
      requests.sort((a, b) {
        // First sort by expiration time (most urgent first)
        final expireCompare = a.expiresAt.compareTo(b.expiresAt);
        if (expireCompare != 0) return expireCompare;
        
        // Then by request time (newest first)
        return b.requestTime.compareTo(a.requestTime);
      });
      
      print('🔍 Found ${requests.length} pending coach auth requests for $coachEmail');
      
      // Check for new requests
      await _checkForNewRequests(requests);
      
      return requests;
    } catch (e) {
      print('❌ Error checking for pending coach auth requests: $e');
      return [];
    }
  }
  
  /// Check for new requests and send notifications
  static Future<void> _checkForNewRequests(List<CoachAuthRequest> currentRequests) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckTime = prefs.getInt(_prefKeyLastCheck) ?? 0;
      final lastCheck = DateTime.fromMillisecondsSinceEpoch(lastCheckTime);
      
      // Find new requests since last check
      final newRequests = currentRequests.where((request) =>
          request.requestTime.isAfter(lastCheck)
      ).toList();
      
      if (newRequests.isNotEmpty) {
        print('🆕 Found ${newRequests.length} new coach auth requests');
        
        // Send notifications for new requests
        for (final request in newRequests) {
          await _sendNotification(request);
        }
      }
      
      // Update last check time
      await prefs.setInt(_prefKeyLastCheck, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('❌ Error checking for new coach auth requests: $e');
    }
  }
  
  /// Send notification for a coach auth request
  static Future<void> _sendNotification(CoachAuthRequest request) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        'Trainer Freigabe Anfragen',
        channelDescription: 'Benachrichtigungen für Trainer Kader-Freigabe Anfragen',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'Trainer Freigabe erforderlich',
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        autoCancel: false,
        ongoing: false,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
      );
      
      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        interruptionLevel: InterruptionLevel.critical,
      );
      
      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      final timeRemaining = request.expiresAt.difference(DateTime.now());
      final minutesRemaining = timeRemaining.inMinutes;
      
      await _localNotifications.show(
        request.hashCode,
        '⚠️ Kader-Freigabe erforderlich',
        '${request.teamName} - ${request.gameTitle}\nVerbleibt: ${minutesRemaining}min',
        details,
        payload: jsonEncode({
          'requestId': request.id,
          'type': 'coach_auth_request',
        }),
      );
      
      print('📱 Sent coach auth notification: ${request.teamName}');
    } catch (e) {
      print('❌ Error sending coach auth notification: $e');
    }
  }
  

  
  /// Respond to a coach auth request
  static Future<bool> respondToRequest(String requestId, String coachEmail, String response) async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Map response strings to enum values
      CoachAuthStatus status;
      switch (response.toLowerCase()) {
        case 'approved':
        case 'accept':
        case 'genehmigt':
          status = CoachAuthStatus.approved;
          break;
        case 'declined':
        case 'reject':
        case 'abgelehnt':
          status = CoachAuthStatus.declined;
          break;
        default:
          throw Exception('Invalid response: $response');
      }
      
      // Update the request
      await firestore.collection('coach_auth_requests').doc(requestId).update({
        'status': status.toString().split('.').last,
        'responseTime': Timestamp.fromDate(DateTime.now()),
        'responseByUserId': 'system', // TODO: Get actual coach user ID
        'responseByName': coachEmail.split('@').first,
        'responseMethod': 'biometric',
      });
      
      print('✅ Updated coach auth request $requestId with response: $response');
      return true;
    } catch (e) {
      print('❌ Error responding to coach auth request: $e');
      return false;
    }
  }
  
  /// Get pending coach auth requests for a coach
  static Future<List<CoachAuthRequest>> getPendingRequests(String coachEmail) async {
    return await checkForPendingRequests(coachEmail);
  }
  
  /// Create a new coach authentication request
  static Future<bool> createAuthRequest({
    required String gameId,
    required String teamId,
    required String squadId,
    required String teamName,
    required String gameTitle,
    required DateTime gameDate,
    required String requestedByUserId,
    required String requestedByName,
    required String coachEmail,
    required String coachName,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Check if there's already a pending request for this squad
      final existingQuery = await firestore
          .collection('coach_auth_requests')
          .where('squadId', isEqualTo: squadId)
          .where('status', isEqualTo: 'pending')
          .get();
      
      // Cancel existing pending requests for this squad
      for (final doc in existingQuery.docs) {
        await doc.reference.update({
          'status': 'expired',
        });
      }
      
      // Create new request
      final request = CoachAuthRequest(
        id: '',
        gameId: gameId,
        teamId: teamId,
        squadId: squadId,
        teamName: teamName,
        gameTitle: gameTitle,
        gameDate: gameDate,
        requestedByUserId: requestedByUserId,
        requestedByName: requestedByName,
        requestTime: DateTime.now(),
        coachEmail: coachEmail,
        coachName: coachName,
        expiresAt: DateTime.now().add(const Duration(hours: 2)), // Expires in 2 hours
      );
      
      await firestore.collection('coach_auth_requests').add(request.toFirestore());
      
      print('✅ Created coach auth request for $teamName');
      return true;
    } catch (e) {
      print('❌ Error creating coach auth request: $e');
      return false;
    }
  }
} 