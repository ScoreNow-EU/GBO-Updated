import 'package:cloud_firestore/cloud_firestore.dart';

/// A Kampfgericht member: someone who can serve as Zeitnehmer (Timekeeper) or
/// Sekretär (Scorekeeper) at tournaments.
///
/// Note: All referees can also serve as Kampfgericht, but not vice versa.
/// This model is for people who are ONLY Kampfgericht (not referees).
class KampfgerichtMember {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Address fields
  final String? street;
  final String? houseNumber;
  final String? plz;
  final String? city;
  final double? latitude;
  final double? longitude;

  KampfgerichtMember({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.createdAt,
    required this.updatedAt,
    this.street,
    this.houseNumber,
    this.plz,
    this.city,
    this.latitude,
    this.longitude,
  });

  String get fullName => '$firstName $lastName';

  /// Full formatted address string, or null if no address data
  String? get fullAddress {
    final parts = <String>[];
    if (street != null && street!.isNotEmpty) {
      parts.add(houseNumber != null && houseNumber!.isNotEmpty
          ? '$street $houseNumber'
          : street!);
    }
    if (plz != null && plz!.isNotEmpty || city != null && city!.isNotEmpty) {
      parts.add('${plz ?? ''} ${city ?? ''}'.trim());
    }
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// Whether this member has valid coordinates for distance calculation
  bool get hasCoordinates => latitude != null && longitude != null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'street': street,
      'houseNumber': houseNumber,
      'plz': plz,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory KampfgerichtMember.fromJson(Map<String, dynamic> json) {
    return KampfgerichtMember(
      id: json['id'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      email: json['email'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      street: json['street'],
      houseNumber: json['houseNumber'],
      plz: json['plz'],
      city: json['city'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
    );
  }

  // Firebase Firestore methods
  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'street': street,
      'houseNumber': houseNumber,
      'plz': plz,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory KampfgerichtMember.fromMap(Map<String, dynamic> map, String documentId) {
    return KampfgerichtMember(
      id: documentId,
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      email: map['email'] ?? '',
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: map['updatedAt']?.toDate() ?? DateTime.now(),
      street: map['street'],
      houseNumber: map['houseNumber'],
      plz: map['plz'],
      city: map['city'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
    );
  }

  KampfgerichtMember copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? street,
    String? houseNumber,
    String? plz,
    String? city,
    double? latitude,
    double? longitude,
  }) {
    return KampfgerichtMember(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      street: street ?? this.street,
      houseNumber: houseNumber ?? this.houseNumber,
      plz: plz ?? this.plz,
      city: city ?? this.city,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  @override
  String toString() {
    return 'KampfgerichtMember{id: $id, firstName: $firstName, lastName: $lastName, email: $email, city: $city}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KampfgerichtMember && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
