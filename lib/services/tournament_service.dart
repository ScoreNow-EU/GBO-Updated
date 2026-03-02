import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tournament.dart';
import '../models/referee.dart';
import '../models/team.dart';
import '../services/referee_service.dart';
import '../services/geocoding_service.dart';
import '../services/team_manager_service.dart';
import '../services/custom_notification_service.dart';

class TournamentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RefereeService _refereeService = RefereeService();
  final GeocodingService _geocodingService = GeocodingService();
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
      late StreamSubscription firebaseSubscription;
      
      controller = StreamController<List<Tournament>>(
        onListen: () async {
          // First emit cached data immediately
          if (!controller.isClosed) {
            controller.add(_cachedTournaments!);
          }
          
          // Then listen for Firebase updates
          firebaseSubscription = _firestore
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
                (tournaments) {
                  if (!controller.isClosed) {
                    controller.add(tournaments);
                  }
                },
                onError: (error) {
                  if (!controller.isClosed) {
                    controller.addError(error);
                  }
                },
                onDone: () {
                  if (!controller.isClosed) {
                    controller.close();
                  }
                },
              );
        },
        onCancel: () {
          firebaseSubscription.cancel();
          if (!controller.isClosed) {
            controller.close();
          }
        },
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

  // Get tournaments by season
  Stream<List<Tournament>> getTournamentsBySeason(String season) {
    return getTournamentsWithCache().map((tournaments) => 
        tournaments.where((tournament) => tournament.season == season).toList());
  }

  // Add a new tournament
  Future<void> addTournament(Tournament tournament) async {
    await _firestore.collection(_collection).add(tournament.toMap());
    // Invalidate cache
    _invalidateCache();
  }

  // Update method to ensure season is set correctly
  Future<Tournament?> updateTournament(Tournament tournament) async {
    try {
      // Ensure season is dynamically set based on start date
      final tournamentMap = tournament.toMap();

      // Update in Firestore
      await _firestore
          .collection(_collection)
          .doc(tournament.id)
          .update(tournamentMap);

      // Invalidate cache
      _invalidateCache();

      // Return the original tournament (with dynamically set season)
      return tournament;
    } catch (e) {
      print('Error updating tournament: $e');
      rethrow;
    }
  }

  // Modify createTournament to use dynamic season
  Future<Tournament> createTournament(Tournament tournament) async {
    try {
      // Ensure tournament has an ID if not provided
      final tournamentId = tournament.id.isEmpty 
          ? _firestore.collection(_collection).doc().id 
          : tournament.id;

      // Convert to map, which will use dynamic season determination
      final tournamentMap = tournament.toMap();

      // Add timestamp fields
      tournamentMap['createdAt'] = FieldValue.serverTimestamp();
      tournamentMap['updatedAt'] = FieldValue.serverTimestamp();

      // Save to Firestore
      await _firestore
          .collection(_collection)
          .doc(tournamentId)
          .set(tournamentMap);

      // Invalidate cache
      _invalidateCache();

      // Return the tournament with the correct ID
      return Tournament(
        id: tournamentId,
        name: tournament.name,
        location: tournament.location,
        startDate: tournament.startDate,
        endDate: tournament.endDate,
        status: tournament.status,
        description: tournament.description,
        imageUrl: tournament.imageUrl,
        teamIds: tournament.teamIds,
        refereeInvitations: tournament.refereeInvitations,
        delegateIds: tournament.delegateIds,
        refereeGespanne: tournament.refereeGespanne,
        divisionBrackets: tournament.divisionBrackets,
        customBrackets: tournament.customBrackets,
        courts: tournament.courts,
        isRegistrationOpen: tournament.isRegistrationOpen,
        registrationDeadline: tournament.registrationDeadline,
        pools: tournament.pools,
        poolMetadata: tournament.poolMetadata,
        results: tournament.results,
      );
    } catch (e) {
      print('Error creating tournament: $e');
      rethrow;
    }
  }

  /// Notify team managers about their teams being added to the tournament
  Future<void> _notifyTeamManagers(List<String> teamIds, Tournament tournament) async {
    print('ðŸ“¬ Sending notifications to team managers...');
    
    // Fetch all teams in parallel
    final teamFutures = teamIds.map((teamId) => 
      FirebaseFirestore.instance.collection('teams').doc(teamId).get()
    );
    final teamDocs = await Future.wait(teamFutures);
    
    // Group teams by manager to avoid duplicate notifications
    final managerTeams = <String, List<String>>{};
    
    for (final teamDoc in teamDocs) {
      if (!teamDoc.exists) continue;
      
      final teamData = teamDoc.data()!;
      final teamName = teamData['name'] as String;
      final teamManager = teamData['teamManager'] as String?;
      
      if (teamManager != null) {
        if (!managerTeams.containsKey(teamManager)) {
          managerTeams[teamManager] = [];
        }
        managerTeams[teamManager]!.add(teamName);
      }
    }
    
    // Send notifications to each manager
    final teamManagerService = TeamManagerService();
    final notificationService = CustomNotificationService();
    
    for (final entry in managerTeams.entries) {
      final managerName = entry.key;
      final teamNames = entry.value;
      
      print('ðŸ” Looking up team manager: $managerName');
      final manager = await teamManagerService.getTeamManagerByName(managerName);
      
      if (manager != null) {
        print('âœ‰ï¸ Sending notification to ${manager.name} (${manager.email})');
        
        String message;
        if (teamNames.length == 1) {
          message = '${teamNames[0]} wurde zu ${tournament.name} hinzugefÃ¼gt.';
        } else {
          message = 'Ihre Teams (${teamNames.join(", ")}) wurden zu ${tournament.name} hinzugefÃ¼gt.';
        }
        
        await notificationService.sendCustomNotification(
          title: 'Teams zum Turnier hinzugefÃ¼gt',
          message: message,
          userEmail: manager.email,
        );
      } else {
        print('âŒ Team manager not found: $managerName');
      }
    }
  }

  /// Log all teams and their managers in the tournament
  Future<void> _logTeamsAndManagers(Tournament tournament) async {
    print('\nðŸ‘¥ Teams in Tournament:');
    
    final teamIds = tournament.teamIds;
    
    if (teamIds.isEmpty) {
      print('   No teams registered yet');
      return;
    }

    // Fetch all teams in parallel
    final teamFutures = teamIds.map((teamId) => 
      FirebaseFirestore.instance.collection('teams').doc(teamId).get()
    );
    final teamDocs = await Future.wait(teamFutures);

    // Process each team
    for (final teamDoc in teamDocs) {
      if (!teamDoc.exists) {
        print('   âŒ Team ${teamDoc.id} not found');
        continue;
      }

      final teamData = teamDoc.data()!;
      final teamName = teamData['name'] as String;
      final teamManager = teamData['teamManager'] as String?;
      final division = teamData['division'] as String;

      print('   ðŸ“‹ Team: $teamName');
      print('      Team Manager: ${teamManager ?? "none"}');
    }
    print(''); // Empty line for better readability
  }
  
  // Auto-update tournament statuses based on current date
  Future<void> updateTournamentStatuses() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Get all tournaments that might need status updates
      final snapshot = await _firestore
          .collection(_collection)
          .get();
      
      final batch = _firestore.batch();
      bool hasUpdates = false;
      
      for (final doc in snapshot.docs) {
        final tournament = Tournament.fromMap(doc.data(), doc.id);
        String newStatus = tournament.status;
        
        // Determine the actual start and end dates
        DateTime tournamentStart = tournament.startDate;
        DateTime? tournamentEnd = tournament.endDate;
        
        // Convert to date-only for comparison
        final startDate = DateTime(tournamentStart.year, tournamentStart.month, tournamentStart.day);
        final endDate = tournamentEnd != null 
            ? DateTime(tournamentEnd.year, tournamentEnd.month, tournamentEnd.day)
            : startDate;
        
        // Determine new status based on dates
        if (today.isAfter(endDate)) {
          newStatus = 'completed';
        } else if (today.isAfter(startDate) || today.isAtSameMomentAs(startDate)) {
          newStatus = 'ongoing';
        } else {
          newStatus = 'upcoming';
        }
        
        // Update if status changed
        if (newStatus != tournament.status) {
          batch.update(doc.reference, {'status': newStatus});
          hasUpdates = true;
        }
      }
      
      // Commit all updates
      if (hasUpdates) {
        await batch.commit();
        
        // Invalidate cache to reload updated tournaments
        _invalidateCache();
      }
    } catch (e) {
      print('Error updating tournament statuses: $e');
    }
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

  // ──────────────────────────────────────────────────────────────────────────
  // Referee Availability (admin-entered)
  // ──────────────────────────────────────────────────────────────────────────

  /// Add a referee to the tournament's availability list (status: 'pending').
  Future<bool> addRefereeToTournament(String tournamentId, String refereeId) async {
    try {
      final tournament = await getTournamentById(tournamentId);
      if (tournament == null) return false;

      // Don't duplicate
      if (tournament.refereeInvitations.any((inv) => inv.refereeId == refereeId)) {
        return false;
      }

      final newInvitation = RefereeInvitation(
        refereeId: refereeId,
        status: 'pending',
      );

      final updatedInvitations = [...tournament.refereeInvitations, newInvitation];

      await _firestore.collection(_collection).doc(tournamentId).update({
        'refereeInvitations': updatedInvitations.map((inv) => inv.toMap()).toList(),
      });

      _invalidateCache();
      return true;
    } catch (e) {
      print('Error adding referee to tournament: $e');
      return false;
    }
  }

  /// Remove a referee from the tournament's availability list entirely.
  Future<bool> removeRefereeFromTournament(String tournamentId, String refereeId) async {
    try {
      final tournament = await getTournamentById(tournamentId);
      if (tournament == null) return false;

      final updatedInvitations = tournament.refereeInvitations
          .where((inv) => inv.refereeId != refereeId)
          .toList();

      await _firestore.collection(_collection).doc(tournamentId).update({
        'refereeInvitations': updatedInvitations.map((inv) => inv.toMap()).toList(),
      });

      _invalidateCache();
      return true;
    } catch (e) {
      print('Error removing referee from tournament: $e');
      return false;
    }
  }

  /// Set a referee's availability status (admin enters accept/decline after external contact).
  Future<bool> setRefereeAvailability(
    String tournamentId,
    String refereeId,
    String status, // 'pending', 'accepted', 'declined'
    {
    String? notes,
    DateTime? availableFrom,
    DateTime? availableUntil,
    bool? isFullDay,
  }) async {
    try {
      final tournament = await getTournamentById(tournamentId);
      if (tournament == null) return false;

      final invitationIndex = tournament.refereeInvitations
          .indexWhere((invitation) => invitation.refereeId == refereeId);

      if (invitationIndex == -1) return false;

      final updatedInvitations = List<RefereeInvitation>.from(tournament.refereeInvitations);
      updatedInvitations[invitationIndex] = updatedInvitations[invitationIndex].copyWith(
        status: status,
        respondedAt: status != 'pending' ? DateTime.now() : null,
        notes: notes,
        availableFrom: availableFrom,
        availableUntil: availableUntil,
        isFullDay: isFullDay,
      );

      await _firestore.collection(_collection).doc(tournamentId).update({
        'refereeInvitations': updatedInvitations.map((inv) => inv.toMap()).toList(),
      });

      _invalidateCache();
      return true;
    } catch (e) {
      print('Error setting referee availability: $e');
      return false;
    }
  }

  // Legacy method — kept for backward compat but simplified
  Future<bool> inviteRefereeToTournament(String tournamentId, String refereeId) async {
    return addRefereeToTournament(tournamentId, refereeId);
  }

  // Legacy method — kept for backward compat but simplified
  Future<bool> respondToRefereeInvitation(
    String tournamentId,
    String refereeId,
    String response,
    {String? notes}
  ) async {
    return setRefereeAvailability(tournamentId, refereeId, response, notes: notes);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Kampfgericht Availability (admin-entered)
  // ──────────────────────────────────────────────────────────────────────────

  /// Add a Kampfgericht member to the tournament's availability list.
  Future<bool> addKampfgerichtToTournament(String tournamentId, String memberId) async {
    try {
      final tournament = await getTournamentById(tournamentId);
      if (tournament == null) return false;

      if (tournament.kampfgerichtInvitations.any((inv) => inv.memberId == memberId)) {
        return false;
      }

      final newInvitation = KampfgerichtInvitation(
        memberId: memberId,
        status: 'pending',
      );

      final updatedInvitations = [...tournament.kampfgerichtInvitations, newInvitation];

      await _firestore.collection(_collection).doc(tournamentId).update({
        'kampfgerichtInvitations': updatedInvitations.map((inv) => inv.toMap()).toList(),
      });

      _invalidateCache();
      return true;
    } catch (e) {
      print('Error adding Kampfgericht member to tournament: $e');
      return false;
    }
  }

  /// Remove a Kampfgericht member from the tournament.
  Future<bool> removeKampfgerichtFromTournament(String tournamentId, String memberId) async {
    try {
      final tournament = await getTournamentById(tournamentId);
      if (tournament == null) return false;

      final updatedInvitations = tournament.kampfgerichtInvitations
          .where((inv) => inv.memberId != memberId)
          .toList();

      await _firestore.collection(_collection).doc(tournamentId).update({
        'kampfgerichtInvitations': updatedInvitations.map((inv) => inv.toMap()).toList(),
      });

      _invalidateCache();
      return true;
    } catch (e) {
      print('Error removing Kampfgericht member from tournament: $e');
      return false;
    }
  }

  /// Set a Kampfgericht member's availability status.
  Future<bool> setKampfgerichtAvailability(
    String tournamentId,
    String memberId,
    String status,
    {
    String? notes,
    DateTime? availableFrom,
    DateTime? availableUntil,
    bool? isFullDay,
  }) async {
    try {
      final tournament = await getTournamentById(tournamentId);
      if (tournament == null) return false;

      final invitationIndex = tournament.kampfgerichtInvitations
          .indexWhere((inv) => inv.memberId == memberId);

      if (invitationIndex == -1) return false;

      final updatedInvitations = List<KampfgerichtInvitation>.from(tournament.kampfgerichtInvitations);
      updatedInvitations[invitationIndex] = updatedInvitations[invitationIndex].copyWith(
        status: status,
        respondedAt: status != 'pending' ? DateTime.now() : null,
        notes: notes,
        availableFrom: availableFrom,
        availableUntil: availableUntil,
        isFullDay: isFullDay,
      );

      await _firestore.collection(_collection).doc(tournamentId).update({
        'kampfgerichtInvitations': updatedInvitations.map((inv) => inv.toMap()).toList(),
      });

      _invalidateCache();
      return true;
    } catch (e) {
      print('Error setting Kampfgericht availability: $e');
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Venue address and geocoding
  // ──────────────────────────────────────────────────────────────────────────

  /// Update venue address and auto-geocode coordinates.
  Future<bool> updateVenueAddress(
    String tournamentId, {
    String? venueStreet,
    String? venueHouseNumber,
    String? venuePlz,
    String? location,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (venueStreet != null) updates['venueStreet'] = venueStreet;
      if (venueHouseNumber != null) updates['venueHouseNumber'] = venueHouseNumber;
      if (venuePlz != null) updates['venuePlz'] = venuePlz;
      if (location != null) updates['location'] = location;

      // Auto-geocode
      final coords = await _geocodingService.geocodeAddress(
        street: venueStreet,
        houseNumber: venueHouseNumber,
        plz: venuePlz,
        city: location,
      );
      if (coords != null) {
        updates['venueLatitude'] = coords['lat'];
        updates['venueLongitude'] = coords['lng'];
      }

      await _firestore.collection(_collection).doc(tournamentId).update(updates);
      _invalidateCache();
      return true;
    } catch (e) {
      print('Error updating venue address: $e');
      return false;
    }
  }

  /// Calculate distances between venue and all accepted referees/Kampfgericht.
  /// Returns a map of officialId → DistanceResult.
  Future<Map<String, DistanceResult>> getDistancesToVenue(Tournament tournament) async {
    final distances = <String, DistanceResult>{};
    if (!tournament.hasVenueCoordinates) return distances;

    final venueLat = tournament.venueLatitude!;
    final venueLng = tournament.venueLongitude!;

    // Get all accepted referees
    for (final invitation in tournament.refereeInvitations) {
      final referee = await _refereeService.getRefereeById(invitation.refereeId);
      if (referee != null && referee.hasCoordinates) {
        final result = await _geocodingService.calculateDrivingDistance(
          referee.latitude!, referee.longitude!, venueLat, venueLng,
        );
        if (result != null) {
          distances[referee.id] = result;
        }
      }
    }

    return distances;
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
        name: 'RHBL Spieltag 1',
        location: 'Berlin, DEU',
        startDate: DateTime(2025, 9, 13),
        endDate: DateTime(2025, 9, 14),
        status: 'upcoming',
        description: 'Erster Spieltag der Rollstuhlhandball Bundesliga Saison 2025/26',
      ),
      Tournament(
        id: '',
        name: 'RHBL Spieltag 2',
        location: 'Hamburg, DEU',
        startDate: DateTime(2025, 10, 5),
        status: 'upcoming',
        description: 'Zweiter Spieltag der Rollstuhlhandball Bundesliga',
      ),
    ];

    for (Tournament tournament in sampleTournaments) {
      await addTournament(tournament);
    }
  }

  // Register a team for a tournament
  Future<bool> registerTeamForTournament(String tournamentId, String teamId, String category, {List<Map<String, String>>? roster}) async {
    try {
      print('ðŸ† Registering team $teamId for tournament $tournamentId');
      
      final tournament = await getTournamentById(tournamentId);
      if (tournament == null) {
        print('âŒ Tournament not found: $tournamentId');
        return false;
      }
      print('ðŸ“… Found tournament: ${tournament.name}');

      // Check if team exists
      final team = await FirebaseFirestore.instance.collection('teams').doc(teamId).get();
      if (!team.exists) {
        print('âŒ Team not found: $teamId');
        return false;
      }
      
      final teamData = team.data() as Map<String, dynamic>;
      final teamName = teamData['name'] as String;
      print('ðŸ‘¥ Found team: $teamName');

      // Check if team is already registered
      if (tournament.isTeamRegistered(teamId)) {
        print('âŒ Team is already registered');
        return false;
      }

      // Add to general teamIds
      List<String> updatedTeamIds = List.from(tournament.teamIds);
      if (!updatedTeamIds.contains(teamId)) {
        updatedTeamIds.add(teamId);
      }

      Map<String, dynamic> updateData = {
        'teamIds': updatedTeamIds,
      };

      if (roster != null && roster.isNotEmpty) {
        updateData['rosters'] = {
          ...tournament.toMap()['rosters'] ?? {},
          teamId: roster,
        };
        print('ðŸ“‹ Added roster information for team');
      }

      await _firestore.collection(_collection).doc(tournamentId).update(updateData);
      print('ðŸ’¾ Tournament updated with new team registration');

      _invalidateCache();
      return true;
    } catch (e) {
      print('âŒ Error registering team for tournament: $e');
      return false;
    }
  }

  // Unregister a team from a tournament
  Future<bool> unregisterTeamFromTournament(String tournamentId, String teamId) async {
    try {
      final tournament = await getTournamentById(tournamentId);
      if (tournament == null) return false;

      if (!tournament.teamIds.contains(teamId)) return false;

      List<String> updatedTeamIds = List.from(tournament.teamIds);
      updatedTeamIds.remove(teamId);

      await _firestore.collection(_collection).doc(tournamentId).update({
        'teamIds': updatedTeamIds,
      });

      _invalidateCache();
      return true;
    } catch (e) {
      print('Error unregistering team from tournament: $e');
      return false;
    }
  }

  // Update tournament registration settings
  Future<bool> updateTournamentRegistration(String tournamentId, {
    bool? isRegistrationOpen,
    DateTime? registrationDeadline,
  }) async {
    try {
      Map<String, dynamic> updates = {};
      
      if (isRegistrationOpen != null) updates['isRegistrationOpen'] = isRegistrationOpen;
      if (registrationDeadline != null) {
        updates['registrationDeadline'] = registrationDeadline.millisecondsSinceEpoch;
      }

      await _firestore.collection(_collection).doc(tournamentId).update(updates);
      _invalidateCache();
      return true;
    } catch (e) {
      print('Error updating tournament registration: $e');
      return false;
    }
  }

  // Get tournaments that a specific team can register for
  Stream<List<Tournament>> getTournamentsForTeamRegistration(String teamId) {
    return getTournamentsWithCache().map((tournaments) => 
        tournaments.where((tournament) => 
            tournament.approvalStatus == 'approved' &&
            tournament.isRegistrationOpen && 
            tournament.status == 'upcoming' &&
            !tournament.isTeamRegistered(teamId) &&
            (tournament.registrationDeadline == null || 
             DateTime.now().isBefore(tournament.registrationDeadline!))
        ).toList());
  }

  // Get tournaments where a specific team is registered
  Stream<List<Tournament>> getTournamentsForTeam(String teamId) {
    return getTournamentsWithCache().map((tournaments) => 
        tournaments.where((tournament) => tournament.isTeamRegistered(teamId)).toList());
  }

  // Get tournaments where a specific referee is assigned (any status)
  Stream<List<Tournament>> getTournamentsForReferee(String refereeId) {
    return getTournamentsWithCache().map((tournaments) => 
        tournaments.where((tournament) => 
            tournament.refereeInvitations.any((invitation) => invitation.refereeId == refereeId)
        ).toList());
  }

  // Get upcoming tournaments for a referee (future tournaments only)
  Stream<List<Tournament>> getUpcomingTournamentsForReferee(String refereeId) {
    final now = DateTime.now();
    return getTournamentsForReferee(refereeId).map((tournaments) => 
        tournaments.where((tournament) => 
            tournament.startDate.isAfter(now) || 
            (tournament.endDate != null && tournament.endDate!.isAfter(now))
        ).toList());
  }

  // Get tournaments with pending invitations for a referee
  Stream<List<Tournament>> getPendingInvitationsForReferee(String refereeId) {
    return getTournamentsWithCache().map((tournaments) => 
        tournaments.where((tournament) => 
            tournament.refereeInvitations.any((invitation) => 
                invitation.refereeId == refereeId && invitation.isPending)
        ).toList());
  }

  // Get tournaments where referee has accepted invitations
  Stream<List<Tournament>> getAcceptedTournamentsForReferee(String refereeId) {
    final now = DateTime.now();
    return getTournamentsWithCache().map((tournaments) => 
        tournaments.where((tournament) => 
            tournament.refereeInvitations.any((invitation) => 
                invitation.refereeId == refereeId && invitation.isAccepted) &&
            (tournament.startDate.isAfter(now) || 
             (tournament.endDate != null && tournament.endDate!.isAfter(now)))
        ).toList());
  }

  // Placeholder: update tournaments with default settings for RHBL
  Future<void> updateTournamentsWithDefaultSettings() async {
    // RHBL doesn't use categories - nothing to do
    return;
  }

  // Migrate all tournaments to 2025 season
  Future<int> migrateToSeason2025() async {
    try {
      // Get all tournaments
      final querySnapshot = await _firestore.collection(_collection).get();
      
      // Batch write for better performance
      final batch = _firestore.batch();
      int count = 0;

      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {'season': '2025'});
        count++;
      }

      // Commit the batch
      await batch.commit();
      
      // Invalidate cache
      _invalidateCache();
      
      print('âœ… Successfully migrated $count tournaments to 2025 season');
      return count;
    } catch (e) {
      print('âŒ Error migrating tournaments: $e');
      rethrow;
    }
  }

  // Removed: updateTournamentPoints (no longer used in RHBL)
} 