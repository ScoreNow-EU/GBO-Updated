/// A simplified court — just a label for scheduling (e.g. "Feld 1", "Feld 2").
/// Venue address and coordinates live on the Tournament itself.
class Court {
  final String id;
  final String name;

  Court({
    required this.id,
    required this.name,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  // Create from Map — handles legacy fields gracefully
  factory Court.fromMap(Map<String, dynamic> map) {
    return Court(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
    );
  }

  // Copy with new values
  Court copyWith({
    String? id,
    String? name,
  }) {
    return Court(
      id: id ?? this.id,
      name: name ?? this.name,
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
    return 'Court(id: $id, name: $name)';
  }
}