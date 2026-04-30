import 'dart:async';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/team.dart';

class TeamService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _collection = 'teams';
  
  // Cache for faster subsequent loads
  List<Team>? _cachedTeams;
  DateTime? _lastCacheTime;
  static const Duration _cacheTimeout = Duration(minutes: 5);

  // Calculate best 3 total points from points history
  int _calculateBest3TotalPoints(List<Map<String, dynamic>> pointsHistory) {
    // Sort points history by points in descending order
    final sortedPoints = List<Map<String, dynamic>>.from(pointsHistory);
    sortedPoints.sort((a, b) {
      final pointsA = a['points'] as int? ?? 0;
      final pointsB = b['points'] as int? ?? 0;
      return pointsB.compareTo(pointsA); // Descending order
    });
    
    // Take only the best 3 results
    final best3Results = sortedPoints.take(3).toList();
    
    // Sum up the points from the best 3 results
    return best3Results.fold<int>(
      0,
      (sum, entry) => sum + (entry['points'] as int? ?? 0),
    );
  }

  // Get all teams as Future (for one-time fetch)
  Future<List<Team>> getAllTeams() async {
    try {
      final snapshot = await _firestore.collection(_collection).get();
      List<Team> teams = snapshot.docs
          .map((doc) => Team.fromFirestore(doc))
          .toList();
      
      // Sort by best 3 total points (descending), then by name
      teams.sort((a, b) {
        final best3PointsA = _calculateBest3TotalPoints(a.pointsHistory);
        final best3PointsB = _calculateBest3TotalPoints(b.pointsHistory);
        final pointsComparison = best3PointsB.compareTo(best3PointsA);
        if (pointsComparison != 0) {
          return pointsComparison;
        }
        return a.name.compareTo(b.name);
      });
      
      // Cache the results
      _cachedTeams = teams;
      _lastCacheTime = DateTime.now();
      
      return teams;
    } catch (e) {
      debugPrint('Error fetching all teams: $e');
      rethrow;
    }
  }

  // Get all teams with caching
  Stream<List<Team>> getTeams() {
    // Return cached data immediately if available and fresh
    if (_cachedTeams != null && _lastCacheTime != null && 
        DateTime.now().difference(_lastCacheTime!) < _cacheTimeout) {
      return Stream.value(_cachedTeams!);
    }

    return _firestore
        .collection(_collection)
        .limit(1000)
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

  // Add a new team
  Future<void> addTeam(Team team) async {
    await _firestore.collection(_collection).add(team.toFirestore());
    // Invalidate cache
    _invalidateCache();
  }

  // Update team
  Future<bool> updateTeam(String teamId, Team team) async {
    try {
      debugPrint('ðŸ TeamService: Updating team $teamId');
      debugPrint('ðŸ Team name: ${team.name}');
      debugPrint('ðŸ Roster player IDs: ${team.rosterPlayerIds}');
      
      final data = team.toFirestore();
      debugPrint('ðŸ Firestore data: $data');
      
      await _firestore
          .collection(_collection)
          .doc(teamId)
          .update(data);
      
      // Invalidate cache
      _invalidateCache();
      debugPrint('ðŸ TeamService: Team updated successfully');
      return true;
    } catch (e) {
      debugPrint('âŒ TeamService: Error updating team: $e');
      return false;
    }
  }

  /// Upload a team logo image and persist its download URL on the team doc.
  /// [bytes] is the raw image bytes. [extension] is without dot, e.g. 'jpg'.
  Future<String> uploadTeamLogo({
    required String teamId,
    required Uint8List bytes,
    String extension = 'jpg',
  }) async {
    final path =
        'teamLogos/$teamId/${DateTime.now().millisecondsSinceEpoch}.$extension';
    final ref = _storage.ref().child(path);
    final metadata = SettableMetadata(contentType: 'image/$extension');
    await ref.putData(bytes, metadata);
    final url = await ref.getDownloadURL();
    await _firestore.collection(_collection).doc(teamId).update({'logoUrl': url});
    _invalidateCache();
    return url;
  }

  /// Remove the logoUrl from the team doc and delete the storage object.
  Future<void> removeTeamLogo(String teamId, {String? currentUrl}) async {
    if (currentUrl != null && currentUrl.isNotEmpty) {
      try {
        await _storage.refFromURL(currentUrl).delete();
      } catch (e) {
        debugPrint('removeTeamLogo: storage delete failed (non-fatal): $e');
      }
    }
    await _firestore
        .collection(_collection)
        .doc(teamId)
        .update({'logoUrl': FieldValue.delete()});
    _invalidateCache();
  }

  // Delete team
  Future<bool> deleteTeam(String id) async {
    try {
    await _firestore.collection(_collection).doc(id).delete();
    // Invalidate cache
    _invalidateCache();
      return true;
    } catch (e) {
      debugPrint('Error deleting team: $e');
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
        debugPrint('Error preloading teams: $e');
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