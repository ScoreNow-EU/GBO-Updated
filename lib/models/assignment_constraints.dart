/// Models for the AI-based game official assignment system.
///
/// The solver takes a list of games with their constraints and a list of
/// available officials (referees + Kampfgericht) with their availability
/// windows and compatibility preferences, then produces an optimal assignment
/// that maximizes break times between consecutive assignments.

/// Constraint on a specific game's official requirements.
class GameAssignmentConstraint {
  final String gameId;
  /// Minimum license level required for referees on this game.
  /// Null means no restriction. Values: 'Entwicklungskader', 'Leistungskader',
  /// 'Elitekader', 'EHF Referee' (ordered from lowest to highest).
  final String? requiredLicenseLevel;
  // Manual overrides — if set, the solver must use these exact officials
  final String? manualReferee1Id;
  final String? manualReferee2Id;
  final String? manualTimekeeperId;
  final String? manualScorekeeperId;
  /// Officials who must NOT be assigned to this game (e.g. conflict of interest)
  final List<String> excludedOfficialIds;

  GameAssignmentConstraint({
    required this.gameId,
    this.requiredLicenseLevel,
    this.manualReferee1Id,
    this.manualReferee2Id,
    this.manualTimekeeperId,
    this.manualScorekeeperId,
    this.excludedOfficialIds = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'gameId': gameId,
      'requiredLicenseLevel': requiredLicenseLevel,
      'manualReferee1Id': manualReferee1Id,
      'manualReferee2Id': manualReferee2Id,
      'manualTimekeeperId': manualTimekeeperId,
      'manualScorekeeperId': manualScorekeeperId,
      'excludedOfficialIds': excludedOfficialIds,
    };
  }

  factory GameAssignmentConstraint.fromJson(Map<String, dynamic> json) {
    return GameAssignmentConstraint(
      gameId: json['gameId'] ?? '',
      requiredLicenseLevel: json['requiredLicenseLevel'],
      manualReferee1Id: json['manualReferee1Id'],
      manualReferee2Id: json['manualReferee2Id'],
      manualTimekeeperId: json['manualTimekeeperId'],
      manualScorekeeperId: json['manualScorekeeperId'],
      excludedOfficialIds: List<String>.from(json['excludedOfficialIds'] ?? []),
    );
  }
}

/// Defines whether two officials can or cannot work together.
class RefereeCompatibility {
  final String official1Id;
  final String official2Id;
  /// true = they CAN work together (preferred pair), false = they CANNOT
  final bool canWorkTogether;

  RefereeCompatibility({
    required this.official1Id,
    required this.official2Id,
    required this.canWorkTogether,
  });

  Map<String, dynamic> toJson() {
    return {
      'official1Id': official1Id,
      'official2Id': official2Id,
      'canWorkTogether': canWorkTogether,
    };
  }

  factory RefereeCompatibility.fromJson(Map<String, dynamic> json) {
    return RefereeCompatibility(
      official1Id: json['official1Id'] ?? '',
      official2Id: json['official2Id'] ?? '',
      canWorkTogether: json['canWorkTogether'] ?? true,
    );
  }
}

/// An official (referee or Kampfgericht member) with their availability
/// and capabilities for the solver input.
class OfficialInput {
  final String id;
  /// 'referee' or 'kampfgericht'
  final String type;
  /// License level (only for referees). Null for Kampfgericht.
  final String? licenseLevel;
  /// Availability window. Null = not available.
  final DateTime? availableFrom;
  final DateTime? availableUntil;
  final bool isFullDay;

  OfficialInput({
    required this.id,
    required this.type,
    this.licenseLevel,
    this.availableFrom,
    this.availableUntil,
    this.isFullDay = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'licenseLevel': licenseLevel,
      'availableFrom': availableFrom?.toIso8601String(),
      'availableUntil': availableUntil?.toIso8601String(),
      'isFullDay': isFullDay,
    };
  }

  factory OfficialInput.fromJson(Map<String, dynamic> json) {
    return OfficialInput(
      id: json['id'] ?? '',
      type: json['type'] ?? 'referee',
      licenseLevel: json['licenseLevel'],
      availableFrom: json['availableFrom'] != null
          ? DateTime.parse(json['availableFrom'])
          : null,
      availableUntil: json['availableUntil'] != null
          ? DateTime.parse(json['availableUntil'])
          : null,
      isFullDay: json['isFullDay'] ?? true,
    );
  }
}

/// A game input for the solver.
class GameInput {
  final String id;
  final DateTime scheduledTime;
  /// Estimated game duration in minutes (used for break calculation)
  final int durationMinutes;
  final String? courtId;

  GameInput({
    required this.id,
    required this.scheduledTime,
    this.durationMinutes = 40,
    this.courtId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scheduledTime': scheduledTime.toIso8601String(),
      'durationMinutes': durationMinutes,
      'courtId': courtId,
    };
  }

  factory GameInput.fromJson(Map<String, dynamic> json) {
    return GameInput(
      id: json['id'] ?? '',
      scheduledTime: DateTime.parse(json['scheduledTime']),
      durationMinutes: json['durationMinutes'] ?? 40,
      courtId: json['courtId'],
    );
  }
}

/// The result for a single game from the solver.
class AssignmentResult {
  final String gameId;
  final String? referee1Id;
  final String? referee2Id;
  final String? timekeeperId;
  final String? scorekeeperId;

  AssignmentResult({
    required this.gameId,
    this.referee1Id,
    this.referee2Id,
    this.timekeeperId,
    this.scorekeeperId,
  });

  Map<String, dynamic> toJson() {
    return {
      'gameId': gameId,
      'referee1Id': referee1Id,
      'referee2Id': referee2Id,
      'timekeeperId': timekeeperId,
      'scorekeeperId': scorekeeperId,
    };
  }

  factory AssignmentResult.fromJson(Map<String, dynamic> json) {
    return AssignmentResult(
      gameId: json['gameId'] ?? '',
      referee1Id: json['referee1Id'],
      referee2Id: json['referee2Id'],
      timekeeperId: json['timekeeperId'],
      scorekeeperId: json['scorekeeperId'],
    );
  }
}

/// Full solver response containing all game assignments and metadata.
class SolverResponse {
  final List<AssignmentResult> assignments;
  /// Per-official break time summary: officialId → list of break durations in minutes
  final Map<String, List<int>> breakTimes;
  /// Whether the solver found a fully valid solution (no constraint violations)
  final bool isOptimal;
  /// Human-readable warnings/notes from the solver
  final List<String> warnings;

  SolverResponse({
    required this.assignments,
    this.breakTimes = const {},
    this.isOptimal = true,
    this.warnings = const [],
  });

  factory SolverResponse.fromJson(Map<String, dynamic> json) {
    return SolverResponse(
      assignments: (json['assignments'] as List?)
              ?.map((a) => AssignmentResult.fromJson(a))
              .toList() ??
          [],
      breakTimes: (json['breakTimes'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, List<int>.from(value)),
          ) ??
          {},
      isOptimal: json['isOptimal'] ?? true,
      warnings: List<String>.from(json['warnings'] ?? []),
    );
  }
}

/// License level hierarchy for comparison.
class LicenseLevels {
  static const List<String> ordered = [
    'Entwicklungskader',
    'Leistungskader',
    'Elitekader',
    'EHF Referee',
  ];

  /// Returns true if [actual] meets or exceeds the [required] level.
  static bool meetsRequirement(String actual, String required) {
    final actualIndex = ordered.indexOf(actual);
    final requiredIndex = ordered.indexOf(required);
    if (actualIndex == -1 || requiredIndex == -1) return false;
    return actualIndex >= requiredIndex;
  }
}
