import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/fine.dart';

class FineService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _collection => _firestore.collection('fines');

  /// Create a new fine
  Future<String> createFine(Fine fine) async {
    final docRef = await _collection.add(fine.toFirestore());
    debugPrint('Fine created: ${docRef.id} - ${fine.reason}');
    return docRef.id;
  }

  /// Get all fines for a season
  Future<List<Fine>> getFinesForSeason(String seasonId) async {
    final snapshot = await _collection
        .where('seasonId', isEqualTo: seasonId)
        .orderBy('issuedAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => Fine.fromFirestore(doc)).toList();
  }

  /// Get all fines for a tournament
  Future<List<Fine>> getFinesForTournament(String tournamentId) async {
    final snapshot = await _collection
        .where('tournamentId', isEqualTo: tournamentId)
        .orderBy('issuedAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => Fine.fromFirestore(doc)).toList();
  }

  /// Get fines for a specific target (team or player)
  Future<List<Fine>> getFinesForTarget(String targetId) async {
    final snapshot = await _collection
        .where('targetId', isEqualTo: targetId)
        .orderBy('issuedAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => Fine.fromFirestore(doc)).toList();
  }

  /// Get all unpaid fines
  Future<List<Fine>> getUnpaidFines() async {
    final snapshot = await _collection
        .where('status', isEqualTo: FineStatus.issued.name)
        .orderBy('issuedAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => Fine.fromFirestore(doc)).toList();
  }

  /// Stream all fines (real-time)
  Stream<List<Fine>> streamFines() {
    return _collection
        .orderBy('issuedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Fine.fromFirestore(doc)).toList());
  }

  /// Mark fine as paid
  Future<void> markAsPaid(String fineId, {String? paymentReference}) async {
    await _collection.doc(fineId).update({
      'status': FineStatus.paid.name,
      'paidAt': FieldValue.serverTimestamp(),
      'paymentReference': paymentReference,
    });
    debugPrint('Fine marked as paid: $fineId');
  }

  /// Mark fine as appealed
  Future<void> markAsAppealed(String fineId) async {
    await _collection.doc(fineId).update({
      'status': FineStatus.appealed.name,
    });
    debugPrint('Fine appealed: $fineId');
  }

  /// Cancel a fine
  Future<void> cancelFine(String fineId) async {
    await _collection.doc(fineId).update({
      'status': FineStatus.cancelled.name,
    });
    debugPrint('Fine cancelled: $fineId');
  }

  /// Delete a fine (admin only)
  Future<void> deleteFine(String fineId) async {
    await _collection.doc(fineId).delete();
    debugPrint('Fine deleted: $fineId');
  }

  /// Get total unpaid fines amount for a target
  Future<double> getTotalUnpaidAmount(String targetId) async {
    final fines = await getFinesForTarget(targetId);
    return fines
        .where((f) => f.status == FineStatus.issued)
        .fold<double>(0.0, (sum, f) => sum + f.amount);
  }
}
