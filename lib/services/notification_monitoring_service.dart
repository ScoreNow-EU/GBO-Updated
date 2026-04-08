import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import '../screens/roster_confirmation_screen.dart';
import '../screens/game_sign_off_screen.dart';

class NotificationMonitoringService {
  static const String _prefKeyLastCheck = 'lastNotificationCheck';
  static const String _prefKeyCurrentUserEmail = 'currentUserEmail';
  static const String _channelId = 'rhbl_notifications';
  
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  static Timer? _periodicTimer;
  static String? _currentUserEmail;
  static bool _isInitialized = false;
  
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Method channel for communicating with native iOS code
  static const MethodChannel _methodChannel = MethodChannel('notification_monitoring');
  
  /// Initialize the monitoring service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Set up method channel for iOS communication
      _methodChannel.setMethodCallHandler(_handleMethodCall);
      
      // Handle notification that launched the app (cold start)
      await _handleAppLaunchNotification();
      
      _isInitialized = true;
      print('✅ Notification monitoring service initialized');
    } catch (e) {
      print('❌ Error initializing notification monitoring service: $e');
    }
  }
  
  /// Check if the app was launched by tapping a notification and handle it
  static Future<void> _handleAppLaunchNotification() async {
    try {
      final details = await _localNotifications.getNotificationAppLaunchDetails();
      if (details != null && details.didNotificationLaunchApp && details.notificationResponse != null) {
        print('🚀 App launched from notification tap — handling...');
        await _onNotificationResponse(details.notificationResponse!);
      }
    } catch (e) {
      print('❌ Error handling app launch notification: $e');
    }
  }
  
  /// Handle method calls from native iOS code
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'checkForNotifications':
        final userEmail = call.arguments as String?;
        if (userEmail != null) {
          return await _checkForNotifications(userEmail);
        }
        break;
      case 'handleNotificationResponse':
        // iOS sends this when user taps a notification
        final args = call.arguments as Map<dynamic, dynamic>?;
        if (args != null) {
          final data = Map<String, dynamic>.from(args);
          final actionId = data['actionId'] as String? ?? 'view';
          await _handleNotificationAction(actionId, data);
        }
        break;
      default:
        throw PlatformException(
          code: 'UNIMPLEMENTED',
          message: 'Method ${call.method} not implemented',
        );
    }
  }
  
  /// Start monitoring for a specific user
  static Future<void> startMonitoring(String userEmail) async {
    try {
      _currentUserEmail = userEmail;
      
      // Save user email to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyCurrentUserEmail, userEmail);
      
      // Notify native iOS code that monitoring started
      await _methodChannel.invokeMethod('startBackgroundMonitoring', userEmail);
      
      // Start foreground periodic check
      _startPeriodicCheck();
      
      print('🔔 Started notification monitoring for user: $userEmail');
    } catch (e) {
      print('❌ Error starting notification monitoring: $e');
    }
  }
  
  /// Stop monitoring
  static Future<void> stopMonitoring() async {
    try {
      _currentUserEmail = null;
      _periodicTimer?.cancel();
      _periodicTimer = null;
      
      // Clear preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyCurrentUserEmail);
      
      // Notify native iOS code to stop monitoring
      await _methodChannel.invokeMethod('stopBackgroundMonitoring');
      
      print('🛑 Stopped notification monitoring');
    } catch (e) {
      print('❌ Error stopping notification monitoring: $e');
    }
  }
  
  /// Start periodic check (foreground only)
  static void _startPeriodicCheck() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(
      const Duration(seconds: 30), // Check every 30 seconds when app is active
      (timer) async {
        if (_currentUserEmail != null) {
          await _checkForNotifications(_currentUserEmail!);
        }
      },
    );
  }
  
  /// Check for notifications (main logic)
  static Future<Map<String, dynamic>> _checkForNotifications(String userEmail) async {
    try {
      print('🔍 Checking notifications for user: $userEmail');
      
      final prefs = await SharedPreferences.getInstance();
      final lastCheckStr = prefs.getString(_prefKeyLastCheck);
      final lastCheck = lastCheckStr != null ? DateTime.parse(lastCheckStr) : null;
      
      // Query for new notifications without compound index
      var query = _firestore.collection('custom_notifications');
      
      // Get all notifications from the last 24 hours
      final snapshot = await query.get();
      final allNotifications = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .where((notification) {
            // Filter by time in memory
            DateTime? sentAt;
            if (notification['sentAt'] is Timestamp) {
              sentAt = (notification['sentAt'] as Timestamp).toDate();
            } else if (notification['sentAt'] is String) {
              try {
                sentAt = DateTime.parse(notification['sentAt']);
              } catch (e) {
                print('❌ Error parsing notification date: ${notification['sentAt']}');
                return false;
              }
            }
            
            if (sentAt == null) return false;
            
            final cutoffTime = lastCheck ?? DateTime.now().subtract(const Duration(days: 1));
            
            // Filter by user email in memory
            final notificationUserEmail = notification['userEmail'] as String;
            return sentAt.isAfter(cutoffTime) && 
                   (notificationUserEmail == 'all' || notificationUserEmail == userEmail);
          })
          .toList();
      
      print('📊 Found ${allNotifications.length} new notifications');
      
      // Update last check time
      await prefs.setString(_prefKeyLastCheck, DateTime.now().toIso8601String());
      
      // Send push notifications for new notifications
      if (allNotifications.isNotEmpty) {
        print('🔔 Sending push notifications for ${allNotifications.length} notifications');
        await _sendPushNotifications(allNotifications);
        
        // Auto-navigate for game-related notifications (sign_off_request, roster_confirmation)
        await _autoNavigateForGameNotifications(allNotifications);
      }
      
      return {
        'newNotifications': allNotifications,
      };
    } catch (e) {
      print('❌ Error checking for notifications: $e');
      return {
        'newNotifications': [],
        'error': e.toString(),
      };
    }
  }
  
  /// Auto-navigate to the appropriate screen for game-related notifications
  static Future<void> _autoNavigateForGameNotifications(List<Map<String, dynamic>> notifications) async {
    try {
      // Find the most recent game notification that needs action
      for (final notification in notifications) {
        final type = notification['type'] as String? ?? '';
        final gameId = notification['gameId'] as String?;
        final teamId = notification['teamId'] as String?;
        final teamName = notification['teamName'] as String? ?? '';

        if (gameId == null || teamId == null) continue;

        final navigator = RHBLApp.navigatorKey.currentState;
        if (navigator == null) {
          print('⚠️ Navigator not available for auto-navigation');
          return;
        }

        if (type == 'sign_off_request') {
          print('🖊️ Auto-navigating to sign-off screen for game $gameId');
          navigator.push(MaterialPageRoute(
            builder: (_) => GameSignOffScreen(
              gameId: gameId,
              teamId: teamId,
              teamName: teamName,
            ),
          ));
          return; // Only navigate to one screen at a time
        } else if (type == 'roster_confirmation') {
          print('📋 Auto-navigating to roster confirmation for game $gameId');
          navigator.push(MaterialPageRoute(
            builder: (_) => RosterConfirmationScreen(
              gameId: gameId,
              teamId: teamId,
              teamName: teamName,
            ),
          ));
          return; // Only navigate to one screen at a time
        }
      }
    } catch (e) {
      print('❌ Error auto-navigating for game notifications: $e');
    }
  }

  /// Send push notifications through iOS native code
  static Future<void> _sendPushNotifications(List<Map<String, dynamic>> notifications) async {
    try {
      // Call iOS native code to send push notifications
      await _methodChannel.invokeMethod('sendPushNotifications', {
        'notifications': notifications,
      });
      
      print('📱 Push notifications sent');
    } catch (e) {
      print('❌ Error sending push notifications: $e');
      print('🔄 Falling back to local notifications');
      
      // Fall back to local notifications
      for (final notification in notifications) {
        await _showLocalNotification(
          notification['title'] as String,
          notification['message'] as String,
          isTimeSensitive: notification['isTimeSensitive'] as bool? ?? false,
          type: notification['type'] as String? ?? 'custom_notification',
          gameId: notification['gameId'] as String?,
          teamId: notification['teamId'] as String?,
          teamName: notification['teamName'] as String?,
        );
      }
    }
  }
  
  /// Show local notification
  static Future<void> _showLocalNotification(String title, String message, {
    bool isTimeSensitive = false,
    String type = 'custom_notification',
    String? gameId,
    String? teamId,
    String? teamName,
  }) async {
    try {
      final notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'RHBL Benachrichtigungen',
          channelDescription: 'Benachrichtigungen von der RHBL App',
          importance: isTimeSensitive ? Importance.max : Importance.high,
          priority: isTimeSensitive ? Priority.max : Priority.high,
          showWhen: true,
          enableVibration: isTimeSensitive,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          categoryIdentifier: isTimeSensitive ? 'time_sensitive_notification' : 'custom_notification',
          sound: isTimeSensitive ? 'default' : null,
          threadIdentifier: isTimeSensitive ? 'time_sensitive' : null,
        ),
      );

      final payloadMap = <String, dynamic>{
        'type': type,
        'title': title,
        'message': message,
        'isTimeSensitive': isTimeSensitive,
      };
      if (gameId != null) payloadMap['gameId'] = gameId;
      if (teamId != null) payloadMap['teamId'] = teamId;
      if (teamName != null) payloadMap['teamName'] = teamName;
      
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        isTimeSensitive ? "⚠️ $title" : title,
        message,
        notificationDetails,
        payload: jsonEncode(payloadMap),
      );
      
      print('📱 Local notification shown');
    } catch (e) {
      print('❌ Error showing local notification: $e');
    }
  }
  
  /// Initialize local notifications
  static Future<void> _initializeLocalNotifications() async {
    try {
      const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      final initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        notificationCategories: [
          DarwinNotificationCategory(
            'custom_notification',
            actions: [
              DarwinNotificationAction.plain(
                'view',
                'Anzeigen',
                options: {DarwinNotificationActionOption.foreground},
              ),
              DarwinNotificationAction.plain(
                'dismiss',
                'Später',
                options: {},
              ),
            ],
          ),
          DarwinNotificationCategory(
            'time_sensitive_notification',
            options: {
              DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
            },
            actions: [
              DarwinNotificationAction.plain(
                'view',
                'Jetzt anzeigen',
                options: {DarwinNotificationActionOption.foreground},
              ),
            ],
          ),
        ],
      );
      
      final initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );
      
      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );
      
      print('📱 Local notifications initialized');
    } catch (e) {
      print('❌ Error initializing local notifications: $e');
    }
  }
  
  /// Handle notification response
  static Future<void> _onNotificationResponse(NotificationResponse response) async {
    try {
      final payload = response.payload;
      if (payload == null) return;
      
      Map<String, dynamic> data;
      try {
        data = jsonDecode(payload) as Map<String, dynamic>;
      } catch (_) {
        // Legacy plain-text payload
        data = {'type': payload};
      }
      
      final actionId = response.actionId ?? 'view';
      await _handleNotificationAction(actionId, data);
    } catch (e) {
      print('❌ Error handling notification response: $e');
    }
  }
  
  /// Handle notification action
  static Future<void> _handleNotificationAction(String actionId, Map<String, dynamic> data) async {
    try {
      switch (actionId) {
        case 'view':
        case '':  // Default tap (no explicit action)
        case 'com.apple.UNNotificationDefaultActionIdentifier': // iOS default tap action
          final type = data['type'] as String? ?? '';
          final gameId = data['gameId'] as String?;
          final teamId = data['teamId'] as String?;
          final teamName = data['teamName'] as String? ?? '';

          if (gameId == null || teamId == null) {
            print('⚠️ Cannot navigate: gameId=$gameId, teamId=$teamId');
            return;
          }

          // Wait for navigator to be ready (cold start may need a moment)
          NavigatorState? navigator = RHBLApp.navigatorKey.currentState;
          if (navigator == null) {
            for (int i = 0; i < 20; i++) {
              await Future.delayed(const Duration(milliseconds: 250));
              navigator = RHBLApp.navigatorKey.currentState;
              if (navigator != null) break;
            }
          }
          if (navigator == null) {
            print('⚠️ Navigator not available after waiting');
            return;
          }

          if (type == 'roster_confirmation') {
            navigator.push(MaterialPageRoute(
              builder: (_) => RosterConfirmationScreen(
                gameId: gameId,
                teamId: teamId,
                teamName: teamName,
              ),
            ));
          } else if (type == 'sign_off_request') {
            navigator.push(MaterialPageRoute(
              builder: (_) => GameSignOffScreen(
                gameId: gameId,
                teamId: teamId,
                teamName: teamName,
              ),
            ));
          } else {
            print('📋 Generic notification view: $type');
          }
          break;
        case 'dismiss':
          print('Notification dismissed');
          break;
      }
    } catch (e) {
      print('❌ Error handling notification action: $e');
    }
  }
  
  /// Get current user email
  static String? getCurrentUserEmail() => _currentUserEmail;
  
  /// Dispose resources
  static void dispose() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }
} 