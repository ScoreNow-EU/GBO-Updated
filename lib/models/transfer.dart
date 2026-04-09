import 'package:cloud_firestore/cloud_firestore.dart';

enum TransferStatus {
  requested,
  approved,
  rejected,
}

class Transfer {
  final String id;
  final String playerId;
  final String playerName;
  final String fromTeamId;
  final String fromTeamName;
  final String toTeamId;
  final String toTeamName;
  final String requestedByUserId;
  final String requestedByName;
  final TransferStatus status;
  final String? approvedByUserId;
  final String? approvedByName;
  final String? rejectionReason;
  final DateTime requestedAt;
  final DateTime? resolvedAt;

  Transfer({
    required this.id,
    required this.playerId,
    required this.playerName,
    required this.fromTeamId,
    required this.fromTeamName,
    required this.toTeamId,
    required this.toTeamName,
    required this.requestedByUserId,
    required this.requestedByName,
    this.status = TransferStatus.requested,
    this.approvedByUserId,
    this.approvedByName,
    this.rejectionReason,
    required this.requestedAt,
    this.resolvedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'playerId': playerId,
      'playerName': playerName,
      'fromTeamId': fromTeamId,
      'fromTeamName': fromTeamName,
      'toTeamId': toTeamId,
      'toTeamName': toTeamName,
      'requestedByUserId': requestedByUserId,
      'requestedByName': requestedByName,
      'status': status.name,
      'approvedByUserId': approvedByUserId,
      'approvedByName': approvedByName,
      'rejectionReason': rejectionReason,
      'requestedAt': Timestamp.fromDate(requestedAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
    };
  }

  static Transfer fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Transfer(
      id: doc.id,
      playerId: data['playerId'] ?? '',
      playerName: data['playerName'] ?? '',
      fromTeamId: data['fromTeamId'] ?? '',
      fromTeamName: data['fromTeamName'] ?? '',
      toTeamId: data['toTeamId'] ?? '',
      toTeamName: data['toTeamName'] ?? '',
      requestedByUserId: data['requestedByUserId'] ?? '',
      requestedByName: data['requestedByName'] ?? '',
      status: TransferStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => TransferStatus.requested,
      ),
      approvedByUserId: data['approvedByUserId'],
      approvedByName: data['approvedByName'],
      rejectionReason: data['rejectionReason'],
      requestedAt: data['requestedAt'] != null
          ? (data['requestedAt'] as Timestamp).toDate()
          : DateTime.now(),
      resolvedAt: data['resolvedAt'] != null
          ? (data['resolvedAt'] as Timestamp).toDate()
          : null,
    );
  }
}
