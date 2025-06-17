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
  final String? refereeGespannId; // Allocated referee pair

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
    };
    
    // Debug logging for scheduling data
    if (scheduledTime != null || courtId != null) {
      print('🎮 Game.toJson: Saving scheduling data for ${id.substring(id.length - 8)}: scheduledTime=${scheduledTime?.toIso8601String()}, courtId=$courtId');
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
    );
  }
}

class GameResult {
  final int teamASetWins;
  final int teamBSetWins;
  final List<SetResult> sets;
  final ShootoutResult? shootout;
  final String? winnerId;
  final String winnerName;

  GameResult({
    required this.teamASetWins,
    required this.teamBSetWins,
    required this.sets,
    this.shootout,
    this.winnerId,
    required this.winnerName,
  });

  bool get isComplete => winnerId != null;
  bool get hasShootout => shootout != null;
  String get finalScore => '$teamASetWins:$teamBSetWins';

  Map<String, dynamic> toJson() {
    return {
      'teamASetWins': teamASetWins,
      'teamBSetWins': teamBSetWins,
      'sets': sets.map((s) => s.toJson()).toList(),
      'shootout': shootout?.toJson(),
      'winnerId': winnerId,
      'winnerName': winnerName,
    };
  }

  factory GameResult.fromJson(Map<String, dynamic> json) {
    return GameResult(
      teamASetWins: json['teamASetWins'],
      teamBSetWins: json['teamBSetWins'],
      sets: (json['sets'] as List).map((s) => SetResult.fromJson(s)).toList(),
      shootout: json['shootout'] != null ? ShootoutResult.fromJson(json['shootout']) : null,
      winnerId: json['winnerId'],
      winnerName: json['winnerName'],
    );
  }
}

class SetResult {
  final int setNumber;
  final int teamAScore;
  final int teamBScore;
  final String? winnerId;
  final String winnerName;

  SetResult({
    required this.setNumber,
    required this.teamAScore,
    required this.teamBScore,
    this.winnerId,
    required this.winnerName,
  });

  String get score => '$teamAScore:$teamBScore';

  Map<String, dynamic> toJson() {
    return {
      'setNumber': setNumber,
      'teamAScore': teamAScore,
      'teamBScore': teamBScore,
      'winnerId': winnerId,
      'winnerName': winnerName,
    };
  }

  factory SetResult.fromJson(Map<String, dynamic> json) {
    return SetResult(
      setNumber: json['setNumber'],
      teamAScore: json['teamAScore'],
      teamBScore: json['teamBScore'],
      winnerId: json['winnerId'],
      winnerName: json['winnerName'],
    );
  }
}

class ShootoutResult {
  final int teamAScore;
  final int teamBScore;
  final String? winnerId;
  final String winnerName;

  ShootoutResult({
    required this.teamAScore,
    required this.teamBScore,
    this.winnerId,
    required this.winnerName,
  });

  String get score => '$teamAScore:$teamBScore';

  Map<String, dynamic> toJson() {
    return {
      'teamAScore': teamAScore,
      'teamBScore': teamBScore,
      'winnerId': winnerId,
      'winnerName': winnerName,
    };
  }

  factory ShootoutResult.fromJson(Map<String, dynamic> json) {
    return ShootoutResult(
      teamAScore: json['teamAScore'],
      teamBScore: json['teamBScore'],
      winnerId: json['winnerId'],
      winnerName: json['winnerName'],
    );
  }
}

enum GameType {
  pool,
  elimination,
}

enum GameStatus {
  scheduled,
  inProgress,
  completed,
  cancelled,
} 