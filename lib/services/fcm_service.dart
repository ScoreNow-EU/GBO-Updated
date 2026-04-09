import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for Firebase Cloud Messaging — token management & topic subscriptions
class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Request notification permission and register FCM token
  Future<bool> initialize({String? userId}) async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        final token = await _messaging.getToken(
          vapidKey: null, // Set VAPID key if needed for web push
        );
        if (token != null && userId != null) {
          await _saveToken(userId, token);
        }

        // Listen for token refresh
        _messaging.onTokenRefresh.listen((newToken) {
          if (userId != null) _saveToken(userId, newToken);
        });

        return true;
      }
      return false;
    } catch (e) {
      debugPrint('FCM initialization error: $e');
      return false;
    }
  }

  /// Save FCM token to Firestore for the user
  Future<void> _saveToken(String userId, String token) async {
    await _firestore.collection('users').doc(userId).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'lastTokenUpdate': FieldValue.serverTimestamp(),
    });
  }

  /// Subscribe to a topic (e.g., tournament_xyz, team_abc)
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to topic $topic: $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Error unsubscribing from topic $topic: $e');
    }
  }

  /// Subscribe to tournament notifications
  Future<void> subscribeToTournament(String tournamentId) async {
    await subscribeToTopic('tournament_$tournamentId');
  }

  /// Unsubscribe from tournament notifications  
  Future<void> unsubscribeFromTournament(String tournamentId) async {
    await unsubscribeFromTopic('tournament_$tournamentId');
  }

  /// Subscribe to team notifications
  Future<void> subscribeToTeam(String teamId) async {
    await subscribeToTopic('team_$teamId');
  }

  /// Listen for foreground messages
  void onForegroundMessage(void Function(RemoteMessage message) handler) {
    FirebaseMessaging.onMessage.listen(handler);
  }

  /// Handle message that opened the app
  void onMessageOpenedApp(void Function(RemoteMessage message) handler) {
    FirebaseMessaging.onMessageOpenedApp.listen(handler);
  }

  /// Get the initial message if app was opened from notification
  Future<RemoteMessage?> getInitialMessage() async {
    return _messaging.getInitialMessage();
  }
}
