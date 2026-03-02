import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../services/player_service.dart';
import '../services/team_service.dart';

class BulkAddPlayersScreen extends StatefulWidget {
  final Team? preselectedTeam;
  const BulkAddPlayersScreen({super.key, this.preselectedTeam});

  @override
  State<BulkAddPlayersScreen> createState() => _BulkAddPlayersScreenState();
}

/// Lightweight per-row data — no email required.
class BulkPlayerRow {
  final TextEditingController firstName = TextEditingController();
  final TextEditingController lastName = TextEditingController();
  final TextEditingController jersey = TextEditingController();
  String? gender;

  void dispose() {
    firstName.dispose();
    lastName.dispose();
    jersey.dispose();
  }

  bool get hasData => firstName.text.isNotEmpty || lastName.text.isNotEmpty;
  bool get isComplete => firstName.text.isNotEmpty && lastName.text.isNotEmpty && gender != null;
}

class _BulkAddPlayersScreenState extends State<BulkAddPlayersScreen> {
  final PlayerService _playerService = PlayerService();
  final TeamService _teamService = TeamService();

  bool _isLoading = false;
  bool _teamsLoading = true;
  String? _teamsError;
  List<Team> _teams = [];
  Team? _selectedTeam;
  List<BulkPlayerRow> _rows = [BulkPlayerRow()];

  @override
  void initState() {
    super.initState();
    if (widget.preselectedTeam != null) {
      _selectedTeam = widget.preselectedTeam;
    }
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    setState(() { _teamsLoading = true; _teamsError = null; });
    try {
      final teams = await _teamService.getAllTeams();
      if (mounted) {
        setState(() {
          _teams = teams..sort((a, b) => a.name.compareTo(b.name));
          _teamsLoading = false;
          // Refresh selectedTeam from loaded list so we have latest roster data
          if (widget.preselectedTeam != null) {
            _selectedTeam = _teams.firstWhere(
              (t) => t.id == widget.preselectedTeam!.id,
              orElse: () => widget.preselectedTeam!,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() { _teamsLoading = false; _teamsError = '$e'; });
    }
  }

  @override
  void dispose() {
    for (final r in _rows) r.dispose();
    super.dispose();
  }

  void _ensureTrailingEmpty() {
    if (_rows.isEmpty || _rows.last.hasData) _rows.add(BulkPlayerRow());
  }

  void _removeRow(int i) {
    setState(() {
      _rows[i].dispose();
      _rows.removeAt(i);
      _ensureTrailingEmpty();
    });
  }

  Future<void> _save() async {
    final ready = _rows.where((r) => r.isComplete).toList();
    if (ready.isEmpty) { _toast('Keine vollständigen Einträge', ToastificationType.warning); return; }
    setState(() => _isLoading = true);
    try {
      final newIds = <String>[];
      int created = 0, failed = 0;
      for (final row in ready) {
        final id = await _playerService.addPlayer(Player(
          id: '',
          firstName: row.firstName.text.trim(),
          lastName: row.lastName.text.trim(),
          jerseyNumber: row.jersey.text.trim().isEmpty ? null : row.jersey.text.trim(),
          gender: row.gender!,
          isActive: true,
          createdAt: DateTime.now(),
        ));
        if (id != null) { newIds.add(id); created++; } else { failed++; }
      }
      if (_selectedTeam != null && newIds.isNotEmpty) {
        final updated = _selectedTeam!.copyWith(rosterPlayerIds: [..._selectedTeam!.rosterPlayerIds, ...newIds]);
        await _teamService.updateTeam(_selectedTeam!.id, updated);
      }
      if (mounted) {
        final teamMsg = _selectedTeam != null ? ' • mit ${_selectedTeam!.name} verknüpft' : '';
        _toast('$created Spieler erstellt${failed > 0 ? ', $failed fehler' : ''}$teamMsg', ToastificationType.success);
        Navigator.of(context).pop();
      }
    } catch (e) {
      _toast('Fehler: $e', ToastificationType.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toast(String msg, ToastificationType type) {
    toastification.show(
      context: context, type: type, style: ToastificationStyle.fillColored,
      title: Text(msg), autoCloseDuration: const Duration(seconds: 4), alignment: Alignment.topCenter,
    );
  }

  @override
  Widget build(BuildContext context) {
    final completeCount = _rows.where((r) => r.isComplete).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spieler Import'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save, size: 18),
                label: Text('$completeCount Spieler speichern'),
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.green.shade800),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mannschafts-Auswahl
            Row(
              children: [
                const Text('Mannschaft:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(width: 12),
                SizedBox(
                  width: 340,
                  child: _teamsLoading
                      ? const SizedBox(
                          height: 40,
                          child: Row(children: [
                            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 10),
                            Text('Teams werden geladen…', style: TextStyle(fontSize: 13, color: Colors.grey)),
                          ]),
                        )
                      : _teamsError != null
                          ? Row(children: [
                              Icon(Icons.error_outline, color: Colors.red.shade600, size: 18),
                              const SizedBox(width: 6),
                              Expanded(child: Text('Ladefehler: $_teamsError', style: TextStyle(fontSize: 12, color: Colors.red.shade700))),
                              TextButton(onPressed: _loadTeams, child: const Text('Nochmal')),
                            ])
                          : DropdownButtonFormField<Team>(
                              value: _selectedTeam,
                              hint: Text(_teams.isEmpty ? 'Keine Teams im System' : 'Keine (nur Spieler anlegen)'),
                              decoration: InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: [
                                const DropdownMenuItem<Team>(value: null, child: Text('Ohne Mannschaft')),
                                ..._teams.map((t) => DropdownMenuItem<Team>(value: t, child: Text(t.name))),
                              ],
                              onChanged: (t) => setState(() => _selectedTeam = t),
                            ),
                ),
                const Spacer(),
                Text('$completeCount vollständige Einträge', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 16),

            // Spalten-Header
            Container(
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade200),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: const Row(children: [
                SizedBox(width: 40, child: Text('#', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                Expanded(flex: 3, child: Text('Vorname *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                SizedBox(width: 8),
                Expanded(flex: 3, child: Text('Nachname *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                SizedBox(width: 8),
                SizedBox(width: 70, child: Text('Trikot', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                SizedBox(width: 8),
                SizedBox(width: 140, child: Text('Geschlecht *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                SizedBox(width: 40),
              ]),
            ),

            // Zeilen
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                ),
                child: ListView.builder(
                  itemCount: _rows.length,
                  itemExtent: 58.0,
                  itemBuilder: (_, i) => _buildRow(i),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Footer
            Row(children: [
              OutlinedButton.icon(
                onPressed: () => setState(() => _rows.add(BulkPlayerRow())),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Zeile hinzufügen'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.green.shade700),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Abbrechen'),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(int i) {
    final row = _rows[i];
    final InputDecoration dec = InputDecoration(
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    );
    return Container(
      decoration: BoxDecoration(
        color: i.isOdd ? Colors.grey.shade50 : Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 40, child: Text('${i + 1}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12))),
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: row.firstName,
              style: const TextStyle(fontSize: 12),
              decoration: dec.copyWith(hintText: 'Vorname'),
              onChanged: (_) => setState(_ensureTrailingEmpty),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: row.lastName,
              style: const TextStyle(fontSize: 12),
              decoration: dec.copyWith(hintText: 'Nachname'),
              onChanged: (_) => setState(_ensureTrailingEmpty),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: TextFormField(
              controller: row.jersey,
              style: const TextStyle(fontSize: 12),
              decoration: dec.copyWith(hintText: 'Nr.'),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 140,
            child: DropdownButtonFormField<String>(
              value: row.gender,
              isDense: true,
              decoration: dec,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              hint: Text('–', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Männlich', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'female', child: Text('Weiblich', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'divers', child: Text('Divers', style: TextStyle(fontSize: 12))),
              ],
              onChanged: (v) => setState(() { row.gender = v; _ensureTrailingEmpty(); }),
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade300, size: 18),
              onPressed: _rows.length > 1 ? () => _removeRow(i) : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ),
        ],
      ),
    );
  }
}
