/// Integration tests for critical workflows (T14).
///
/// Run with the Firebase emulator suite:
///   firebase emulators:exec --only auth,firestore,storage \
///     "flutter test integration_test --dart-define=USE_EMULATOR=true"
///
/// These tests do NOT spin up the full Flutter UI; they exercise the
/// service layer directly against the local emulator. UI-driven tests
/// can be added later under the same harness.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:GermanBeachOpen/firebase_test_config.dart';
import 'package:GermanBeachOpen/models/game_event.dart';
import 'package:GermanBeachOpen/services/live_scoring_service.dart';
import 'package:GermanBeachOpen/services/suspension_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await FirebaseTestConfig.ensureInitialized();
    if (!FirebaseTestConfig.useEmulator) {
      // Hard fail rather than hit prod. Run with --dart-define=USE_EMULATOR=true.
      throw StateError(
        'Integration tests must run against the Firebase emulator. '
        'Re-run with --dart-define=USE_EMULATOR=true.',
      );
    }
  });

  group('Scoring flow', () {
    test('goal event increments teamAScore atomically', () async {
      final firestore = FirebaseFirestore.instance;
      final scoring = LiveScoringService();

      final gameId = 'test-game-${DateTime.now().millisecondsSinceEpoch}';
      const teamAId = 'teamA';
      const teamBId = 'teamB';

      // Seed game doc with both team ids (so the service knows which side).
      await firestore.collection('games').doc(gameId).set({
        'teamAId': teamAId,
        'teamBId': teamBId,
        'teamAScore': 0,
        'teamBScore': 0,
        'minutes': 0,
        'seconds': 0,
        'currentPeriod': 1,
        'currentHalf': 1,
        'halfDurationMinutes': 15,
        'isRunning': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await scoring.addGameEvent(
        gameId: gameId,
        playerId: 'p1',
        playerName: 'Test Player',
        teamId: teamAId,
        teamName: 'Team A',
        eventType: GameEventType.goal,
      );

      final snap = await firestore.collection('games').doc(gameId).get();
      expect(snap.data()?['teamAScore'], 1);
      expect(snap.data()?['teamBScore'], 0);

      // Cleanup
      await firestore.collection('games').doc(gameId).delete();
    });
  });

  group('Suspensions', () {
    test('active suspension blocks player for tournament', () async {
      final firestore = FirebaseFirestore.instance;
      final service = SuspensionService();

      const playerId = 'susp-player';
      const tournamentId = 'susp-tournament';

      final ref = await firestore.collection('suspensions').add({
        'playerId': playerId,
        'playerName': 'Suspended P',
        'teamId': 'tX',
        'teamName': 'Team X',
        'tournamentId': tournamentId,
        'type': 'tournament',
        'reason': 'integration test',
        'isActive': true,
        'issuedAt': Timestamp.now(),
        'issuedBy': 'test',
      });

      final blocked = await service.isPlayerSuspendedForTournament(
        playerId,
        tournamentId,
      );
      expect(blocked, isTrue);

      // getAllSuspensions includes inactive too — verify it returns this row.
      final all = await service.getAllSuspensions();
      expect(all.any((s) => s.playerId == playerId), isTrue);

      await ref.delete();
    });
  });

  group('Tournament manualPoints', () {
    test('persists override and reads it back', () async {
      final firestore = FirebaseFirestore.instance;
      final ref = await firestore.collection('tournaments').add({
        'name': 'Test Tournament',
        'season': '2026',
        'location': 'Test',
        'startDate': Timestamp.now(),
        'status': 'upcoming',
        'manualPoints': null,
      });

      await ref.update({'manualPoints': 99});
      final snap = await ref.get();
      expect(snap.data()?['manualPoints'], 99);

      await ref.delete();
    });
  });
}
