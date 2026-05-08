import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

// ---------------------------------------------------------------------------
// Mangel (deficiency entry within a minor category)
// ---------------------------------------------------------------------------
class Mangel {
  final String id;
  final String description;
  final List<String> causes;

  Mangel({
    required this.id,
    required this.description,
    required this.causes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'description': description,
        'causes': causes,
      };

  factory Mangel.fromMap(Map<String, dynamic> data) => Mangel(
        id: data['id'] as String,
        description: data['description'] as String,
        causes: List<String>.from(data['causes'] ?? []),
      );

  Mangel copyWith({String? id, String? description, List<String>? causes}) =>
      Mangel(
        id: id ?? this.id,
        description: description ?? this.description,
        causes: causes ?? this.causes,
      );
}

// ---------------------------------------------------------------------------
// MinorCategory — has its own bestScore / worstScore range
// ---------------------------------------------------------------------------
class MinorCategory {
  final String id;
  final String name;
  final int bestScore;
  final int worstScore;
  final List<Mangel> mangel;

  MinorCategory({
    required this.id,
    required this.name,
    required this.bestScore,
    required this.worstScore,
    required this.mangel,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'bestScore': bestScore,
        'worstScore': worstScore,
        'mangel': mangel.map((m) => m.toMap()).toList(),
      };

  factory MinorCategory.fromMap(Map<String, dynamic> data) => MinorCategory(
        id: data['id'] as String,
        name: data['name'] as String,
        bestScore: (data['bestScore'] as num).toInt(),
        worstScore: (data['worstScore'] as num).toInt(),
        mangel: (data['mangel'] as List<dynamic>? ?? [])
            .map((m) => Mangel.fromMap(Map<String, dynamic>.from(m)))
            .toList(),
      );

  MinorCategory copyWith({
    String? id,
    String? name,
    int? bestScore,
    int? worstScore,
    List<Mangel>? mangel,
  }) =>
      MinorCategory(
        id: id ?? this.id,
        name: name ?? this.name,
        bestScore: bestScore ?? this.bestScore,
        worstScore: worstScore ?? this.worstScore,
        mangel: mangel ?? this.mangel,
      );

  int get minScore => min(bestScore, worstScore);
  int get maxScore => max(bestScore, worstScore);
}

// ---------------------------------------------------------------------------
// MajorCategory
// ---------------------------------------------------------------------------
class MajorCategory {
  final String id;
  final String name;
  final List<MinorCategory> minorCategories;

  MajorCategory({
    required this.id,
    required this.name,
    required this.minorCategories,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'minorCategories': minorCategories.map((m) => m.toMap()).toList(),
      };

  factory MajorCategory.fromMap(Map<String, dynamic> data) => MajorCategory(
        id: data['id'] as String,
        name: data['name'] as String,
        minorCategories:
            (data['minorCategories'] as List<dynamic>? ?? [])
                .map((m) => MinorCategory.fromMap(Map<String, dynamic>.from(m)))
                .toList(),
      );

  MajorCategory copyWith({
    String? id,
    String? name,
    List<MinorCategory>? minorCategories,
  }) =>
      MajorCategory(
        id: id ?? this.id,
        name: name ?? this.name,
        minorCategories: minorCategories ?? this.minorCategories,
      );
}

// ---------------------------------------------------------------------------
// ObservationTemplate
// calculationMethod: 'average' | 'sum'
// type: 'delegate' | 'team'
// ---------------------------------------------------------------------------
class ObservationTemplate {
  final String id;
  final String type; // 'delegate' | 'team'
  final String name;
  final String calculationMethod; // 'average' | 'sum'
  final List<MajorCategory> majorCategories;
  final DateTime createdAt;
  final DateTime updatedAt;

  ObservationTemplate({
    required this.id,
    required this.type,
    required this.name,
    required this.calculationMethod,
    required this.majorCategories,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'type': type,
        'name': name,
        'calculationMethod': calculationMethod,
        'majorCategories': majorCategories.map((m) => m.toMap()).toList(),
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory ObservationTemplate.fromMap(Map<String, dynamic> data, String id) =>
      ObservationTemplate(
        id: id,
        type: data['type'] as String,
        name: data['name'] as String,
        calculationMethod: data['calculationMethod'] as String? ?? 'average',
        majorCategories:
            (data['majorCategories'] as List<dynamic>? ?? [])
                .map((m) => MajorCategory.fromMap(Map<String, dynamic>.from(m)))
                .toList(),
        createdAt: (data['createdAt'] as Timestamp).toDate(),
        updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      );

  ObservationTemplate copyWith({
    String? id,
    String? type,
    String? name,
    String? calculationMethod,
    List<MajorCategory>? majorCategories,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      ObservationTemplate(
        id: id ?? this.id,
        type: type ?? this.type,
        name: name ?? this.name,
        calculationMethod: calculationMethod ?? this.calculationMethod,
        majorCategories: majorCategories ?? this.majorCategories,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// All minor categories across all major categories
  List<MinorCategory> get allMinorCategories =>
      majorCategories.expand((m) => m.minorCategories).toList();
}
