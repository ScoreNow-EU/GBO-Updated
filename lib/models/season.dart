import 'package:cloud_firestore/cloud_firestore.dart';

class Season {
  final String id;
  final String name;                    // e.g., "2025/2026"
  final DateTime startDate;
  final DateTime endDate;
  final List<String> spieltageIds;      // Tournament IDs in order
  final bool isActive;
  final String? format;                 // 'round_robin', 'swiss', 'groups', etc.
  final DateTime createdAt;
  final String? createdByUserId;

  Season({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.spieltageIds = const [],
    this.isActive = true,
    this.format,
    required this.createdAt,
    this.createdByUserId,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'spieltageIds': spieltageIds,
      'isActive': isActive,
      'format': format,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdByUserId': createdByUserId,
    };
  }

  static Season fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Season(
      id: doc.id,
      name: data['name'] ?? '',
      startDate: data['startDate'] != null
          ? (data['startDate'] as Timestamp).toDate()
          : DateTime.now(),
      endDate: data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : DateTime.now(),
      spieltageIds: List<String>.from(data['spieltageIds'] ?? []),
      isActive: data['isActive'] ?? true,
      format: data['format'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      createdByUserId: data['createdByUserId'],
    );
  }

  Season copyWith({
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? spieltageIds,
    bool? isActive,
    String? format,
  }) {
    return Season(
      id: id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      spieltageIds: spieltageIds ?? this.spieltageIds,
      isActive: isActive ?? this.isActive,
      format: format ?? this.format,
      createdAt: createdAt,
      createdByUserId: createdByUserId,
    );
  }
}
