import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/assignment_constraints.dart';
import '../models/game.dart';
import '../models/referee.dart';
import '../models/kampfgericht_member.dart';
import '../models/tournament.dart';

/// Service that calls the server-side AI solver (Firebase Cloud Function)
/// to produce optimal referee + Kampfgericht assignments for tournament games.
///
/// The solver maximizes minimum break time between consecutive assignments
/// while respecting hard constraints (availability, license levels, exclusions,
/// manual overrides, no double-booking).
class AssignmentSolverService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// The base URL for the Cloud Function.
  /// In production, this will be the deployed Cloud Function URL.
  /// Set via environment config or hardcoded after deployment.
  String? _cloudFunctionUrl;

  AssignmentSolverService({String? cloudFunctionUrl})
      : _cloudFunctionUrl = cloudFunctionUrl;

  /// Set the Cloud Function URL (call after Firebase init if needed).
  void setCloudFunctionUrl(String url) {
    _cloudFunctionUrl = url;
  }

  /// Run the AI solver for a tournament.
  ///
  /// [games] — all games that need officials assigned (must have scheduledTime).
  /// [referees] — accepted referees for this tournament (with availability).
  /// [kampfgerichtMembers] — accepted Kampfgericht members (with availability).
  /// [refereeInvitations] — to extract availability windows.
  /// [kampfgerichtInvitations] — to extract availability windows.
  /// [constraints] — per-game constraints (license levels, manual overrides, exclusions).
  /// [compatibilities] — who can/can't work together.
  ///
  /// Returns a [SolverResponse] with assignments and metadata.
  Future<SolverResponse> solveAssignment({
    required List<Game> games,
    required List<Referee> referees,
    required List<KampfgerichtMember> kampfgerichtMembers,
    required List<RefereeInvitation> refereeInvitations,
    required List<KampfgerichtInvitation> kampfgerichtInvitations,
    required List<GameAssignmentConstraint> constraints,
    List<RefereeCompatibility> compatibilities = const [],
  }) async {
    if (_cloudFunctionUrl == null || _cloudFunctionUrl!.isEmpty) {
      throw Exception(
          'Cloud Function URL not configured. Deploy the solver function first.');
    }

    // Build the solver input payload
    final gameInputs = games
        .where((g) => g.scheduledTime != null)
        .map((g) => GameInput(
              id: g.id,
              scheduledTime: g.scheduledTime!,
              courtId: g.courtId,
            ).toJson())
        .toList();

    // Build officials list from referees
    final officialInputs = <Map<String, dynamic>>[];

    for (final referee in referees) {
      final invitation = refereeInvitations
          .where((inv) => inv.refereeId == referee.id && inv.isAccepted)
          .firstOrNull;
      if (invitation == null) continue;

      officialInputs.add(OfficialInput(
        id: referee.id,
        type: 'referee',
        licenseLevel: referee.licenseType,
        availableFrom: invitation.availableFrom,
        availableUntil: invitation.availableUntil,
        isFullDay: invitation.isFullDay,
      ).toJson());
    }

    // Build officials list from Kampfgericht members
    for (final member in kampfgerichtMembers) {
      final invitation = kampfgerichtInvitations
          .where((inv) => inv.memberId == member.id && inv.isAccepted)
          .firstOrNull;
      if (invitation == null) continue;

      officialInputs.add(OfficialInput(
        id: member.id,
        type: 'kampfgericht',
        availableFrom: invitation.availableFrom,
        availableUntil: invitation.availableUntil,
        isFullDay: invitation.isFullDay,
      ).toJson());
    }

    // Also add referees as potential Kampfgericht candidates
    // (all referees can do timekeeper/scorekeeper)
    for (final referee in referees) {
      final invitation = refereeInvitations
          .where((inv) => inv.refereeId == referee.id && inv.isAccepted)
          .firstOrNull;
      if (invitation == null) continue;

      officialInputs.add(OfficialInput(
        id: '${referee.id}_kg', // Suffix to distinguish from referee role
        type: 'kampfgericht_capable_referee',
        licenseLevel: referee.licenseType,
        availableFrom: invitation.availableFrom,
        availableUntil: invitation.availableUntil,
        isFullDay: invitation.isFullDay,
      ).toJson());
    }

    final payload = {
      'games': gameInputs,
      'officials': officialInputs,
      'constraints': constraints.map((c) => c.toJson()).toList(),
      'compatibilities': compatibilities.map((c) => c.toJson()).toList(),
    };

    try {
      final response = await http.post(
        Uri.parse(_cloudFunctionUrl!),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return SolverResponse.fromJson(data);
      } else {
        throw Exception(
            'Solver returned status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Error calling solver: $e');
      rethrow;
    }
  }

  /// Apply a solver's assignment results to the game documents in Firestore.
  Future<void> applyAssignment({
    required String tournamentId,
    required List<AssignmentResult> results,
  }) async {
    final batch = _firestore.batch();

    for (final result in results) {
      final gameRef = _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('games')
          .doc(result.gameId);

      batch.update(gameRef, {
        'referee1Id': result.referee1Id,
        'referee2Id': result.referee2Id,
        'timekeeperId': result.timekeeperId,
        'scorekeeperId': result.scorekeeperId,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }

    await batch.commit();
  }

  /// Clear all official assignments for games in a tournament.
  Future<void> clearAssignments(String tournamentId) async {
    final gamesSnapshot = await _firestore
        .collection('tournaments')
        .doc(tournamentId)
        .collection('games')
        .get();

    final batch = _firestore.batch();
    for (final doc in gamesSnapshot.docs) {
      batch.update(doc.reference, {
        'referee1Id': null,
        'referee2Id': null,
        'timekeeperId': null,
        'scorekeeperId': null,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }

    await batch.commit();
  }
}
