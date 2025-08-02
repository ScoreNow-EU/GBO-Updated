import 'package:cloud_firestore/cloud_firestore.dart';

class GermanState {
  final String id;
  final String name;
  final String abbreviation;
  final String country;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GermanState({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.country,
    required this.createdAt,
    required this.updatedAt,
  });

  String get displayName => '$name ($abbreviation)';

  @override
  String toString() => displayName;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'abbreviation': abbreviation,
      'country': country,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory GermanState.fromMap(Map<String, dynamic> map, String id) {
    return GermanState(
      id: id,
      name: map['name'] ?? '',
      abbreviation: map['abbreviation'] ?? '',
      country: map['country'] ?? 'Deutschland',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory GermanState.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data is null');
    }
    return GermanState.fromMap(data, doc.id);
  }

  GermanState copyWith({
    String? id,
    String? name,
    String? abbreviation,
    String? country,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GermanState(
      id: id ?? this.id,
      name: name ?? this.name,
      abbreviation: abbreviation ?? this.abbreviation,
      country: country ?? this.country,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GermanState &&
        other.id == id &&
        other.name == name &&
        other.abbreviation == abbreviation;
  }

  @override
  int get hashCode {
    return id.hashCode ^ name.hashCode ^ abbreviation.hashCode;
  }
}