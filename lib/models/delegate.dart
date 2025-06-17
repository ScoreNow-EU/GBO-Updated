class Delegate {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String licenseType;
  final DateTime createdAt;
  final DateTime updatedAt;

  Delegate({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.licenseType,
    required this.createdAt,
    required this.updatedAt,
  });

  String get fullName => '$firstName $lastName';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'licenseType': licenseType,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Delegate.fromJson(Map<String, dynamic> json) {
    return Delegate(
      id: json['id'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      email: json['email'],
      licenseType: json['licenseType'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
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
    };
  }

  factory Delegate.fromMap(Map<String, dynamic> map, String documentId) {
    return Delegate(
      id: documentId,
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      email: map['email'] ?? '',
      licenseType: map['licenseType'] ?? 'EHF Delegate',
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: map['updatedAt']?.toDate() ?? DateTime.now(),
    );
  }

  Delegate copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? licenseType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Delegate(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      licenseType: licenseType ?? this.licenseType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Delegate{id: $id, firstName: $firstName, lastName: $lastName, email: $email, licenseType: $licenseType}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Delegate && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // Static list of available license types for delegates
  static const List<String> licenseTypes = [
    'EHF Delegate',
    'DHB National Delegate',
  ];
} 