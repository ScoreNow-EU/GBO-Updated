import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tournament.dart';
import '../models/referee.dart';
import '../models/team.dart';
import '../services/referee_service.dart';
import '../services/team_manager_service.dart';
import '../services/custom_notification_service.dart';

class TournamentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RefereeService _refereeService = RefereeService();
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
    try {
      print('\n📊 Tournament Update Summary for: ${tournament.name}');
      
      // Get the old tournament to compare team changes
      final oldTournament = await getTournamentById(tournament.id);
      final oldTeamIds = oldTournament?.teamIds ?? [];
      final newTeamIds = tournament.teamIds;
      
      // Find newly added teams
      final addedTeamIds = newTeamIds.where((id) => !oldTeamIds.contains(id)).toList();
      print('📋 Found ${addedTeamIds.length} newly added teams');
      
      // Update tournament in Firestore
      await _firestore
          .collection(_collection)
          .doc(tournament.id)
          .update(tournament.toMap());
      
      // Send notifications for newly added teams
      if (addedTeamIds.isNotEmpty) {
        await _notifyTeamManagers(addedTeamIds, tournament);
      }
      
      // Log all teams and their managers
      await _logTeamsAndManagers(tournament);
      
      // Invalidate cache
      _invalidateCache();
      print('✅ Tournament update completed\n');
    } catch (e) {
      print('❌ Error updating tournament: $e');
      rethrow;
    }
  }

  /// Notify team managers about their teams being added to the tournament
  Future<void> _notifyTeamManagers(List<String> teamIds, Tournament tournament) async {
    print('📬 Sending notifications to team managers...');
    
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
      
      print('🔍 Looking up team manager: $managerName');
      final manager = await teamManagerService.getTeamManagerByName(managerName);
      
      if (manager != null) {
        print('✉️ Sending notification to ${manager.name} (${manager.email})');
        
        String message;
        if (teamNames.length == 1) {
          message = '${teamNames[0]} wurde zu ${tournament.name} hinzugefügt.';
        } else {
          message = 'Ihre Teams (${teamNames.join(", ")}) wurden zu ${tournament.name} hinzugefügt.';
        }
        
        await notificationService.sendCustomNotification(
          title: 'Teams zum Turnier hinzugefügt',
          message: message,
          userEmail: manager.email,
        );
      } else {
        print('❌ Team manager not found: $managerName');
      }
    }
  }

  /// Log all teams and their managers in the tournament
  Future<void> _logTeamsAndManagers(Tournament tournament) async {
    print('\n👥 Teams in Tournament:');
    
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
        print('   ❌ Team ${teamDoc.id} not found');
        continue;
      }

      final teamData = teamDoc.data()!;
      final teamName = teamData['name'] as String;
      final teamManager = teamData['teamManager'] as String?;
      final division = teamData['division'] as String;

      // Find which tournament division this team is in
      final teamDivisions = tournament.divisionTeams.entries
          .where((entry) => entry.value.contains(teamDoc.id))
          .map((entry) => entry.key)
          .toList();

      print('   📋 Team: $teamName');
      print('      Division: $division');
      print('      Tournament Divisions: ${teamDivisions.isEmpty ? "Not assigned to division" : teamDivisions.join(", ")}');
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
        
        // If tournament has category-specific dates, find the earliest start and latest end
        if (tournament.categoryStartDates != null && tournament.categoryStartDates!.isNotEmpty) {
          tournamentStart = tournament.categoryStartDates!.values.reduce((a, b) => a.isBefore(b) ? a : b);
        }
        
        if (tournament.categoryEndDates != null && tournament.categoryEndDates!.isNotEmpty) {
          tournamentEnd = tournament.categoryEndDates!.values.reduce((a, b) => a.isAfter(b) ? a : b);
        }
        
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

  // Sync pending invitations count for all referees
  Future<void> syncAllRefereesPendingInvitationsCount() async {
    try {
      // First, initialize the pendingInvitations field for all referees
      await _refereeService.initializePendingInvitationsFieldForAllReferees();

      // Get all tournaments
      final tournamentsSnapshot = await _firestore.collection(_collection).get();
      final Map<String, List<String>> refereesPendingInvitations = {};

      // Collect pending invitations for each referee
      for (final doc in tournamentsSnapshot.docs) {
        final tournament = Tournament.fromMap(doc.data(), doc.id);
        
        for (final invitation in tournament.refereeInvitations) {
          if (invitation.isPending) {
            refereesPendingInvitations[invitation.refereeId] = 
                (refereesPendingInvitations[invitation.refereeId] ?? [])..add(tournament.id);
          }
        }
      }

      // Update all referees with their actual pending invitations
      await _refereeService.updateMultipleRefereesPendingInvitations(refereesPendingInvitations);

      print('Synced pending invitations for ${refereesPendingInvitations.length} referees');
    } catch (e) {
      print('Error syncing referees pending invitations: $e');
    }
  }

  // Update tournament referee nominations (deprecated but kept for backward compatibility)
  Future<void> updateTournamentReferees(String tournamentId, List<String> refereeIds) async {
    try {
      final tournament = await getTournamentById(tournamentId);
      if (tournament == null) return;

      // Track changes in pending invitations
      final Set<String> refereesWithRemovedPendingInvitations = {};
      final Set<String> refereesWithAddedPendingInvitations = {};
      
      // Check for removed pending invitations
      for (final oldInvitation in tournament.refereeInvitations) {
        if (oldInvitation.isPending && !refereeIds.contains(oldInvitation.refereeId)) {
          refereesWithRemovedPendingInvitations.add(oldInvitation.refereeId);
        }
      }

      // Check for new pending invitations
      for (final refereeId in refereeIds) {
        final existingInvitation = tournament.refereeInvitations
            .where((inv) => inv.refereeId == refereeId)
            .firstOrNull;
        
        if (existingInvitation == null) {
          // New invitation
          refereesWithAddedPendingInvitations.add(refereeId);
        }
      }

      // Convert refereeIds to invitations for backward compatibility
      final invitations = refereeIds.map((refereeId) {
        // Check if this referee already has an invitation
        final existingInvitation = tournament.refereeInvitations
            .where((inv) => inv.refereeId == refereeId)
            .firstOrNull;

        if (existingInvitation != null) {
          // Keep existing invitation
          return existingInvitation;
        } else {
          // Create new pending invitation
          return RefereeInvitation(
            refereeId: refereeId,
            status: 'pending',
            invitedAt: DateTime.now(),
          );
        }
      }).toList();

      await _firestore
          .collection(_collection)
          .doc(tournamentId)
          .update({'refereeInvitations': invitations.map((inv) => inv.toMap()).toList()});

      // Update pending invitations for affected referees
      for (final refereeId in refereesWithRemovedPendingInvitations) {
        await _refereeService.removePendingInvitation(refereeId, tournamentId);
      }
      
      for (final refereeId in refereesWithAddedPendingInvitations) {
        await _refereeService.addPendingInvitation(refereeId, tournamentId);
      }

      _invalidateCache();
    } catch (e) {
      print('Error updating tournament referees: $e');
    }
  }

  // Invite a referee to a tournament
  Future<bool> inviteRefereeToTournament(String tournamentId, String refereeId) async {
    try {
      final tournament = await getTournamentById(tournamentId);
      if (tournament == null) return false;

      // Check if referee is already invited
      final existingInvitation = tournament.refereeInvitations
          .where((invitation) => invitation.refereeId == refereeId)
          .firstOrNull;

      if (existingInvitation != null) {
        // Already invited, don't duplicate
        return false;
      }

      // Add new invitation
      final newInvitation = RefereeInvitation(
        refereeId: refereeId,
        status: 'pending',
        invitedAt: DateTime.now(),
      );

      final updatedInvitations = [...tournament.refereeInvitations, newInvitation];

      await _firestore.collection(_collection).doc(tournamentId).update({
        'refereeInvitations': updatedInvitations.map((inv) => inv.toMap()).toList(),
      });

      // Add pending invitation to referee
      await _refereeService.addPendingInvitation(refereeId, tournamentId);

      _invalidateCache();
      return true;
    } catch (e) {
      print('Error inviting referee to tournament: $e');
      return false;
    }
  }

  // Respond to referee invitation
  Future<bool> respondToRefereeInvitation(
    String tournamentId, 
    String refereeId, 
    String response, // 'accepted', 'declined', 'pending'
    {String? notes}
  ) async {
    try {
      final tournament = await getTournamentById(tournamentId);
      if (tournament == null) return false;

      // Find the invitation
      final invitationIndex = tournament.refereeInvitations
          .indexWhere((invitation) => invitation.refereeId == refereeId);

      if (invitationIndex == -1) return false;

      final oldInvitation = tournament.refereeInvitations[invitationIndex];

      // Update the invitation
      final updatedInvitations = List<RefereeInvitation>.from(tournament.refereeInvitations);
      updatedInvitations[invitationIndex] = tournament.refereeInvitations[invitationIndex].copyWith(
        status: response,
        respondedAt: response != 'pending' ? DateTime.now() : null,
        notes: notes,
      );

      await _firestore.collection(_collection).doc(tournamentId).update({
        'refereeInvitations': updatedInvitations.map((inv) => inv.toMap()).toList(),
      });

      // Update pending invitations for referee
      if (oldInvitation.status == 'pending' && response != 'pending') {
        // Was pending, now responded - remove from pending
        await _refereeService.removePendingInvitation(refereeId, tournamentId);
      } else if (oldInvitation.status != 'pending' && response == 'pending') {
        // Was responded, now pending again - add to pending
        await _refereeService.addPendingInvitation(refereeId, tournamentId);
      }

      _invalidateCache();
      return true;
    } catch (e) {
      print('Error responding to referee invitation: $e');
      return false;
    }
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
        categories: ['GBO Juniors Cup'],
        location: 'Verden, DEU',
        startDate: DateTime(2025, 7, 5),
        points: 15,
        status: 'upcoming',
        description: 'Junior tournament for U18 and U16 divisions',
      ),
    ];

    for (Tournament tournament in sampleTournaments) {
      await addTournament(tournament);
    }
  }

  // Register a team for a tournament division
  Future<bool> registerTeamForTournament(String tournamentId, String teamId, String division, {List<Map<String, String>>? roster}) async {
    try {
      print('🏆 Registering team $teamId for tournament $tournamentId in division $division');
      
      // Get the tournament first
      final tournament = await getTournamentById(tournamentId);
      if (tournament == null) {
        print('❌ Tournament not found: $tournamentId');
        return false;
      }
      print('📅 Found tournament: ${tournament.name}');

      // Check if team can register
      final team = await FirebaseFirestore.instance.collection('teams').doc(teamId).get();
      if (!team.exists) {
        print('❌ Team not found: $teamId');
        return false;
      }
      
      final teamData = team.data() as Map<String, dynamic>;
      final teamDivision = teamData['division'] as String;
      final teamName = teamData['name'] as String;
      final teamManager = teamData['teamManager'];
      print('👥 Found team: $teamName (Manager: $teamManager)');
      
      if (!tournament.canRegisterForDivision(division, teamDivision)) {
        print('❌ Team cannot register for division $division (team division: $teamDivision)');
        return false;
      }

      // Check if team is already registered
      if (tournament.isTeamRegistered(teamId)) {
        print('❌ Team is already registered');
        return false;
      }

      // Update the tournament with the new team registration
      Map<String, List<String>> updatedDivisionTeams = Map.from(tournament.divisionTeams);
      if (!updatedDivisionTeams.containsKey(division)) {
        updatedDivisionTeams[division] = [];
      }
      updatedDivisionTeams[division]!.add(teamId);
      print('✅ Added team to division $division');

      // Also add to general teamIds for backward compatibility
      List<String> updatedTeamIds = List.from(tournament.teamIds);
      if (!updatedTeamIds.contains(teamId)) {
        updatedTeamIds.add(teamId);
      }

      Map<String, dynamic> updateData = {
        'divisionTeams': updatedDivisionTeams.map((key, value) => MapEntry(key, value)),
        'teamIds': updatedTeamIds,
      };

      // Store roster information if provided
      if (roster != null && roster.isNotEmpty) {
        updateData['rosters'] = {
          ...tournament.toMap()['rosters'] ?? {},
          teamId: roster,
        };
        print('📋 Added roster information for team');
      }

      await _firestore.collection(_collection).doc(tournamentId).update(updateData);
      print('💾 Tournament updated with new team registration');

      _invalidateCache();
      return true;
    } catch (e) {
      print('❌ Error registering team for tournament: $e');
      return false;
    }
  }

  // Unregister a team from a tournament
  Future<bool> unregisterTeamFromTournament(String tournamentId, String teamId) async {
    try {
      final tournament = await getTournamentById(tournamentId);
      if (tournament == null) return false;

      // Find and remove team from division
      Map<String, List<String>> updatedDivisionTeams = Map.from(tournament.divisionTeams);
      bool teamFound = false;
      
      for (String division in updatedDivisionTeams.keys) {
        if (updatedDivisionTeams[division]!.contains(teamId)) {
          updatedDivisionTeams[division]!.remove(teamId);
          teamFound = true;
          break;
        }
      }

      if (!teamFound) return false;

      // Also remove from general teamIds
      List<String> updatedTeamIds = List.from(tournament.teamIds);
      updatedTeamIds.remove(teamId);

      await _firestore.collection(_collection).doc(tournamentId).update({
        'divisionTeams': updatedDivisionTeams.map((key, value) => MapEntry(key, value)),
        'teamIds': updatedTeamIds,
      });

      _invalidateCache();
      return true;
    } catch (e) {
      print('Error unregistering team from tournament: $e');
      return false;
    }
  }

  // Update tournament divisions and settings
  Future<bool> updateTournamentDivisions(String tournamentId, {
    List<String>? divisions,
    Map<String, int>? divisionMaxTeams,
    bool? isRegistrationOpen,
    DateTime? registrationDeadline,
  }) async {
    try {
      Map<String, dynamic> updates = {};
      
      if (divisions != null) updates['divisions'] = divisions;
      if (divisionMaxTeams != null) updates['divisionMaxTeams'] = divisionMaxTeams;
      if (isRegistrationOpen != null) updates['isRegistrationOpen'] = isRegistrationOpen;
      if (registrationDeadline != null) {
        updates['registrationDeadline'] = registrationDeadline.millisecondsSinceEpoch;
      }

      await _firestore.collection(_collection).doc(tournamentId).update(updates);
      _invalidateCache();
      return true;
    } catch (e) {
      print('Error updating tournament divisions: $e');
      return false;
    }
  }

  // Get tournaments that a specific team can register for
  Stream<List<Tournament>> getTournamentsForTeamRegistration(String teamDivision) {
    return getTournamentsWithCache().map((tournaments) => 
        tournaments.where((tournament) => 
            tournament.isRegistrationOpen && 
            tournament.divisions.contains(teamDivision) &&
            tournament.status == 'upcoming' &&
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

  // Update existing tournaments to have default divisions if they don't have any
  Future<void> updateTournamentsWithDefaultDivisions() async {
    try {
      final snapshot = await _firestore.collection(_collection).get();
      
      for (final doc in snapshot.docs) {
        final tournament = Tournament.fromMap(doc.data(), doc.id);
        
        // Skip if tournament already has divisions configured
        if (tournament.divisions.isNotEmpty) continue;
        
        // Configure default divisions based on categories
        List<String> defaultDivisions = [];
        Map<String, int> defaultMaxTeams = {};
        
        if (tournament.categories.contains('GBO Seniors Cup')) {
          defaultDivisions.addAll([
            'Women\'s Seniors',
            'Women\'s FUN',
            'Men\'s Seniors', 
            'Men\'s FUN',
          ]);
          for (String division in defaultDivisions) {
            defaultMaxTeams[division] = 32;
          }
        }
        
        if (tournament.categories.contains('GBO Juniors Cup')) {
          defaultDivisions.addAll([
            'Women\'s U14',
            'Women\'s U16',
            'Women\'s U18',
            'Men\'s U14',
            'Men\'s U16',
            'Men\'s U18',
          ]);
          for (String division in ['Women\'s U14', 'Women\'s U16', 'Women\'s U18', 'Men\'s U14', 'Men\'s U16', 'Men\'s U18']) {
            defaultMaxTeams[division] = 32;
          }
        }
        
        // Update tournament with default divisions
        if (defaultDivisions.isNotEmpty) {
          await _firestore.collection(_collection).doc(doc.id).update({
            'divisions': defaultDivisions,
            'divisionMaxTeams': defaultMaxTeams,
            'isRegistrationOpen': true,
          });
          print('Updated tournament ${tournament.name} with default divisions: $defaultDivisions');
        }
      }
      
      // Invalidate cache to reload updated tournaments
      _invalidateCache();
    } catch (e) {
      print('Error updating tournaments with default divisions: $e');
    }
  }
} 