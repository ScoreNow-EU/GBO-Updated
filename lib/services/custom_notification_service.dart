import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart' as app_user;
import '../services/auth_service.dart';
import '../services/notification_monitoring_service.dart';

class CustomNotificationService {
  static const MethodChannel _methodChannel = MethodChannel('referee_invitation_monitoring');
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  
  /// Check if time-sensitive notifications are available and request permission if needed
  Future<bool> checkTimeSensitivePermissions() async {
    try {
      print('📱 Calling native iOS method to check time-sensitive permissions...');
      // Call iOS native code to check and request time-sensitive permissions
      final bool hasPermission = await _methodChannel.invokeMethod('checkTimeSensitivePermissions');
      print('📱 Time-sensitive notification permission result: $hasPermission');
      return hasPermission;
    } catch (e) {
      print('❌ Error checking time-sensitive permissions: $e');
      // If the native method fails, fall back to regular notifications
      return false;
    }
  }

  /// Request time-sensitive notification permission explicitly
  Future<bool> requestTimeSensitivePermission() async {
    try {
      print('📱 Requesting time-sensitive notification permission...');
      final bool hasPermission = await _methodChannel.invokeMethod('requestTimeSensitivePermission');
      print('📱 Time-sensitive permission request result: $hasPermission');
      return hasPermission;
    } catch (e) {
      print('❌ Error requesting time-sensitive permission: $e');
      return false;
    }
  }
  
  /// Send a custom notification to a user or all users
  Future<bool> sendCustomNotification({
    required String title,
    required String message,
    String? userEmail, // Optional - if not provided, sends to all users
    bool isTimeSensitive = false,
  }) async {
    try {
      print('📬 Sending notification: "$title" to ${userEmail ?? "all users"}');
      
      // Check time-sensitive permissions if needed
      if (isTimeSensitive) {
        print('📱 Checking time-sensitive notification permissions...');
        final hasPermission = await checkTimeSensitivePermissions();
        if (!hasPermission) {
          print('❌ Time-sensitive notification permission denied');
          return false;
        }
      }
      
      String targetEmail = userEmail ?? 'all';
      String? userId;
      
      // Get the user by email if targeting specific user
      if (userEmail != null) {
        print('🔍 Looking up user by email: $userEmail');
        final user = await _authService.getUserByEmail(userEmail);
        if (user == null) {
          print('❌ User not found for email: $userEmail');
          return false;
        }
        userId = user.id;
        print('✅ Found user: ${user.fullName} (ID: ${user.id})');
      }
      
      // Save notification to Firestore for tracking
      print('💾 Saving notification to Firestore...');
      await _saveNotificationToFirestore(
        title: title,
        message: message,
        userEmail: targetEmail,
        userId: userId,
        isTimeSensitive: isTimeSensitive,
      );
      
      // Send push notification via iOS
      print('📱 Sending push notification...');
      await _sendPushNotification(
        title: title,
        message: message,
        userEmail: targetEmail,
        isTimeSensitive: isTimeSensitive,
      );
      
      print('✅ Custom notification sent successfully to: $targetEmail');
      return true;
    } catch (e) {
      print('❌ Error sending custom notification: $e');
      return false;
    }
  }
  
  /// Save notification to Firestore for tracking
  Future<void> _saveNotificationToFirestore({
    required String title,
    required String message,
    required String userEmail,
    String? userId,
    required bool isTimeSensitive,
  }) async {
    try {
      await _firestore.collection('custom_notifications').add({
        'title': title,
        'message': message,
        'userEmail': userEmail,
        'userId': userId,
        'sentAt': FieldValue.serverTimestamp(), // Use server timestamp for consistency
        'type': 'custom_notification',
        'status': 'sent',
        'isTimeSensitive': isTimeSensitive,
      });
      
      print('📝 Notification saved to Firestore');
    } catch (e) {
      print('❌ Error saving notification to Firestore: $e');
      rethrow;
    }
  }
  
  /// Send push notification through iOS native code
  Future<void> _sendPushNotification({
    required String title,
    required String message,
    required String userEmail,
    required bool isTimeSensitive,
  }) async {
    try {
      print('📱 Attempting to send push notification - Time Sensitive: $isTimeSensitive');
      
      // Call iOS native code to send push notification
      await _methodChannel.invokeMethod('sendCustomNotification', {
        'title': title,
        'message': message,
        'userEmail': userEmail,
        'isTimeSensitive': isTimeSensitive,
        'timestamp': DateTime.now().millisecondsSinceEpoch, // Add timestamp in milliseconds for iOS
      });
      
      print('📱 Custom push notification sent via iOS (Time Sensitive: $isTimeSensitive)');
    } catch (e) {
      print('❌ Error sending push notification: $e');
      print('🔄 Falling back to local notification (Time Sensitive: $isTimeSensitive)');
      // Fall back to local notification
      await _showLocalNotification(title, message, isTimeSensitive: isTimeSensitive);
    }
  }
  
  /// Show local notification as fallback
  Future<void> _showLocalNotification(String title, String message, {bool isTimeSensitive = false}) async {
    try {
      print('📱 Creating local notification - Time Sensitive: $isTimeSensitive');
      
      final notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'custom_notifications',
          'Benutzerdefinierte Benachrichtigungen',
          channelDescription: 'Benutzerdefinierte Benachrichtigungen vom Admin',
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
          // Using threadIdentifier for time-sensitive grouping
          threadIdentifier: isTimeSensitive ? 'time_sensitive' : null,
        ),
      );
      
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        isTimeSensitive ? "⚠️ $title" : title,
        message,
        notificationDetails,
        payload: 'custom_notification',
      );
      
      print('📱 Local notification shown as fallback (Time Sensitive: $isTimeSensitive)');
    } catch (e) {
      print('❌ Error showing local notification: $e');
    }
  }
  
  /// Get all custom notifications sent (for admin dashboard)
  Stream<List<Map<String, dynamic>>> getCustomNotifications() {
    return _firestore
        .collection('custom_notifications')
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }
  
  /// Get notifications for a specific user
  Stream<List<Map<String, dynamic>>> getNotificationsForUser(String userEmail) {
    final DateTime cutoff = DateTime.now().subtract(const Duration(hours: 24));
    
    return _firestore
        .collection('custom_notifications')
        .where('userEmail', whereIn: [userEmail, 'all'])
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              final data = doc.data();
              
              // Convert sentAt to DateTime for comparison
              DateTime? sentAt;
              if (data['sentAt'] is String) {
                try {
                  sentAt = DateTime.parse(data['sentAt']);
                } catch (e) {
                  print('❌ Error parsing date string: ${data['sentAt']}');
                }
              } else if (data['sentAt'] is Timestamp) {
                sentAt = (data['sentAt'] as Timestamp).toDate();
              }
              
              // Only include notifications from the last 24 hours
              if (sentAt != null && sentAt.isAfter(cutoff)) {
                return data;
              }
              return null;
            })
            .where((data) => data != null)
            .cast<Map<String, dynamic>>()
            .toList());
  }
} 