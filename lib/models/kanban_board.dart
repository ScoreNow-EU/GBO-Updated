import 'package:cloud_firestore/cloud_firestore.dart';

class KanbanBoard {
  final String id;
  final String name;
  final String description;
  final String projectKey;
  final List<String> adminIds;
  final List<String> memberIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdById;
  final String createdByName;
  final bool isActive;

  KanbanBoard({
    required this.id,
    required this.name,
    required this.description,
    required this.projectKey,
    required this.adminIds,
    required this.memberIds,
    required this.createdAt,
    required this.updatedAt,
    required this.createdById,
    required this.createdByName,
    this.isActive = true,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'projectKey': projectKey,
      'adminIds': adminIds,
      'memberIds': memberIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdById': createdById,
      'createdByName': createdByName,
      'isActive': isActive,
    };
  }

  factory KanbanBoard.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return KanbanBoard(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      projectKey: data['projectKey'] ?? '',
      adminIds: List<String>.from(data['adminIds'] ?? []),
      memberIds: List<String>.from(data['memberIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdById: data['createdById'] ?? '',
      createdByName: data['createdByName'] ?? '',
      isActive: data['isActive'] ?? true,
    );
  }

  KanbanBoard copyWith({
    String? name,
    String? description,
    String? projectKey,
    List<String>? adminIds,
    List<String>? memberIds,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return KanbanBoard(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      projectKey: projectKey ?? this.projectKey,
      adminIds: adminIds ?? this.adminIds,
      memberIds: memberIds ?? this.memberIds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      createdById: createdById,
      createdByName: createdByName,
      isActive: isActive ?? this.isActive,
    );
  }
} 