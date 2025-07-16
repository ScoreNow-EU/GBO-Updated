import 'package:cloud_firestore/cloud_firestore.dart';

class Referee {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String licenseType; // EHF Kader, DHB Elite Kader, DHB Stamm Kader, Perspektiv Kader, Basis Lizenz
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> invitationsPending; // Tournament IDs with pending invitations

  Referee({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.licenseType,
    required this.createdAt,
    required this.updatedAt,
    this.invitationsPending = const [],
  });

  String get fullName => '$firstName $lastName';

  // Get count of pending invitations
  int get pendingInvitationsCount => invitationsPending.length;

  // Check if has pending invitation for specific tournament
  bool hasPendingInvitation(String tournamentId) => invitationsPending.contains(tournamentId);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'licenseType': licenseType,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'invitationsPending': invitationsPending,
    };
  }

  factory Referee.fromJson(Map<String, dynamic> json) {
    return Referee(
      id: json['id'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      email: json['email'],
      licenseType: json['licenseType'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      invitationsPending: List<String>.from(json['invitationsPending'] ?? []),
    );
  }

  // Firebase Firestore methods
  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'licenseType': licenseType,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'invitationsPending': invitationsPending,
    };
  }

  factory Referee.fromMap(Map<String, dynamic> map, String documentId) {
    // Handle migration from int to List<String>
    dynamic invitationsPendingData = map['invitationsPending'];
    List<String> invitationsPending = [];
    
    if (invitationsPendingData != null) {
      if (invitationsPendingData is int) {
        // Old format - just ignore the count as we'll sync it properly
        invitationsPending = [];
      } else if (invitationsPendingData is List) {
        invitationsPending = List<String>.from(invitationsPendingData);
      }
    }

    return Referee(
      id: documentId,
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      email: map['email'] ?? '',
      licenseType: map['licenseType'] ?? 'Basis-Lizenz',
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: map['updatedAt']?.toDate() ?? DateTime.now(),
      invitationsPending: invitationsPending,
    );
  }

  Referee copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? licenseType,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? invitationsPending,
  }) {
    return Referee(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      licenseType: licenseType ?? this.licenseType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      invitationsPending: invitationsPending ?? this.invitationsPending,
    );
  }

  @override
  String toString() {
    return 'Referee{id: $id, firstName: $firstName, lastName: $lastName, email: $email, licenseType: $licenseType, invitationsPending: $invitationsPending}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Referee && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // Available license types
  static const List<String> licenseTypes = [
    'EHF Kader',
    'DHB Elite Kader', 
    'DHB Stamm Kader',
    'Perspektiv Kader',
    'Basis-Lizenz',
  ];
}

class RefereeGespann {
  final String id;
  final String referee1Id;
  final String referee2Id;
  final String name; // Optional name for the pair
  final DateTime createdAt;

  RefereeGespann({
    required this.id,
    required this.referee1Id,
    required this.referee2Id,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'referee1Id': referee1Id,
      'referee2Id': referee2Id,
      'name': name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory RefereeGespann.fromMap(Map<String, dynamic> map, String id) {
    return RefereeGespann(
      id: id,
      referee1Id: map['referee1Id'] ?? '',
      referee2Id: map['referee2Id'] ?? '',
      name: map['name'] ?? '',
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory RefereeGespann.fromJson(Map<String, dynamic> json, String id) => RefereeGespann.fromMap(json, id);
} 