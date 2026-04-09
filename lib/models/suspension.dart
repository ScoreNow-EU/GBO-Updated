import 'package:cloud_firestore/cloud_firestore.dart';

enum SuspensionType {
  tournament,  // Single tournament ban (e.g., blue card)
  season,      // Entire season ban
  custom,      // Custom duration set by teamRHD
}

class Suspension {
  final String id;
  final String playerId;
  final String playerName;
  final String teamId;
  final String teamName;
  final SuspensionType type;
  final String reason;
  final String issuedByUserId;
  final String issuedByName;
  final DateTime issuedAt;
  final String? tournamentId;   // For tournament-scope suspensions
  final String? seasonId;       // For season-scope suspensions
  final DateTime? expiresAt;    // For custom-duration suspensions
  final int? gamesRemaining;    // Number of games remaining in suspension
  final bool isActive;
  final String? sourceGameId;   // Game where the infraction occurred
  final String? notes;

  Suspension({
    required this.id,
    required this.playerId,
    required this.playerName,
    required this.teamId,
    required this.teamName,
    required this.type,
    required this.reason,
    required this.issuedByUserId,
    required this.issuedByName,
    required this.issuedAt,
    this.tournamentId,
    this.seasonId,
    this.expiresAt,
    this.gamesRemaining,
    this.isActive = true,
    this.sourceGameId,
    this.notes,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'playerId': playerId,
      'playerName': playerName,
      'teamId': teamId,
      'teamName': teamName,
      'type': type.name,
      'reason': reason,
      'issuedByUserId': issuedByUserId,
      'issuedByName': issuedByName,
      'issuedAt': Timestamp.fromDate(issuedAt),
      'tournamentId': tournamentId,
      'seasonId': seasonId,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'gamesRemaining': gamesRemaining,
      'isActive': isActive,
      'sourceGameId': sourceGameId,
      'notes': notes,
    };
  }

  static Suspension fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Suspension(
      id: doc.id,
      playerId: data['playerId'] ?? '',
      playerName: data['playerName'] ?? '',
      teamId: data['teamId'] ?? '',
      teamName: data['teamName'] ?? '',
      type: SuspensionType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => SuspensionType.tournament,
      ),
      reason: data['reason'] ?? '',
      issuedByUserId: data['issuedByUserId'] ?? '',
      issuedByName: data['issuedByName'] ?? '',
      issuedAt: data['issuedAt'] != null
          ? (data['issuedAt'] as Timestamp).toDate()
          : DateTime.now(),
      tournamentId: data['tournamentId'],
      seasonId: data['seasonId'],
      expiresAt: data['expiresAt'] != null
          ? (data['expiresAt'] as Timestamp).toDate()
          : null,
      gamesRemaining: data['gamesRemaining'],
      isActive: data['isActive'] ?? true,
      sourceGameId: data['sourceGameId'],
      notes: data['notes'],
    );
  }

  Suspension copyWith({
    bool? isActive,
    int? gamesRemaining,
    String? notes,
    DateTime? expiresAt,
  }) {
    return Suspension(
      id: id,
      playerId: playerId,
      playerName: playerName,
      teamId: teamId,
      teamName: teamName,
      type: type,
      reason: reason,
      issuedByUserId: issuedByUserId,
      issuedByName: issuedByName,
      issuedAt: issuedAt,
      tournamentId: tournamentId,
      seasonId: seasonId,
      expiresAt: expiresAt ?? this.expiresAt,
      gamesRemaining: gamesRemaining ?? this.gamesRemaining,
      isActive: isActive ?? this.isActive,
      sourceGameId: sourceGameId,
      notes: notes ?? this.notes,
    );
  }
}
