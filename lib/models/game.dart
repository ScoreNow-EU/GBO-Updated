class Game {
  final String id;
  final String tournamentId;
  final String? teamAId;
  final String? teamBId;
  final String teamAName; // Can be placeholder like "1st from Pool A"
  final String teamBName; // Can be placeholder like "2nd from Pool B"
  final GameType gameType;
  final String? poolId; // For pool games
  final int? bracketRound; // For elimination games (1=Round of 16, 2=Quarterfinals, etc.)
  final int? bracketPosition; // Position in bracket
  final DateTime? scheduledTime;
  final GameStatus status;
  final GameResult? result;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? courtId; // Court where the game is scheduled
  final String? refereeGespannId; // Legacy: allocated referee pair
  final String? delegateId; // Allocated delegate
  // Individual official assignments (used by AI solver)
  final String? referee1Id;
  final String? referee2Id;
  final String? timekeeperId;
  final String? scorekeeperId;

  Game({
    required this.id,
    required this.tournamentId,
    this.teamAId,
    this.teamBId,
    required this.teamAName,
    required this.teamBName,
    required this.gameType,
    this.poolId,
    this.bracketRound,
    this.bracketPosition,
    this.scheduledTime,
    required this.status,
    this.result,
    required this.createdAt,
    required this.updatedAt,
    this.courtId,
    this.refereeGespannId,
    this.delegateId,
    this.referee1Id,
    this.referee2Id,
    this.timekeeperId,
    this.scorekeeperId,
  });

  bool get isPlaceholder => teamAId == null || teamBId == null;
  bool get isComplete => result != null && result!.isComplete;
  String get displayName => '$teamAName vs $teamBName';

  Map<String, dynamic> toJson() {
    final json = {
      'id': id,
      'tournamentId': tournamentId,
      'teamAId': teamAId,
      'teamBId': teamBId,
      'teamAName': teamAName,
      'teamBName': teamBName,
      'gameType': gameType.toString(),
      'poolId': poolId,
      'bracketRound': bracketRound,
      'bracketPosition': bracketPosition,
      'scheduledTime': scheduledTime?.toIso8601String(),
      'status': status.toString(),
      'result': result?.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'courtId': courtId,
      'refereeGespannId': refereeGespannId,
      'delegateId': delegateId,
      'referee1Id': referee1Id,
      'referee2Id': referee2Id,
      'timekeeperId': timekeeperId,
      'scorekeeperId': scorekeeperId,
    };
    
    // Debug logging for scheduling data
    if (scheduledTime != null || courtId != null) {
      final shortId = id.length >= 8 ? id.substring(id.length - 8) : id;
      print('🎮 Game.toJson: Saving scheduling data for $shortId: scheduledTime=${scheduledTime?.toIso8601String()}, courtId=$courtId');
    }
    
    return json;
  }

  factory Game.fromJson(Map<String, dynamic> json) {
    final scheduledTime = json['scheduledTime'] != null ? DateTime.parse(json['scheduledTime']) : null;
    final courtId = json['courtId'];
    
    // Debug logging for scheduling data
    if (scheduledTime != null || courtId != null) {
      final gameId = json['id'] ?? 'unknown';
      print('🎮 Game.fromJson: Loading scheduling data for ${gameId.toString().substring(gameId.toString().length - 8)}: scheduledTime=${scheduledTime?.toIso8601String()}, courtId=$courtId');
    }
    
    return Game(
      id: json['id'],
      tournamentId: json['tournamentId'],
      teamAId: json['teamAId'],
      teamBId: json['teamBId'],
      teamAName: json['teamAName'],
      teamBName: json['teamBName'],
      gameType: GameType.values.firstWhere((e) => e.toString() == json['gameType']),
      poolId: json['poolId'],
      bracketRound: json['bracketRound'],
      bracketPosition: json['bracketPosition'],
      scheduledTime: scheduledTime,
      status: GameStatus.values.firstWhere((e) => e.toString() == json['status']),
      result: json['result'] != null ? GameResult.fromJson(json['result']) : null,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      courtId: courtId,
      refereeGespannId: json['refereeGespannId'],
      delegateId: json['delegateId'],
      referee1Id: json['referee1Id'],
      referee2Id: json['referee2Id'],
      timekeeperId: json['timekeeperId'],
      scorekeeperId: json['scorekeeperId'],
    );
  }

  Game copyWith({
    String? id,
    String? tournamentId,
    String? teamAId,
    String? teamBId,
    String? teamAName,
    String? teamBName,
    GameType? gameType,
    String? poolId,
    int? bracketRound,
    int? bracketPosition,
    DateTime? scheduledTime,
    GameStatus? status,
    GameResult? result,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? courtId,
    String? refereeGespannId,
    String? delegateId,
    String? referee1Id,
    String? referee2Id,
    String? timekeeperId,
    String? scorekeeperId,
  }) {
    return Game(
      id: id ?? this.id,
      tournamentId: tournamentId ?? this.tournamentId,
      teamAId: teamAId ?? this.teamAId,
      teamBId: teamBId ?? this.teamBId,
      teamAName: teamAName ?? this.teamAName,
      teamBName: teamBName ?? this.teamBName,
      gameType: gameType ?? this.gameType,
      poolId: poolId ?? this.poolId,
      bracketRound: bracketRound ?? this.bracketRound,
      bracketPosition: bracketPosition ?? this.bracketPosition,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      status: status ?? this.status,
      result: result ?? this.result,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      courtId: courtId ?? this.courtId,
      refereeGespannId: refereeGespannId ?? this.refereeGespannId,
      delegateId: delegateId ?? this.delegateId,
      referee1Id: referee1Id ?? this.referee1Id,
      referee2Id: referee2Id ?? this.referee2Id,
      timekeeperId: timekeeperId ?? this.timekeeperId,
      scorekeeperId: scorekeeperId ?? this.scorekeeperId,
    );
  }
}

class GameResult {
  final int teamAScore;
  final int teamBScore;
  final String? winnerId;
  final String winnerName;
  final int? halfTimeScoreA;
  final int? halfTimeScoreB;
  final int? overtimeScoreA;
  final int? overtimeScoreB;
  final int? penaltyScoreA;
  final int? penaltyScoreB;
  final String? specialScenario; // e.g. "Wertung gegen Heim", "Spielabbruch"
  final String? resultComment;   // free-text remark

  GameResult({
    required this.teamAScore,
    required this.teamBScore,
    this.winnerId,
    required this.winnerName,
    this.halfTimeScoreA,
    this.halfTimeScoreB,
    this.overtimeScoreA,
    this.overtimeScoreB,
    this.penaltyScoreA,
    this.penaltyScoreB,
    this.specialScenario,
    this.resultComment,
  });

  bool get isComplete => winnerId != null;
  bool get isDraw => teamAScore == teamBScore;
  String get finalScore => '$teamAScore:$teamBScore';
  String? get halfTimeScore => halfTimeScoreA != null && halfTimeScoreB != null
      ? '$halfTimeScoreA:$halfTimeScoreB'
      : null;

  Map<String, dynamic> toJson() {
    return {
      'teamAScore': teamAScore,
      'teamBScore': teamBScore,
      'winnerId': winnerId,
      'winnerName': winnerName,
      'halfTimeScoreA': halfTimeScoreA,
      'halfTimeScoreB': halfTimeScoreB,
      'overtimeScoreA': overtimeScoreA,
      'overtimeScoreB': overtimeScoreB,
      'penaltyScoreA': penaltyScoreA,
      'penaltyScoreB': penaltyScoreB,
      'specialScenario': specialScenario,
      'resultComment': resultComment,
    };
  }

  factory GameResult.fromJson(Map<String, dynamic> json) {
    return GameResult(
      teamAScore: json['teamAScore'] ?? json['teamASetWins'] ?? 0,
      teamBScore: json['teamBScore'] ?? json['teamBSetWins'] ?? 0,
      winnerId: json['winnerId'],
      winnerName: json['winnerName'] ?? '',
      halfTimeScoreA: json['halfTimeScoreA'],
      halfTimeScoreB: json['halfTimeScoreB'],
      overtimeScoreA: json['overtimeScoreA'],
      overtimeScoreB: json['overtimeScoreB'],
      penaltyScoreA: json['penaltyScoreA'],
      penaltyScoreB: json['penaltyScoreB'],
      specialScenario: json['specialScenario'],
      resultComment: json['resultComment'],
    );
  }
}

enum GameType {
  pool,
  elimination,
  friendly,
}

enum GameStatus {
  scheduled,
  inProgress,
  completed,
  cancelled,
} 