import 'dart:convert';

class RecentAccount {
  final String email;
  final String firstName;
  final String lastName;
  final String id;
  final List<String> roles;
  final DateTime lastLoginAt;
  final String? avatarUrl;
  final String? encryptedPassword; // Store encrypted password

  RecentAccount({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.id,
    required this.roles,
    required this.lastLoginAt,
    this.avatarUrl,
    this.encryptedPassword,
  });

  String get fullName => '$firstName $lastName';

  String get displayRole {
    if (roles.isEmpty) return 'Benutzer';
    
    // Map role names to German display names
    final roleMap = {
      'admin': 'Administrator',
      'teamManager': 'Team Manager',
      'referee': 'Schiedsrichter',
      'delegate': 'Delegat',
      'scoringTablet': 'Punktetablet',
      'seriesOrganizer': 'Serienorganisator',
      'spieler': 'Spieler',
      'tournamentOrganizer': 'Turnierorganisator',
    };
    
    // Return the first role's display name
    return roleMap[roles.first] ?? roles.first;
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'id': id,
      'roles': roles,
      'lastLoginAt': lastLoginAt.toIso8601String(),
      'avatarUrl': avatarUrl,
      'encryptedPassword': encryptedPassword,
    };
  }

  static RecentAccount fromJson(Map<String, dynamic> json) {
    return RecentAccount(
      email: json['email'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      id: json['id'] ?? '',
      roles: List<String>.from(json['roles'] ?? []),
      lastLoginAt: DateTime.parse(json['lastLoginAt']),
      avatarUrl: json['avatarUrl'],
      encryptedPassword: json['encryptedPassword'],
    );
  }

  @override
  String toString() {
    return 'RecentAccount(email: $email, fullName: $fullName, roles: $roles)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecentAccount && other.email == email;
  }

  @override
  int get hashCode => email.hashCode;
}
