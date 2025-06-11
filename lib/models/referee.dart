class Referee {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String licenseType;
  final DateTime createdAt;
  final DateTime updatedAt;

  Referee({
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

  factory Referee.fromJson(Map<String, dynamic> json) {
    return Referee(
      id: json['id'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      email: json['email'],
      licenseType: json['licenseType'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
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
  }) {
    return Referee(
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
    return 'Referee{id: $id, firstName: $firstName, lastName: $lastName, email: $email, licenseType: $licenseType}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Referee && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // Static list of available license types
  static const List<String> licenseTypes = [
    'Basis-Lizenz',
    'Perspektivkader',
    'DHB Stamm+Anschlusskader',
    'DHB Elitekader',
    'EBT Referee',
  ];
} 