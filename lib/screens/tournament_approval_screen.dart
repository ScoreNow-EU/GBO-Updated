import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../models/tournament.dart';
import '../models/user.dart' as app_user;
import '../services/tournament_service.dart';

class TournamentApprovalScreen extends StatefulWidget {
  final app_user.User currentUser;

  const TournamentApprovalScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<TournamentApprovalScreen> createState() => _TournamentApprovalScreenState();
}

class _TournamentApprovalScreenState extends State<TournamentApprovalScreen> {
  final TournamentService _tournamentService = TournamentService();
  final TextEditingController _rejectionReasonController = TextEditingController();

  @override
  void dispose() {
    _rejectionReasonController.dispose();
    super.dispose();
  }

  Future<void> _approveTournament(Tournament tournament) async {
    try {
      final updatedTournament = tournament.copyWith(
        approvalStatus: 'approved',
        approvedBy: widget.currentUser.id,
        approvedAt: DateTime.now(),
      );

      await _tournamentService.updateTournament(updatedTournament);

      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          title: const Text('Turnier genehmigt'),
          description: Text('${tournament.name} wurde erfolgreich genehmigt'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          title: const Text('Fehler'),
          description: Text('Fehler beim Genehmigen: $e'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    }
  }

  Future<void> _rejectTournament(Tournament tournament) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Turnier ablehnen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Warum wird das Turnier "${tournament.name}" abgelehnt?',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _rejectionReasonController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Ablehnungsgrund *',
                hintText: 'Bitte geben Sie einen Grund für die Ablehnung an...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_rejectionReasonController.text.trim().isEmpty) {
                toastification.show(
                  context: context,
                  type: ToastificationType.warning,
                  style: ToastificationStyle.fillColored,
                  title: const Text('Grund erforderlich'),
                  description: const Text('Bitte geben Sie einen Grund für die Ablehnung an'),
                  autoCloseDuration: const Duration(seconds: 2),
                );
                return;
              }
              Navigator.of(context).pop(_rejectionReasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ablehnen'),
          ),
        ],
      ),
    );

    if (reason != null && reason.isNotEmpty) {
      try {
        final updatedTournament = tournament.copyWith(
          approvalStatus: 'rejected',
          approvedBy: widget.currentUser.id,
          approvedAt: DateTime.now(),
          rejectionReason: reason,
        );

        await _tournamentService.updateTournament(updatedTournament);

        if (mounted) {
          toastification.show(
            context: context,
            type: ToastificationType.info,
            style: ToastificationStyle.fillColored,
            title: const Text('Turnier abgelehnt'),
            description: Text('${tournament.name} wurde abgelehnt'),
            autoCloseDuration: const Duration(seconds: 3),
          );
        }
      } catch (e) {
        if (mounted) {
          toastification.show(
            context: context,
            type: ToastificationType.error,
            style: ToastificationStyle.fillColored,
            title: const Text('Fehler'),
            description: Text('Fehler beim Ablehnen: $e'),
            autoCloseDuration: const Duration(seconds: 3),
          );
        }
      }
      _rejectionReasonController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Turnier-Freigaben'),
      ),
      body: StreamBuilder<List<Tournament>>(
        stream: _tournamentService.getTournamentsWithCache(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Fehler: ${snapshot.error}'),
            );
          }

          final allTournaments = snapshot.data ?? [];
          final pendingTournaments = allTournaments
              .where((t) => t.approvalStatus == 'pending_approval')
              .toList();

          if (pendingTournaments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Keine Turniere warten auf Freigabe',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pendingTournaments.length,
            itemBuilder: (context, index) {
              final tournament = pendingTournaments[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.pending_actions,
                                  size: 16,
                                  color: Colors.orange.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Ausstehend',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Tournament Name
                      Text(
                        tournament.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Details
                      _buildDetailRow(Icons.location_on, tournament.location),
                      const SizedBox(height: 8),
                      _buildDetailRow(Icons.calendar_today, tournament.dateString),
                      const SizedBox(height: 8),


                      if (tournament.description != null &&
                          tournament.description!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 12),
                        Text(
                          tournament.description!,
                          style: TextStyle(
                            color: Colors.grey[700],
                            height: 1.4,
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _rejectTournament(tournament),
                              icon: const Icon(Icons.close),
                              label: const Text('Ablehnen'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _approveTournament(tournament),
                              icon: const Icon(Icons.check),
                              label: const Text('Genehmigen'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
