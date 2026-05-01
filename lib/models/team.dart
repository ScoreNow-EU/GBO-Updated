import 'package:cloud_firestore/cloud_firestore.dart';

class Team {
  final String id;
  final String name;
  final String? clubName;
  final String? teamManager;
  final String? logoUrl;
  final String city;
  final String bundesland;
  final String? coachName;
  final String? coachEmail;
  final List<String> rosterPlayerIds;
  final int totalPoints; // Sum of tournament placement points (7,6,5,4,3,2,1,0)
  final List<Map<String, dynamic>> pointsHistory; // Array of tournaments with points earned
  /// Primary brand color stored as ARGB int (e.g. `0xFF3F51B5`).
  final int? primaryColor;
  /// Secondary / accent brand color stored as ARGB int.
  final int? secondaryColor;
  final DateTime createdAt;

  Team({
    required this.id,
    required this.name,
    this.clubName,
    this.teamManager,
    this.logoUrl,
    required this.city,
    required this.bundesland,
    this.coachName,
    this.coachEmail,
    this.rosterPlayerIds = const [],
    this.totalPoints = 0,
    this.pointsHistory = const [],
    this.primaryColor,
    this.secondaryColor,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'clubName': clubName,
      'teamManager': teamManager,
      'logoUrl': logoUrl,
      'city': city,
      'bundesland': bundesland,
      'coachName': coachName,
      'coachEmail': coachEmail,
      'rosterPlayerIds': rosterPlayerIds,
      'totalPoints': totalPoints,
      'pointsHistory': pointsHistory,
      'primaryColor': primaryColor,
      'secondaryColor': secondaryColor,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static Team fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return Team(
      id: doc.id,
      name: data['name'] ?? '',
      clubName: data['clubName'],
      teamManager: data['teamManager'],
      logoUrl: data['logoUrl'],
      city: data['city'] ?? '',
      bundesland: data['bundesland'] ?? '',
      coachName: data['coachName'],
      coachEmail: data['coachEmail'],
      rosterPlayerIds: List<String>.from(data['rosterPlayerIds'] ?? []),
      totalPoints: data['totalPoints'] ?? 0,
      pointsHistory: List<Map<String, dynamic>>.from(data['pointsHistory'] ?? []),
      primaryColor: (data['primaryColor'] as num?)?.toInt(),
      secondaryColor: (data['secondaryColor'] as num?)?.toInt(),
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  Team copyWith({
    String? name,
    String? clubName,
    String? teamManager,
    String? logoUrl,
    String? city,
    String? bundesland,
    String? coachName,
    String? coachEmail,
    List<String>? rosterPlayerIds,
    int? totalPoints,
    List<Map<String, dynamic>>? pointsHistory,
    int? primaryColor,
    int? secondaryColor,
    bool clearPrimaryColor = false,
    bool clearSecondaryColor = false,
  }) {
    return Team(
      id: id,
      name: name ?? this.name,
      clubName: clubName ?? this.clubName,
      teamManager: teamManager ?? this.teamManager,
      logoUrl: logoUrl ?? this.logoUrl,
      city: city ?? this.city,
      bundesland: bundesland ?? this.bundesland,
      coachName: coachName ?? this.coachName,
      coachEmail: coachEmail ?? this.coachEmail,
      rosterPlayerIds: rosterPlayerIds ?? this.rosterPlayerIds,
      totalPoints: totalPoints ?? this.totalPoints,
      pointsHistory: pointsHistory ?? this.pointsHistory,
      primaryColor: clearPrimaryColor ? null : (primaryColor ?? this.primaryColor),
      secondaryColor:
          clearSecondaryColor ? null : (secondaryColor ?? this.secondaryColor),
      createdAt: createdAt,
    );
  }
} 