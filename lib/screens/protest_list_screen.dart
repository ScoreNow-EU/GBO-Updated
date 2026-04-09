import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../models/protest.dart';
import '../models/user.dart' as app_user;
import '../services/protest_service.dart';
import '../services/auth_service.dart';

class ProtestListScreen extends StatefulWidget {
  final String tournamentId;
  final String? tournamentName;

  const ProtestListScreen({
    super.key,
    required this.tournamentId,
    this.tournamentName,
  });

  @override
  State<ProtestListScreen> createState() => _ProtestListScreenState();
}

class _ProtestListScreenState extends State<ProtestListScreen> {
  final ProtestService _protestService = ProtestService();
  final AuthService _authService = AuthService();
  app_user.User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getCurrentUser();
    if (mounted) setState(() => _currentUser = user);
  }

  bool get _canResolve {
    if (_currentUser == null) return false;
    return _currentUser!.roles.contains(app_user.UserRole.admin) ||
        _currentUser!.roles.contains(app_user.UserRole.teamRHD) ||
        _currentUser!.roles.contains(app_user.UserRole.delegate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Proteste${widget.tournamentName != null ? ' – ${widget.tournamentName}' : ''}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red[700],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<List<Protest>>(
        stream: _protestService.streamProtestsForTournament(widget.tournamentId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Fehler: ${snapshot.error}',
                  style: TextStyle(color: Colors.red[700])),
            );
          }

          final protests = snapshot.data ?? [];

          if (protests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.gavel, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('Keine Proteste eingereicht',
                      style: TextStyle(
                          fontSize: 16, color: Colors.grey[600])),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: protests.length,
            itemBuilder: (context, index) =>
                _buildProtestCard(protests[index]),
          );
        },
      ),
    );
  }

  Widget _buildProtestCard(Protest protest) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                _buildStatusBadge(protest.status),
                const Spacer(),
                Text(
                  _formatDate(protest.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Filed by
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  'Eingereicht von: ${protest.filedByName}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Reason
            Text(
              protest.reason,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),

            if (protest.description != null) ...[
              const SizedBox(height: 6),
              Text(
                protest.description!,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ],

            // Resolution
            if (protest.resolution != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: protest.status == ProtestStatus.accepted
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Entscheidung',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: protest.status == ProtestStatus.accepted
                            ? Colors.green[700]
                            : Colors.red[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(protest.resolution!,
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],

            // Action buttons for authorized users
            if (_canResolve &&
                (protest.status == ProtestStatus.filed ||
                    protest.status == ProtestStatus.underReview)) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (protest.status == ProtestStatus.filed)
                    OutlinedButton.icon(
                      onPressed: () => _updateStatus(
                          protest, ProtestStatus.underReview),
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('In Prüfung'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange[700],
                        side: BorderSide(color: Colors.orange[300]!),
                      ),
                    ),
                  if (protest.status == ProtestStatus.filed)
                    const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _showResolveDialog(protest, ProtestStatus.accepted),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Annehmen'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green[700],
                      side: BorderSide(color: Colors.green[300]!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _showResolveDialog(protest, ProtestStatus.rejected),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Ablehnen'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red[700],
                      side: BorderSide(color: Colors.red[300]!),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ProtestStatus status) {
    Color bgColor;
    Color textColor;
    String label;
    IconData icon;

    switch (status) {
      case ProtestStatus.filed:
        bgColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        label = 'Eingereicht';
        icon = Icons.flag;
        break;
      case ProtestStatus.underReview:
        bgColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        label = 'In Prüfung';
        icon = Icons.visibility;
        break;
      case ProtestStatus.accepted:
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        label = 'Angenommen';
        icon = Icons.check_circle;
        break;
      case ProtestStatus.rejected:
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        label = 'Abgelehnt';
        icon = Icons.cancel;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textColor)),
        ],
      ),
    );
  }

  Future<void> _updateStatus(Protest protest, ProtestStatus status) async {
    try {
      final currentUser = _authService.currentFirebaseUser;
      await _protestService.resolveProtest(
        protestId: protest.id,
        status: status,
        resolution: status == ProtestStatus.underReview
            ? 'Wird geprüft'
            : '',
        resolvedByUserId: currentUser?.uid ?? '',
      );
      if (mounted) {
        toastification.show(
          context: context,
          title: const Text('Status aktualisiert'),
          type: ToastificationType.success,
          autoCloseDuration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          title: Text('Fehler: $e'),
          type: ToastificationType.error,
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    }
  }

  Future<void> _showResolveDialog(
      Protest protest, ProtestStatus targetStatus) async {
    final resolutionController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(targetStatus == ProtestStatus.accepted
            ? 'Protest annehmen'
            : 'Protest ablehnen'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Grund: ${protest.reason}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: resolutionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Begründung der Entscheidung *',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  hintText: 'Erläutern Sie die Entscheidung...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              if (resolutionController.text.trim().isEmpty) {
                toastification.show(
                  context: context,
                  title: const Text('Bitte geben Sie eine Begründung an'),
                  type: ToastificationType.warning,
                  autoCloseDuration: const Duration(seconds: 2),
                );
                return;
              }
              Navigator.of(context).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: targetStatus == ProtestStatus.accepted
                  ? Colors.green[700]
                  : Colors.red[700],
              foregroundColor: Colors.white,
            ),
            child: Text(targetStatus == ProtestStatus.accepted
                ? 'Annehmen'
                : 'Ablehnen'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final currentUser = _authService.currentFirebaseUser;
      await _protestService.resolveProtest(
        protestId: protest.id,
        status: targetStatus,
        resolution: resolutionController.text.trim(),
        resolvedByUserId: currentUser?.uid ?? '',
      );
      toastification.show(
        context: context,
        title: Text(targetStatus == ProtestStatus.accepted
            ? 'Protest angenommen'
            : 'Protest abgelehnt'),
        type: ToastificationType.success,
        autoCloseDuration: const Duration(seconds: 3),
      );
    }
    resolutionController.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
