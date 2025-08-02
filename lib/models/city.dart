import 'package:cloud_firestore/cloud_firestore.dart';

class City {
  final String id;
  final String name;
  final String state;
  final String country;
  final DateTime createdAt;
  final DateTime updatedAt;

  const City({
    required this.id,
    required this.name,
    required this.state,
    required this.country,
    required this.createdAt,
    required this.updatedAt,
  });

  String get stateAbbreviation {
    const stateAbbreviations = {
      'Baden-Württemberg': 'BW',
      'Bayern': 'BAY',
      'Berlin': 'BER',
      'Brandenburg': 'BRA',
      'Bremen': 'BRE',
      'Hamburg': 'HAM',
      'Hessen': 'HES',
      'Mecklenburg-Vorpommern': 'MVP',
      'Niedersachsen': 'NDS',
      'Nordrhein-Westfalen': 'NRW',
      'Rheinland-Pfalz': 'RLP',
      'Saarland': 'SAA',
      'Sachsen': 'SAC',
      'Sachsen-Anhalt': 'SAH',
      'Schleswig-Holstein': 'SHL',
      'Thüringen': 'THU',
      // International "states" (countries)
      'Dänemark': 'DK',
      'Norwegen': 'NO',
      'Niederlande': 'NL',
      'Serbien': 'SRB',
      'Frankreich': 'FRA',
    };
    return stateAbbreviations[state] ?? state.substring(0, 3).toUpperCase();
  }

  String get displayName => '$name ($stateAbbreviation)';

  @override
  String toString() => displayName;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'state': state,
      'country': country,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory City.fromMap(Map<String, dynamic> map, String id) {
    return City(
      id: id,
      name: map['name'] ?? '',
      state: map['state'] ?? '',
      country: map['country'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory City.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data is null');
    }
    return City.fromMap(data, doc.id);
  }

  City copyWith({
    String? id,
    String? name,
    String? state,
    String? country,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return City(
      id: id ?? this.id,
      name: name ?? this.name,
      state: state ?? this.state,
      country: country ?? this.country,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is City &&
        other.id == id &&
        other.name == name &&
        other.state == state &&
        other.country == country;
  }

  @override
  int get hashCode {
    return id.hashCode ^ name.hashCode ^ state.hashCode ^ country.hashCode;
  }
}