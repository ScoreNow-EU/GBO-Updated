import 'package:cloud_firestore/cloud_firestore.dart';

class Referee {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String licenseType;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Address fields
  final String? street;
  final String? houseNumber;
  final String? plz;
  final String? city;
  final double? latitude;
  final double? longitude;

  Referee({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.licenseType,
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

  /// Whether this referee has valid coordinates for distance calculation
  bool get hasCoordinates => latitude != null && longitude != null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'licenseType': licenseType,
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

  factory Referee.fromJson(Map<String, dynamic> json) {
    return Referee(
      id: json['id'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      email: json['email'],
      licenseType: json['licenseType'],
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
      'licenseType': licenseType,
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

  factory Referee.fromMap(Map<String, dynamic> map, String documentId) {
    // Migrate old license types to new ones
    String licenseType = map['licenseType'] ?? 'Entwicklungskader';
    licenseType = _migrateLicenseType(licenseType);

    return Referee(
      id: documentId,
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      email: map['email'] ?? '',
      licenseType: licenseType,
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

  /// Migrate old license type values to the new system
  static String _migrateLicenseType(String license) {
    switch (license) {
      case 'Keine Lizenz':
        return 'Entwicklungskader';
      case 'RHBL-Stammkader':
        return 'Leistungskader';
      case 'EHF Young Referee':
        return 'Elitekader';
      case 'EHF Referee':
        return 'EHF Referee';
      default:
        // Already a new value or unknown — keep as-is
        return license;
    }
  }

  Referee copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? licenseType,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? street,
    String? houseNumber,
    String? plz,
    String? city,
    double? latitude,
    double? longitude,
  }) {
    return Referee(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      licenseType: licenseType ?? this.licenseType,
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
    return 'Referee{id: $id, firstName: $firstName, lastName: $lastName, email: $email, licenseType: $licenseType, city: $city}';
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
    'Entwicklungskader',
    'Leistungskader',
    'Elitekader',
    'EHF Referee',
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