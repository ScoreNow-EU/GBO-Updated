import 'package:cloud_firestore/cloud_firestore.dart';

class Club {
  final String id;
  final String name;
  final String? logoUrl;
  final String city;
  final String bundesland;
  final String? contactEmail;
  final String? contactPhone;
  final String? website;
  final String? description;
  final List<String> teamIds; // References to teams belonging to this club
  final DateTime createdAt;
  final DateTime? updatedAt;

  Club({
    required this.id,
    required this.name,
    this.logoUrl,
    required this.city,
    required this.bundesland,
    this.contactEmail,
    this.contactPhone,
    this.website,
    this.description,
    this.teamIds = const [],
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'logoUrl': logoUrl,
      'city': city,
      'bundesland': bundesland,
      'contactEmail': contactEmail,
      'contactPhone': contactPhone,
      'website': website,
      'description': description,
      'teamIds': teamIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  static Club fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return Club(
      id: doc.id,
      name: data['name'] ?? '',
      logoUrl: data['logoUrl'],
      city: data['city'] ?? '',
      bundesland: data['bundesland'] ?? '',
      contactEmail: data['contactEmail'],
      contactPhone: data['contactPhone'],
      website: data['website'],
      description: data['description'],
      teamIds: List<String>.from(data['teamIds'] ?? []),
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  Club copyWith({
    String? id,
    String? name,
    String? logoUrl,
    String? city,
    String? bundesland,
    String? contactEmail,
    String? contactPhone,
    String? website,
    String? description,
    List<String>? teamIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Club(
      id: id ?? this.id,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      city: city ?? this.city,
      bundesland: bundesland ?? this.bundesland,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      website: website ?? this.website,
      description: description ?? this.description,
      teamIds: teamIds ?? this.teamIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 