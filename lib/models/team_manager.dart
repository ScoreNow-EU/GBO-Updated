import 'package:cloud_firestore/cloud_firestore.dart';

class TeamManager {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final List<String> teamIds; // Teams this manager is responsible for
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final String? userId; // Firebase Auth UID when they register

  TeamManager({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.teamIds,
    this.isActive = true,
    required this.createdAt,
    this.lastLoginAt,
    this.userId,
  });

  factory TeamManager.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TeamManager(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'],
      teamIds: List<String>.from(data['teamIds'] ?? []),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastLoginAt: data['lastLoginAt'] != null 
          ? (data['lastLoginAt'] as Timestamp).toDate() 
          : null,
      userId: data['userId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'teamIds': teamIds,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': lastLoginAt != null 
          ? Timestamp.fromDate(lastLoginAt!) 
          : null,
      'userId': userId,
    };
  }

  TeamManager copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    List<String>? teamIds,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    String? userId,
  }) {
    return TeamManager(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      teamIds: teamIds ?? this.teamIds,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      userId: userId ?? this.userId,
    );
  }
} 