import 'package:flutter/material.dart';
import 'dart:async';
import '../models/tournament.dart';
import '../models/game.dart';
import '../models/referee.dart';
import '../models/kampfgericht_member.dart';
import '../models/court.dart';
import '../models/assignment_constraints.dart';
import '../services/game_service.dart';
import '../services/referee_service.dart';
import '../services/kampfgericht_service.dart';
import '../services/court_service.dart';
import '../services/assignment_solver_service.dart';
import 'package:toastification/toastification.dart';

/// Screen for AI-driven assignment of referees and Kampfgericht to tournament games.
///
/// Shows a game list with current assignments, per-game constraint editing,
/// a "KI-Zuordnung starten" button, and results with break-time summary.
class TournamentAssignmentScreen extends StatefulWidget {
  final Tournament tournament;

  const TournamentAssignmentScreen({super.key, required this.tournament});

  @override
  State<TournamentAssignmentScreen> createState() =>
      _TournamentAssignmentScreenState();
}

class _TournamentAssignmentScreenState
    extends State<TournamentAssignmentScreen> {
  final GameService _gameService = GameService();
  final RefereeService _refereeService = RefereeService();
  final KampfgerichtService _kampfgerichtService = KampfgerichtService();
  final CourtService _courtService = CourtService();
  final AssignmentSolverService _solverService = AssignmentSolverService();

  List<Game> _games = [];
  List<Referee> _referees = [];
  List<KampfgerichtMember> _kampfgerichtMembers = [];
  List<Court> _courts = [];

  /// Per-game constraints (gameId → constraint)
  Map<String, GameAssignmentConstraint> _constraints = {};

  /// Solver result
  SolverResponse? _solverResponse;

  bool _isLoading = true;
  bool _isSolving = false;
  bool _isApplying = false;
  String? _errorMessage;
  String _selectedView = 'games'; // 'games', 'results', 'summary'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _gameService.getGamesForTournament(widget.tournament.id).first,
        _refereeService.getAllReferees(),
        _kampfgerichtService.getAllMembers(),
        _courtService.getCourts().first,
      ]);

      final allGames = results[0] as List<Game>;
      // Only include games that have a scheduled time (needed for solver)
      final scheduledGames =
          allGames.where((g) => g.scheduledTime != null).toList();
      scheduledGames.sort((a, b) => a.scheduledTime!.compareTo(b.scheduledTime!));

      // Filter referees to those invited to this tournament
      final invitedRefereeIds = widget.tournament.refereeInvitations
          .map((inv) => inv.refereeId)
          .toSet();
      final invitedReferees = (results[1] as List<Referee>)
          .where((r) => invitedRefereeIds.contains(r.id))
          .toList();

      // Filter kampfgericht to those invited
      final invitedKgIds = widget.tournament.kampfgerichtInvitations
          .map((inv) => inv.memberId)
          .toSet();
      final invitedKg = (results[2] as List<KampfgerichtMember>)
          .where((m) => invitedKgIds.contains(m.id))
          .toList();

      setState(() {
        _games = scheduledGames;
        _referees = invitedReferees;
        _kampfgerichtMembers = invitedKg;
        _courts = results[3] as List<Court>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Fehler beim Laden: $e';
      });
    }
  }

  Future<void> _runSolver() async {
    if (_games.isEmpty) {
      _showToast('Keine geplanten Spiele vorhanden', ToastificationType.warning);
      return;
    }

    if (_referees.isEmpty) {
      _showToast(
          'Keine Schiedsrichter eingeladen', ToastificationType.warning);
      return;
    }

    setState(() {
      _isSolving = true;
      _errorMessage = null;
      _solverResponse = null;
    });

    try {
      final response = await _solverService.solveAssignment(
        games: _games,
        referees: _referees,
        kampfgerichtMembers: _kampfgerichtMembers,
        refereeInvitations: widget.tournament.refereeInvitations,
        kampfgerichtInvitations: widget.tournament.kampfgerichtInvitations,
        constraints: _constraints.values.toList(),
      );

      setState(() {
        _solverResponse = response;
        _isSolving = false;
        _selectedView = 'results';
      });

      if (response.warnings.isNotEmpty) {
        _showToast(
          'Zuordnung berechnet mit ${response.warnings.length} Hinweis(en)',
          ToastificationType.warning,
        );
      } else {
        _showToast('Zuordnung erfolgreich berechnet!', ToastificationType.success);
      }
    } catch (e) {
      setState(() {
        _isSolving = false;
        _errorMessage = 'Solver-Fehler: $e';
      });
      _showToast('Fehler bei KI-Zuordnung: $e', ToastificationType.error);
    }
  }

  Future<void> _applyAssignment() async {
    if (_solverResponse == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zuordnung übernehmen?'),
        content: const Text(
          'Die berechnete Zuordnung wird auf alle Spiele angewendet. '
          'Bestehende Zuordnungen werden überschrieben.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Übernehmen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isApplying = true);

    try {
      await _solverService.applyAssignment(
        tournamentId: widget.tournament.id,
        results: _solverResponse!.assignments,
      );
      _showToast('Zuordnung erfolgreich übernommen!', ToastificationType.success);
      await _loadData(); // Reload to show updated assignments
    } catch (e) {
      _showToast('Fehler beim Übernehmen: $e', ToastificationType.error);
    } finally {
      setState(() => _isApplying = false);
    }
  }

  Future<void> _clearAllAssignments() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alle Zuordnungen löschen?'),
        content: const Text(
          'Alle Schiedsrichter- und Kampfgericht-Zuordnungen '
          'werden von allen Spielen entfernt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _solverService.clearAssignments(widget.tournament.id);
      _showToast('Alle Zuordnungen gelöscht', ToastificationType.success);
      setState(() => _solverResponse = null);
      await _loadData();
    } catch (e) {
      _showToast('Fehler: $e', ToastificationType.error);
    }
  }

  void _showToast(String message, ToastificationType type) {
    toastification.show(
      context: context,
      type: type,
      style: ToastificationStyle.fillColored,
      title: Text(message),
      alignment: Alignment.topRight,
      autoCloseDuration: const Duration(seconds: 4),
      showProgressBar: false,
    );
  }

  String _getOfficialName(String? id) {
    if (id == null) return '–';
    // Check referees
    final referee = _referees.where((r) => r.id == id).firstOrNull;
    if (referee != null) return referee.fullName;
    // Check kampfgericht
    final kg = _kampfgerichtMembers.where((m) => m.id == id).firstOrNull;
    if (kg != null) return kg.fullName;
    return 'Unbekannt';
  }

  String _getCourtName(String? courtId) {
    if (courtId == null) return '–';
    final court = _courts.where((c) => c.id == courtId).firstOrNull;
    return court?.name ?? '–';
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '–';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '–';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Zuordnung: ${widget.tournament.name}'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          if (_solverResponse != null)
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              tooltip: 'Zuordnung übernehmen',
              onPressed: _isApplying ? null : _applyAssignment,
            ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Alle Zuordnungen löschen',
            onPressed: _clearAllAssignments,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Daten neu laden',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(_errorMessage!,
                          style: TextStyle(color: Colors.red.shade700)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Erneut versuchen'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildStatsBar(),
                    _buildViewSelector(),
                    Expanded(child: _buildContent()),
                  ],
                ),
      floatingActionButton: !_isLoading && _errorMessage == null
          ? FloatingActionButton.extended(
              onPressed: _isSolving ? null : _runSolver,
              backgroundColor: _isSolving ? Colors.grey : Colors.deepPurple,
              icon: _isSolving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_fix_high, color: Colors.white),
              label: Text(
                _isSolving ? 'Berechne...' : 'KI-Zuordnung starten',
                style: const TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildStatsBar() {
    final assignedGames = _games
        .where((g) =>
            g.referee1Id != null ||
            g.referee2Id != null ||
            g.timekeeperId != null ||
            g.scorekeeperId != null)
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: Colors.deepPurple.shade50,
      child: Row(
        children: [
          _buildStatChip(
              Icons.sports, '${_games.length} Spiele', Colors.deepPurple),
          const SizedBox(width: 12),
          _buildStatChip(Icons.sports_hockey,
              '${_referees.length} Schiedsrichter', Colors.purple),
          const SizedBox(width: 12),
          _buildStatChip(Icons.gavel,
              '${_kampfgerichtMembers.length} Kampfgericht', Colors.teal),
          const SizedBox(width: 12),
          _buildStatChip(Icons.assignment_turned_in,
              '$assignedGames zugeordnet', Colors.green),
          const Spacer(),
          if (_constraints.isNotEmpty)
            Chip(
              avatar: const Icon(Icons.tune, size: 16),
              label: Text('${_constraints.length} Einschränkungen'),
              backgroundColor: Colors.orange.shade100,
            ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildViewSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildViewTab('games', 'Spiele & Einschränkungen', Icons.list),
          if (_solverResponse != null)
            _buildViewTab('results', 'Ergebnisse', Icons.assignment),
          if (_solverResponse != null)
            _buildViewTab('summary', 'Zusammenfassung', Icons.analytics),
        ],
      ),
    );
  }

  Widget _buildViewTab(String key, String label, IconData icon) {
    final isSelected = _selectedView == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedView = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? Colors.deepPurple : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: isSelected ? Colors.white : Colors.grey.shade600),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedView) {
      case 'results':
        return _buildResultsView();
      case 'summary':
        return _buildSummaryView();
      default:
        return _buildGamesView();
    }
  }

  // ---- Games & Constraints View ----

  Widget _buildGamesView() {
    if (_games.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Keine geplanten Spiele vorhanden',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Spiele müssen erst im Zeitplan erstellt und eingeplant werden.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _games.length,
      itemBuilder: (context, index) {
        final game = _games[index];
        return _buildGameCard(game);
      },
    );
  }

  Widget _buildGameCard(Game game) {
    final constraint = _constraints[game.id];
    final hasConstraint = constraint != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: hasConstraint
            ? BorderSide(color: Colors.orange.shade300, width: 1.5)
            : BorderSide.none,
      ),
      child: ExpansionTile(
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _formatTime(game.scheduledTime),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            Text(
              _formatDate(game.scheduledTime),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        title: Text(
          game.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            if (game.courtId != null) ...[
              Icon(Icons.place, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 2),
              Text(_getCourtName(game.courtId),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(width: 12),
            ],
            // Show current assignments inline
            if (game.referee1Id != null)
              _buildMiniAssignment('SR1', _getOfficialName(game.referee1Id)),
            if (game.referee2Id != null)
              _buildMiniAssignment('SR2', _getOfficialName(game.referee2Id)),
            if (game.timekeeperId != null)
              _buildMiniAssignment('ZN', _getOfficialName(game.timekeeperId)),
            if (game.scorekeeperId != null)
              _buildMiniAssignment('SK', _getOfficialName(game.scorekeeperId)),
          ],
        ),
        trailing: hasConstraint
            ? Icon(Icons.tune, color: Colors.orange.shade600)
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildConstraintEditor(game),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniAssignment(String role, String name) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$role: $name',
        style: const TextStyle(fontSize: 10, color: Colors.green),
      ),
    );
  }

  Widget _buildConstraintEditor(Game game) {
    final constraint =
        _constraints[game.id] ?? GameAssignmentConstraint(gameId: game.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Text('Einschränkungen für dieses Spiel',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
                fontSize: 14)),
        const SizedBox(height: 12),

        // Required license level
        Row(
          children: [
            const SizedBox(
                width: 180,
                child:
                    Text('Min. Lizenzstufe:', style: TextStyle(fontSize: 13))),
            Expanded(
              child: DropdownButtonFormField<String?>(
                value: constraint.requiredLicenseLevel,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Keine Einschränkung')),
                  ...LicenseLevels.ordered.map((level) =>
                      DropdownMenuItem(value: level, child: Text(level))),
                ],
                onChanged: (value) {
                  _updateConstraint(game.id, constraint.copyWith(requiredLicenseLevel: value));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Manual referee 1
        _buildManualAssignDropdown(
          label: 'SR 1 (fest):',
          value: constraint.manualReferee1Id,
          officials: _referees.map((r) => MapEntry(r.id, r.fullName)).toList(),
          onChanged: (v) =>
              _updateConstraint(game.id, constraint.copyWith(manualReferee1Id: v)),
        ),
        const SizedBox(height: 8),

        // Manual referee 2
        _buildManualAssignDropdown(
          label: 'SR 2 (fest):',
          value: constraint.manualReferee2Id,
          officials: _referees.map((r) => MapEntry(r.id, r.fullName)).toList(),
          onChanged: (v) =>
              _updateConstraint(game.id, constraint.copyWith(manualReferee2Id: v)),
        ),
        const SizedBox(height: 8),

        // Manual timekeeper
        _buildManualAssignDropdown(
          label: 'Zeitnehmer (fest):',
          value: constraint.manualTimekeeperId,
          officials: [
            ..._referees.map((r) => MapEntry(r.id, '${r.fullName} (SR)')),
            ..._kampfgerichtMembers
                .map((m) => MapEntry(m.id, '${m.fullName} (KG)')),
          ],
          onChanged: (v) =>
              _updateConstraint(game.id, constraint.copyWith(manualTimekeeperId: v)),
        ),
        const SizedBox(height: 8),

        // Manual scorekeeper
        _buildManualAssignDropdown(
          label: 'Sekretär (fest):',
          value: constraint.manualScorekeeperId,
          officials: [
            ..._referees.map((r) => MapEntry(r.id, '${r.fullName} (SR)')),
            ..._kampfgerichtMembers
                .map((m) => MapEntry(m.id, '${m.fullName} (KG)')),
          ],
          onChanged: (v) =>
              _updateConstraint(game.id, constraint.copyWith(manualScorekeeperId: v)),
        ),
        const SizedBox(height: 12),

        // Actions
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_constraints.containsKey(game.id))
              TextButton.icon(
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Einschränkung entfernen'),
                onPressed: () {
                  setState(() => _constraints.remove(game.id));
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildManualAssignDropdown({
    required String label,
    required String? value,
    required List<MapEntry<String, String>> officials,
    required ValueChanged<String?> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(width: 180, child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(
          child: DropdownButtonFormField<String?>(
            value: officials.any((o) => o.key == value) ? value : null,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            isExpanded: true,
            items: [
              const DropdownMenuItem(
                  value: null, child: Text('Automatisch (KI)')),
              ...officials.map((o) =>
                  DropdownMenuItem(value: o.key, child: Text(o.value))),
            ],
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  void _updateConstraint(String gameId, GameAssignmentConstraint constraint) {
    setState(() {
      _constraints[gameId] = constraint;
    });
  }

  // ---- Results View ----

  Widget _buildResultsView() {
    if (_solverResponse == null) {
      return const Center(child: Text('Noch keine Ergebnisse'));
    }

    final assignments = _solverResponse!.assignments;

    return Column(
      children: [
        // Warnings banner
        if (_solverResponse!.warnings.isNotEmpty)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Text('Hinweise',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700)),
                  ],
                ),
                const SizedBox(height: 8),
                ..._solverResponse!.warnings.map((w) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $w',
                          style: TextStyle(
                              fontSize: 13, color: Colors.orange.shade800)),
                    )),
              ],
            ),
          ),

        // Apply button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isApplying ? null : _applyAssignment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _isApplying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle, color: Colors.white),
              label: Text(
                _isApplying
                    ? 'Wird übernommen...'
                    : 'Zuordnung auf alle Spiele übernehmen',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Results table
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor:
                  WidgetStateProperty.all(Colors.deepPurple.shade50),
              columns: const [
                DataColumn(label: Text('Spiel')),
                DataColumn(label: Text('Uhrzeit')),
                DataColumn(label: Text('Feld')),
                DataColumn(label: Text('SR 1')),
                DataColumn(label: Text('SR 2')),
                DataColumn(label: Text('Zeitnehmer')),
                DataColumn(label: Text('Sekretär')),
              ],
              rows: assignments.map((a) {
                final game =
                    _games.where((g) => g.id == a.gameId).firstOrNull;
                return DataRow(cells: [
                  DataCell(Text(game?.displayName ?? a.gameId,
                      style: const TextStyle(fontWeight: FontWeight.w500))),
                  DataCell(Text(_formatTime(game?.scheduledTime))),
                  DataCell(Text(_getCourtName(game?.courtId))),
                  DataCell(Text(_getOfficialName(a.referee1Id))),
                  DataCell(Text(_getOfficialName(a.referee2Id))),
                  DataCell(Text(_getOfficialName(a.timekeeperId))),
                  DataCell(Text(_getOfficialName(a.scorekeeperId))),
                ]);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ---- Summary View ----

  Widget _buildSummaryView() {
    if (_solverResponse == null) {
      return const Center(child: Text('Noch keine Ergebnisse'));
    }

    final breakTimes = _solverResponse!.breakTimes;
    // Build per-official summary
    final officialIds = <String>{};
    for (final a in _solverResponse!.assignments) {
      if (a.referee1Id != null) officialIds.add(a.referee1Id!);
      if (a.referee2Id != null) officialIds.add(a.referee2Id!);
      if (a.timekeeperId != null) officialIds.add(a.timekeeperId!);
      if (a.scorekeeperId != null) officialIds.add(a.scorekeeperId!);
    }

    // Count assignments per official
    final assignmentCounts = <String, int>{};
    for (final a in _solverResponse!.assignments) {
      for (final id in [
        a.referee1Id,
        a.referee2Id,
        a.timekeeperId,
        a.scorekeeperId
      ]) {
        if (id != null) {
          assignmentCounts[id] = (assignmentCounts[id] ?? 0) + 1;
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Optimality
          Card(
            color: _solverResponse!.isOptimal
                ? Colors.green.shade50
                : Colors.orange.shade50,
            child: ListTile(
              leading: Icon(
                _solverResponse!.isOptimal
                    ? Icons.check_circle
                    : Icons.warning,
                color: _solverResponse!.isOptimal ? Colors.green : Colors.orange,
              ),
              title: Text(_solverResponse!.isOptimal
                  ? 'Optimale Lösung gefunden'
                  : 'Lösung mit Einschränkungen'),
              subtitle: Text(
                '${_solverResponse!.assignments.length} Spiele zugeordnet, '
                '${officialIds.length} Officials eingesetzt',
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Per-official stats
          Text('Einsatzübersicht pro Official',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800)),
          const SizedBox(height: 12),

          ...officialIds.map((id) {
            final name = _getOfficialName(id);
            final count = assignmentCounts[id] ?? 0;
            final breaks = breakTimes[id] ?? [];
            final minBreak =
                breaks.isEmpty ? 0 : breaks.reduce((a, b) => a < b ? a : b);
            final avgBreak = breaks.isEmpty
                ? 0
                : (breaks.reduce((a, b) => a + b) / breaks.length).round();

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.deepPurple.shade100,
                  child: Text(
                    name.isNotEmpty ? name[0] : '?',
                    style: TextStyle(color: Colors.deepPurple.shade700),
                  ),
                ),
                title: Text(name),
                subtitle: Text('$count Einsätze'),
                trailing: breaks.isNotEmpty
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Min. Pause: $minBreak Min.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: minBreak < 10
                                      ? Colors.red
                                      : Colors.green.shade700)),
                          Text('Ø Pause: $avgBreak Min.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600)),
                        ],
                      )
                    : null,
              ),
            );
          }),
        ],
      ),
    );
  }
}

// Extension to add copyWith to GameAssignmentConstraint
extension GameAssignmentConstraintCopyWith on GameAssignmentConstraint {
  GameAssignmentConstraint copyWith({
    String? requiredLicenseLevel,
    String? manualReferee1Id,
    String? manualReferee2Id,
    String? manualTimekeeperId,
    String? manualScorekeeperId,
    List<String>? excludedOfficialIds,
  }) {
    return GameAssignmentConstraint(
      gameId: gameId,
      requiredLicenseLevel: requiredLicenseLevel ?? this.requiredLicenseLevel,
      manualReferee1Id: manualReferee1Id ?? this.manualReferee1Id,
      manualReferee2Id: manualReferee2Id ?? this.manualReferee2Id,
      manualTimekeeperId: manualTimekeeperId ?? this.manualTimekeeperId,
      manualScorekeeperId: manualScorekeeperId ?? this.manualScorekeeperId,
      excludedOfficialIds: excludedOfficialIds ?? this.excludedOfficialIds,
    );
  }
}
