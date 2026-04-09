import 'package:cloud_firestore/cloud_firestore.dart';
import 'device.dart';

enum UserRole {
  admin,
  user,
  teamManager,
  referee,
  delegate,
  scoringTablet,
  sanitater,
  seriesOrganizer,
  spieler,
  tournamentOrganizer,
  teamRHD,
}

class User {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final List<UserRole> roles;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final String? refereeId; // Link to referee document if role is referee
  final String? teamManagerId; // Link to team manager document if role is teamManager
  final String? delegateId; // Link to delegate document if role is delegate
  final Map<String, Device> devices; // Device-specific settings
  final String? defaultTournamentFilter; // Default tournament category filter
  final String? defaultSeason; // Default season filter
  final String? tournamentOrganizerId; // Link to tournament organizer document if role is tournamentOrganizer
  final double totalDonations; // Total amount donated by this user
  final DateTime? lastDonationDate; // Date of last donation

  User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.roles,
    this.isActive = true,
    required this.createdAt,
    this.lastLoginAt,
    this.refereeId,
    this.teamManagerId,
    this.delegateId,
    this.devices = const {},
    this.defaultTournamentFilter,
    this.defaultSeason,
    this.tournamentOrganizerId,
    this.totalDonations = 0.0,
    this.lastDonationDate,
  });

  String get fullName => '$firstName $lastName';

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'roles': roles.map((role) => role.name).toList(),
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'refereeId': refereeId,
      'teamManagerId': teamManagerId,
      'delegateId': delegateId,
      'devices': devices.map((key, device) => MapEntry(key, device.toFirestore())),
      'defaultTournamentFilter': defaultTournamentFilter,
      'defaultSeason': defaultSeason,
      'tournamentOrganizerId': tournamentOrganizerId,
      'totalDonations': totalDonations,
      'lastDonationDate': lastDonationDate != null ? Timestamp.fromDate(lastDonationDate!) : null,
    };
  }

  static User fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Parse devices map
    Map<String, Device> devices = {};
    if (data['devices'] != null) {
      Map<String, dynamic> devicesData = data['devices'] as Map<String, dynamic>;
      devices = devicesData.map((key, value) => 
        MapEntry(key, Device.fromFirestore(value as Map<String, dynamic>))
      );
    }
    
    // Parse roles - support both old single role format and new multiple roles format
    List<UserRole> roles = [];
    if (data['roles'] != null) {
      // New format - multiple roles
      List<String> roleNames = List<String>.from(data['roles']);
      roles = roleNames.map((roleName) => 
        UserRole.values.firstWhere(
          (role) => role.name == roleName,
          orElse: () => UserRole.teamManager,
        )
      ).toList();
    } else if (data['role'] != null) {
      // Old format - single role, convert to list
      UserRole singleRole = UserRole.values.firstWhere(
        (role) => role.name == data['role'],
        orElse: () => UserRole.teamManager,
      );
      roles = [singleRole];
    } else {
      // Default role if none specified
      roles = [UserRole.teamManager];
    }

    return User(
      id: doc.id,
      email: data['email'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      roles: roles,
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      lastLoginAt: data['lastLoginAt'] != null 
          ? (data['lastLoginAt'] as Timestamp).toDate() 
          : null,
      refereeId: data['refereeId'],
      teamManagerId: data['teamManagerId'],
      delegateId: data['delegateId'],
      devices: devices,
      defaultTournamentFilter: data['defaultTournamentFilter'],
      defaultSeason: data['defaultSeason'],
      tournamentOrganizerId: data['tournamentOrganizerId'],
      totalDonations: (data['totalDonations'] ?? 0.0).toDouble(),
      lastDonationDate: data['lastDonationDate'] != null 
          ? (data['lastDonationDate'] as Timestamp).toDate() 
          : null,
    );
  }

  User copyWith({
    String? email,
    String? firstName,
    String? lastName,
    List<UserRole>? roles,
    bool? isActive,
    DateTime? lastLoginAt,
    String? refereeId,
    String? teamManagerId,
    String? delegateId,
    Map<String, Device>? devices,
    String? defaultTournamentFilter,
    String? defaultSeason,
    String? tournamentOrganizerId,
  }) {
    return User(
      id: id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      roles: roles ?? this.roles,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      refereeId: refereeId ?? this.refereeId,
      teamManagerId: teamManagerId ?? this.teamManagerId,
      delegateId: delegateId ?? this.delegateId,
      devices: devices ?? this.devices,
      defaultTournamentFilter: defaultTournamentFilter ?? this.defaultTournamentFilter,
      defaultSeason: defaultSeason ?? this.defaultSeason,
      tournamentOrganizerId: tournamentOrganizerId ?? this.tournamentOrganizerId,
    );
  }
} 