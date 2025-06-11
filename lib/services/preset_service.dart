import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tournament.dart';

class BracketPreset {
  final String id;
  final String name;
  final String description;
  final String division;
  final List<CustomBracketNode> nodes;
  final Map<String, List<String>> poolTeams;
  final DateTime createdAt;

  BracketPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.division,
    required this.nodes,
    required this.poolTeams,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'division': division,
      'nodes': nodes.map((node) => node.toJson()).toList(),
      'poolTeams': poolTeams,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory BracketPreset.fromJson(Map<String, dynamic> json) {
    return BracketPreset(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      division: json['division'],
      nodes: (json['nodes'] as List)
          .map((nodeJson) => CustomBracketNode.fromJson(nodeJson))
          .toList(),
      poolTeams: Map<String, List<String>>.from(
        json['poolTeams'].map(
          (key, value) => MapEntry(key, List<String>.from(value)),
        ),
      ),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class PresetService {
  static const String _presetsKey = 'bracket_presets';

  Future<List<BracketPreset>> getPresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final presetsJson = prefs.getString(_presetsKey);
      
      if (presetsJson == null) {
        return [];
      }
      
      final List<dynamic> presetsList = json.decode(presetsJson);
      return presetsList
          .map((presetJson) => BracketPreset.fromJson(presetJson))
          .toList();
    } catch (e) {
      print('Error loading presets: $e');
      return [];
    }
  }

  Future<List<BracketPreset>> getPresetsForDivision(String division) async {
    final allPresets = await getPresets();
    return allPresets.where((preset) => preset.division == division).toList();
  }

  Future<void> savePreset(BracketPreset preset) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final presets = await getPresets();
      
      // Remove existing preset with same ID if it exists
      presets.removeWhere((p) => p.id == preset.id);
      
      // Add the new/updated preset
      presets.add(preset);
      
      // Save back to preferences
      final presetsJson = json.encode(presets.map((p) => p.toJson()).toList());
      await prefs.setString(_presetsKey, presetsJson);
    } catch (e) {
      print('Error saving preset: $e');
      throw Exception('Failed to save preset');
    }
  }

  Future<void> deletePreset(String presetId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final presets = await getPresets();
      
      presets.removeWhere((p) => p.id == presetId);
      
      final presetsJson = json.encode(presets.map((p) => p.toJson()).toList());
      await prefs.setString(_presetsKey, presetsJson);
    } catch (e) {
      print('Error deleting preset: $e');
      throw Exception('Failed to delete preset');
    }
  }

  Future<BracketPreset?> getPreset(String presetId) async {
    final presets = await getPresets();
    try {
      return presets.firstWhere((p) => p.id == presetId);
    } catch (e) {
      return null;
    }
  }
} 