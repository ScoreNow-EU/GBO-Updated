import 'package:cloud_firestore/cloud_firestore.dart';

enum ProtestStatus {
  filed,
  underReview,
  accepted,
  rejected,
}

class Protest {
  final String id;
  final String gameId;
  final String tournamentId;
  final String filedByTeamId;
  final String filedByUserId;
  final String filedByName;
  final String reason;
  final String? description;
  final ProtestStatus status;
  final String? resolution;
  final String? resolvedByUserId;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final List<String> notifiedUserIds;

  Protest({
    required this.id,
    required this.gameId,
    required this.tournamentId,
    required this.filedByTeamId,
    required this.filedByUserId,
    required this.filedByName,
    required this.reason,
    this.description,
    this.status = ProtestStatus.filed,
    this.resolution,
    this.resolvedByUserId,
    this.resolvedAt,
    required this.createdAt,
    this.notifiedUserIds = const [],
  });

  Map<String, dynamic> toFirestore() {
    return {
      'gameId': gameId,
      'tournamentId': tournamentId,
      'filedByTeamId': filedByTeamId,
      'filedByUserId': filedByUserId,
      'filedByName': filedByName,
      'reason': reason,
      'description': description,
      'status': status.name,
      'resolution': resolution,
      'resolvedByUserId': resolvedByUserId,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'notifiedUserIds': notifiedUserIds,
    };
  }

  static Protest fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Protest(
      id: doc.id,
      gameId: data['gameId'] ?? '',
      tournamentId: data['tournamentId'] ?? '',
      filedByTeamId: data['filedByTeamId'] ?? '',
      filedByUserId: data['filedByUserId'] ?? '',
      filedByName: data['filedByName'] ?? '',
      reason: data['reason'] ?? '',
      description: data['description'],
      status: ProtestStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => ProtestStatus.filed,
      ),
      resolution: data['resolution'],
      resolvedByUserId: data['resolvedByUserId'],
      resolvedAt: data['resolvedAt'] != null
          ? (data['resolvedAt'] as Timestamp).toDate()
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      notifiedUserIds: List<String>.from(data['notifiedUserIds'] ?? []),
    );
  }

  Protest copyWith({
    String? reason,
    String? description,
    ProtestStatus? status,
    String? resolution,
    String? resolvedByUserId,
    DateTime? resolvedAt,
    List<String>? notifiedUserIds,
  }) {
    return Protest(
      id: id,
      gameId: gameId,
      tournamentId: tournamentId,
      filedByTeamId: filedByTeamId,
      filedByUserId: filedByUserId,
      filedByName: filedByName,
      reason: reason ?? this.reason,
      description: description ?? this.description,
      status: status ?? this.status,
      resolution: resolution ?? this.resolution,
      resolvedByUserId: resolvedByUserId ?? this.resolvedByUserId,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      createdAt: createdAt,
      notifiedUserIds: notifiedUserIds ?? this.notifiedUserIds,
    );
  }
}
