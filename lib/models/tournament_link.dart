import 'package:flutter/material.dart';

class TournamentLink {
  final String id;
  final String label; // e.g., "Facebook", "Ausschreibung", "Instagram"
  final String url; // Link URL
  final String iconName; // Icon name from Flutter Icons (e.g., "facebook", "language")
  final int colorValue; // Color as integer (e.g., Colors.blue.value)
  final String type; // 'agb' for Ausschreibungen/AGBs, 'social' for social media
  final int sortOrder; // For sorting

  TournamentLink({
    required this.id,
    required this.label,
    required this.url,
    required this.iconName,
    required this.colorValue,
    required this.type,
    this.sortOrder = 0,
  });

  // Copy with method for immutability
  TournamentLink copyWith({
    String? id,
    String? label,
    String? url,
    String? iconName,
    int? colorValue,
    String? type,
    int? sortOrder,
  }) {
    return TournamentLink(
      id: id ?? this.id,
      label: label ?? this.label,
      url: url ?? this.url,
      iconName: iconName ?? this.iconName,
      colorValue: colorValue ?? this.colorValue,
      type: type ?? this.type,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'label': label,
      'url': url,
      'iconName': iconName,
      'colorValue': colorValue,
      'type': type,
      'sortOrder': sortOrder,
    };
  }

  // Create from Firestore document
  factory TournamentLink.fromFirestore(Map<String, dynamic> data) {
    return TournamentLink(
      id: data['id'] ?? '',
      label: data['label'] ?? '',
      url: data['url'] ?? '',
      iconName: data['iconName'] ?? 'language',
      colorValue: (data['colorValue'] as int?) ?? Colors.blue.value,
      type: data['type'] ?? 'social',
      sortOrder: data['sortOrder'] ?? 0,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() => toFirestore();

  // Create from JSON
  factory TournamentLink.fromJson(Map<String, dynamic> json) {
    return TournamentLink.fromFirestore(json);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TournamentLink &&
        other.id == id &&
        other.label == label &&
        other.url == url &&
        other.iconName == iconName &&
        other.colorValue == colorValue &&
        other.type == type &&
        other.sortOrder == sortOrder;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        label.hashCode ^
        url.hashCode ^
        iconName.hashCode ^
        colorValue.hashCode ^
        type.hashCode ^
        sortOrder.hashCode;
  }
}
