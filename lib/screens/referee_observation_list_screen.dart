import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/referee_observation.dart';
import '../services/referee_observation_service.dart';
import '../services/auth_service.dart';
import '../models/user.dart' as app_user;
import 'referee_observation_form_screen.dart';

/// Filterable list of referee observations.
/// [refereeId] — if set, only shows observations for that referee (referee self-view)
/// [submitterId] — if set, only shows observations by that submitter
/// If neither is set, shows all (admin/delegate view)
class RefereeObservationListScreen extends StatefulWidget {
  final String? refereeId;
  final String? submitterId;
  final String? title;

  const RefereeObservationListScreen({
    super.key,
    this.refereeId,
    this.submitterId,
    this.title,
  });

  @override
  State<RefereeObservationListScreen> createState() =>
      _RefereeObservationListScreenState();
}

class _RefereeObservationListScreenState
    extends State<RefereeObservationListScreen> {
  final RefereeObservationService _service = RefereeObservationService();
  final AuthService _authService = AuthService();
  app_user.User? _currentUser;
  late final Stream<List<RefereeObservation>> _stream;

  @override
  void initState() {
    super.initState();
    // Cache the stream so StreamBuilder never re-subscribes on rebuild
    if (widget.refereeId != null) {
      _stream = _service.getObservationsForReferee(widget.refereeId!);
    } else if (widget.submitterId != null) {
      _stream = _service.getObservationsBySubmitter(widget.submitterId!);
    } else {
      _stream = _service.getAllObservations();
    }
    _authService.getCurrentUser().then((u) {
      if (mounted) setState(() => _currentUser = u);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        title: Text(
          widget.title ?? 'Beobachtungen',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: StreamBuilder<List<RefereeObservation>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Fehler: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red)),
            );
          }
          final observations = snapshot.data ?? [];
          if (observations.isEmpty) {
            return const Center(
              child: Text('Keine Beobachtungen vorhanden.',
                  style: TextStyle(color: Colors.black45)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: observations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) =>
                _ObservationCard(
                  observation: observations[i],
                  currentUser: _currentUser,
                  service: _service,
                ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single observation card
// ---------------------------------------------------------------------------
class _ObservationCard extends StatelessWidget {
  final RefereeObservation observation;
  final app_user.User? currentUser;
  final RefereeObservationService service;
  static final _dateFmt = DateFormat('dd.MM.yyyy');

  const _ObservationCard({
    required this.observation,
    required this.currentUser,
    required this.service,
  });

  Color get _statusColor =>
      observation.isSubmitted ? Colors.green : Colors.orange;
  String get _statusLabel =>
      observation.isSubmitted ? 'Eingereicht' : 'Entwurf';

  @override
  Widget build(BuildContext context) {
    final isAdmin = currentUser?.roles.contains(app_user.UserRole.admin) == true;
    final isOwn = currentUser?.id == observation.submitterId;

    return Card(
      color: Colors.white,
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      observation.refereesDisplay,
                      style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _statusColor),
                    ),
                    child: Text(_statusLabel,
                        style: TextStyle(
                            color: _statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 12, color: Colors.black38),
                  const SizedBox(width: 4),
                  Text(observation.submitterName,
                      style: const TextStyle(
                          color: Colors.black54, fontSize: 12)),
                  const Spacer(),
                  const Icon(Icons.calendar_today,
                      size: 12, color: Colors.black38),
                  const SizedBox(width: 4),
                  Text(_dateFmt.format(observation.createdAt),
                      style: const TextStyle(
                          color: Colors.black54, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: observation.templateType == 'delegate'
                          ? Colors.indigo.withOpacity(0.3)
                          : Colors.teal.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      observation.templateType == 'delegate'
                          ? 'Delegierte'
                          : 'Verein',
                      style: const TextStyle(
                          color: Colors.black87, fontSize: 11),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Gesamt: ${observation.overallResult.toStringAsFixed(1)}',
                    style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ],
              ),
              // Admin delete button for drafts / all
              if (isAdmin || (isOwn && observation.isDraft)) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade300,
                        padding: EdgeInsets.zero),
                    icon: const Icon(Icons.delete_outline, size: 14),
                    label: const Text('Löschen', style: TextStyle(fontSize: 12)),
                    onPressed: () => _confirmDelete(context),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDetail(BuildContext context) async {
    // Delegate back to the form screen in read/edit mode
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RefereeObservationFormScreen(
          gameId: observation.gameId,
          tournamentId: observation.tournamentId,
          gameName: observation.refereesDisplay,
          gameDate: '',
          refereeIds: observation.refereeIds,
          refereeNames: observation.refereeNames,
          submitterId: observation.submitterId,
          submitterName: observation.submitterName,
          submitterRole: observation.submitterRole,
          templateType: observation.templateType,
          existingObservation: observation,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Beobachtung löschen'),
        content: const Text('Diese Beobachtung wirklich löschen?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Löschen',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await service.deleteObservation(observation.id);
    }
  }
}
