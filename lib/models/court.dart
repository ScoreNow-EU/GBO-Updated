class Court {
  final String id;
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final String type; // 'indoor', 'outdoor', 'grass', 'sand', etc.
  final int maxCapacity; // max spectators/players
  final List<String> amenities; // ['lights', 'scoreboard', 'parking', etc.]
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Court({
    required this.id,
    required this.name,
    this.description = '',
    required this.latitude,
    required this.longitude,
    this.type = 'outdoor',
    this.maxCapacity = 0,
    this.amenities = const [],
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'type': type,
      'maxCapacity': maxCapacity,
      'amenities': amenities,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // Create from Map
  factory Court.fromMap(Map<String, dynamic> map) {
    return Court(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      type: map['type'] ?? 'outdoor',
      maxCapacity: (map['maxCapacity'] ?? 0).toInt(),
      amenities: List<String>.from(map['amenities'] ?? []),
      isActive: map['isActive'] ?? true,
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
    );
  }

  // Copy with new values
  Court copyWith({
    String? id,
    String? name,
    String? description,
    double? latitude,
    double? longitude,
    String? type,
    int? maxCapacity,
    List<String>? amenities,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Court(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      type: type ?? this.type,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      amenities: amenities ?? this.amenities,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Court && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Court(id: $id, name: $name, latitude: $latitude, longitude: $longitude)';
  }
} 