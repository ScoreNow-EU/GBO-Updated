import 'package:flutter/material.dart';
import '../services/team_service.dart';
import '../services/tournament_service.dart';
import 'package:toastification/toastification.dart';

class AdminDataManagementScreen extends StatefulWidget {
  const AdminDataManagementScreen({super.key});

  @override
  State<AdminDataManagementScreen> createState() =>
      _AdminDataManagementScreenState();
}

class _AdminDataManagementScreenState extends State<AdminDataManagementScreen> {
  final TeamService _teamService = TeamService();
  final TournamentService _tournamentService = TournamentService();

  int _teamCount = 0;
  int _tournamentCount = 0;
  bool _isLoading = true;
  bool _isDeletingTeams = false;
  bool _isDeletingTournaments = false;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    setState(() => _isLoading = true);
    try {
      final teams = await _teamService.getAllTeams();
      final tournaments = await _tournamentService.getTournaments().first;
      if (mounted) {
        setState(() {
          _teamCount = teams.length;
          _tournamentCount = tournaments.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteAllTeams() async {
    final confirmed = await _showDeleteConfirmationDialog(
      title: 'Alle Teams löschen',
      message:
          'Es werden $_teamCount Teams unwiderruflich gelöscht. Diese Aktion kann nicht rückgängig gemacht werden.',
      confirmWord: 'LÖSCHEN',
    );

    if (confirmed != true) return;

    setState(() => _isDeletingTeams = true);
    try {
      final teams = await _teamService.getAllTeams();
      int deleted = 0;
      for (final team in teams) {
        await _teamService.deleteTeam(team.id);
        deleted++;
      }
      if (mounted) {
        setState(() {
          _teamCount = 0;
          _isDeletingTeams = false;
        });
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          title: Text('$deleted Teams gelöscht'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeletingTeams = false);
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          title: const Text('Fehler beim Löschen der Teams'),
          description: Text(e.toString()),
          autoCloseDuration: const Duration(seconds: 5),
        );
      }
    }
  }

  Future<void> _deleteAllTournaments() async {
    final confirmed = await _showDeleteConfirmationDialog(
      title: 'Alle Turniere löschen',
      message:
          'Es werden $_tournamentCount Turniere unwiderruflich gelöscht. Diese Aktion kann nicht rückgängig gemacht werden.',
      confirmWord: 'LÖSCHEN',
    );

    if (confirmed != true) return;

    setState(() => _isDeletingTournaments = true);
    try {
      final tournaments = await _tournamentService.getTournaments().first;
      int deleted = 0;
      for (final tournament in tournaments) {
        await _tournamentService.deleteTournament(tournament.id);
        deleted++;
      }
      if (mounted) {
        setState(() {
          _tournamentCount = 0;
          _isDeletingTournaments = false;
        });
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          title: Text('$deleted Turniere gelöscht'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeletingTournaments = false);
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          title: const Text('Fehler beim Löschen der Turniere'),
          description: Text(e.toString()),
          autoCloseDuration: const Duration(seconds: 5),
        );
      }
    }
  }

  Future<bool?> _showDeleteConfirmationDialog({
    required String title,
    required String message,
    required String confirmWord,
  }) {
    final controller = TextEditingController();
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isConfirmed = controller.text == confirmWord;
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.red, size: 28),
                  const SizedBox(width: 12),
                  Expanded(child: Text(title)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message),
                  const SizedBox(height: 20),
                  Text(
                    'Geben Sie "$confirmWord" ein, um zu bestätigen:',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      hintText: confirmWord,
                      border: const OutlineInputBorder(),
                      prefixIcon:
                          const Icon(Icons.lock_outline, color: Colors.red),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Abbrechen'),
                ),
                ElevatedButton(
                  onPressed: isConfirmed
                      ? () => Navigator.of(context).pop(true)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Endgültig löschen'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Datenverwaltung'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Warning banner
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.red.shade700, size: 32),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Text(
                                'Achtung: Löschvorgänge können nicht rückgängig gemacht werden. '
                                'Alle Daten werden dauerhaft aus der Datenbank entfernt.',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Teams section
                      _buildDeleteCard(
                        icon: Icons.group,
                        iconColor: Colors.blue,
                        title: 'Alle Teams löschen',
                        description:
                            'Löscht alle Teams aus der Datenbank. Zugehörige Kader und Turnier-Registrierungen werden ungültig.',
                        count: _teamCount,
                        countLabel: 'Teams in der Datenbank',
                        isDeleting: _isDeletingTeams,
                        onDelete: _teamCount > 0 ? _deleteAllTeams : null,
                      ),

                      const SizedBox(height: 20),

                      // Tournaments section
                      _buildDeleteCard(
                        icon: Icons.emoji_events,
                        iconColor: Colors.orange,
                        title: 'Alle Turniere löschen',
                        description:
                            'Löscht alle Turniere aus der Datenbank. Zugehörige Spiele, Ergebnisse und Spielpläne werden entfernt.',
                        count: _tournamentCount,
                        countLabel: 'Turniere in der Datenbank',
                        isDeleting: _isDeletingTournaments,
                        onDelete: _tournamentCount > 0
                            ? _deleteAllTournaments
                            : null,
                      ),

                      const SizedBox(height: 32),

                      // Refresh button
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: _loadCounts,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Anzahl aktualisieren'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildDeleteCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required int count,
    required String countLabel,
    required bool isDeleting,
    required VoidCallback? onDelete,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: count > 0
                            ? Colors.blue.shade50
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$count $countLabel',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color:
                              count > 0 ? Colors.blue.shade700 : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                isDeleting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : ElevatedButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_forever, size: 18),
                        label: const Text('Alle löschen'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                        ),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
