import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/protest.dart';

class ProtestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _collection => _firestore.collection('protests');

  /// Create a new protest and notify all relevant parties
  Future<String> createProtest(Protest protest) async {
    final docRef = await _collection.add(protest.toFirestore());
    debugPrint('Protest created: ${docRef.id} for game ${protest.gameId}');

    // Send notifications to all relevant parties
    await _sendProtestNotifications(docRef.id, protest);

    return docRef.id;
  }

  /// Notify referees, delegates, opposing coach, tournament organizer, and teamRHD
  Future<void> _sendProtestNotifications(String protestId, Protest protest) async {
    try {
      final notifiedUserIds = <String>[];

      // 1. Get the game to find assigned referees
      final gameDoc = await _firestore
          .collection('tournaments')
          .doc(protest.tournamentId)
          .collection('games')
          .doc(protest.gameId)
          .get();

      String opponentTeamId = '';
      if (gameDoc.exists) {
        final gameData = gameDoc.data()!;
        // Notify assigned referees
        for (final field in ['referee1Id', 'referee2Id']) {
          final refId = gameData[field];
          if (refId != null && refId.toString().isNotEmpty) {
            final refUser = await _findUserByRefereeId(refId);
            if (refUser != null) notifiedUserIds.add(refUser);
          }
        }
        // Determine opposing team
        final teamAId = gameData['teamAId'] ?? '';
        final teamBId = gameData['teamBId'] ?? '';
        opponentTeamId = protest.filedByTeamId == teamAId ? teamBId : teamAId;
      }

      // 2. Get tournament for delegates and organizer
      final tournamentDoc = await _firestore
          .collection('tournaments')
          .doc(protest.tournamentId)
          .get();

      if (tournamentDoc.exists) {
        final tData = tournamentDoc.data()!;
        // Notify delegates
        final delegateIds = List<String>.from(tData['delegateIds'] ?? []);
        for (final dId in delegateIds) {
          final delegateUser = await _findUserByDelegateId(dId);
          if (delegateUser != null) notifiedUserIds.add(delegateUser);
        }
        // Notify tournament organizer
        final organizerId = tData['tournamentOrganizerId'];
        if (organizerId != null && organizerId.toString().isNotEmpty) {
          notifiedUserIds.add(organizerId);
        }
      }

      // 3. Notify opposing team's coach/manager
      if (opponentTeamId.isNotEmpty) {
        final teamDoc = await _firestore.collection('teams').doc(opponentTeamId).get();
        if (teamDoc.exists) {
          final coachEmail = (teamDoc.data() as Map<String, dynamic>)['coachEmail'];
          if (coachEmail != null && coachEmail.toString().isNotEmpty) {
            final coachUser = await _findUserByEmail(coachEmail);
            if (coachUser != null) notifiedUserIds.add(coachUser);
          }
        }
      }

      // 4. Notify all teamRHD users (league commissioners)
      final teamRHDUsers = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'teamRHD')
          .get();
      for (final doc in teamRHDUsers.docs) {
        notifiedUserIds.add(doc.id);
      }

      // Remove duplicates and the filing user
      final uniqueIds = notifiedUserIds.toSet()
        ..remove(protest.filedByUserId);

      // Save notification for each user
      final batch = _firestore.batch();
      for (final userId in uniqueIds) {
        final notifRef = _firestore.collection('custom_notifications').doc();
        batch.set(notifRef, {
          'title': 'Protest eingereicht',
          'message': '${protest.filedByName} hat einen Protest eingereicht: ${protest.reason}',
          'userId': userId,
          'sentAt': FieldValue.serverTimestamp(),
          'type': 'protest_filed',
          'status': 'sent',
          'isTimeSensitive': true,
          'protestId': protestId,
          'tournamentId': protest.tournamentId,
          'gameId': protest.gameId,
        });
      }
      await batch.commit();

      // Update protest with notified user IDs
      await _collection.doc(protestId).update({
        'notifiedUserIds': uniqueIds.toList(),
      });

      debugPrint('Protest notifications sent to ${uniqueIds.length} users');
    } catch (e) {
      debugPrint('Error sending protest notifications: $e');
    }
  }

  Future<String?> _findUserByRefereeId(String refereeId) async {
    final snap = await _firestore
        .collection('users')
        .where('refereeId', isEqualTo: refereeId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty ? snap.docs.first.id : null;
  }

  Future<String?> _findUserByDelegateId(String delegateId) async {
    final snap = await _firestore
        .collection('users')
        .where('delegateId', isEqualTo: delegateId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty ? snap.docs.first.id : null;
  }

  Future<String?> _findUserByEmail(String email) async {
    final snap = await _firestore
        .collection('users')
        .where('email', isEqualTo: email.toLowerCase())
        .limit(1)
        .get();
    return snap.docs.isNotEmpty ? snap.docs.first.id : null;
  }

  /// Get all protests for a tournament
  Future<List<Protest>> getProtestsForTournament(String tournamentId) async {
    final snapshot = await _collection
        .where('tournamentId', isEqualTo: tournamentId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => Protest.fromFirestore(doc)).toList();
  }

  /// Get all protests for a specific game
  Future<List<Protest>> getProtestsForGame(String gameId) async {
    final snapshot = await _collection
        .where('gameId', isEqualTo: gameId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => Protest.fromFirestore(doc)).toList();
  }

  /// Get a single protest by ID
  Future<Protest?> getProtest(String protestId) async {
    final doc = await _collection.doc(protestId).get();
    if (!doc.exists) return null;
    return Protest.fromFirestore(doc);
  }

  /// Stream protests for a tournament (real-time)
  Stream<List<Protest>> streamProtestsForTournament(String tournamentId) {
    return _collection
        .where('tournamentId', isEqualTo: tournamentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Protest.fromFirestore(doc)).toList());
  }

  /// Update protest status (review/accept/reject)
  Future<void> resolveProtest({
    required String protestId,
    required ProtestStatus status,
    required String resolution,
    required String resolvedByUserId,
  }) async {
    await _collection.doc(protestId).update({
      'status': status.name,
      'resolution': resolution,
      'resolvedByUserId': resolvedByUserId,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('Protest $protestId resolved with status: ${status.name}');
  }

  /// Check if a game has any filed protests
  Future<bool> hasOpenProtests(String gameId) async {
    final snapshot = await _collection
        .where('gameId', isEqualTo: gameId)
        .where('status', isEqualTo: ProtestStatus.filed.name)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  /// Delete a protest (admin only)
  Future<void> deleteProtest(String protestId) async {
    await _collection.doc(protestId).delete();
    debugPrint('Protest deleted: $protestId');
  }
}
