import 'package:cloud_firestore/cloud_firestore.dart';

class GameSquad {
  final String id;
  final String gameId;
  final String teamId;
  final List<SquadPlayer> selectedPlayers; // Max 10 players
  final DateTime selectionTime;
  final String selectedByUserId; // Team manager who selected
  final String selectedByName;
  final CoachApproval? coachApproval;
  final DateTime updatedAt;

  GameSquad({
    required this.id,
    required this.gameId,
    required this.teamId,
    required this.selectedPlayers,
    required this.selectionTime,
    required this.selectedByUserId,
    required this.selectedByName,
    this.coachApproval,
    required this.updatedAt,
  });

  bool get isApproved => coachApproval != null && coachApproval!.isApproved;
  bool get isRejected => coachApproval != null && !coachApproval!.isApproved;
  bool get isPending => coachApproval == null;
  int get playerCount => selectedPlayers.length;
  bool get isValidSquad => selectedPlayers.length <= 10 && selectedPlayers.isNotEmpty;

  Map<String, dynamic> toFirestore() {
    return {
      'gameId': gameId,
      'teamId': teamId,
      'selectedPlayers': selectedPlayers.map((p) => p.toFirestore()).toList(),
      'selectionTime': Timestamp.fromDate(selectionTime),
      'selectedByUserId': selectedByUserId,
      'selectedByName': selectedByName,
      'coachApproval': coachApproval?.toFirestore(),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static GameSquad fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return GameSquad(
      id: doc.id,
      gameId: data['gameId'] ?? '',
      teamId: data['teamId'] ?? '',
      selectedPlayers: (data['selectedPlayers'] as List? ?? [])
          .map((p) => SquadPlayer.fromFirestore(p))
          .toList(),
      selectionTime: data['selectionTime'] != null 
          ? (data['selectionTime'] as Timestamp).toDate() 
          : DateTime.now(),
      selectedByUserId: data['selectedByUserId'] ?? '',
      selectedByName: data['selectedByName'] ?? '',
      coachApproval: data['coachApproval'] != null 
          ? CoachApproval.fromFirestore(data['coachApproval']) 
          : null,
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  GameSquad copyWith({
    String? gameId,
    String? teamId,
    List<SquadPlayer>? selectedPlayers,
    DateTime? selectionTime,
    String? selectedByUserId,
    String? selectedByName,
    CoachApproval? coachApproval,
    DateTime? updatedAt,
  }) {
    return GameSquad(
      id: id,
      gameId: gameId ?? this.gameId,
      teamId: teamId ?? this.teamId,
      selectedPlayers: selectedPlayers ?? this.selectedPlayers,
      selectionTime: selectionTime ?? this.selectionTime,
      selectedByUserId: selectedByUserId ?? this.selectedByUserId,
      selectedByName: selectedByName ?? this.selectedByName,
      coachApproval: coachApproval ?? this.coachApproval,
      updatedAt: updatedAt ?? this.updatedAt,  
    );
  }
}

class SquadPlayer {
  final String playerId;
  final String firstName;
  final String lastName;
  final String? jerseyNumber;
  final String? classification; // 'Gruppe A', 'Gruppe B', 'Gruppe C'
  final String? gender;
  final bool isStarter; // Starting lineup vs substitute
  final int? lineupPosition; // Position in lineup

  SquadPlayer({
    required this.playerId,
    required this.firstName,
    required this.lastName,
    this.jerseyNumber,
    this.classification,
    this.gender,
    this.isStarter = false,
    this.lineupPosition,
  });

  String get fullName => '$firstName $lastName';
  String get displayName => jerseyNumber != null 
      ? '#$jerseyNumber $fullName' 
      : fullName;

  Map<String, dynamic> toFirestore() {
    return {
      'playerId': playerId,
      'firstName': firstName,
      'lastName': lastName,
      'jerseyNumber': jerseyNumber,
      'classification': classification,
      'gender': gender,
      'isStarter': isStarter,
      'lineupPosition': lineupPosition,
    };
  }

  static SquadPlayer fromFirestore(Map<String, dynamic> data) {
    return SquadPlayer(
      playerId: data['playerId'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      jerseyNumber: data['jerseyNumber'],
      classification: data['classification'] ?? data['position'],
      gender: data['gender'],
      isStarter: data['isStarter'] ?? false,
      lineupPosition: data['lineupPosition'],
    );
  }

  SquadPlayer copyWith({
    String? playerId,
    String? firstName,
    String? lastName,
    String? jerseyNumber,
    String? classification,
    String? gender,
    bool? isStarter,
    int? lineupPosition,
  }) {
    return SquadPlayer(
      playerId: playerId ?? this.playerId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      jerseyNumber: jerseyNumber ?? this.jerseyNumber,
      classification: classification ?? this.classification,
      gender: gender ?? this.gender,
      isStarter: isStarter ?? this.isStarter,
      lineupPosition: lineupPosition ?? this.lineupPosition,
    );
  }
}

class CoachApproval {
  final bool isApproved;
  final DateTime approvalTime;
  final String approvedByUserId;
  final String approvedByName;
  final String approvalMethod; // 'biometric' or 'pin'
  final String? notes;

  CoachApproval({
    required this.isApproved,
    required this.approvalTime,
    required this.approvedByUserId,
    required this.approvedByName,
    required this.approvalMethod,
    this.notes,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'isApproved': isApproved,
      'approvalTime': Timestamp.fromDate(approvalTime),
      'approvedByUserId': approvedByUserId,
      'approvedByName': approvedByName,
      'approvalMethod': approvalMethod,
      'notes': notes,
    };
  }

  static CoachApproval fromFirestore(Map<String, dynamic> data) {
    return CoachApproval(
      isApproved: data['isApproved'] ?? false,
      approvalTime: data['approvalTime'] != null 
          ? (data['approvalTime'] as Timestamp).toDate() 
          : DateTime.now(),
      approvedByUserId: data['approvedByUserId'] ?? '',
      approvedByName: data['approvedByName'] ?? '',
      approvalMethod: data['approvalMethod'] ?? 'biometric',
      notes: data['notes'],
    );
  }
} 