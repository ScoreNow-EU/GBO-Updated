import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tournament.dart';

class TournamentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'tournaments';

  // Cache for faster subsequent loads
  List<Tournament>? _cachedTournaments;
  DateTime? _lastCacheTime;
  static const Duration _cacheTimeout = Duration(minutes: 5);

  // Get all tournaments with caching
  Stream<List<Tournament>> getTournaments() {
    // Return cached data immediately if available and fresh
    if (_cachedTournaments != null && _lastCacheTime != null && 
        DateTime.now().difference(_lastCacheTime!) < _cacheTimeout) {
      return Stream.value(_cachedTournaments!);
    }

    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) {
          List<Tournament> tournaments = snapshot.docs
              .map((doc) => Tournament.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();
          
          // Sort locally instead of using orderBy to avoid index requirements
          tournaments.sort((a, b) => a.startDate.compareTo(b.startDate));
          
          // Cache the results
          _cachedTournaments = tournaments;
          _lastCacheTime = DateTime.now();
          
          return tournaments;
        });
  }

  // Get tournaments with immediate cache return + background update
  Stream<List<Tournament>> getTournamentsWithCache() {
    if (_cachedTournaments != null) {
      // Create a stream controller to manage the flow
      late StreamController<List<Tournament>> controller;
      controller = StreamController<List<Tournament>>(
        onListen: () async {
          // First emit cached data immediately
          controller.add(_cachedTournaments!);
          
          // Then listen for Firebase updates
          _firestore
              .collection(_collection)
              .snapshots()
              .map((snapshot) {
                List<Tournament> tournaments = snapshot.docs
                    .map((doc) => Tournament.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                    .toList();
                
                tournaments.sort((a, b) => a.startDate.compareTo(b.startDate));
                
                // Update cache
                _cachedTournaments = tournaments;
                _lastCacheTime = DateTime.now();
                
                return tournaments;
              })
              .listen(
                (tournaments) => controller.add(tournaments),
                onError: (error) => controller.addError(error),
                onDone: () => controller.close(),
              );
        },
        onCancel: () => controller.close(),
      );
      
      return controller.stream;
    } else {
      // No cache, load from Firebase
      return getTournaments();
    }
  }

  // Get tournaments by status with caching
  Stream<List<Tournament>> getTournamentsByStatus(String status) {
    return getTournamentsWithCache().map((tournaments) => 
        tournaments.where((tournament) => tournament.status == status).toList());
  }

  // Get tournaments by category with caching
  Stream<List<Tournament>> getTournamentsByCategory(String category) {
    return getTournamentsWithCache().map((tournaments) => 
        tournaments.where((tournament) => tournament.hasCategory(category)).toList());
  }

  // Add a new tournament
  Future<void> addTournament(Tournament tournament) async {
    await _firestore.collection(_collection).add(tournament.toMap());
    // Invalidate cache
    _invalidateCache();
  }

  // Update tournament
  Future<void> updateTournament(Tournament tournament) async {
    await _firestore
        .collection(_collection)
        .doc(tournament.id)
        .update(tournament.toMap());
    // Invalidate cache
    _invalidateCache();
  }

  // Delete tournament
  Future<void> deleteTournament(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
    // Invalidate cache
    _invalidateCache();
  }

  // Get tournament by ID (with local cache search first)
  Future<Tournament?> getTournamentById(String id) async {
    // Try to find in cache first
    if (_cachedTournaments != null) {
      try {
        return _cachedTournaments!.firstWhere((tournament) => tournament.id == id);
      } catch (e) {
        // Not found in cache, fall through to Firestore
      }
    }
    
    DocumentSnapshot doc = await _firestore.collection(_collection).doc(id).get();
    if (doc.exists) {
      return Tournament.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  // Update referee nominations for a tournament
  Future<void> updateTournamentReferees(String tournamentId, List<String> refereeIds) async {
    await _firestore
        .collection(_collection)
        .doc(tournamentId)
        .update({'refereeIds': refereeIds});
    // Invalidate cache
    _invalidateCache();
  }

  // Preload tournaments for faster initial access
  Future<void> preloadTournaments() async {
    if (_cachedTournaments == null || 
        (_lastCacheTime != null && DateTime.now().difference(_lastCacheTime!) > _cacheTimeout)) {
      try {
        final snapshot = await _firestore.collection(_collection).get();
        List<Tournament> tournaments = snapshot.docs
            .map((doc) => Tournament.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList();
        
        tournaments.sort((a, b) => a.startDate.compareTo(b.startDate));
        
        _cachedTournaments = tournaments;
        _lastCacheTime = DateTime.now();
      } catch (e) {
        print('Error preloading tournaments: $e');
      }
    }
  }

  // Invalidate cache when data changes
  void _invalidateCache() {
    _cachedTournaments = null;
    _lastCacheTime = null;
  }

  // Clear cache manually
  void clearCache() {
    _invalidateCache();
  }

  // Initialize with sample data
  Future<void> initializeSampleData() async {
    // Check if data already exists
    QuerySnapshot existing = await _firestore.collection(_collection).limit(1).get();
    if (existing.docs.isNotEmpty) return;

    // Add sample tournaments with multiple categories
    List<Tournament> sampleTournaments = [
      Tournament(
        id: '',
        name: 'Herrenhäuser Beachcup 2025',
        categories: ['GBO Juniors Cup', 'GBO Seniors Cup'], // Both categories
        location: 'Hannover, DEU',
        startDate: DateTime(2025, 6, 13),
        endDate: DateTime(2025, 6, 14),
        points: 20,
        status: 'upcoming',
        description: 'Annual beach handball tournament in Hannover for all age groups',
      ),
      Tournament(
        id: '',
        name: 'Verdener Beach-Cup mU18 + mU16',
        categories: ['GBO Juniors Cup'], // Juniors only
        location: 'Verden (Aller), DEU',
        startDate: DateTime(2025, 6, 14),
        points: 20,
        status: 'upcoming',
        description: 'Youth tournament for U18 and U16 categories',
      ),
      Tournament(
        id: '',
        name: 'MOB BeachCup 2025',
        categories: ['GBO Juniors Cup', 'GBO Seniors Cup'], // Both categories
        location: 'Wittingen, DEU',
        startDate: DateTime(2025, 6, 15),
        points: 20,
        status: 'upcoming',
        description: 'Multi-age beach handball competition',
      ),
      Tournament(
        id: '',
        name: 'HVNB Cuxhaven Tournament',
        categories: ['GBO Seniors Cup'], // Seniors only
        location: 'Cuxhaven, DEU',
        startDate: DateTime(2025, 6, 19),
        endDate: DateTime(2025, 6, 21),
        points: 20,
        status: 'upcoming',
        description: 'Senior tournament at the coast',
      ),
    ];

    for (Tournament tournament in sampleTournaments) {
      await addTournament(tournament);
    }
  }
} 