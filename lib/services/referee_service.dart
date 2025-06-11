import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/referee.dart';

class RefereeService {
  static const String _refereeKey = 'referees';
  final StreamController<List<Referee>> _refereeController = StreamController<List<Referee>>.broadcast();
  List<Referee> _referees = [];

  Stream<List<Referee>> get refereeStream => _refereeController.stream;

  RefereeService() {
    _loadReferees();
  }

  Future<void> _loadReferees() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refereeJson = prefs.getStringList(_refereeKey) ?? [];
      
      _referees = refereeJson
          .map((json) => Referee.fromJson(jsonDecode(json)))
          .toList();
      
      _refereeController.add(_referees);
    } catch (e) {
      print('Error loading referees: $e');
      _referees = [];
      _refereeController.add(_referees);
    }
  }

  Future<void> _saveReferees() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refereeJson = _referees
          .map((referee) => jsonEncode(referee.toJson()))
          .toList();
      
      await prefs.setStringList(_refereeKey, refereeJson);
      _refereeController.add(_referees);
    } catch (e) {
      print('Error saving referees: $e');
      throw Exception('Fehler beim Speichern der Schiedsrichter');
    }
  }

  Stream<List<Referee>> getReferees() {
    return refereeStream;
  }

  List<Referee> getAllReferees() {
    return List.from(_referees);
  }

  Future<void> addReferee(Referee referee) async {
    // Check if email already exists
    if (_referees.any((r) => r.email.toLowerCase() == referee.email.toLowerCase())) {
      throw Exception('Ein Schiedsrichter mit dieser E-Mail-Adresse existiert bereits');
    }

    _referees.add(referee);
    await _saveReferees();
  }

  Future<void> updateReferee(Referee updatedReferee) async {
    // Check if email already exists for other referees
    if (_referees.any((r) => r.id != updatedReferee.id && 
                            r.email.toLowerCase() == updatedReferee.email.toLowerCase())) {
      throw Exception('Ein anderer Schiedsrichter mit dieser E-Mail-Adresse existiert bereits');
    }

    final index = _referees.indexWhere((r) => r.id == updatedReferee.id);
    if (index != -1) {
      _referees[index] = updatedReferee;
      await _saveReferees();
    } else {
      throw Exception('Schiedsrichter nicht gefunden');
    }
  }

  Future<void> deleteReferee(String refereeId) async {
    _referees.removeWhere((r) => r.id == refereeId);
    await _saveReferees();
  }

  Referee? getRefereeById(String id) {
    try {
      return _referees.firstWhere((r) => r.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Referee> getRefereesByLicenseType(String licenseType) {
    return _referees.where((r) => r.licenseType == licenseType).toList();
  }

  List<Referee> searchReferees(String searchTerm) {
    final term = searchTerm.toLowerCase();
    return _referees.where((r) => 
      r.firstName.toLowerCase().contains(term) ||
      r.lastName.toLowerCase().contains(term) ||
      r.email.toLowerCase().contains(term) ||
      r.licenseType.toLowerCase().contains(term)
    ).toList();
  }

  int get refereeCount => _referees.length;

  Map<String, int> getLicenseTypeDistribution() {
    final distribution = <String, int>{};
    for (final licenseType in Referee.licenseTypes) {
      distribution[licenseType] = _referees.where((r) => r.licenseType == licenseType).length;
    }
    return distribution;
  }

  void dispose() {
    _refereeController.close();
  }
} 