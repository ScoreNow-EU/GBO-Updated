import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/suspension.dart';

class SuspensionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _collection => _firestore.collection('suspensions');

  /// Create a new suspension (teamRHD or system)
  Future<String> createSuspension(Suspension suspension) async {
    final docRef = await _collection.add(suspension.toFirestore());
    debugPrint('Suspension created: ${docRef.id} for player ${suspension.playerName}');
    return docRef.id;
  }

  /// Get all active suspensions for a player
  Future<List<Suspension>> getActiveSuspensionsForPlayer(String playerId) async {
    final snapshot = await _collection
        .where('playerId', isEqualTo: playerId)
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs.map((doc) => Suspension.fromFirestore(doc)).toList();
  }

  /// Check if player is suspended for a specific tournament
  Future<bool> isPlayerSuspendedForTournament(
    String playerId,
    String tournamentId,
  ) async {
    final suspensions = await getActiveSuspensionsForPlayer(playerId);
    for (final s in suspensions) {
      // Tournament-scope: matches this tournament
      if (s.type == SuspensionType.tournament && s.tournamentId == tournamentId) {
        return true;
      }
      // Season-scope: active for the whole season
      if (s.type == SuspensionType.season) {
        return true;
      }
      // Custom: check expiry
      if (s.type == SuspensionType.custom) {
        if (s.expiresAt == null || s.expiresAt!.isAfter(DateTime.now())) {
          return true;
        }
      }
    }
    return false;
  }

  /// Get suspension reason for display
  Future<String?> getSuspensionReason(String playerId, String tournamentId) async {
    final suspensions = await getActiveSuspensionsForPlayer(playerId);
    for (final s in suspensions) {
      if (s.type == SuspensionType.tournament && s.tournamentId == tournamentId) {
        return s.reason;
      }
      if (s.type == SuspensionType.season || s.type == SuspensionType.custom) {
        return s.reason;
      }
    }
    return null;
  }

  /// Get all suspensions for a tournament
  Future<List<Suspension>> getSuspensionsForTournament(String tournamentId) async {
    final snapshot = await _collection
        .where('tournamentId', isEqualTo: tournamentId)
        .get();
    return snapshot.docs.map((doc) => Suspension.fromFirestore(doc)).toList();
  }

  /// Get all active suspensions (across all tournaments/seasons)
  Future<List<Suspension>> getAllActiveSuspensions() async {
    final snapshot = await _collection
        .where('isActive', isEqualTo: true)
        .orderBy('issuedAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => Suspension.fromFirestore(doc)).toList();
  }

  /// Get all suspensions (active + inactive) for the historical view.
  /// Capped at 1000 entries, ordered by issuedAt desc.
  Future<List<Suspension>> getAllSuspensions() async {
    final snapshot = await _collection
        .orderBy('issuedAt', descending: true)
        .limit(1000)
        .get();
    if (snapshot.docs.length == 1000) {
      debugPrint('⚠️ Suspensions: snapshot hit limit cap (1000)');
    }
    return snapshot.docs.map((doc) => Suspension.fromFirestore(doc)).toList();
  }

  /// Stream all active suspensions (real-time)
  Stream<List<Suspension>> streamActiveSuspensions() {
    return _collection
        .where('isActive', isEqualTo: true)
        .orderBy('issuedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Suspension.fromFirestore(doc)).toList());
  }

  /// Deactivate a suspension
  Future<void> deactivateSuspension(String suspensionId) async {
    await _collection.doc(suspensionId).update({'isActive': false});
    debugPrint('Suspension deactivated: $suspensionId');
  }

  /// Update suspension (e.g., reduce games remaining)
  Future<void> updateSuspension(String suspensionId, Map<String, dynamic> updates) async {
    await _collection.doc(suspensionId).update(updates);
  }

  /// Delete a suspension (admin only)
  Future<void> deleteSuspension(String suspensionId) async {
    await _collection.doc(suspensionId).delete();
    debugPrint('Suspension deleted: $suspensionId');
  }

  /// Auto-create tournament suspension from blue card
  Future<String> createBlueCardSuspension({
    required String playerId,
    required String playerName,
    required String teamId,
    required String teamName,
    required String tournamentId,
    required String gameId,
    required String issuedByUserId,
    required String issuedByName,
  }) async {
    final suspension = Suspension(
      id: '',
      playerId: playerId,
      playerName: playerName,
      teamId: teamId,
      teamName: teamName,
      type: SuspensionType.tournament,
      reason: 'Blaue Karte – Turniersperre & Bericht an Verband',
      issuedByUserId: issuedByUserId,
      issuedByName: issuedByName,
      issuedAt: DateTime.now(),
      tournamentId: tournamentId,
      sourceGameId: gameId,
      isActive: true,
    );
    return createSuspension(suspension);
  }
}
