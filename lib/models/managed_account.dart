import 'package:cloud_firestore/cloud_firestore.dart';

enum ManagedAccountType {
  scoringTablet,
}

class ManagedAccount {
  final String id;
  final String name;
  final String email;
  final String password; // Temporary password for tablet login
  final ManagedAccountType type;
  final String? tournamentId; // Assigned tournament
  final String? courtId; // For scoring tablets - assigned court
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? notes; // Additional notes
  final String? oneTimeCode; // One-time login code
  final bool isOneTimeCodeUsed; // Track if the one-time code has been used
  final DateTime? oneTimeCodeUsedAt; // When the code was used

  ManagedAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.type,
    this.tournamentId,
    this.courtId,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.notes,
    this.oneTimeCode,
    this.isOneTimeCodeUsed = false,
    this.oneTimeCodeUsedAt,
  });

  String get typeDisplayName {
    switch (type) {
      case ManagedAccountType.scoringTablet:
        return 'Scoring Tablet';
    }
  }

  String get typeDisplayNameGerman {
    switch (type) {
      case ManagedAccountType.scoringTablet:
        return 'Punktetablet';
    }
  }

  bool get requiresCourt => type == ManagedAccountType.scoringTablet;

  bool get isAssignedToTournament => tournamentId != null;

  bool get isAssignedToCourt => courtId != null;

  bool get hasValidOneTimeCode => oneTimeCode != null && !isOneTimeCodeUsed;

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'password': password,
      'type': type.name,
      'tournamentId': tournamentId,
      'courtId': courtId,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'notes': notes,
      'oneTimeCode': oneTimeCode,
      'isOneTimeCodeUsed': isOneTimeCodeUsed,
      'oneTimeCodeUsedAt': oneTimeCodeUsedAt != null ? Timestamp.fromDate(oneTimeCodeUsedAt!) : null,
    };
  }

  factory ManagedAccount.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return ManagedAccount(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      password: data['password'] ?? '',
      type: ManagedAccountType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => ManagedAccountType.scoringTablet,
      ),
      tournamentId: data['tournamentId'],
      courtId: data['courtId'],
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      notes: data['notes'],
      oneTimeCode: data['oneTimeCode'],
      isOneTimeCodeUsed: data['isOneTimeCodeUsed'] ?? false,
      oneTimeCodeUsedAt: (data['oneTimeCodeUsedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory ManagedAccount.fromMap(Map<String, dynamic> data, String id) {
    return ManagedAccount(
      id: id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      password: data['password'] ?? '',
      type: ManagedAccountType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => ManagedAccountType.scoringTablet,
      ),
      tournamentId: data['tournamentId'],
      courtId: data['courtId'],
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      notes: data['notes'],
      oneTimeCode: data['oneTimeCode'],
      isOneTimeCodeUsed: data['isOneTimeCodeUsed'] ?? false,
      oneTimeCodeUsedAt: (data['oneTimeCodeUsedAt'] as Timestamp?)?.toDate(),
    );
  }

  ManagedAccount copyWith({
    String? id,
    String? name,
    String? email,
    String? password,
    ManagedAccountType? type,
    String? tournamentId,
    String? courtId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
    String? oneTimeCode,
    bool? isOneTimeCodeUsed,
    DateTime? oneTimeCodeUsedAt,
  }) {
    return ManagedAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      type: type ?? this.type,
      tournamentId: tournamentId ?? this.tournamentId,
      courtId: courtId ?? this.courtId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
      oneTimeCode: oneTimeCode ?? this.oneTimeCode,
      isOneTimeCodeUsed: isOneTimeCodeUsed ?? this.isOneTimeCodeUsed,
      oneTimeCodeUsedAt: oneTimeCodeUsedAt ?? this.oneTimeCodeUsedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ManagedAccount && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ManagedAccount(id: $id, name: $name, type: $type, tournament: $tournamentId, court: $courtId)';
  }
} 