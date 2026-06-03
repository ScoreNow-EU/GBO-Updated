import 'export_helper_stub.dart'
    if (dart.library.html) 'export_helper_web.dart';
import '../services/tournament_stats_service.dart';
import '../services/disciplinary_service.dart';
import '../services/game_service.dart';
import '../models/game.dart';

/// Service for exporting tournament data as CSV files (browser download)
class TournamentExportService {
  final TournamentStatsService _statsService = TournamentStatsService();
  final DisciplinaryService _disciplinaryService = DisciplinaryService();
  final GameService _gameService = GameService();

  /// Export top scorers as CSV
  Future<void> exportTopScorers(String tournamentId, String tournamentName) async {
    final scorers = await _statsService.getTopScorers(tournamentId);
    final filtered = scorers.where((s) => s.totalGoals > 0).toList();

    final buffer = StringBuffer();
    buffer.writeln('Rang,Spieler,Team,Tore,7m-Tore,7m-Fehl,Spiele');
    for (int i = 0; i < filtered.length; i++) {
      final s = filtered[i];
      buffer.writeln(
        '${i + 1},"${_escapeCsv(s.playerName)}","${_escapeCsv(s.teamName)}",${s.totalGoals},${s.sevenMeterGoals},${s.sevenMeterMisses},${s.gamesPlayed}',
      );
    }

    _downloadCsv(buffer.toString(), '${tournamentName}_Torschuetzen.csv');
  }

  /// Export team table as CSV
  Future<void> exportTeamTable(String tournamentId, String tournamentName) async {
    final teams = await _statsService.getOverallTeamStats(tournamentId);

    final buffer = StringBuffer();
    buffer.writeln('Rang,Team,Sp,S,U,N,Tore,Diff,Pkt');
    for (int i = 0; i < teams.length; i++) {
      final t = teams[i];
      buffer.writeln(
        '${i + 1},"${_escapeCsv(t.teamName)}",${t.played},${t.won},${t.drawn},${t.lost},${t.goalsFor}:${t.goalsAgainst},${t.goalDifference},${t.points}',
      );
    }

    _downloadCsv(buffer.toString(), '${tournamentName}_Tabelle.csv');
  }

  /// Export discipline overview as CSV
  Future<void> exportDiscipline(String tournamentId, String tournamentName) async {
    final records =
        await _disciplinaryService.getDisciplinaryRecords(tournamentId);

    final buffer = StringBuffer();
    buffer.writeln('Spieler,Team,Gelb,2min,Rot,Blau,Gesperrt,Grund');
    for (final r in records) {
      buffer.writeln(
        '"${_escapeCsv(r.playerName)}","${_escapeCsv(r.teamName)}",${r.yellowCards},${r.twoMinuteSuspensions},${r.redCards},${r.blueCards},${r.isSuspended ? "Ja" : "Nein"},"${_escapeCsv(r.suspensionReason ?? "")}"',
      );
    }

    _downloadCsv(buffer.toString(), '${tournamentName}_Disziplin.csv');
  }

  /// Export all games as CSV
  Future<void> exportGames(String tournamentId, String tournamentName) async {
    final games =
        await _gameService.getGamesForTournament(tournamentId).first;

    final buffer = StringBuffer();
    buffer.writeln('Typ,Team A,Team B,Ergebnis,Status,Datum,Platz-ID');
    for (final g in games) {
      final result = g.result != null
          ? '${g.result!.teamAScore}:${g.result!.teamBScore}'
          : '-';
      final status = _statusLabel(g.status);
      final date = g.scheduledTime != null
          ? '${g.scheduledTime!.day}.${g.scheduledTime!.month}.${g.scheduledTime!.year} ${g.scheduledTime!.hour}:${g.scheduledTime!.minute.toString().padLeft(2, '0')}'
          : '-';
      buffer.writeln(
        '"${_gameTypeLabel(g.gameType)}","${_escapeCsv(g.teamAName)}","${_escapeCsv(g.teamBName)}","$result","$status","$date","${_escapeCsv(g.courtId ?? "")}"',
      );
    }

    _downloadCsv(buffer.toString(), '${tournamentName}_Spiele.csv');
  }

  /// Export complete tournament report (all data in one CSV)
  Future<void> exportFullReport(String tournamentId, String tournamentName) async {
    final buffer = StringBuffer();

    // Section 1: Games
    buffer.writeln('=== SPIELE ===');
    final games =
        await _gameService.getGamesForTournament(tournamentId).first;
    buffer.writeln('Typ,Team A,Team B,Ergebnis,Status,Datum');
    for (final g in games) {
      final result = g.result != null
          ? '${g.result!.teamAScore}:${g.result!.teamBScore}'
          : '-';
      buffer.writeln(
        '"${_gameTypeLabel(g.gameType)}","${_escapeCsv(g.teamAName)}","${_escapeCsv(g.teamBName)}","$result","${_statusLabel(g.status)}"',
      );
    }

    buffer.writeln();
    buffer.writeln('=== TABELLE ===');
    final teams = await _statsService.getOverallTeamStats(tournamentId);
    buffer.writeln('Rang,Team,Sp,S,U,N,Tore,Diff,Pkt');
    for (int i = 0; i < teams.length; i++) {
      final t = teams[i];
      buffer.writeln(
        '${i + 1},"${_escapeCsv(t.teamName)}",${t.played},${t.won},${t.drawn},${t.lost},${t.goalsFor}:${t.goalsAgainst},${t.goalDifference},${t.points}',
      );
    }

    buffer.writeln();
    buffer.writeln('=== TORSCHÜTZEN ===');
    final scorers = await _statsService.getTopScorers(tournamentId);
    buffer.writeln('Rang,Spieler,Team,Tore,7m');
    for (int i = 0; i < scorers.length; i++) {
      final s = scorers[i];
      if (s.totalGoals == 0) continue;
      buffer.writeln(
        '${i + 1},"${_escapeCsv(s.playerName)}","${_escapeCsv(s.teamName)}",${s.totalGoals},${s.sevenMeterGoals}',
      );
    }

    buffer.writeln();
    buffer.writeln('=== DISZIPLIN ===');
    final discipline =
        await _disciplinaryService.getDisciplinaryRecords(tournamentId);
    buffer.writeln('Spieler,Team,Gelb,2min,Rot,Blau,Gesperrt');
    for (final r in discipline) {
      buffer.writeln(
        '"${_escapeCsv(r.playerName)}","${_escapeCsv(r.teamName)}",${r.yellowCards},${r.twoMinuteSuspensions},${r.redCards},${r.blueCards},${r.isSuspended ? "Ja" : "Nein"}',
      );
    }

    _downloadCsv(buffer.toString(), '${tournamentName}_Gesamtbericht.csv');
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  String _escapeCsv(String value) {
    return value.replaceAll('"', '""');
  }

  String _statusLabel(GameStatus status) {
    switch (status) {
      case GameStatus.scheduled:
        return 'Geplant';
      case GameStatus.inProgress:
        return 'Live';
      case GameStatus.completed:
        return 'Beendet';
      case GameStatus.cancelled:
        return 'Abgesagt';
      default:
        return status.name;
    }
  }

  String _gameTypeLabel(GameType type) {
    switch (type) {
      case GameType.pool:
        return 'Gruppenspiel';
      case GameType.elimination:
        return 'KO-Spiel';
      case GameType.friendly:
        return 'Freundschaftsspiel';
      default:
        return type.name;
    }
  }

  void _downloadCsv(String content, String filename) {
    downloadCsv(content, filename);
  }
}
