import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:html' as html;

/// Browser-native notification service for web.
/// Uses the Notification API to show score updates when games change.
class WebNotificationService {
  static final WebNotificationService _instance = WebNotificationService._();
  factory WebNotificationService() => _instance;
  WebNotificationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, StreamSubscription> _gameSubscriptions = {};
  final Map<String, Map<String, int>> _lastKnownScores = {};
  bool _permissionGranted = false;

  /// Whether browser notifications are supported
  bool get isSupported => kIsWeb;

  /// Whether permission has been granted
  bool get hasPermission => _permissionGranted;

  /// Request notification permission from the browser.
  /// Returns true if granted.
  Future<bool> requestPermission() async {
    if (!kIsWeb) return false;

    try {
      final permission = await html.Notification.requestPermission();
      _permissionGranted = permission == 'granted';
      return _permissionGranted;
    } catch (e) {
      debugPrint('Notification permission error: $e');
      return false;
    }
  }

  /// Check current permission status without prompting
  String get permissionStatus {
    if (!kIsWeb) return 'unsupported';
    try {
      return html.Notification.permission ?? 'default';
    } catch (_) {
      return 'unsupported';
    }
  }

  /// Show a browser notification
  void showNotification(String title, {String? body, String? tag}) {
    if (!kIsWeb || !_permissionGranted) return;

    try {
      html.Notification(
        title,
        body: body,
        icon: '/icons/Icon-192.png',
        tag: tag,
      );
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  /// Subscribe to live score updates for a tournament.
  /// Triggers browser notifications when scores change.
  void watchTournament(String tournamentId) {
    if (_gameSubscriptions.containsKey(tournamentId)) return;

    final sub = _firestore
        .collection('games')
        .where('tournamentId', isEqualTo: tournamentId)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          _handleGameUpdate(change.doc);
        }
      }
    });

    _gameSubscriptions[tournamentId] = sub;
  }

  /// Stop watching a tournament
  void unwatchTournament(String tournamentId) {
    _gameSubscriptions[tournamentId]?.cancel();
    _gameSubscriptions.remove(tournamentId);
    _lastKnownScores.remove(tournamentId);
  }

  /// Stop all watchers
  void dispose() {
    for (final sub in _gameSubscriptions.values) {
      sub.cancel();
    }
    _gameSubscriptions.clear();
    _lastKnownScores.clear();
  }

  void _handleGameUpdate(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return;

    final gameId = doc.id;
    final status = data['status'] as String?;
    final teamAName = data['teamAName'] as String? ?? 'Team A';
    final teamBName = data['teamBName'] as String? ?? 'Team B';

    final result = data['result'] as Map<String, dynamic>?;
    if (result == null) return;

    final scoreA = result['teamAScore'] as int? ?? 0;
    final scoreB = result['teamBScore'] as int? ?? 0;

    final lastScores = _lastKnownScores[gameId];
    final oldScoreA = lastScores?['a'] ?? 0;
    final oldScoreB = lastScores?['b'] ?? 0;

    _lastKnownScores[gameId] = {'a': scoreA, 'b': scoreB};

    // Only notify on actual score changes (skip first load)
    if (lastScores == null) return;

    if (status == 'completed') {
      showNotification(
        'Spiel beendet',
        body: '$teamAName $scoreA – $scoreB $teamBName',
        tag: 'game_$gameId',
      );
    } else if (scoreA != oldScoreA || scoreB != oldScoreB) {
      final scoringTeam = scoreA > oldScoreA ? teamAName : teamBName;
      showNotification(
        'Tor! $scoringTeam',
        body: '$teamAName $scoreA – $scoreB $teamBName',
        tag: 'game_$gameId',
      );
    }
  }
}
