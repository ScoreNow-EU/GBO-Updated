class GameEvent {
  final String id;
  final String gameId;
  final String? playerId;
  final String playerName;
  final String teamId;
  final String teamName;
  final GameEventType eventType;
  final DateTime timestamp;
  final int gameMinute;
  final int? setNumber;
  final String? notes;

  GameEvent({
    required this.id,
    required this.gameId,
    this.playerId,
    required this.playerName,
    required this.teamId,
    required this.teamName,
    required this.eventType,
    required this.timestamp,
    required this.gameMinute,
    this.setNumber,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gameId': gameId,
      'playerId': playerId,
      'playerName': playerName,
      'teamId': teamId,
      'teamName': teamName,
      'eventType': eventType.toString(),
      'timestamp': timestamp.toIso8601String(),
      'gameMinute': gameMinute,
      'setNumber': setNumber,
      'notes': notes,
    };
  }

  factory GameEvent.fromJson(Map<String, dynamic> json) {
    return GameEvent(
      id: json['id'],
      gameId: json['gameId'],
      playerId: json['playerId'],
      playerName: json['playerName'],
      teamId: json['teamId'],
      teamName: json['teamName'],
      eventType: GameEventType.values.firstWhere((e) => e.toString() == json['eventType']),
      timestamp: DateTime.parse(json['timestamp']),
      gameMinute: json['gameMinute'],
      setNumber: json['setNumber'],
      notes: json['notes'],
    );
  }

  String get displayName {
    switch (eventType) {
      case GameEventType.onePoint:
        return '1 Punkt';
      case GameEventType.twoPoints:
        return '2 Punkte';
      case GameEventType.suspension:
        return 'Hinausstellung';
      case GameEventType.redCard:
        return 'Rote Karte';
      case GameEventType.timeout:
        return 'Auszeit';
      case GameEventType.substitution:
        return 'Wechsel';
      case GameEventType.sixMeterHit:
        return '6m Treffer';
      case GameEventType.sixMeterMiss:
        return '6m Verfehlt';
    }
  }

  int get points {
    switch (eventType) {
      case GameEventType.onePoint:
        return 1;
      case GameEventType.twoPoints:
        return 2;
      case GameEventType.sixMeterHit:
        return 2; // 6m goals always give 2 points in beach handball
      default:
        return 0;
    }
  }
}

enum GameEventType {
  onePoint,
  twoPoints,
  suspension,
  redCard,
  timeout,
  substitution,
  sixMeterHit,
  sixMeterMiss,
}

class GameState {
  final String gameId;
  final int currentSet;
  final int teamASetWins;
  final int teamBSetWins;
  final List<SetScore> setScores;
  final GameTime gameTime;
  final bool isRunning;
  final List<GameEvent> events;

  GameState({
    required this.gameId,
    this.currentSet = 1,
    this.teamASetWins = 0,
    this.teamBSetWins = 0,
    this.setScores = const [],
    required this.gameTime,
    this.isRunning = false,
    this.events = const [],
  });

  int getTeamScore(String teamId, int setNumber) {
    final set = setScores.where((s) => s.setNumber == setNumber).firstOrNull;
    if (set == null) return 0;
    
    return teamId == set.teamAId ? set.teamAScore : set.teamBScore;
  }

  int getCurrentSetScore(String teamId) {
    return events
        .where((e) => e.teamId == teamId && e.setNumber == currentSet)
        .fold(0, (total, event) => total + event.points);
  }

  GameState copyWith({
    int? currentSet,
    int? teamASetWins,
    int? teamBSetWins,
    List<SetScore>? setScores,
    GameTime? gameTime,
    bool? isRunning,
    List<GameEvent>? events,
  }) {
    return GameState(
      gameId: gameId,
      currentSet: currentSet ?? this.currentSet,
      teamASetWins: teamASetWins ?? this.teamASetWins,
      teamBSetWins: teamBSetWins ?? this.teamBSetWins,
      setScores: setScores ?? this.setScores,
      gameTime: gameTime ?? this.gameTime,
      isRunning: isRunning ?? this.isRunning,
      events: events ?? this.events,
    );
  }
}

class SetScore {
  final int setNumber;
  final String teamAId;
  final String teamBId;
  final int teamAScore;
  final int teamBScore;
  final bool isCompleted;

  SetScore({
    required this.setNumber,
    required this.teamAId,
    required this.teamBId,
    required this.teamAScore,
    required this.teamBScore,
    this.isCompleted = false,
  });

  SetScore copyWith({
    int? teamAScore,
    int? teamBScore,
    bool? isCompleted,
  }) {
    return SetScore(
      setNumber: setNumber,
      teamAId: teamAId,
      teamBId: teamBId,
      teamAScore: teamAScore ?? this.teamAScore,
      teamBScore: teamBScore ?? this.teamBScore,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class GameTime {
  final int minutes;
  final int seconds;
  final int currentPeriod; // 1 or 2 (for 2x 10 minute periods)

  GameTime({
    this.minutes = 0,
    this.seconds = 0,
    this.currentPeriod = 1,
  });

  String get displayTime {
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get periodDisplay {
    return '$currentPeriod. Halbzeit ($displayTime/10:00)';
  }

  bool get isHalfTime => minutes >= 10 && currentPeriod == 1;
  bool get isFullTime => minutes >= 10 && currentPeriod == 2;

  GameTime copyWith({
    int? minutes,
    int? seconds,
    int? currentPeriod,
  }) {
    return GameTime(
      minutes: minutes ?? this.minutes,
      seconds: seconds ?? this.seconds,
      currentPeriod: currentPeriod ?? this.currentPeriod,
    );
  }

  GameTime addSecond() {
    int newSeconds = seconds + 1;
    int newMinutes = minutes;
    
    if (newSeconds >= 60) {
      newSeconds = 0;
      newMinutes += 1;
    }
    
    return GameTime(
      minutes: newMinutes,
      seconds: newSeconds,
      currentPeriod: currentPeriod,
    );
  }
} 