import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/game.dart';
import '../models/game_event.dart';
import '../models/game_squad.dart';
import '../models/tournament.dart';

/// Generates official Spielbericht PDF for a completed game
class SpielberichtPdfService {
  /// Generate PDF bytes for a single game report
  Future<Uint8List> generateSpielberichtPdf({
    required Game game,
    required Tournament tournament,
    required List<GameEvent> events,
    GameSquad? squadA,
    GameSquad? squadB,
    required Map<String, bool> signatures,
    required Map<String, DateTime?> signatureTimes,
    required Map<String, String> signatureNames,
    required bool isLocked,
    String? referee1Name,
    String? referee2Name,
    String? delegateName,
  }) async {
    final pdf = pw.Document(
      title: 'Spielbericht – ${game.teamAName} vs ${game.teamBName}',
      author: 'RHBL GBO System',
    );

    final result = game.result;
    final sortedEvents = [...events]
      ..sort((a, b) {
        final h = (a.half ?? 1).compareTo(b.half ?? 1);
        return h != 0 ? h : a.gameMinute.compareTo(b.gameMinute);
      });

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildPdfHeader(tournament, game),
        footer: (context) => _buildPdfFooter(context),
        build: (context) => [
          _buildScoreSection(game, result),
          pw.SizedBox(height: 16),
          _buildOfficialsSection(
            referee1Name: referee1Name,
            referee2Name: referee2Name,
            delegateName: delegateName,
          ),
          pw.SizedBox(height: 16),
          if (squadA != null || squadB != null)
            _buildSquadsSection(game, squadA, squadB, events),
          if (squadA != null || squadB != null) pw.SizedBox(height: 16),
          _buildEventsSection(game, sortedEvents),
          pw.SizedBox(height: 16),
          _buildStatsSection(game, events),
          pw.SizedBox(height: 24),
          _buildSignaturesSection(signatures, signatureTimes, signatureNames, isLocked, game),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfHeader(Tournament tournament, Game game) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('SPIELBERICHT',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.Text('Rollstuhlhandball Bundesliga',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(tournament.name,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          pw.SizedBox(height: 2),
          pw.Row(
            children: [
              pw.Text(_gameTypeLabel(game.gameType),
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              pw.SizedBox(width: 16),
              if (game.scheduledTime != null)
                pw.Text(
                  '${_formatDate(game.scheduledTime!)}  ${_formatTime(game.scheduledTime!)}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              pw.SizedBox(width: 16),
              if (game.courtId != null)
                pw.Text('Feld: ${game.courtId}',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ],
          ),
          pw.Divider(),
        ],
      ),
    );
  }

  pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
        'Seite ${context.pageNumber} von ${context.pagesCount} – generiert am ${_formatDate(DateTime.now())}',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
      ),
    );
  }

  pw.Widget _buildScoreSection(Game game, GameResult? result) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  children: [
                    pw.Text('HEIM', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
                    pw.SizedBox(height: 4),
                    pw.Text(game.teamAName,
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.center),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      result != null ? result.finalScore : 'vs',
                      style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
                    ),
                    if (result?.halfTimeScore != null)
                      pw.Text('HZ: ${result!.halfTimeScore}',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                    if (result?.overtimeScoreA != null)
                      pw.Text('V: ${result!.overtimeScoreA}:${result.overtimeScoreB}',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                    if (result?.penaltyScoreA != null)
                      pw.Text('7m-W: ${result!.penaltyScoreA}:${result.penaltyScoreB}',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  children: [
                    pw.Text('GAST', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
                    pw.SizedBox(height: 4),
                    pw.Text(game.teamBName,
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.center),
                  ],
                ),
              ),
            ],
          ),
          if (result?.specialScenario != null) ...[
            pw.SizedBox(height: 8),
            pw.Text('Sonderwertung: ${result!.specialScenario}',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
          ],
          if (result?.resultComment != null && result!.resultComment!.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text('Bemerkung: ${result.resultComment}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildSquadsSection(Game game, GameSquad? squadA, GameSquad? squadB, List<GameEvent> events) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Kaderaufstellungen',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (squadA != null) pw.Expanded(child: _buildSquadTable(game.teamAName, squadA, events, game.teamAId)),
            if (squadA != null && squadB != null) pw.SizedBox(width: 16),
            if (squadB != null) pw.Expanded(child: _buildSquadTable(game.teamBName, squadB, events, game.teamBId)),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildSquadTable(String teamName, GameSquad squad, List<GameEvent> events, String? teamId) {
    // Compute per-player stats from events
    // Match by playerId first, fall back to playerName for legacy events
    Map<String, Map<String, int>> playerStats = {};
    Map<String, Map<String, int>> playerStatsByName = {};
    for (final e in events) {
      if (e.teamId != teamId) continue;
      if (e.playerId != null) {
        playerStats.putIfAbsent(e.playerId!, () => {
          'goals': 0, '7mHit': 0, '7mMiss': 0,
          'yellow': 0, 'twoMin': 0, 'red': 0, 'blue': 0,
        });
        final s = playerStats[e.playerId!]!;
        _applyEventToStats(s, e);
      } else if (e.playerName.isNotEmpty) {
        final key = e.playerName.trim().toLowerCase();
        playerStatsByName.putIfAbsent(key, () => {
          'goals': 0, '7mHit': 0, '7mMiss': 0,
          'yellow': 0, 'twoMin': 0, 'red': 0, 'blue': 0,
        });
        _applyEventToStats(playerStatsByName[key]!, e);
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(teamName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(22),
            1: const pw.FlexColumnWidth(),
            2: const pw.FixedColumnWidth(22),
            3: const pw.FixedColumnWidth(22),
            4: const pw.FixedColumnWidth(28),
            5: const pw.FixedColumnWidth(16),
            6: const pw.FixedColumnWidth(20),
            7: const pw.FixedColumnWidth(16),
            8: const pw.FixedColumnWidth(16),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _tableCell('#', bold: true),
                _tableCell('Name', bold: true),
                _tableCell('Kl.', bold: true),
                _tableCell('T', bold: true),
                _tableCell('7m', bold: true),
                _tableCell('G', bold: true),
                _tableCell('2\'', bold: true),
                _tableCell('R', bold: true),
                _tableCell('B', bold: true),
              ],
            ),
            ...squad.selectedPlayers.map((p) {
              final s = playerStats[p.playerId]
                  ?? playerStatsByName['${p.firstName} ${p.lastName}'.trim().toLowerCase()]
                  ?? {};
              final goals = s['goals'] ?? 0;
              final smHit = s['7mHit'] ?? 0;
              final smMiss = s['7mMiss'] ?? 0;
              final smTotal = smHit + smMiss;
              return pw.TableRow(
                children: [
                  _tableCell(p.jerseyNumber ?? '-'),
                  _tableCell('${p.firstName} ${p.lastName}'),
                  _tableCell(p.classification ?? '-'),
                  _tableCell(goals > 0 ? '$goals' : '-', align: pw.TextAlign.center),
                  _tableCell(smTotal > 0 ? '$smHit/$smTotal' : '-', align: pw.TextAlign.center),
                  _tableCell((s['yellow'] ?? 0) > 0 ? '${s['yellow']}' : '-', align: pw.TextAlign.center),
                  _tableCell((s['twoMin'] ?? 0) > 0 ? '${s['twoMin']}' : '-', align: pw.TextAlign.center),
                  _tableCell((s['red'] ?? 0) > 0 ? '${s['red']}' : '-', align: pw.TextAlign.center),
                  _tableCell((s['blue'] ?? 0) > 0 ? '${s['blue']}' : '-', align: pw.TextAlign.center),
                ],
              );
            }),
          ],
        ),
        if (squad.officials.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text('Offizielle:', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ...squad.officials.map((o) => pw.Text(
                '${o.role}: ${o.name}',
                style: const pw.TextStyle(fontSize: 8),
              )),
        ],
        pw.SizedBox(height: 4),
        pw.Text('Mannschaftsverantwortlicher: ${squad.selectedByName}',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  void _applyEventToStats(Map<String, int> s, GameEvent e) {
    switch (e.eventType) {
      case GameEventType.goal: s['goals'] = (s['goals'] ?? 0) + 1;
      case GameEventType.sevenMeterHit:
        s['goals'] = (s['goals'] ?? 0) + 1;
        s['7mHit'] = (s['7mHit'] ?? 0) + 1;
      case GameEventType.sevenMeterMiss: s['7mMiss'] = (s['7mMiss'] ?? 0) + 1;
      case GameEventType.yellowCard: s['yellow'] = (s['yellow'] ?? 0) + 1;
      case GameEventType.twoMinuteSuspension: s['twoMin'] = (s['twoMin'] ?? 0) + 1;
      case GameEventType.redCard: s['red'] = (s['red'] ?? 0) + 1;
      case GameEventType.blueCard: s['blue'] = (s['blue'] ?? 0) + 1;
      default: break;
    }
  }

  pw.Widget _buildOfficialsSection({
    String? referee1Name,
    String? referee2Name,
    String? delegateName,
  }) {
    final hasOfficials = (referee1Name != null && referee1Name.isNotEmpty) ||
        (referee2Name != null && referee2Name.isNotEmpty) ||
        (delegateName != null && delegateName.isNotEmpty);
    if (!hasOfficials) return pw.SizedBox();

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Spielleitung',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              if (referee1Name != null && referee1Name.isNotEmpty)
                pw.Expanded(
                  child: pw.RichText(text: pw.TextSpan(children: [
                    pw.TextSpan(text: 'SR 1: ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.TextSpan(text: referee1Name, style: const pw.TextStyle(fontSize: 9)),
                  ])),
                ),
              if (referee2Name != null && referee2Name.isNotEmpty)
                pw.Expanded(
                  child: pw.RichText(text: pw.TextSpan(children: [
                    pw.TextSpan(text: 'SR 2: ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.TextSpan(text: referee2Name, style: const pw.TextStyle(fontSize: 9)),
                  ])),
                ),
              if (delegateName != null && delegateName.isNotEmpty)
                pw.Expanded(
                  child: pw.RichText(text: pw.TextSpan(children: [
                    pw.TextSpan(text: 'Delegierter: ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.TextSpan(text: delegateName, style: const pw.TextStyle(fontSize: 9)),
                  ])),
                ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildEventsSection(Game game, List<GameEvent> events) {
    if (events.isEmpty) {
      return pw.Text('Keine Spielereignisse verzeichnet.',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500));
    }

    int sA = 0, sB = 0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Spielereignisse',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(40),
            1: const pw.FixedColumnWidth(32),
            2: const pw.FixedColumnWidth(40),
            3: const pw.FlexColumnWidth(),
            4: const pw.FlexColumnWidth(),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _tableCell('Team', bold: true),
                _tableCell('Zeit', bold: true),
                _tableCell('Stand', bold: true),
                _tableCell('Ereignis', bold: true),
                _tableCell('Person', bold: true),
              ],
            ),
            ...events.map((e) {
              if (e.points > 0) {
                if (e.teamId == game.teamAId) {
                  sA += e.points;
                } else {
                  sB += e.points;
                }
              }
              return pw.TableRow(children: [
                _tableCell(e.teamId == game.teamAId ? 'Heim' : 'Gast'),
                _tableCell('${e.half ?? 1}.${e.gameMinute.toString().padLeft(2, '0')}\''),
                _tableCell(e.points > 0 ? '$sA:$sB' : '–'),
                _tableCell(_eventTypeLabel(e.eventType)),
                _tableCell(e.playerName.isNotEmpty ? e.playerName : '–'),
              ]);
            }),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildStatsSection(Game game, List<GameEvent> events) {
    if (events.isEmpty) return pw.SizedBox();

    final teamAId = game.teamAId;
    final teamBId = game.teamBId;

    int count(String? teamId, GameEventType type) =>
        events.where((e) => e.teamId == teamId && e.eventType == type).length;

    final goalsA = count(teamAId, GameEventType.goal) + count(teamAId, GameEventType.sevenMeterHit);
    final goalsB = count(teamBId, GameEventType.goal) + count(teamBId, GameEventType.sevenMeterHit);
    final smHitA = count(teamAId, GameEventType.sevenMeterHit);
    final smHitB = count(teamBId, GameEventType.sevenMeterHit);
    final smMissA = count(teamAId, GameEventType.sevenMeterMiss);
    final smMissB = count(teamBId, GameEventType.sevenMeterMiss);
    final yellowA = count(teamAId, GameEventType.yellowCard);
    final yellowB = count(teamBId, GameEventType.yellowCard);
    final twoMinA = count(teamAId, GameEventType.twoMinuteSuspension);
    final twoMinB = count(teamBId, GameEventType.twoMinuteSuspension);
    final redA = count(teamAId, GameEventType.redCard);
    final redB = count(teamBId, GameEventType.redCard);
    final blueA = count(teamAId, GameEventType.blueCard);
    final blueB = count(teamBId, GameEventType.blueCard);
    final toA = count(teamAId, GameEventType.timeout);
    final toB = count(teamBId, GameEventType.timeout);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Statistik',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(50),
            1: const pw.FlexColumnWidth(),
            2: const pw.FixedColumnWidth(50),
          },
          children: [
            _statHeaderRow(game.teamAName, game.teamBName),
            _statRow('$goalsA', 'Tore', '$goalsB'),
            _statRow('$smHitA/${smHitA + smMissA}', '7m (Treffer/Ges.)', '$smHitB/${smHitB + smMissB}'),
            _statRow('$yellowA', 'Verwarnungen', '$yellowB'),
            _statRow('$twoMinA', '2-Min Strafen', '$twoMinB'),
            _statRow('$redA', 'Rote Karten', '$redB'),
            if (blueA > 0 || blueB > 0) _statRow('$blueA', 'Blaue Karten', '$blueB'),
            _statRow('$toA', 'Auszeiten', '$toB'),
          ],
        ),
      ],
    );
  }

  pw.TableRow _statHeaderRow(String teamA, String teamB) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: [
        _tableCell(teamA, bold: true),
        _tableCell('', bold: true),
        _tableCell(teamB, bold: true),
      ],
    );
  }

  pw.TableRow _statRow(String valA, String label, String valB) {
    return pw.TableRow(children: [
      _tableCell(valA, align: pw.TextAlign.center),
      _tableCell(label, align: pw.TextAlign.center),
      _tableCell(valB, align: pw.TextAlign.center),
    ]);
  }

  pw.Widget _buildSignaturesSection(
    Map<String, bool> signatures,
    Map<String, DateTime?> signatureTimes,
    Map<String, String> signatureNames,
    bool isLocked,
    Game game,
  ) {
    final roles = ['teamACoach', 'teamBCoach', 'referee1', 'referee2', 'delegate'];
    final labels = {
      'teamACoach': 'Trainer ${game.teamAName}',
      'teamBCoach': 'Trainer ${game.teamBName}',
      'referee1': 'Schiedsrichter 1',
      'referee2': 'Schiedsrichter 2',
      'delegate': 'Delegierter',
    };

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Unterschriften',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        if (isLocked)
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 4, bottom: 8),
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
              color: PdfColors.green50,
              border: pw.Border.all(color: PdfColors.green300),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text('Spielbericht abgeschlossen',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
          ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FixedColumnWidth(50),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _tableCell('Rolle', bold: true),
                _tableCell('Status', bold: true),
                _tableCell('Name', bold: true),
                _tableCell('Zeitpunkt', bold: true),
              ],
            ),
            ...roles.map((role) {
              final signed = signatures[role] ?? false;
              final signedAt = signatureTimes[role];
              final name = signatureNames[role] ?? '';
              return pw.TableRow(children: [
                _tableCell(labels[role] ?? role),
                _tableCell(signed ? '✓' : '–', align: pw.TextAlign.center),
                _tableCell(signed ? name : '–'),
                _tableCell(signed && signedAt != null
                    ? '${_formatDate(signedAt)} ${_formatTime(signedAt)}'
                    : '–'),
              ]);
            }),
          ],
        ),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────

  pw.Widget _tableCell(String text, {bool bold = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(text,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
          textAlign: align),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _gameTypeLabel(GameType type) {
    switch (type) {
      case GameType.pool:
        return 'Gruppenspiel';
      case GameType.elimination:
        return 'K.O.-Runde';
      case GameType.friendly:
        return 'Freundschaftsspiel';
    }
  }

  String _eventTypeLabel(GameEventType type) {
    switch (type) {
      case GameEventType.goal:
        return 'Tor';
      case GameEventType.sevenMeterHit:
        return '7m Treffer';
      case GameEventType.sevenMeterMiss:
        return '7m Verfehlt';
      case GameEventType.yellowCard:
        return 'Gelbe Karte';
      case GameEventType.twoMinuteSuspension:
        return '2-Min';
      case GameEventType.redCard:
        return 'Rote Karte';
      case GameEventType.blueCard:
        return 'Blaue Karte';
      case GameEventType.timeout:
        return 'Auszeit';
      case GameEventType.substitution:
        return 'Wechsel';
    }
  }
}
