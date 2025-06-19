import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/team.dart';

class TeamService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'teams';
  
  // Cache for faster subsequent loads
  List<Team>? _cachedTeams;
  DateTime? _lastCacheTime;
  static const Duration _cacheTimeout = Duration(minutes: 5);

  // Get all teams with caching
  Stream<List<Team>> getTeams() {
    // Return cached data immediately if available and fresh
    if (_cachedTeams != null && _lastCacheTime != null && 
        DateTime.now().difference(_lastCacheTime!) < _cacheTimeout) {
      return Stream.value(_cachedTeams!);
    }

    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) {
          List<Team> teams = snapshot.docs
              .map((doc) => Team.fromFirestore(doc))
              .toList();
          
          // Sort by name
          teams.sort((a, b) => a.name.compareTo(b.name));
          
          // Cache the results
          _cachedTeams = teams;
          _lastCacheTime = DateTime.now();
          
          return teams;
        });
  }

  // Get teams with immediate cache return + background update
  Stream<List<Team>> getTeamsWithCache() {
    if (_cachedTeams != null) {
      // Create a stream controller to manage the flow
      late StreamController<List<Team>> controller;
      controller = StreamController<List<Team>>(
        onListen: () async {
          // First emit cached data immediately
          controller.add(_cachedTeams!);
          
          // Then listen for Firebase updates
          _firestore
              .collection(_collection)
              .snapshots()
              .map((snapshot) {
                List<Team> teams = snapshot.docs
                    .map((doc) => Team.fromFirestore(doc))
                    .toList();
                
                teams.sort((a, b) => a.name.compareTo(b.name));
                
                // Update cache
                _cachedTeams = teams;
                _lastCacheTime = DateTime.now();
                
                return teams;
              })
              .listen(
                (teams) => controller.add(teams),
                onError: (error) => controller.addError(error),
                onDone: () => controller.close(),
              );
        },
        onCancel: () => controller.close(),
      );
      
      return controller.stream;
    } else {
      // No cache, load from Firebase
      return getTeams();
    }
  }

  // Get teams by Bundesland with caching
  Stream<List<Team>> getTeamsByBundesland(String bundesland) {
    return getTeamsWithCache().map((teams) => 
        teams.where((team) => team.bundesland == bundesland).toList());
  }

  // Get teams by division with caching  
  Stream<List<Team>> getTeamsByDivision(String division) {
    return getTeamsWithCache().map((teams) => 
        teams.where((team) => team.division == division).toList());
  }

  // Add a new team
  Future<void> addTeam(Team team) async {
    await _firestore.collection(_collection).add(team.toFirestore());
    // Invalidate cache
    _invalidateCache();
  }

  // Update team
  Future<bool> updateTeam(String teamId, Team team) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(teamId)
          .update(team.toFirestore());
      // Invalidate cache
      _invalidateCache();
      return true;
    } catch (e) {
      print('Error updating team: $e');
      return false;
    }
  }

  // Delete team
  Future<bool> deleteTeam(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
      // Invalidate cache
      _invalidateCache();
      return true;
    } catch (e) {
      print('Error deleting team: $e');
      return false;
    }
  }

  // Get team by ID (with local cache search first)
  Future<Team?> getTeamById(String id) async {
    // Try to find in cache first
    if (_cachedTeams != null) {
      try {
        return _cachedTeams!.firstWhere((team) => team.id == id);
      } catch (e) {
        // Not found in cache, fall through to Firestore
      }
    }
    
    DocumentSnapshot doc = await _firestore.collection(_collection).doc(id).get();
    if (doc.exists) {
      return Team.fromFirestore(doc);
    }
    return null;
  }

  // Preload teams for faster initial access
  Future<void> preloadTeams() async {
    if (_cachedTeams == null || 
        (_lastCacheTime != null && DateTime.now().difference(_lastCacheTime!) > _cacheTimeout)) {
      try {
        final snapshot = await _firestore.collection(_collection).get();
        List<Team> teams = snapshot.docs
            .map((doc) => Team.fromFirestore(doc))
            .toList();
        
        teams.sort((a, b) => a.name.compareTo(b.name));
        
        _cachedTeams = teams;
        _lastCacheTime = DateTime.now();
      } catch (e) {
        print('Error preloading teams: $e');
      }
    }
  }

  // Invalidate cache when data changes
  void _invalidateCache() {
    _cachedTeams = null;
    _lastCacheTime = null;
  }

  // Clear cache manually
  void clearCache() {
    _invalidateCache();
  }

  // Initialize with sample data
  Future<void> initializeSampleData() async {
    // No sample data initialization - teams will be created manually
    return;
  }
} 