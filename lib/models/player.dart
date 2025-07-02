import 'package:cloud_firestore/cloud_firestore.dart';

class Player {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final DateTime? birthDate;
  final String? position; // Optional position like 'Blocker', 'Defender', etc.
  final String? jerseyNumber;
  final String? clubId; // Reference to club
  final String gender; // 'male' or 'female'
  final bool isActive;
  final DateTime createdAt;

  Player({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.birthDate,
    this.position,
    this.jerseyNumber,
    this.clubId,
    required this.gender,
    this.isActive = true,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName';

  Map<String, dynamic> toFirestore() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'birthDate': birthDate != null ? Timestamp.fromDate(birthDate!) : null,
      'position': position,
      'jerseyNumber': jerseyNumber,
      'clubId': clubId,
      'gender': gender,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static Player fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return Player(
      id: doc.id,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'],
      birthDate: data['birthDate'] != null 
          ? (data['birthDate'] as Timestamp).toDate() 
          : null,
      position: data['position'],
      jerseyNumber: data['jerseyNumber'],
      clubId: data['clubId'],
      gender: data['gender'] ?? 'male', // Default to male for backwards compatibility
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  Player copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    DateTime? birthDate,
    String? position,
    String? jerseyNumber,
    String? clubId,
    String? gender,
    bool? isActive,
  }) {
    return Player(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      birthDate: birthDate ?? this.birthDate,
      position: position ?? this.position,
      jerseyNumber: jerseyNumber ?? this.jerseyNumber,
      clubId: clubId ?? this.clubId,
      gender: gender ?? this.gender,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }
} 