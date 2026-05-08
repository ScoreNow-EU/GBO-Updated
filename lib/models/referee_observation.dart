import 'package:cloud_firestore/cloud_firestore.dart';
import 'observation_template.dart';

// ---------------------------------------------------------------------------
// ObservationCategoryScore — filled-in data for one MinorCategory
// ---------------------------------------------------------------------------
class ObservationCategoryScore {
  final String minorCategoryId;
  final String minorCategoryName;
  final String majorCategoryName;
  final int bestScore;
  final int worstScore;
  final int? score;
  final List<String> selectedMangelIds;
  final List<String> selectedCauses;
  final String? notes;

  ObservationCategoryScore({
    required this.minorCategoryId,
    required this.minorCategoryName,
    required this.majorCategoryName,
    required this.bestScore,
    required this.worstScore,
    this.score,
    required this.selectedMangelIds,
    required this.selectedCauses,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'minorCategoryId': minorCategoryId,
        'minorCategoryName': minorCategoryName,
        'majorCategoryName': majorCategoryName,
        'bestScore': bestScore,
        'worstScore': worstScore,
        'score': score,
        'selectedMangelIds': selectedMangelIds,
        'selectedCauses': selectedCauses,
        'notes': notes,
      };

  factory ObservationCategoryScore.fromMap(Map<String, dynamic> data) =>
      ObservationCategoryScore(
        minorCategoryId: data['minorCategoryId'] as String,
        minorCategoryName: data['minorCategoryName'] as String,
        majorCategoryName: data['majorCategoryName'] as String,
        bestScore: (data['bestScore'] as num).toInt(),
        worstScore: (data['worstScore'] as num).toInt(),
        score: data['score'] != null ? (data['score'] as num).toInt() : null,
        selectedMangelIds: List<String>.from(data['selectedMangelIds'] ?? []),
        selectedCauses: List<String>.from(data['selectedCauses'] ?? []),
        notes: data['notes'] as String?,
      );

  ObservationCategoryScore copyWith({
    int? score,
    List<String>? selectedMangelIds,
    List<String>? selectedCauses,
    String? notes,
  }) =>
      ObservationCategoryScore(
        minorCategoryId: minorCategoryId,
        minorCategoryName: minorCategoryName,
        majorCategoryName: majorCategoryName,
        bestScore: bestScore,
        worstScore: worstScore,
        score: score ?? this.score,
        selectedMangelIds: selectedMangelIds ?? this.selectedMangelIds,
        selectedCauses: selectedCauses ?? this.selectedCauses,
        notes: notes ?? this.notes,
      );

  /// Factory from a MinorCategory template with empty values
  factory ObservationCategoryScore.empty(
      MinorCategory minor, String majorName) =>
      ObservationCategoryScore(
        minorCategoryId: minor.id,
        minorCategoryName: minor.name,
        majorCategoryName: majorName,
        bestScore: minor.bestScore,
        worstScore: minor.worstScore,
        selectedMangelIds: [],
        selectedCauses: [],
      );
}

// ---------------------------------------------------------------------------
// RefereeObservation
// Covers the referee *pair* of a game. refereeIds / refereeNames are both lists.
// status: 'draft' | 'submitted'
// ---------------------------------------------------------------------------
class RefereeObservation {
  final String id;
  final String templateId;
  final String templateType; // 'delegate' | 'team'
  final String gameId;
  final String tournamentId;
  final List<String> refereeIds;
  final List<String> refereeNames;
  final String submitterId;
  final String submitterName;
  final String submitterRole;
  final double overallResult;
  final String notes;
  final List<ObservationCategoryScore> categoryScores;
  final String status; // 'draft' | 'submitted'
  final DateTime createdAt;
  final DateTime updatedAt;

  RefereeObservation({
    required this.id,
    required this.templateId,
    required this.templateType,
    required this.gameId,
    required this.tournamentId,
    required this.refereeIds,
    required this.refereeNames,
    required this.submitterId,
    required this.submitterName,
    required this.submitterRole,
    required this.overallResult,
    required this.notes,
    required this.categoryScores,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'templateId': templateId,
        'templateType': templateType,
        'gameId': gameId,
        'tournamentId': tournamentId,
        'refereeIds': refereeIds,
        'refereeNames': refereeNames,
        'submitterId': submitterId,
        'submitterName': submitterName,
        'submitterRole': submitterRole,
        'overallResult': overallResult,
        'notes': notes,
        'categoryScores': categoryScores.map((s) => s.toMap()).toList(),
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory RefereeObservation.fromMap(Map<String, dynamic> data, String id) =>
      RefereeObservation(
        id: id,
        templateId: data['templateId'] as String,
        templateType: data['templateType'] as String,
        gameId: data['gameId'] as String,
        tournamentId: data['tournamentId'] as String,
        refereeIds: List<String>.from(data['refereeIds'] ?? []),
        refereeNames: List<String>.from(data['refereeNames'] ?? []),
        submitterId: data['submitterId'] as String,
        submitterName: data['submitterName'] as String,
        submitterRole: data['submitterRole'] as String,
        overallResult: (data['overallResult'] as num).toDouble(),
        notes: data['notes'] as String? ?? '',
        categoryScores: (data['categoryScores'] as List<dynamic>? ?? [])
            .map((s) =>
                ObservationCategoryScore.fromMap(Map<String, dynamic>.from(s)))
            .toList(),
        status: data['status'] as String? ?? 'draft',
        createdAt: (data['createdAt'] as Timestamp).toDate(),
        updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      );

  RefereeObservation copyWith({
    String? id,
    String? templateId,
    String? templateType,
    String? gameId,
    String? tournamentId,
    List<String>? refereeIds,
    List<String>? refereeNames,
    String? submitterId,
    String? submitterName,
    String? submitterRole,
    double? overallResult,
    String? notes,
    List<ObservationCategoryScore>? categoryScores,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      RefereeObservation(
        id: id ?? this.id,
        templateId: templateId ?? this.templateId,
        templateType: templateType ?? this.templateType,
        gameId: gameId ?? this.gameId,
        tournamentId: tournamentId ?? this.tournamentId,
        refereeIds: refereeIds ?? this.refereeIds,
        refereeNames: refereeNames ?? this.refereeNames,
        submitterId: submitterId ?? this.submitterId,
        submitterName: submitterName ?? this.submitterName,
        submitterRole: submitterRole ?? this.submitterRole,
        overallResult: overallResult ?? this.overallResult,
        notes: notes ?? this.notes,
        categoryScores: categoryScores ?? this.categoryScores,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  bool get isSubmitted => status == 'submitted';
  bool get isDraft => status == 'draft';

  String get refereesDisplay => refereeNames.join(' / ');

  /// Compute overallResult from category scores given the template's calculation method.
  static double computeOverallResult(
    List<ObservationCategoryScore> scores,
    String calculationMethod,
  ) {
    final filled = scores.where((s) => s.score != null).toList();
    if (filled.isEmpty) return 0.0;
    final total = filled.fold<int>(0, (sum, s) => sum + s.score!);
    if (calculationMethod == 'sum') return total.toDouble();
    return total / filled.length;
  }
}
