import 'package:cloud_firestore/cloud_firestore.dart';

class Venue {
  final String id;
  final String name;
  final String street;
  final String? houseNumber;
  final String plz;
  final String city;
  final double? latitude;
  final double? longitude;
  final int? capacity;
  final List<String> courtNames;      // Names/IDs of courts at this venue
  final String? contactPerson;
  final String? contactEmail;
  final String? contactPhone;
  final String? hostTeamId;           // Team that hosts at this venue
  final String? notes;
  final DateTime createdAt;

  Venue({
    required this.id,
    required this.name,
    required this.street,
    this.houseNumber,
    required this.plz,
    required this.city,
    this.latitude,
    this.longitude,
    this.capacity,
    this.courtNames = const [],
    this.contactPerson,
    this.contactEmail,
    this.contactPhone,
    this.hostTeamId,
    this.notes,
    required this.createdAt,
  });

  String get fullAddress {
    final houseNum = houseNumber != null ? ' $houseNumber' : '';
    return '$street$houseNum, $plz $city';
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'street': street,
      'houseNumber': houseNumber,
      'plz': plz,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      'capacity': capacity,
      'courtNames': courtNames,
      'contactPerson': contactPerson,
      'contactEmail': contactEmail,
      'contactPhone': contactPhone,
      'hostTeamId': hostTeamId,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static Venue fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Venue(
      id: doc.id,
      name: data['name'] ?? '',
      street: data['street'] ?? '',
      houseNumber: data['houseNumber'],
      plz: data['plz'] ?? '',
      city: data['city'] ?? '',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      capacity: data['capacity'],
      courtNames: List<String>.from(data['courtNames'] ?? []),
      contactPerson: data['contactPerson'],
      contactEmail: data['contactEmail'],
      contactPhone: data['contactPhone'],
      hostTeamId: data['hostTeamId'],
      notes: data['notes'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Venue copyWith({
    String? name,
    String? street,
    String? houseNumber,
    String? plz,
    String? city,
    double? latitude,
    double? longitude,
    int? capacity,
    List<String>? courtNames,
    String? contactPerson,
    String? contactEmail,
    String? contactPhone,
    String? hostTeamId,
    String? notes,
  }) {
    return Venue(
      id: id,
      name: name ?? this.name,
      street: street ?? this.street,
      houseNumber: houseNumber ?? this.houseNumber,
      plz: plz ?? this.plz,
      city: city ?? this.city,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      capacity: capacity ?? this.capacity,
      courtNames: courtNames ?? this.courtNames,
      contactPerson: contactPerson ?? this.contactPerson,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      hostTeamId: hostTeamId ?? this.hostTeamId,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }
}
