import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart' as app_user;
import '../services/auth_service.dart';

class NotificationMonitoringService {
  static const String _prefKeyLastCheck = 'lastNotificationCheck';
  static const String _prefKeyCurrentUserEmail = 'currentUserEmail';
  static const String _channelId = 'gbo_notifications';
  
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  static Timer? _periodicTimer;
  static String? _currentUserEmail;
  static bool _isInitialized = false;
  
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final AuthService _authService = AuthService();
  
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
      
      _isInitialized = true;
      print('✅ Notification monitoring service initialized');
    } catch (e) {
      print('❌ Error initializing notification monitoring service: $e');
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
        );
      }
    }
  }
  
  /// Show local notification
  static Future<void> _showLocalNotification(String title, String message, {bool isTimeSensitive = false}) async {
    try {
      final notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'GBO Benachrichtigungen',
          channelDescription: 'Benachrichtigungen von der GBO App',
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
      
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        isTimeSensitive ? "⚠️ $title" : title,
        message,
        notificationDetails,
        payload: jsonEncode({
          'type': 'custom_notification',
          'title': title,
          'message': message,
          'isTimeSensitive': isTimeSensitive,
        }),
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
      
      final data = jsonDecode(payload);
      if (data['type'] == 'custom_notification') {
        final actionId = response.actionId;
        if (actionId != null) {
          await _handleNotificationAction(actionId, data);
        }
      }
    } catch (e) {
      print('❌ Error handling notification response: $e');
    }
  }
  
  /// Handle notification action
  static Future<void> _handleNotificationAction(String actionId, Map<String, dynamic> data) async {
    try {
      switch (actionId) {
        case 'view':
          // TODO: Navigate to notification details or relevant screen
          print('View notification action triggered');
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