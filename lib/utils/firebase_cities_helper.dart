import '../models/city.dart';
import '../models/state.dart';
import '../services/city_service.dart';

/// Firebase-based utility for city operations that replaces GermanCities
class FirebaseCitiesHelper {
  static final CityService _cityService = CityService();
  
  /// Get all cities from Firebase (cached for performance)
  static Future<List<City>> getAllCities() async {
    return await _cityService.getAllCities();
  }
  
  /// Search cities by query string (name, state, or abbreviation)
  static Future<List<City>> searchCities(String query) async {
    return await _cityService.searchCities(query);
  }
  
  /// Find a specific city by name and state
  static Future<City?> findCity(String cityName, String stateName) async {
    return await _cityService.findCity(cityName, stateName);
  }
  
  /// Find city by display name (e.g., "Berlin (BER)")
  static Future<City?> findByDisplayName(String displayName) async {
    final cities = await getAllCities();
    final matches = cities.where(
      (city) => city.displayName == displayName,
    );
    return matches.isNotEmpty ? matches.first : null;
  }
  
  /// Find city by just the city name (first match if multiple exist)
  static Future<City?> findByName(String cityName) async {
    final cities = await getAllCities();
    final matches = cities.where(
      (city) => city.name.toLowerCase() == cityName.toLowerCase(),
    );
    return matches.isNotEmpty ? matches.first : null;
  }
  
  /// Get all unique states/bundesländer
  static Future<List<String>> getAllStates() async {
    final cities = await getAllCities();
    final states = cities.map((city) => city.state).toSet().toList();
    states.sort();
    return states;
  }
  
  /// Get all unique countries
  static Future<List<String>> getAllCountries() async {
    final cities = await getAllCities();
    final countries = cities.map((city) => city.country).toSet().toList();
    countries.sort();
    return countries;
  }
  
  /// Get cities by state
  static Future<List<City>> getCitiesByState(String stateName) async {
    return await _cityService.getCitiesByState(stateName);
  }
  
  /// Get cities by country
  static Future<List<City>> getCitiesByCountry(String countryName) async {
    final cities = await getAllCities();
    return cities.where((city) => city.country == countryName).toList();
  }
  
  /// Create a City from old GermanCity data (for migration compatibility)
  static City fromLegacyData(String name, String state) {
    final isInternational = ['Dänemark', 'Norwegen', 'Niederlande', 'Serbien', 'Frankreich'].contains(state);
    final country = isInternational ? state : 'Deutschland';
    return City(
      id: '', // Will be set by Firebase
      name: name,
      state: state,
      country: country,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
  
  /// Synchronize states collection based on all existing cities
  static Future<Map<String, dynamic>> syncStatesFromCities() async {
    try {
      final cities = await getAllCities();
      if (cities.isEmpty) {
        return {'success': false, 'message': 'Keine Städte gefunden', 'added': 0, 'existing': 0};
      }

      // Get unique states from cities with their countries
      final stateCountryMap = <String, String>{};
      for (final city in cities) {
        stateCountryMap[city.state] = city.country;
      }

      final cityStates = stateCountryMap.keys.toList();
      cityStates.sort();

      // Get existing states from Firebase
      final cityService = CityService();
      final existingStates = await cityService.getAllStates();
      final existingStateNames = existingStates.map((state) => state.name).toSet();

      // Find states that need to be added
      final statesToAdd = cityStates.where((stateName) => 
        !existingStateNames.contains(stateName)).toList();

      if (statesToAdd.isEmpty) {
        return {
          'success': true, 
          'message': 'Alle Bundesländer bereits synchronisiert', 
          'added': 0, 
          'existing': existingStates.length,
          'total': cityStates.length
        };
      }

      // Create state objects for missing states
      final newStates = statesToAdd.map((stateName) {
        final abbreviation = _getStateAbbreviation(stateName);
        final country = stateCountryMap[stateName] ?? 'Deutschland';
        
        return GermanState(
          id: '', // Will be set by Firestore
          name: stateName,
          abbreviation: abbreviation,
          country: country,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }).toList();

      // Add new states to Firebase
      final success = await cityService.batchAddStates(newStates);
      
      if (success) {
        return {
          'success': true,
          'message': '${newStates.length} neue Bundesländer hinzugefügt',
          'added': newStates.length,
          'existing': existingStates.length,
          'total': cityStates.length,
          'newStates': statesToAdd
        };
      } else {
        return {
          'success': false,
          'message': 'Fehler beim Hinzufügen der Bundesländer',
          'added': 0,
          'existing': existingStates.length
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Fehler beim Synchronisieren: $e',
        'added': 0,
        'existing': 0
      };
    }
  }

  /// Get state abbreviation for a given state name
  static String _getStateAbbreviation(String stateName) {
    const stateAbbreviations = {
      'Baden-Württemberg': 'BW',
      'Bayern': 'BAY',
      'Berlin': 'BER',
      'Brandenburg': 'BRA',
      'Bremen': 'BRE',
      'Hamburg': 'HAM',
      'Hessen': 'HES',
      'Mecklenburg-Vorpommern': 'MVP',
      'Niedersachsen': 'NDS',
      'Nordrhein-Westfalen': 'NRW',
      'Rheinland-Pfalz': 'RLP',
      'Saarland': 'SAA',
      'Sachsen': 'SAC',
      'Sachsen-Anhalt': 'SAH',
      'Schleswig-Holstein': 'SHL',
      'Thüringen': 'THU',
      // International "states" (countries)
      'Dänemark': 'DK',
      'Norwegen': 'NO',
      'Niederlande': 'NL',
      'Serbien': 'SRB',
      'Frankreich': 'FRA',
    };
    
    return stateAbbreviations[stateName] ?? stateName.substring(0, 3).toUpperCase();
  }
}

/// Compatibility extension to make City work like GermanCity
extension CityCompat on City {
  /// Legacy compatibility for old code
  String get bundesland => state;
  
  /// Legacy compatibility - returns the city name for old code that expects just the name
  String get cityName => name;
}

/// Legacy compatibility class for gradual migration
@Deprecated('Use FirebaseCitiesHelper and City model instead')
class LegacyCityAdapter {
  final City _city;
  
  LegacyCityAdapter(this._city);
  
  String get name => _city.name;
  String get state => _city.state;
  String get country => _city.country;
  String get stateAbbreviation => _city.stateAbbreviation;
  String get displayName => _city.displayName;
  
  @override
  String toString() => _city.toString();
}