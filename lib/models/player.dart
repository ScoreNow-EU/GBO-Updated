import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class Player {
  final String id;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final DateTime? birthDate;
  final String? classification; // 'Gruppe A', 'Gruppe B', 'Gruppe C'
  final String? jerseyNumber;
  final String gender; // 'mÃ¤nnlich', 'weiblich', 'divers'
  final bool isActive;
  final DateTime createdAt;

  Player({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.birthDate,
    this.classification,
    this.jerseyNumber,
    required this.gender,
    this.isActive = true,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName';

  /// Classification types for wheelchair handball
  static const List<String> classificationTypes = [
    'Gruppe A',  // GdB & International Klassifizierbar
    'Gruppe B',  // GdB
    'Gruppe C',  // keine
  ];

  static const Map<String, String> classificationDescriptions = {
    'Gruppe A': 'GdB & International Klassifizierbar',
    'Gruppe B': 'GdB',
    'Gruppe C': 'Keine Klassifizierung',
  };

  static const List<String> genderOptions = [
    'mÃ¤nnlich',
    'weiblich',
    'divers',
  ];

  Map<String, dynamic> toFirestore() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'birthDate': birthDate != null ? Timestamp.fromDate(birthDate!) : null,
      'classification': classification,
      'jerseyNumber': jerseyNumber,
      'gender': gender,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static Player fromFirestore(DocumentSnapshot doc) {
    try {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      
      // Migration: convert old 'position' field to 'classification'
      String? classification = data['classification'];
      if (classification == null && data['position'] != null) {
        classification = 'Gruppe C';
      }

      // Migration: convert old gender values
      String gender = data['gender'] ?? 'mÃ¤nnlich';
      if (gender == 'male') gender = 'mÃ¤nnlich';
      if (gender == 'female') gender = 'weiblich';
      
      return Player(
        id: doc.id,
        firstName: data['firstName'] ?? '',
        lastName: data['lastName'] ?? '',
        email: data['email'],
        phone: data['phone'],
        birthDate: data['birthDate'] != null 
            ? (data['birthDate'] as Timestamp).toDate() 
            : null,
        classification: classification,
        jerseyNumber: data['jerseyNumber'],
        gender: gender,
        isActive: data['isActive'] ?? true,
        createdAt: data['createdAt'] != null 
            ? (data['createdAt'] as Timestamp).toDate() 
            : DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error parsing player document ${doc.id}: $e');
      debugPrint('Document data: ${doc.data()}');
      rethrow;
    }
  }

  Player copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    DateTime? birthDate,
    String? classification,
    String? jerseyNumber,
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
      classification: classification ?? this.classification,
      jerseyNumber: jerseyNumber ?? this.jerseyNumber,
      gender: gender ?? this.gender,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }
} 