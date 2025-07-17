import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart' as app_user;
import '../services/auth_service.dart';

class CustomNotificationService {
  static const MethodChannel _methodChannel = MethodChannel('referee_invitation_monitoring');
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  
  /// Send a custom notification to a user
  Future<bool> sendCustomNotification({
    required String title,
    required String message,
    required String userEmail,
  }) async {
    try {
      // Get the user by email
      final user = await _authService.getUserByEmail(userEmail);
      if (user == null) {
        print('❌ User not found for email: $userEmail');
        return false;
      }
      
      // Save notification to Firestore for tracking
      await _saveNotificationToFirestore(
        title: title,
        message: message,
        userEmail: userEmail,
        userId: user.id,
      );
      
      // Send push notification via iOS
      await _sendPushNotification(
        title: title,
        message: message,
        userEmail: userEmail,
      );
      
      print('✅ Custom notification sent successfully to: $userEmail');
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
    required String userId,
  }) async {
    try {
      await _firestore.collection('custom_notifications').add({
        'title': title,
        'message': message,
        'userEmail': userEmail,
        'userId': userId,
        'sentAt': Timestamp.now(),
        'type': 'custom_notification',
        'status': 'sent',
      });
      
      print('📝 Notification saved to Firestore');
    } catch (e) {
      print('❌ Error saving notification to Firestore: $e');
    }
  }
  
  /// Send push notification through iOS native code
  Future<void> _sendPushNotification({
    required String title,
    required String message,
    required String userEmail,
  }) async {
    try {
      // Call iOS native code to send push notification
      await _methodChannel.invokeMethod('sendCustomNotification', {
        'title': title,
        'message': message,
        'userEmail': userEmail,
      });
      
      print('📱 Custom push notification sent via iOS');
    } catch (e) {
      print('❌ Error sending push notification: $e');
      // Fall back to local notification
      await _showLocalNotification(title, message);
    }
  }
  
  /// Show local notification as fallback
  Future<void> _showLocalNotification(String title, String message) async {
    try {
      const notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'custom_notifications',
          'Benutzerdefinierte Benachrichtigungen',
          channelDescription: 'Benutzerdefinierte Benachrichtigungen vom Admin',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          categoryIdentifier: 'custom_notification',
        ),
      );
      
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        message,
        notificationDetails,
        payload: 'custom_notification',
      );
      
      print('📱 Local notification shown as fallback');
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
    return _firestore
        .collection('custom_notifications')
        .where('userEmail', isEqualTo: userEmail)
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }
} 