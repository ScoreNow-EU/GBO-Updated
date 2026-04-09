import 'package:cloud_firestore/cloud_firestore.dart';

enum FineTargetType {
  team,
  player,
  official,
}

enum FineStatus {
  issued,
  paid,
  appealed,
  cancelled,
}

class Fine {
  final String id;
  final FineTargetType targetType;
  final String targetId;              // Team ID, Player ID, or Official ID
  final String targetName;
  final double amount;                // EUR
  final String reason;
  final String? description;
  final FineStatus status;
  final String issuedByUserId;
  final String issuedByName;
  final DateTime issuedAt;
  final String? seasonId;
  final String? tournamentId;
  final String? relatedProtestId;     // Link to protest if applicable
  final String? relatedSuspensionId;  // Link to suspension if applicable
  final DateTime? paidAt;
  final String? paymentReference;

  Fine({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.targetName,
    required this.amount,
    required this.reason,
    this.description,
    this.status = FineStatus.issued,
    required this.issuedByUserId,
    required this.issuedByName,
    required this.issuedAt,
    this.seasonId,
    this.tournamentId,
    this.relatedProtestId,
    this.relatedSuspensionId,
    this.paidAt,
    this.paymentReference,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'targetType': targetType.name,
      'targetId': targetId,
      'targetName': targetName,
      'amount': amount,
      'reason': reason,
      'description': description,
      'status': status.name,
      'issuedByUserId': issuedByUserId,
      'issuedByName': issuedByName,
      'issuedAt': Timestamp.fromDate(issuedAt),
      'seasonId': seasonId,
      'tournamentId': tournamentId,
      'relatedProtestId': relatedProtestId,
      'relatedSuspensionId': relatedSuspensionId,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'paymentReference': paymentReference,
    };
  }

  static Fine fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Fine(
      id: doc.id,
      targetType: FineTargetType.values.firstWhere(
        (t) => t.name == data['targetType'],
        orElse: () => FineTargetType.team,
      ),
      targetId: data['targetId'] ?? '',
      targetName: data['targetName'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      reason: data['reason'] ?? '',
      description: data['description'],
      status: FineStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => FineStatus.issued,
      ),
      issuedByUserId: data['issuedByUserId'] ?? '',
      issuedByName: data['issuedByName'] ?? '',
      issuedAt: data['issuedAt'] != null
          ? (data['issuedAt'] as Timestamp).toDate()
          : DateTime.now(),
      seasonId: data['seasonId'],
      tournamentId: data['tournamentId'],
      relatedProtestId: data['relatedProtestId'],
      relatedSuspensionId: data['relatedSuspensionId'],
      paidAt: data['paidAt'] != null
          ? (data['paidAt'] as Timestamp).toDate()
          : null,
      paymentReference: data['paymentReference'],
    );
  }

  Fine copyWith({
    FineStatus? status,
    String? description,
    DateTime? paidAt,
    String? paymentReference,
  }) {
    return Fine(
      id: id,
      targetType: targetType,
      targetId: targetId,
      targetName: targetName,
      amount: amount,
      reason: reason,
      description: description ?? this.description,
      status: status ?? this.status,
      issuedByUserId: issuedByUserId,
      issuedByName: issuedByName,
      issuedAt: issuedAt,
      seasonId: seasonId,
      tournamentId: tournamentId,
      relatedProtestId: relatedProtestId,
      relatedSuspensionId: relatedSuspensionId,
      paidAt: paidAt ?? this.paidAt,
      paymentReference: paymentReference ?? this.paymentReference,
    );
  }
}
