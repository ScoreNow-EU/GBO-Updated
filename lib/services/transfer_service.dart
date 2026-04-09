import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/transfer.dart';

class TransferService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _collection => _firestore.collection('transfers');

  /// Request a player transfer
  Future<String> requestTransfer(Transfer transfer) async {
    final docRef = await _collection.add(transfer.toFirestore());
    debugPrint('Transfer requested: ${docRef.id} - ${transfer.playerName} from ${transfer.fromTeamName} to ${transfer.toTeamName}');

    // Notify teamRHD users about the transfer request
    await _notifyTransferRequest(docRef.id, transfer);

    return docRef.id;
  }

  /// Get all transfers
  Future<List<Transfer>> getAllTransfers() async {
    final snapshot = await _collection
        .orderBy('requestedAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => Transfer.fromFirestore(doc)).toList();
  }

  /// Get pending transfers
  Future<List<Transfer>> getPendingTransfers() async {
    final snapshot = await _collection
        .where('status', isEqualTo: TransferStatus.requested.name)
        .orderBy('requestedAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => Transfer.fromFirestore(doc)).toList();
  }

  /// Get transfers for a team
  Future<List<Transfer>> getTransfersForTeam(String teamId) async {
    final fromSnap = await _collection
        .where('fromTeamId', isEqualTo: teamId)
        .get();
    final toSnap = await _collection
        .where('toTeamId', isEqualTo: teamId)
        .get();

    final transfers = <Transfer>[];
    for (final doc in fromSnap.docs) {
      transfers.add(Transfer.fromFirestore(doc));
    }
    for (final doc in toSnap.docs) {
      if (!transfers.any((t) => t.id == doc.id)) {
        transfers.add(Transfer.fromFirestore(doc));
      }
    }
    transfers.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return transfers;
  }

  /// Stream all transfers (real-time)
  Stream<List<Transfer>> streamTransfers() {
    return _collection
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Transfer.fromFirestore(doc)).toList());
  }

  /// Approve a transfer — moves player between team rosters
  Future<void> approveTransfer({
    required String transferId,
    required String approvedByUserId,
    required String approvedByName,
  }) async {
    final doc = await _collection.doc(transferId).get();
    if (!doc.exists) return;

    final transfer = Transfer.fromFirestore(doc);

    // Move player from old team to new team in a batch
    final batch = _firestore.batch();

    // Remove from old team roster
    batch.update(
      _firestore.collection('teams').doc(transfer.fromTeamId),
      {'rosterPlayerIds': FieldValue.arrayRemove([transfer.playerId])},
    );

    // Add to new team roster
    batch.update(
      _firestore.collection('teams').doc(transfer.toTeamId),
      {'rosterPlayerIds': FieldValue.arrayUnion([transfer.playerId])},
    );

    // Update transfer status
    batch.update(_collection.doc(transferId), {
      'status': TransferStatus.approved.name,
      'approvedByUserId': approvedByUserId,
      'approvedByName': approvedByName,
      'resolvedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    debugPrint('Transfer $transferId approved — ${transfer.playerName} moved to ${transfer.toTeamName}');
  }

  /// Reject a transfer
  Future<void> rejectTransfer({
    required String transferId,
    required String rejectedByUserId,
    required String rejectedByName,
    String? reason,
  }) async {
    await _collection.doc(transferId).update({
      'status': TransferStatus.rejected.name,
      'approvedByUserId': rejectedByUserId,
      'approvedByName': rejectedByName,
      'rejectionReason': reason,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('Transfer $transferId rejected');
  }

  /// Notify teamRHD users about a new transfer request
  Future<void> _notifyTransferRequest(String transferId, Transfer transfer) async {
    try {
      final teamRHDUsers = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'teamRHD')
          .get();

      final batch = _firestore.batch();
      for (final user in teamRHDUsers.docs) {
        final notifRef = _firestore.collection('custom_notifications').doc();
        batch.set(notifRef, {
          'title': 'Transferanfrage',
          'message': '${transfer.playerName}: ${transfer.fromTeamName} → ${transfer.toTeamName}',
          'userId': user.id,
          'sentAt': FieldValue.serverTimestamp(),
          'type': 'transfer_request',
          'status': 'sent',
          'isTimeSensitive': false,
          'transferId': transferId,
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error notifying transfer request: $e');
    }
  }

  /// Delete a transfer
  Future<void> deleteTransfer(String transferId) async {
    await _collection.doc(transferId).delete();
    debugPrint('Transfer deleted: $transferId');
  }
}
