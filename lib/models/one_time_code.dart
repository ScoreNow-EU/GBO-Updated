import 'package:cloud_firestore/cloud_firestore.dart';

class OneTimeCode {
  final String id;
  final String code;
  final String teamName;
  final String preEnteredEmail;
  final DateTime expiryDate;
  final bool isUsed;
  final String createdByAdminId;
  final DateTime createdAt;
  final String? usedByUserId;
  final DateTime? usedAt;

  OneTimeCode({
    required this.id,
    required this.code,
    required this.teamName,
    required this.preEnteredEmail,
    required this.expiryDate,
    this.isUsed = false,
    required this.createdByAdminId,
    required this.createdAt,
    this.usedByUserId,
    this.usedAt,
  });

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'code': code,
      'teamName': teamName,
      'preEnteredEmail': preEnteredEmail,
      'expiryDate': expiryDate,
      'isUsed': isUsed,
      'createdByAdminId': createdByAdminId,
      'createdAt': createdAt,
      'usedByUserId': usedByUserId,
      'usedAt': usedAt,
    };
  }

  // Create from Firestore document
  factory OneTimeCode.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OneTimeCode(
      id: doc.id,
      code: data['code'] ?? '',
      teamName: data['teamName'] ?? '',
      preEnteredEmail: data['preEnteredEmail'] ?? '',
      expiryDate: (data['expiryDate'] as Timestamp).toDate(),
      isUsed: data['isUsed'] ?? false,
      createdByAdminId: data['createdByAdminId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      usedByUserId: data['usedByUserId'],
      usedAt: data['usedAt'] != null ? (data['usedAt'] as Timestamp).toDate() : null,
    );
  }

  // Check if code is still valid
  bool isValid() {
    return !isUsed && DateTime.now().isBefore(expiryDate);
  }

  // Copy with updated fields
  OneTimeCode copyWith({
    String? code,
    String? teamName,
    String? preEnteredEmail,
    DateTime? expiryDate,
    bool? isUsed,
    String? createdByAdminId,
    DateTime? createdAt,
    String? usedByUserId,
    DateTime? usedAt,
  }) {
    return OneTimeCode(
      id: id,
      code: code ?? this.code,
      teamName: teamName ?? this.teamName,
      preEnteredEmail: preEnteredEmail ?? this.preEnteredEmail,
      expiryDate: expiryDate ?? this.expiryDate,
      isUsed: isUsed ?? this.isUsed,
      createdByAdminId: createdByAdminId ?? this.createdByAdminId,
      createdAt: createdAt ?? this.createdAt,
      usedByUserId: usedByUserId ?? this.usedByUserId,
      usedAt: usedAt ?? this.usedAt,
    );
  }
}
