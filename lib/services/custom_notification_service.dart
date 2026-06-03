import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart' as app_user;
import '../services/auth_service.dart';
import '../main.dart';
import 'package:toastification/toastification.dart';

class CustomNotificationService {
  static const MethodChannel _methodChannel = MethodChannel('referee_invitation_monitoring');
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  
  /// Check if time-sensitive notifications are available and request permission if needed
  Future<bool> checkTimeSensitivePermissions() async {
    try {
      debugPrint('ðŸ“± Calling native iOS method to check time-sensitive permissions...');
      // Call iOS native code to check and request time-sensitive permissions
      final bool hasPermission = await _methodChannel.invokeMethod('checkTimeSensitivePermissions');
      debugPrint('ðŸ“± Time-sensitive notification permission result: $hasPermission');
      return hasPermission;
    } catch (e) {
      debugPrint('âŒ Error checking time-sensitive permissions: $e');
      // If the native method fails, fall back to regular notifications
      return false;
    }
  }

  /// Request time-sensitive notification permission explicitly
  Future<bool> requestTimeSensitivePermission() async {
    try {
      debugPrint('ðŸ“± Requesting time-sensitive notification permission...');
      final bool hasPermission = await _methodChannel.invokeMethod('requestTimeSensitivePermission');
      debugPrint('ðŸ“± Time-sensitive permission request result: $hasPermission');
      return hasPermission;
    } catch (e) {
      debugPrint('âŒ Error requesting time-sensitive permission: $e');
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
      debugPrint('ðŸ“¬ Sending notification: "$title" to ${userEmail ?? "all users"}');
      
      // Check time-sensitive permissions if needed
      if (isTimeSensitive) {
        debugPrint('ðŸ“± Checking time-sensitive notification permissions...');
        final hasPermission = await checkTimeSensitivePermissions();
        if (!hasPermission) {
          debugPrint('âŒ Time-sensitive notification permission denied');
          return false;
        }
      }
      
      String targetEmail = userEmail ?? 'all';
      String? userId;
      
      // Get the user by email if targeting specific user
      if (userEmail != null) {
        debugPrint('ðŸ” Looking up user by email: $userEmail');
        final user = await _authService.getUserByEmail(userEmail);
        if (user == null) {
          debugPrint('âŒ User not found for email: $userEmail');
          return false;
        }
        userId = user.id;
        debugPrint('âœ… Found user: ${user.fullName} (ID: ${user.id})');
      }
      
      // Save notification to Firestore for tracking
      debugPrint('ðŸ’¾ Saving notification to Firestore...');
      await _saveNotificationToFirestore(
        title: title,
        message: message,
        userEmail: targetEmail,
        userId: userId,
        isTimeSensitive: isTimeSensitive,
      );
      
      // Send push notification via iOS
      debugPrint('ðŸ“± Sending push notification...');
      await _sendPushNotification(
        title: title,
        message: message,
        userEmail: targetEmail,
        isTimeSensitive: isTimeSensitive,
      );
      
      debugPrint('âœ… Custom notification sent successfully to: $targetEmail');
      return true;
    } catch (e) {
      debugPrint('âŒ Error sending custom notification: $e');
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
      
      debugPrint('ðŸ“ Notification saved to Firestore');
    } catch (e) {
      debugPrint('âŒ Error saving notification to Firestore: $e');
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
      debugPrint('ðŸ“± Attempting to send push notification - Time Sensitive: $isTimeSensitive');
      
      // Call iOS native code to send push notification
      await _methodChannel.invokeMethod('sendCustomNotification', {
        'title': title,
        'message': message,
        'userEmail': userEmail,
        'isTimeSensitive': isTimeSensitive,
        'timestamp': DateTime.now().millisecondsSinceEpoch, // Add timestamp in milliseconds for iOS
      });
      
      debugPrint('ðŸ“± Custom push notification sent via iOS (Time Sensitive: $isTimeSensitive)');
    } catch (e) {
      debugPrint('âŒ Error sending push notification: $e');
      debugPrint('ðŸ”„ Falling back to local notification (Time Sensitive: $isTimeSensitive)');
      // Fall back to local notification
      await _showLocalNotification(title, message, isTimeSensitive: isTimeSensitive);
    }
  }
  
  /// Show local notification as fallback
  Future<void> _showLocalNotification(String title, String message, {bool isTimeSensitive = false, String? payload}) async {
    try {
      debugPrint('ðŸ“± Creating local notification - Time Sensitive: $isTimeSensitive');

      // On web, use SnackBar since flutter_local_notifications doesn't work
      if (kIsWeb) {
        _showWebSnackBar(title, message, isTimeSensitive: isTimeSensitive);
        return;
      }

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
        isTimeSensitive ? "\u26a0\ufe0f $title" : title,
        message,
        notificationDetails,
        payload: payload ?? 'custom_notification',
      );
      
      debugPrint('ðŸ“± Local notification shown as fallback (Time Sensitive: $isTimeSensitive)');
    } catch (e) {
      debugPrint('âŒ Error showing local notification: $e');
    }
  }

  /// Show notification as toast on web platform
  void _showWebSnackBar(String title, String message, {bool isTimeSensitive = false}) {
    final context = RHBLApp.navigatorKey.currentState?.context;
    if (context == null) return;
    toastification.show(
      context: context,
      type: isTimeSensitive ? ToastificationType.warning : ToastificationType.info,
      style: ToastificationStyle.fillColored,
      title: Text(isTimeSensitive ? '⚠️ $title' : title),
      description: Text(message),
      alignment: Alignment.topRight,
      autoCloseDuration: Duration(seconds: isTimeSensitive ? 8 : 5),
      showProgressBar: true,
    );
    debugPrint('📱 Web toast notification shown: $title');
  }

  /// Send a game-related notification (roster confirmation, sign-off request)
  Future<bool> sendGameNotification({
    required String title,
    required String message,
    required String notificationType, // 'roster_confirmation' or 'sign_off_request'
    required String gameId,
    required String teamId,
    required String teamName,
    String? userId,
    String? userEmail,
  }) async {
    try {
      debugPrint('ðŸ“¬ Sending game notification ($notificationType): "$title" to ${userEmail ?? userId ?? "unknown"}');

      String targetEmail = userEmail ?? 'all';

      // If we have userId but no email, look up the user
      if (userEmail == null && userId != null) {
        final user = await _authService.getUserById(userId);
        if (user != null) {
          targetEmail = user.email;
        }
      }

      // Save to Firestore with game metadata
      await _firestore.collection('custom_notifications').add({
        'title': title,
        'message': message,
        'userEmail': targetEmail,
        'userId': userId,
        'sentAt': FieldValue.serverTimestamp(),
        'type': notificationType,
        'status': 'sent',
        'isTimeSensitive': true,
        'gameId': gameId,
        'teamId': teamId,
        'teamName': teamName,
      });

      // Build payload with metadata for navigation on tap
      final payload = jsonEncode({
        'type': notificationType,
        'gameId': gameId,
        'teamId': teamId,
        'teamName': teamName,
      });

      // Try native push, fallback to local
      try {
        await _methodChannel.invokeMethod('sendCustomNotification', {
          'title': title,
          'message': message,
          'userEmail': targetEmail,
          'isTimeSensitive': true,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'type': notificationType,
          'gameId': gameId,
          'teamId': teamId,
          'teamName': teamName,
        });
      } catch (e) {
        debugPrint('ðŸ”„ Native push failed, using local notification');
        await _showLocalNotification(title, message,
            isTimeSensitive: true, payload: payload);
      }

      debugPrint('âœ… Game notification sent: $notificationType');
      return true;
    } catch (e) {
      debugPrint('âŒ Error sending game notification: $e');
      return false;
    }
  }

  /// Send a broadcast notification to multiple users filtered by role or team
  Future<int> sendBroadcast({
    required String title,
    required String message,
    List<String>? filterRoles, // e.g. ['teamManager', 'referee']
    List<String>? filterTeamIds, // send to players/managers of these teams
    bool isTimeSensitive = false,
  }) async {
    try {
      debugPrint('📢 Sending broadcast: "$title"');
      
      // Get all users
      final allUsers = await _authService.getAllUsers();
      List<app_user.User> targetUsers = [];

      if (filterRoles != null && filterRoles.isNotEmpty) {
        // Filter users by role
        targetUsers = allUsers.where((user) {
          return user.roles.any((role) => filterRoles.contains(role.name));
        }).toList();
      } else if (filterTeamIds != null && filterTeamIds.isNotEmpty) {
        // Filter users who manage these teams
        for (final user in allUsers) {
          if (user.roles.contains(app_user.UserRole.teamManager) && user.teamManagerId != null) {
            // Check if user manages any of the target teams
            targetUsers.add(user);
          }
        }
      } else {
        // Send to all users
        targetUsers = allUsers;
      }

      int sentCount = 0;
      for (final user in targetUsers) {
        await _firestore.collection('custom_notifications').add({
          'title': title,
          'message': message,
          'userEmail': user.email,
          'userId': user.id,
          'sentAt': FieldValue.serverTimestamp(),
          'type': 'broadcast',
          'status': 'sent',
          'isTimeSensitive': isTimeSensitive,
          'filterRoles': filterRoles,
          'filterTeamIds': filterTeamIds,
        });
        sentCount++;
      }

      // Also try to send push notification
      try {
        await _sendPushNotification(
          title: title,
          message: message,
          userEmail: 'all',
          isTimeSensitive: isTimeSensitive,
        );
      } catch (e) {
        debugPrint('⚠️ Broadcast push failed, Firestore records created: $e');
      }

      debugPrint('✅ Broadcast sent to $sentCount users');
      return sentCount;
    } catch (e) {
      debugPrint('❌ Error sending broadcast: $e');
      return 0;
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
                  debugPrint('âŒ Error parsing date string: ${data['sentAt']}');
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