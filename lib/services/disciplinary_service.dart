import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_event.dart';
import 'tournament_stats_service.dart';

/// Represents a disciplinary record for a player across the tournament
class DisciplinaryRecord {
  final String playerId;
  final String playerName;
  final String teamId;
  final String teamName;
  final int yellowCards;
  final int twoMinuteSuspensions;
  final int redCards;
  final int blueCards;
  final bool isSuspended;
  final String? suspensionReason;

  DisciplinaryRecord({
    required this.playerId,
    required this.playerName,
    required this.teamId,
    required this.teamName,
    this.yellowCards = 0,
    this.twoMinuteSuspensions = 0,
    this.redCards = 0,
    this.blueCards = 0,
    this.isSuspended = false,
    this.suspensionReason,
  });
}

/// Rules for progressive discipline (Handball-Regelwerk IHF)
class DisciplineRules {
  /// Blue card leads to tournament suspension + written report
  final bool blueCardTournamentBan;

  const DisciplineRules({
    this.blueCardTournamentBan = true,
  });

  Map<String, dynamic> toJson() => {
    'blueCardTournamentBan': blueCardTournamentBan,
  };

  factory DisciplineRules.fromJson(Map<String, dynamic> json) {
    return DisciplineRules(
      blueCardTournamentBan: json['blueCardTournamentBan'] ?? true,
    );
  }
}

/// Service for progressive discipline tracking across a tournament
class DisciplinaryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TournamentStatsService _statsService = TournamentStatsService();

  /// Get all disciplinary records for a tournament with suspension status
  Future<List<DisciplinaryRecord>> getDisciplinaryRecords(
    String tournamentId, {
    DisciplineRules rules = const DisciplineRules(),
  }) async {
    final events = await _statsService.getAllTournamentEvents(tournamentId);

    // Group events by player
    final Map<String, _PlayerDisciplineAgg> aggregated = {};

    for (final event in events) {
      final key = event.playerId ?? event.playerName;
      if (key.isEmpty) continue;

      // Only count discipline-related events
      if (event.eventType != GameEventType.yellowCard &&
          event.eventType != GameEventType.twoMinuteSuspension &&
          event.eventType != GameEventType.redCard &&
          event.eventType != GameEventType.blueCard) {
        continue;
      }

      aggregated.putIfAbsent(key, () => _PlayerDisciplineAgg(
        playerId: event.playerId ?? '',
        playerName: event.playerName,
        teamId: event.teamId,
        teamName: event.teamName,
      ));

      final agg = aggregated[key]!;
      switch (event.eventType) {
        case GameEventType.yellowCard:
          agg.yellowCards++;
          break;
        case GameEventType.twoMinuteSuspension:
          agg.twoMinuteSuspensions++;
          break;
        case GameEventType.redCard:
          agg.redCards++;
          break;
        case GameEventType.blueCard:
          agg.blueCards++;
          break;
        default:
          break;
      }
    }

    // Build records with suspension status
    return aggregated.values.map((agg) {
      bool suspended = false;
      String? reason;

      // Blaue Karte → Turniersperre + Bericht an Verband
      if (rules.blueCardTournamentBan && agg.blueCards > 0) {
        suspended = true;
        reason = 'Blaue Karte – Turniersperre & Bericht an Verband';
      }
      // Rote Karte = Disqualifikation für aktuelles Spiel (kein Folge-Spielbann)
      // 3x 2-Minuten = automatisch Rote Karte im laufenden Spiel
      // Beide werden im Spielbericht angezeigt, aber KEINE Turniersperre.

      return DisciplinaryRecord(
        playerId: agg.playerId,
        playerName: agg.playerName,
        teamId: agg.teamId,
        teamName: agg.teamName,
        yellowCards: agg.yellowCards,
        twoMinuteSuspensions: agg.twoMinuteSuspensions,
        redCards: agg.redCards,
        blueCards: agg.blueCards,
        isSuspended: suspended,
        suspensionReason: reason,
      );
    }).toList()
      ..sort((a, b) {
        // Suspended players first, then by severity
        if (a.isSuspended != b.isSuspended) {
          return a.isSuspended ? -1 : 1;
        }
        final aSeverity = a.redCards * 100 + a.blueCards * 80 +
            a.yellowCards * 10 + a.twoMinuteSuspensions * 5;
        final bSeverity = b.redCards * 100 + b.blueCards * 80 +
            b.yellowCards * 10 + b.twoMinuteSuspensions * 5;
        return bSeverity.compareTo(aSeverity);
      });
  }

  /// Check if a specific player is currently suspended
  Future<bool> isPlayerSuspended(
    String tournamentId,
    String playerId, {
    DisciplineRules rules = const DisciplineRules(),
  }) async {
    final records = await getDisciplinaryRecords(tournamentId, rules: rules);
    final record = records.where((r) => r.playerId == playerId).firstOrNull;
    return record?.isSuspended ?? false;
  }

  /// Get suspended players only
  Future<List<DisciplinaryRecord>> getSuspendedPlayers(
    String tournamentId, {
    DisciplineRules rules = const DisciplineRules(),
  }) async {
    final records = await getDisciplinaryRecords(tournamentId, rules: rules);
    return records.where((r) => r.isSuspended).toList();
  }

  /// Save discipline rules for a tournament
  Future<void> saveDisciplineRules(
      String tournamentId, DisciplineRules rules) async {
    await _firestore
        .collection('tournaments')
        .doc(tournamentId)
        .update({'disciplineRules': rules.toJson()});
  }

  /// Load discipline rules for a tournament
  Future<DisciplineRules> loadDisciplineRules(String tournamentId) async {
    final doc = await _firestore
        .collection('tournaments')
        .doc(tournamentId)
        .get();
    final data = doc.data();
    if (data != null && data['disciplineRules'] != null) {
      return DisciplineRules.fromJson(data['disciplineRules']);
    }
    return const DisciplineRules();
  }
}

/// Internal aggregation helper
class _PlayerDisciplineAgg {
  final String playerId;
  final String playerName;
  final String teamId;
  final String teamName;
  int yellowCards = 0;
  int twoMinuteSuspensions = 0;
  int redCards = 0;
  int blueCards = 0;

  _PlayerDisciplineAgg({
    required this.playerId,
    required this.playerName,
    required this.teamId,
    required this.teamName,
  });
}
