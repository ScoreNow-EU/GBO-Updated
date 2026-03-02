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
  final int? half; // 1 or 2 (for 2x15 minute halves)
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
    this.half,
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
      'half': half,
      'notes': notes,
    };
  }

  factory GameEvent.fromJson(Map<String, dynamic> json) {
    // Parse eventType: handle both "GameEventType.goal" and "goal" formats
    final rawType = json['eventType'] as String? ?? '';
    final eventType = GameEventType.values.firstWhere(
      (e) => e.toString() == rawType || e.name == rawType,
      orElse: () => GameEventType.goal,
    );

    // Parse timestamp: handle String (ISO 8601), Firestore Timestamp, and null
    DateTime ts;
    final rawTs = json['timestamp'];
    if (rawTs is String) {
      ts = DateTime.tryParse(rawTs) ?? DateTime.now();
    } else if (rawTs != null && rawTs.runtimeType.toString().contains('Timestamp')) {
      // Firestore Timestamp — has toDate()
      ts = (rawTs as dynamic).toDate();
    } else {
      ts = DateTime.now();
    }

    return GameEvent(
      id: json['id'] ?? '',
      gameId: json['gameId'] ?? '',
      playerId: json['playerId'],
      playerName: (json['playerName'] as String?) ?? '',
      teamId: (json['teamId'] as String?) ?? '',
      teamName: (json['teamName'] as String?) ?? '',
      eventType: eventType,
      timestamp: ts,
      gameMinute: (json['gameMinute'] as int?) ?? 0,
      half: json['half'] ?? json['setNumber'],
      notes: json['notes'],
    );
  }

  String get displayName {
    switch (eventType) {
      case GameEventType.goal:
        return 'Tor';
      case GameEventType.sevenMeterHit:
        return '7m Treffer';
      case GameEventType.sevenMeterMiss:
        return '7m Verfehlt';
      case GameEventType.yellowCard:
        return 'Gelbe Karte';
      case GameEventType.twoMinuteSuspension:
        return '2-Min Hinausstellung';
      case GameEventType.redCard:
        return 'Rote Karte';
      case GameEventType.blueCard:
        return 'Blaue Karte';
      case GameEventType.timeout:
        return 'Auszeit';
      case GameEventType.substitution:
        return 'Wechsel';
    }
  }

  int get points {
    switch (eventType) {
      case GameEventType.goal:
        return 1;
      case GameEventType.sevenMeterHit:
        return 1; // 7m goals give 1 point in indoor/wheelchair handball
      default:
        return 0;
    }
  }

  bool get isPenalty {
    return eventType == GameEventType.yellowCard ||
           eventType == GameEventType.twoMinuteSuspension ||
           eventType == GameEventType.redCard ||
           eventType == GameEventType.blueCard;
  }
}

enum GameEventType {
  goal,
  sevenMeterHit,
  sevenMeterMiss,
  yellowCard,
  twoMinuteSuspension,
  redCard,
  blueCard,
  timeout,
  substitution,
}

class GameState {
  final String gameId;
  final int currentHalf; // 1 or 2
  final int teamAScore;
  final int teamBScore;
  final GameTime gameTime;
  final bool isRunning;
  final List<GameEvent> events;

  GameState({
    required this.gameId,
    this.currentHalf = 1,
    this.teamAScore = 0,
    this.teamBScore = 0,
    required this.gameTime,
    this.isRunning = false,
    this.events = const [],
  });

  int getTeamScore(String teamId) {
    return events
        .where((e) => e.teamId == teamId)
        .fold(0, (total, event) => total + event.points);
  }

  int getTeamScoreForHalf(String teamId, int half) {
    return events
        .where((e) => e.teamId == teamId && e.half == half)
        .fold(0, (total, event) => total + event.points);
  }

  /// Count 2-minute suspensions for a player (3rd = automatic red card)
  int getPlayerSuspensionCount(String playerId) {
    return events
        .where((e) => e.playerId == playerId && e.eventType == GameEventType.twoMinuteSuspension)
        .length;
  }

  GameState copyWith({
    int? currentHalf,
    int? teamAScore,
    int? teamBScore,
    GameTime? gameTime,
    bool? isRunning,
    List<GameEvent>? events,
  }) {
    return GameState(
      gameId: gameId,
      currentHalf: currentHalf ?? this.currentHalf,
      teamAScore: teamAScore ?? this.teamAScore,
      teamBScore: teamBScore ?? this.teamBScore,
      gameTime: gameTime ?? this.gameTime,
      isRunning: isRunning ?? this.isRunning,
      events: events ?? this.events,
    );
  }
}

class GameTime {
  final int minutes;
  final int seconds;
  final int currentPeriod; // 1 or 2 (for 2x 15 minute halves)

  GameTime({
    this.minutes = 0,
    this.seconds = 0,
    this.currentPeriod = 1,
  });

  String get displayTime {
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get periodDisplay {
    return '$currentPeriod. Halbzeit ($displayTime/15:00)';
  }

  bool get isHalfTime => minutes >= 15 && currentPeriod == 1;
  bool get isFullTime => minutes >= 15 && currentPeriod == 2;

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