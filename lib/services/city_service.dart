import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/city.dart';
import '../models/state.dart';
import '../models/team.dart';

class CityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _citiesCollection = 'cities';
  final String _statesCollection = 'states';
  
  // Cache for faster subsequent loads
  List<City>? _cachedCities;
  List<GermanState>? _cachedStates;
  DateTime? _lastCacheTime;
  static const Duration _cacheTimeout = Duration(minutes: 10);

  // Get all cities from Firebase
  Future<List<City>> getAllCities() async {
    try {
      // Return cached data if available and fresh
      if (_cachedCities != null && _lastCacheTime != null && 
          DateTime.now().difference(_lastCacheTime!) < _cacheTimeout) {
        return _cachedCities!;
      }

      final snapshot = await _firestore
          .collection(_citiesCollection)
          .get();
      
      final cities = snapshot.docs
          .map((doc) => City.fromFirestore(doc))
          .toList();
      
      // Sort in memory instead of using compound query
      cities.sort((a, b) {
        final stateComparison = a.state.compareTo(b.state);
        if (stateComparison != 0) return stateComparison;
        return a.name.compareTo(b.name);
      });
      
      // Cache the results
      _cachedCities = cities;
      _lastCacheTime = DateTime.now();
      
      return cities;
    } catch (e) {
      debugPrint('Error fetching cities: $e');
      return [];
    }
  }

  // Get all states from Firebase
  Future<List<GermanState>> getAllStates() async {
    try {
      // Return cached data if available and fresh
      if (_cachedStates != null && _lastCacheTime != null && 
          DateTime.now().difference(_lastCacheTime!) < _cacheTimeout) {
        return _cachedStates!;
      }

      final snapshot = await _firestore
          .collection(_statesCollection)
          .get();
      
      final states = snapshot.docs
          .map((doc) => GermanState.fromFirestore(doc))
          .toList();
      
      // Sort in memory instead of using query
      states.sort((a, b) => a.name.compareTo(b.name));
      
      // Cache the results
      _cachedStates = states;
      _lastCacheTime = DateTime.now();
      
      return states;
    } catch (e) {
      debugPrint('Error fetching states: $e');
      return [];
    }
  }

  // Get cities by state
  Future<List<City>> getCitiesByState(String stateName) async {
    try {
      // Use cached data and filter in memory to avoid index requirements
      final allCities = await getAllCities();
      return allCities.where((city) => city.state == stateName).toList();
    } catch (e) {
      debugPrint('Error fetching cities for state $stateName: $e');
      return [];
    }
  }

  // Get cities by country
  Future<List<City>> getCitiesByCountry(String countryName) async {
    try {
      final allCities = await getAllCities();
      return allCities.where((city) => city.country == countryName).toList();
    } catch (e) {
      debugPrint('Error fetching cities for country $countryName: $e');
      return [];
    }
  }

  // Search cities
  Future<List<City>> searchCities(String query) async {
    if (query.isEmpty) return getAllCities();
    
    try {
      final cities = await getAllCities();
      final lowercaseQuery = query.toLowerCase();
      
      return cities.where((city) {
        return city.name.toLowerCase().contains(lowercaseQuery) ||
               city.displayName.toLowerCase().contains(lowercaseQuery) ||
               city.stateAbbreviation.toLowerCase().contains(lowercaseQuery);
      }).toList();
    } catch (e) {
      debugPrint('Error searching cities: $e');
      return [];
    }
  }

  // Find specific city
  Future<City?> findCity(String cityName, String stateName) async {
    try {
      // Use cached data and filter in memory to avoid compound index
      final allCities = await getAllCities();
      final matches = allCities.where(
        (city) => city.name == cityName && city.state == stateName,
      );
      return matches.isNotEmpty ? matches.first : null;
    } catch (e) {
      debugPrint('Error finding city $cityName in $stateName: $e');
      return null;
    }
  }

  // Add a new state
  Future<String?> addState(GermanState state) async {
    try {
      final docRef = await _firestore
          .collection(_statesCollection)
          .add(state.toMap());
      
      // Invalidate cache
      _invalidateCache();
      
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding state: $e');
      return null;
    }
  }

  // Add a new city
  Future<String?> addCity(City city) async {
    try {
      final docRef = await _firestore
          .collection(_citiesCollection)
          .add(city.toMap());
      
      // Invalidate cache
      _invalidateCache();
      
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding city: $e');
      return null;
    }
  }

  // Batch add cities (for migration)
  Future<bool> batchAddCities(List<City> cities) async {
    try {
      const batchSize = 500; // Firestore batch limit
      
      for (int i = 0; i < cities.length; i += batchSize) {
        final batch = _firestore.batch();
        final endIndex = (i + batchSize < cities.length) ? i + batchSize : cities.length;
        
        for (int j = i; j < endIndex; j++) {
          final city = cities[j];
          final docRef = _firestore.collection(_citiesCollection).doc();
          batch.set(docRef, city.toMap());
        }
        
        await batch.commit();
        debugPrint('Added cities batch ${i ~/ batchSize + 1} (${endIndex - i} cities)');
      }
      
      // Invalidate cache
      _invalidateCache();
      
      return true;
    } catch (e) {
      debugPrint('Error batch adding cities: $e');
      return false;
    }
  }

  // Batch add states (for migration)
  Future<bool> batchAddStates(List<GermanState> states) async {
    try {
      final batch = _firestore.batch();
      
      for (final state in states) {
        final docRef = _firestore.collection(_statesCollection).doc();
        batch.set(docRef, state.toMap());
      }
      
      await batch.commit();
      
      // Invalidate cache
      _invalidateCache();
      
      return true;
    } catch (e) {
      debugPrint('Error batch adding states: $e');
      return false;
    }
  }

  // Clear all cities (for testing/migration)
  Future<bool> clearAllCities() async {
    try {
      final snapshot = await _firestore.collection(_citiesCollection).get();
      
      const batchSize = 500;
      for (int i = 0; i < snapshot.docs.length; i += batchSize) {
        final batch = _firestore.batch();
        final endIndex = (i + batchSize < snapshot.docs.length) ? i + batchSize : snapshot.docs.length;
        
        for (int j = i; j < endIndex; j++) {
          batch.delete(snapshot.docs[j].reference);
        }
        
        await batch.commit();
      }
      
      // Invalidate cache
      _invalidateCache();
      
      return true;
    } catch (e) {
      debugPrint('Error clearing cities: $e');
      return false;
    }
  }

  // Clear all states (for testing/migration)
  Future<bool> clearAllStates() async {
    try {
      final snapshot = await _firestore.collection(_statesCollection).get();
      final batch = _firestore.batch();
      
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      // Invalidate cache
      _invalidateCache();
      
      return true;
    } catch (e) {
      debugPrint('Error clearing states: $e');
      return false;
    }
  }

  // Invalidate cache
  void _invalidateCache() {
    _cachedCities = null;
    _cachedStates = null;
    _lastCacheTime = null;
  }

  // Import cities from CSV content
  Future<List<City>> parseCitiesFromCsv(String csvContent) async {
    try {
      final lines = csvContent.split('\n');
      final cities = <City>[];
      
      // Skip first row (headers: "Stadtname", "Bundesland", "Land")
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        
        final parts = _parseCsvLine(line);
        if (parts.length >= 3) {
          final cityName = parts[0].trim();
          final stateName = parts[1].trim();
          final countryName = parts[2].trim();
          
          if (cityName.isNotEmpty && stateName.isNotEmpty && countryName.isNotEmpty) {
            cities.add(City(
              id: '', // Will be set by Firestore
              name: cityName,
              state: stateName,
              country: countryName,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ));
          }
        }
      }
      
      debugPrint('Parsed ${cities.length} cities from CSV');
      return cities;
    } catch (e) {
      debugPrint('Error parsing CSV: $e');
      return [];
    }
  }

  // Parse CSV line handling quotes and commas properly
  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    
    // Add the last field
    result.add(buffer.toString());
    
    return result;
  }

  // Import cities from CSV and save to Firebase
  Future<bool> importCitiesFromCsv(String csvContent) async {
    try {
      final cities = await parseCitiesFromCsv(csvContent);
      if (cities.isEmpty) {
        debugPrint('No cities to import');
        return false;
      }
      
      debugPrint('Importing ${cities.length} cities to Firebase...');
      return await batchAddCities(cities);
    } catch (e) {
      debugPrint('Error importing cities from CSV: $e');
      return false;
    }
  }

  // Match teams to cities automatically
  Future<Map<String, String>> matchTeamsToCities(List<Team> teams) async {
    try {
      final cities = await getAllCities();
      final matches = <String, String>{}; // teamId -> cityId
      
      for (final team in teams) {
        if (team.city.isEmpty) continue;
        
        final teamCityName = team.city.toLowerCase().trim();
        
        // Try exact match first
        City? matchedCity = cities.where((city) => 
          city.name.toLowerCase() == teamCityName
        ).firstOrNull;
        
        // If no exact match, try partial match
        if (matchedCity == null) {
          matchedCity = cities.where((city) => 
            city.name.toLowerCase().contains(teamCityName) ||
            teamCityName.contains(city.name.toLowerCase())
          ).firstOrNull;
        }
        
        if (matchedCity != null) {
          matches[team.id] = matchedCity.id;
        }
      }
      
      debugPrint('Matched ${matches.length} out of ${teams.length} teams to cities');
      return matches;
    } catch (e) {
      debugPrint('Error matching teams to cities: $e');
      return {};
    }
  }

  // Update teams with city IDs
  Future<bool> updateTeamsWithCityIds(Map<String, String> teamCityMatches) async {
    try {
      const batchSize = 500;
      final entries = teamCityMatches.entries.toList();
      
      for (int i = 0; i < entries.length; i += batchSize) {
        final batch = _firestore.batch();
        final endIndex = (i + batchSize < entries.length) ? i + batchSize : entries.length;
        
        for (int j = i; j < endIndex; j++) {
          final entry = entries[j];
          final teamRef = _firestore.collection('teams').doc(entry.key);
          batch.update(teamRef, {'cityId': entry.value});
        }
        
        await batch.commit();
        debugPrint('Updated teams batch ${i ~/ batchSize + 1}');
      }
      
      return true;
    } catch (e) {
      debugPrint('Error updating teams with city IDs: $e');
      return false;
    }
  }

  // Get statistics
  Future<Map<String, int>> getStatistics() async {
    try {
      final citiesSnapshot = await _firestore.collection(_citiesCollection).get();
      final statesSnapshot = await _firestore.collection(_statesCollection).get();
      
      return {
        'cities': citiesSnapshot.docs.length,
        'states': statesSnapshot.docs.length,
      };
    } catch (e) {
      debugPrint('Error getting statistics: $e');
      return {'cities': 0, 'states': 0};
    }
  }
}