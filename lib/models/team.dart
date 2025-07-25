import 'package:cloud_firestore/cloud_firestore.dart';

class Team {
  final String id;
  final String name;
  final String? teamManager; // Made optional
  final String? logoUrl; // URL or path to logo image
  final String city;
  final String bundesland;
  final String division; // Women's, Men's, U14, U16, U18, Seniors, FUN
  final String? clubId; // Reference to parent club
  final List<String> rosterPlayerIds; // List of player IDs in the roster
  final DateTime createdAt;

  Team({
    required this.id,
    required this.name,
    this.teamManager, // Made optional
    this.logoUrl,
    required this.city,
    required this.bundesland,
    required this.division,
    this.clubId,
    this.rosterPlayerIds = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'teamManager': teamManager,
      'logoUrl': logoUrl,
      'city': city,
      'bundesland': bundesland,
      'division': division,
      'clubId': clubId,
      'rosterPlayerIds': rosterPlayerIds,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static Team fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return Team(
      id: doc.id,
      name: data['name'] ?? '',
      teamManager: data['teamManager'], // Can be null
      logoUrl: data['logoUrl'],
      city: data['city'] ?? '',
      bundesland: data['bundesland'] ?? '',
      division: data['division'] ?? 'Men\'s Seniors',
      clubId: data['clubId'],
      rosterPlayerIds: List<String>.from(data['rosterPlayerIds'] ?? []),
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }
} 