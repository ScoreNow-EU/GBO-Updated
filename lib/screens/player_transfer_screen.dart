import 'package:flutter/material.dart';
import '../models/transfer.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../services/transfer_service.dart';
import '../services/player_service.dart';
import '../services/team_service.dart';
import '../services/auth_service.dart';
import '../models/user.dart' as app_user;
import '../utils/responsive_helper.dart';

class PlayerTransferScreen extends StatefulWidget {
  const PlayerTransferScreen({super.key});

  @override
  State<PlayerTransferScreen> createState() => _PlayerTransferScreenState();
}

class _PlayerTransferScreenState extends State<PlayerTransferScreen> {
  final TransferService _transferService = TransferService();
  final PlayerService _playerService = PlayerService();
  final TeamService _teamService = TeamService();
  final AuthService _authService = AuthService();

  List<Transfer> _transfers = [];
  app_user.User? _currentUser;
  String _filter = 'Alle';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _currentUser = await _authService.getCurrentUser();
      _transfers = await _transferService.getAllTransfers();
    } catch (e) {
      debugPrint('Error loading transfers: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  List<Transfer> get _filteredTransfers {
    if (_filter == 'Alle') return _transfers;
    if (_filter == 'Offen') return _transfers.where((t) => t.status == TransferStatus.requested).toList();
    if (_filter == 'Genehmigt') return _transfers.where((t) => t.status == TransferStatus.approved).toList();
    if (_filter == 'Abgelehnt') return _transfers.where((t) => t.status == TransferStatus.rejected).toList();
    return _transfers;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveHelper.isMobile(screenWidth);

    final pendingCount = _transfers.where((t) => t.status == TransferStatus.requested).length;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.swap_horiz, color: Colors.purple.shade700, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spielertransfers',
                      style: TextStyle(fontSize: isMobile ? 20 : 28, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '$pendingCount offene Anfrage${pendingCount == 1 ? '' : 'n'}',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showRequestTransferDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Transfer anfragen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Filter chips
          Wrap(
            spacing: 8,
            children: ['Alle', 'Offen', 'Genehmigt', 'Abgelehnt'].map((f) {
              return FilterChip(
                label: Text(f),
                selected: _filter == f,
                onSelected: (_) => setState(() => _filter = f),
                selectedColor: Colors.purple.shade100,
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Transfers list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTransfers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.swap_horiz, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text('Keine Transfers gefunden',
                                style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredTransfers.length,
                        itemBuilder: (ctx, i) => _buildTransferCard(_filteredTransfers[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferCard(Transfer transfer) {
    final statusColor = transfer.status == TransferStatus.requested
        ? Colors.orange
        : transfer.status == TransferStatus.approved
            ? Colors.green
            : Colors.red;
    final statusLabel = transfer.status == TransferStatus.requested
        ? 'Offen'
        : transfer.status == TransferStatus.approved
            ? 'Genehmigt'
            : 'Abgelehnt';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  child: Icon(Icons.person, color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(transfer.playerName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(transfer.fromTeamName,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.arrow_forward, size: 14),
                          ),
                          Text(transfer.toTeamName,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Angefragt: ${transfer.requestedAt.day}.${transfer.requestedAt.month}.${transfer.requestedAt.year}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                const Spacer(),
                Text(
                  'Von: ${transfer.requestedByName}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
            if (transfer.rejectionReason != null && transfer.rejectionReason!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Grund: ${transfer.rejectionReason}',
                    style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
              ),
            ],
            if (transfer.status == TransferStatus.requested) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => _rejectTransfer(transfer),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Ablehnen'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _approveTransfer(transfer),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, foregroundColor: Colors.white),
                    child: const Text('Genehmigen'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _approveTransfer(Transfer transfer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transfer genehmigen?'),
        content: Text(
          '${transfer.playerName} wird von "${transfer.fromTeamName}" zu "${transfer.toTeamName}" transferiert.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Genehmigen'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _transferService.approveTransfer(
        transferId: transfer.id,
        approvedByUserId: _currentUser?.id ?? '',
        approvedByName: _currentUser?.fullName ?? '',
      );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transfer genehmigt')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  Future<void> _rejectTransfer(Transfer transfer) async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transfer ablehnen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${transfer.playerName}: ${transfer.fromTeamName} → ${transfer.toTeamName}'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Ablehnungsgrund (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Ablehnen'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _transferService.rejectTransfer(
        transferId: transfer.id,
        rejectedByUserId: _currentUser?.id ?? '',
        rejectedByName: _currentUser?.fullName ?? '',
        reason: reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : null,
      );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transfer abgelehnt')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  void _showRequestTransferDialog() async {
    List<Team> teams = [];
    List<Player> players = [];
    try {
      teams = await _teamService.getAllTeams();
      players = await _playerService.getAllPlayers().first;
    } catch (e) {
      debugPrint('Error loading data for transfer: $e');
    }

    if (!mounted) return;

    Team? fromTeam;
    Team? toTeam;
    Player? selectedPlayer;
    List<Player> teamPlayers = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Transfer anfragen'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // From team
                DropdownButtonFormField<Team>(
                  value: fromTeam,
                  decoration: const InputDecoration(
                    labelText: 'Abgebendes Team',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.people),
                  ),
                  items: teams.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
                  onChanged: (v) {
                    setDlgState(() {
                      fromTeam = v;
                      selectedPlayer = null;
                      if (v != null) {
                        teamPlayers = players.where((p) => v.rosterPlayerIds.contains(p.id)).toList();
                      } else {
                        teamPlayers = [];
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Player from that team
                DropdownButtonFormField<Player>(
                  value: selectedPlayer,
                  decoration: const InputDecoration(
                    labelText: 'Spieler',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: teamPlayers
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text('${p.firstName} ${p.lastName}'),
                          ))
                      .toList(),
                  onChanged: (v) => setDlgState(() => selectedPlayer = v),
                ),
                const SizedBox(height: 16),

                // To team
                DropdownButtonFormField<Team>(
                  value: toTeam,
                  decoration: const InputDecoration(
                    labelText: 'Aufnehmendes Team',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.people_outline),
                  ),
                  items: teams
                      .where((t) => t.id != fromTeam?.id)
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                      .toList(),
                  onChanged: (v) => setDlgState(() => toTeam = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Abbrechen')),
            ElevatedButton(
              onPressed: (fromTeam != null && toTeam != null && selectedPlayer != null)
                  ? () async {
                      final transfer = Transfer(
                        id: '',
                        playerId: selectedPlayer!.id,
                        playerName: '${selectedPlayer!.firstName} ${selectedPlayer!.lastName}',
                        fromTeamId: fromTeam!.id,
                        fromTeamName: fromTeam!.name,
                        toTeamId: toTeam!.id,
                        toTeamName: toTeam!.name,
                        requestedByUserId: _currentUser?.id ?? '',
                        requestedByName: _currentUser?.fullName ?? '',
                        requestedAt: DateTime.now(),
                      );
                      try {
                        await _transferService.requestTransfer(transfer);
                        Navigator.of(ctx).pop();
                        await _loadData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Transferanfrage erstellt')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Fehler: $e')),
                        );
                      }
                    }
                  : null,
              child: const Text('Anfrage senden'),
            ),
          ],
        ),
      ),
    );
  }
}
