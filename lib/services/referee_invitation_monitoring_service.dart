import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/referee.dart';
import '../models/tournament.dart';

class RefereeInvitationMonitoringService {
  static const String _prefKeyLastCheck = 'lastInvitationCheck';
  static const String _prefKeyPendingInvitations = 'pendingInvitations';
  static const String _prefKeyCurrentRefereeId = 'currentRefereeId';
  static const String _channelId = 'referee_invitations';
  
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  static Timer? _periodicTimer;
  static String? _currentRefereeId;
  static bool _isInitialized = false;
  
  /// Method channel for communicating with native iOS code
  static const MethodChannel _methodChannel = MethodChannel('referee_invitation_monitoring');
  
  /// Initialize the monitoring service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Set up method channel for iOS communication
      _methodChannel.setMethodCallHandler(_handleMethodCall);
      
      _isInitialized = true;
      print('✅ Internal monitoring service initialized');
    } catch (e) {
      print('❌ Error initializing monitoring service: $e');
    }
  }
  
  /// Handle method calls from native iOS code
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'checkForPendingInvitations':
        final refereeId = call.arguments as String?;
        if (refereeId != null) {
          return await _checkForPendingInvitations(refereeId);
        }
        break;
      case 'respondToInvitation':
        final args = call.arguments as Map<dynamic, dynamic>;
        final tournamentId = args['tournamentId'] as String;
        final refereeId = args['refereeId'] as String;
        final response = args['response'] as String;
        return await _respondToInvitation(tournamentId, refereeId, response);
      case 'getPendingInvitationsCount':
        final refereeId = call.arguments as String?;
        if (refereeId != null) {
          return await _getPendingInvitationsCount(refereeId);
        }
        break;
      default:
        throw PlatformException(
          code: 'UNIMPLEMENTED',
          message: 'Method ${call.method} not implemented',
        );
    }
  }
  
  /// Start monitoring for a specific referee
  static Future<void> startMonitoring(String refereeId) async {
    try {
      _currentRefereeId = refereeId;
      
      // Save referee ID to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyCurrentRefereeId, refereeId);
      
      // Notify native iOS code that monitoring started
      await _methodChannel.invokeMethod('startBackgroundMonitoring', refereeId);
      
      // Start foreground periodic check
      _startPeriodicCheck();
      
      print('🔔 Started monitoring for referee: $refereeId');
    } catch (e) {
      print('❌ Error starting monitoring: $e');
    }
  }
  
  /// Stop monitoring
  static Future<void> stopMonitoring() async {
    try {
      _currentRefereeId = null;
      _periodicTimer?.cancel();
      _periodicTimer = null;
      
      // Clear preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyCurrentRefereeId);
      await prefs.remove(_prefKeyPendingInvitations);
      
      // Notify native iOS code to stop monitoring
      await _methodChannel.invokeMethod('stopBackgroundMonitoring');
      
      print('🛑 Stopped monitoring');
    } catch (e) {
      print('❌ Error stopping monitoring: $e');
    }
  }
  
  /// Start periodic check (foreground only)
  static void _startPeriodicCheck() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(
      const Duration(seconds: 30), // Check every 30 seconds when app is active
      (timer) async {
        if (_currentRefereeId != null) {
          await _checkForPendingInvitations(_currentRefereeId!);
        }
      },
    );
  }
  
  /// Check for pending invitations (main logic)
  static Future<Map<String, dynamic>> _checkForPendingInvitations(String refereeId) async {
    try {
      print('🔍 Checking pending invitations for referee: $refereeId');
      
      final firestore = FirebaseFirestore.instance;
      
      // Get all tournaments
      final tournamentsSnapshot = await firestore.collection('tournaments').get();
      
      final currentPendingTournaments = <String>[];
      final newTournaments = <Tournament>[];
      
      for (final doc in tournamentsSnapshot.docs) {
        final data = doc.data();
        final invitations = List<Map<String, dynamic>>.from(data['refereeInvitations'] ?? []);
        
        // Check if this referee has a pending invitation
        final pendingInvitation = invitations.firstWhere(
          (invitation) => invitation['refereeId'] == refereeId && invitation['status'] == 'pending',
          orElse: () => <String, dynamic>{},
        );
        
        if (pendingInvitation.isNotEmpty) {
          currentPendingTournaments.add(doc.id);
          
          // Create tournament object for potential notification
          final tournament = Tournament.fromMap(data, doc.id);
          newTournaments.add(tournament);
        }
      }
      
      // Check for new invitations
      final prefs = await SharedPreferences.getInstance();
      final previousPendingJson = prefs.getString(_prefKeyPendingInvitations);
      final previousPending = previousPendingJson != null 
          ? Set<String>.from(jsonDecode(previousPendingJson))
          : <String>{};
      
      final currentPending = currentPendingTournaments.toSet();
      final newInvitations = currentPending.difference(previousPending);
      
      print('📊 Results: ${currentPending.length} pending, ${newInvitations.length} new');
      
      // Update stored pending invitations
      await prefs.setString(_prefKeyPendingInvitations, jsonEncode(currentPending.toList()));
      await prefs.setString(_prefKeyLastCheck, DateTime.now().toIso8601String());
      
      // Send push notification if there are new invitations
      if (newInvitations.isNotEmpty) {
        print('🔔 New invitations detected: ${newInvitations.join(', ')}');
        final newTournamentsList = newTournaments.where((t) => newInvitations.contains(t.id)).toList();
        print('🔔 Sending push notification for ${newTournamentsList.length} tournaments');
        await _sendPushNotification(newTournamentsList);
      } else {
        print('🔔 No new invitations to notify about');
      }
      
      // Return results for native iOS code
      return {
        'totalPending': currentPending.length,
        'newInvitations': newInvitations.length,
        'pendingTournaments': newTournaments.map((t) => {
          'id': t.id,
          'name': t.name,
          'startDate': t.startDate.toIso8601String(),
          'endDate': t.endDate?.toIso8601String(),
          'location': t.location,
          'divisions': t.divisions,
        }).toList(),
      };
      
    } catch (e) {
      print('❌ Error checking for pending invitations: $e');
      return {
        'totalPending': 0,
        'newInvitations': 0,
        'pendingTournaments': [],
        'error': e.toString(),
      };
    }
  }
  
  /// Get pending invitations count for a referee
  static Future<int> _getPendingInvitationsCount(String refereeId) async {
    try {
      final result = await _checkForPendingInvitations(refereeId);
      return result['totalPending'] as int;
    } catch (e) {
      print('❌ Error getting pending invitations count: $e');
      return 0;
    }
  }
  
  /// Respond to tournament invitation
  static Future<bool> _respondToInvitation(String tournamentId, String refereeId, String status) async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Get tournament
      final tournamentDoc = await firestore.collection('tournaments').doc(tournamentId).get();
      if (!tournamentDoc.exists) return false;
      
      final data = tournamentDoc.data()!;
      final invitations = List<Map<String, dynamic>>.from(data['refereeInvitations'] ?? []);
      
      // Update invitation status
      bool found = false;
      for (int i = 0; i < invitations.length; i++) {
        if (invitations[i]['refereeId'] == refereeId) {
          invitations[i]['status'] = status;
          invitations[i]['respondedAt'] = Timestamp.now();
          found = true;
          break;
        }
      }
      
      if (!found) return false;
      
      // Update tournament
      await firestore.collection('tournaments').doc(tournamentId).update({
        'refereeInvitations': invitations,
      });
      
      // Update referee's pending invitations if not pending anymore
      if (status != 'pending') {
        final refereeDoc = await firestore.collection('referees').doc(refereeId).get();
        if (refereeDoc.exists) {
          final refereeData = refereeDoc.data()!;
          final pendingInvitations = List<String>.from(refereeData['invitationsPending'] ?? []);
          pendingInvitations.remove(tournamentId);
          
          await firestore.collection('referees').doc(refereeId).update({
            'invitationsPending': pendingInvitations,
            'updatedAt': Timestamp.now(),
          });
        }
        
        // Update local storage
        final prefs = await SharedPreferences.getInstance();
        final previousPendingJson = prefs.getString(_prefKeyPendingInvitations);
        if (previousPendingJson != null) {
          final previousPending = Set<String>.from(jsonDecode(previousPendingJson));
          previousPending.remove(tournamentId);
          await prefs.setString(_prefKeyPendingInvitations, jsonEncode(previousPending.toList()));
        }
      }
      
      print('✅ Invitation response saved: $status for tournament: $tournamentId');
      return true;
    } catch (e) {
      print('❌ Error responding to invitation: $e');
      return false;
    }
  }
  
  /// Send push notification through iOS native code
  static Future<void> _sendPushNotification(List<Tournament> tournaments) async {
    try {
      final tournamentData = tournaments.map((t) => {
        'id': t.id,
        'name': t.name,
        'startDate': t.startDate.toIso8601String(),
        'endDate': t.endDate?.toIso8601String(),
        'location': t.location,
        'divisions': t.divisions,
      }).toList();
      
      // Call iOS native code to send push notification
      await _methodChannel.invokeMethod('sendPushNotification', {
        'tournaments': tournamentData,
      });
      
      print('📱 Push notification sent for ${tournaments.length} tournaments');
    } catch (e) {
      print('❌ Error sending push notification: $e');
    }
  }
  
  /// Show local notification for new invitations (called from native iOS)
  static Future<void> showLocalNotification(List<Tournament> tournaments) async {
    try {
      final tournament = tournaments.first;
      String title;
      String body;
      
      if (tournaments.length == 1) {
        title = 'Neue Schiedsrichter-Einladung';
        body = 'Du wurdest zum/r ${tournament.name} als Schiedsrichter eingeladen';
      } else {
        title = 'Neue Schiedsrichter-Einladungen';
        body = 'Du hast ${tournaments.length} neue Turniereinladungen';
      }
      
      const notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'referee_invitations',
          'Schiedsrichter-Einladungen',
          channelDescription: 'Benachrichtigungen für neue Schiedsrichter-Einladungen',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          categoryIdentifier: 'referee_invitation',
        ),
      );
      
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        notificationDetails,
        payload: jsonEncode({
          'type': 'referee_invitation',
          'tournaments': tournaments.map((t) => t.toMap()).toList(),
        }),
      );
      
      print('📱 Local notification shown for ${tournaments.length} tournaments');
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
            'referee_invitation',
            actions: [
              DarwinNotificationAction.plain(
                'accept',
                'Zusagen',
                options: {DarwinNotificationActionOption.foreground},
              ),
              DarwinNotificationAction.plain(
                'decline',
                'Absagen',
                options: {DarwinNotificationActionOption.destructive},
              ),
              DarwinNotificationAction.plain(
                'later',
                'Später',
                options: {},
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
      if (data['type'] == 'referee_invitation') {
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
      final tournaments = List<Map<String, dynamic>>.from(data['tournaments'] ?? []);
      if (tournaments.isEmpty) return;
      
      final prefs = await SharedPreferences.getInstance();
      final refereeId = prefs.getString(_prefKeyCurrentRefereeId);
      if (refereeId == null) return;
      
      String status;
      switch (actionId) {
        case 'accept':
          status = 'accepted';
          break;
        case 'decline':
          status = 'declined';
          break;
        case 'later':
          status = 'pending';
          break;
        default:
          return;
      }
      
      // Respond to first tournament invitation
      final firstTournament = tournaments.first;
      final tournamentId = firstTournament['id'];
      
      final success = await _respondToInvitation(tournamentId, refereeId, status);
      
      if (success) {
        // Show confirmation notification
        String confirmationTitle;
        String confirmationBody;
        switch (actionId) {
          case 'accept':
            confirmationTitle = 'Zusage gesendet';
            confirmationBody = 'Sie haben die Einladung angenommen';
            break;
          case 'decline':
            confirmationTitle = 'Absage gesendet';
            confirmationBody = 'Sie haben die Einladung abgelehnt';
            break;
          case 'later':
            confirmationTitle = 'Später entscheiden';
            confirmationBody = 'Sie können später antworten';
            break;
          default:
            return;
        }
        
        await _localNotifications.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1,
          confirmationTitle,
          confirmationBody,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'referee_responses',
              'Schiedsrichter-Antworten',
              channelDescription: 'Bestätigungen für Schiedsrichter-Antworten',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: false,
              presentSound: false,
            ),
          ),
        );
      }
      
      print('✅ Notification action handled: $actionId');
    } catch (e) {
      print('❌ Error handling notification action: $e');
    }
  }
  
  /// Get current referee ID
  static String? getCurrentRefereeId() => _currentRefereeId;
  
  /// Dispose resources
  static void dispose() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }
} 