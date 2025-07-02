import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../models/tournament.dart';
import '../services/tournament_service.dart';

class RefereeInvitationDialog extends StatefulWidget {
  final List<Tournament> pendingTournaments;
  final String refereeId;
  final VoidCallback onCompleted;

  const RefereeInvitationDialog({
    super.key,
    required this.pendingTournaments,
    required this.refereeId,
    required this.onCompleted,
  });

  @override
  State<RefereeInvitationDialog> createState() => _RefereeInvitationDialogState();
}

class _RefereeInvitationDialogState extends State<RefereeInvitationDialog> {
  final TournamentService _tournamentService = TournamentService();
  int _currentIndex = 0;
  bool _isProcessing = false;

  Tournament get currentTournament => widget.pendingTournaments[_currentIndex];
  bool get isLastTournament => _currentIndex >= widget.pendingTournaments.length - 1;
  bool get hasMultipleTournaments => widget.pendingTournaments.length > 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.8),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.sports_handball,
                    color: Colors.orange.shade600,
                    size: 40,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Turnier-Einladung',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        if (hasMultipleTournaments)
                          Text(
                            '${_currentIndex + 1} von ${widget.pendingTournaments.length}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Tournament Details
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentTournament.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.location_on,
                      'Ort',
                      currentTournament.location,
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      Icons.calendar_today,
                      'Datum',
                      currentTournament.dateString,
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      Icons.category,
                      'Kategorien',
                      currentTournament.categoryDisplayNames,
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      Icons.star,
                      'Punkte',
                      '${currentTournament.points} Punkte',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Können Sie bei diesem Turnier als Schiedsrichter teilnehmen?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Action Buttons
              if (_isProcessing)
                const CircularProgressIndicator()
              else
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            'Ja, ich kann',
                            Colors.green,
                            Icons.check_circle,
                            () => _respondToInvitation('accepted'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            'Nein, kann nicht',
                            Colors.red,
                            Icons.cancel,
                            () => _respondToInvitation('declined'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: _buildActionButton(
                        'Später fragen',
                        Colors.grey,
                        Icons.schedule,
                        () => _respondToInvitation('pending'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue.shade600, size: 20),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String text,
    Color color,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
    );
  }

  Future<void> _respondToInvitation(String response) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final success = await _tournamentService.respondToRefereeInvitation(
        currentTournament.id,
        widget.refereeId,
        response,
      );

      if (!success) {
        if (mounted) {
          toastification.show(
            context: context,
            type: ToastificationType.error,
            style: ToastificationStyle.fillColored,
            title: const Text('Fehler'),
            description: const Text('Antwort konnte nicht gespeichert werden.'),
            autoCloseDuration: const Duration(seconds: 3),
          );
        }
        return;
      }

      // Show success message
      String message = '';
      switch (response) {
        case 'accepted':
          message = 'Zusage erfolgreich gesendet!';
          break;
        case 'declined':
          message = 'Absage erfolgreich gesendet.';
          break;
        case 'pending':
          message = 'Wir fragen Sie später noch einmal.';
          break;
      }

      if (mounted) {
        toastification.show(
          context: context,
          type: response == 'accepted' 
              ? ToastificationType.success 
              : ToastificationType.info,
          style: ToastificationStyle.fillColored,
          title: Text(response == 'accepted' ? 'Zusage!' : 'Antwort gespeichert'),
          description: Text(message),
          autoCloseDuration: const Duration(seconds: 2),
        );
      }

      // Move to next tournament or close dialog
      if (isLastTournament) {
        // All done, close dialog
        if (mounted) {
          Navigator.of(context).pop();
          widget.onCompleted();
        }
      } else {
        // Move to next tournament
        setState(() {
          _currentIndex++;
        });
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          title: const Text('Fehler'),
          description: Text('Ein Fehler ist aufgetreten: $e'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
} 