import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../models/protest.dart';
import '../services/protest_service.dart';
import '../services/auth_service.dart';

class ProtestScreen extends StatefulWidget {
  final String tournamentId;
  final String? gameId;
  final String? gameDisplayName;
  final String teamId;

  const ProtestScreen({
    super.key,
    required this.tournamentId,
    this.gameId,
    this.gameDisplayName,
    required this.teamId,
  });

  @override
  State<ProtestScreen> createState() => _ProtestScreenState();
}

class _ProtestScreenState extends State<ProtestScreen> {
  final ProtestService _protestService = ProtestService();
  final AuthService _authService = AuthService();
  final _reasonController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitProtest() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      toastification.show(
        context: context,
        title: const Text('Bitte geben Sie einen Grund an'),
        type: ToastificationType.warning,
        autoCloseDuration: const Duration(seconds: 3),
      );
      return;
    }

    if (widget.gameId == null) {
      toastification.show(
        context: context,
        title: const Text('Kein Spiel ausgewählt'),
        type: ToastificationType.error,
        autoCloseDuration: const Duration(seconds: 3),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final currentUser = _authService.currentFirebaseUser;
      if (currentUser == null) {
        toastification.show(
          context: context,
          title: const Text('Sie sind nicht angemeldet'),
          type: ToastificationType.error,
          autoCloseDuration: const Duration(seconds: 3),
        );
        return;
      }

      final protest = Protest(
        id: '',
        gameId: widget.gameId!,
        tournamentId: widget.tournamentId,
        filedByTeamId: widget.teamId,
        filedByUserId: currentUser.uid,
        filedByName: currentUser.displayName ?? 'Unbekannt',
        reason: reason,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        createdAt: DateTime.now(),
      );

      await _protestService.createProtest(protest);

      if (mounted) {
        toastification.show(
          context: context,
          title: const Text('Protest erfolgreich eingereicht'),
          type: ToastificationType.success,
          autoCloseDuration: const Duration(seconds: 3),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          title: Text('Fehler: $e'),
          type: ToastificationType.error,
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Protest einreichen',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red[700],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Game Info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.sports_handball, color: Colors.grey[600]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Spiel',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey)),
                        Text(
                          widget.gameDisplayName ?? widget.gameId ?? 'Kein Spiel',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Reason
            const Text('Grund des Protests *',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'z.B. Regelverstoß, Spielerwechsel nicht regelkonform...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            // Description
            const Text('Detaillierte Beschreibung (optional)',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Weitere Details zum Vorfall...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),

            // Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Der Protest wird an die Schiedsrichter, den Delegierten, den Turnierveranstalter und Team RHD weitergeleitet.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.orange[800]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitProtest,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.gavel),
                label: Text(
                    _isSubmitting ? 'Wird eingereicht...' : 'Protest einreichen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
