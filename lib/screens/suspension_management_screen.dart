import 'package:flutter/material.dart';
import '../models/suspension.dart';
import '../services/suspension_service.dart';
import '../services/auth_service.dart';
import '../models/user.dart' as app_user;

class SuspensionManagementScreen extends StatefulWidget {
  const SuspensionManagementScreen({super.key});

  @override
  State<SuspensionManagementScreen> createState() => _SuspensionManagementScreenState();
}

class _SuspensionManagementScreenState extends State<SuspensionManagementScreen> {
  final SuspensionService _suspensionService = SuspensionService();
  final AuthService _authService = AuthService();

  app_user.User? _currentUser;
  List<Suspension> _suspensions = [];
  bool _isLoading = true;
  bool _showOnlyActive = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _currentUser = await _authService.getCurrentUser();
      if (_showOnlyActive) {
        _suspensions = await _suspensionService.getAllActiveSuspensions();
      } else {
        _suspensions = await _suspensionService.getAllSuspensions();
      }
    } catch (e) {
      debugPrint('Error loading suspensions: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    return Column(
      children: [
        // Header bar - hide title on mobile (shown in AppBar by ResponsiveLayout)
        Container(
          padding: const EdgeInsets.all(16),
          child: isMobile
              ? Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    FilterChip(
                      label: Text(_showOnlyActive ? 'Nur aktive' : 'Alle'),
                      selected: _showOnlyActive,
                      onSelected: (val) {
                        setState(() => _showOnlyActive = val);
                        _loadData();
                      },
                    ),
                    ElevatedButton.icon(
                      onPressed: _showCreateDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Neue Sperre'),
                    ),
                  ],
                )
              : Row(
                  children: [
                    const Icon(Icons.block, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Sperren-Verwaltung',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    FilterChip(
                      label: Text(_showOnlyActive ? 'Nur aktive' : 'Alle'),
                      selected: _showOnlyActive,
                      onSelected: (val) {
                        setState(() => _showOnlyActive = val);
                        _loadData();
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _showCreateDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Neue Sperre'),
                    ),
                  ],
                ),
        ),
        const Divider(height: 1),

        // Suspensions list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _suspensions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 48, color: Colors.green.shade300),
                          const SizedBox(height: 12),
                          Text(
                            'Keine aktiven Sperren',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _suspensions.length,
                        itemBuilder: (context, index) => _buildSuspensionTile(_suspensions[index]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildSuspensionTile(Suspension suspension) {
    final typeColor = switch (suspension.type) {
      SuspensionType.tournament => Colors.orange,
      SuspensionType.season => Colors.red,
      SuspensionType.custom => Colors.purple,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: typeColor.withValues(alpha: 0.1),
          child: Icon(Icons.block, color: typeColor),
        ),
        title: Text(suspension.playerName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(suspension.teamName),
            Text(suspension.reason, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            Text(
              'Erstellt: ${suspension.issuedAt.day}.${suspension.issuedAt.month}.${suspension.issuedAt.year} von ${suspension.issuedByName}',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(
              label: Text(
                switch (suspension.type) {
                  SuspensionType.tournament => 'Turnier',
                  SuspensionType.season => 'Saison',
                  SuspensionType.custom => 'Individuell',
                },
                style: TextStyle(fontSize: 11, color: typeColor),
              ),
              backgroundColor: typeColor.withValues(alpha: 0.1),
              side: BorderSide.none,
            ),
            if (suspension.isActive)
              IconButton(
                icon: const Icon(Icons.cancel, color: Colors.red),
                tooltip: 'Sperre aufheben',
                onPressed: () => _confirmDeactivate(suspension),
              ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  void _confirmDeactivate(Suspension suspension) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sperre aufheben?'),
        content: Text('Sperre für ${suspension.playerName} (${suspension.teamName}) wirklich aufheben?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _suspensionService.deactivateSuspension(suspension.id);
              _loadData();
            },
            child: const Text('Aufheben', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog() {
    final playerNameController = TextEditingController();
    final playerIdController = TextEditingController();
    final teamNameController = TextEditingController();
    final teamIdController = TextEditingController();
    final reasonController = TextEditingController();
    final notesController = TextEditingController();
    SuspensionType selectedType = SuspensionType.season;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Neue Sperre erstellen'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: playerNameController,
                  decoration: const InputDecoration(labelText: 'Spielername *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: playerIdController,
                  decoration: const InputDecoration(labelText: 'Spieler-ID *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: teamNameController,
                  decoration: const InputDecoration(labelText: 'Teamname *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: teamIdController,
                  decoration: const InputDecoration(labelText: 'Team-ID *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<SuspensionType>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Art der Sperre', border: OutlineInputBorder()),
                  items: SuspensionType.values.map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(switch (t) {
                      SuspensionType.tournament => 'Turniersperre',
                      SuspensionType.season => 'Saisonsperre',
                      SuspensionType.custom => 'Individuelle Sperre',
                    }),
                  )).toList(),
                  onChanged: (val) => setDialogState(() => selectedType = val!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(labelText: 'Begründung *', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Anmerkungen (optional)', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
            ElevatedButton(
              onPressed: () async {
                if (playerNameController.text.isEmpty ||
                    playerIdController.text.isEmpty ||
                    teamNameController.text.isEmpty ||
                    teamIdController.text.isEmpty ||
                    reasonController.text.isEmpty) {
                  return;
                }
                Navigator.pop(ctx);
                final suspension = Suspension(
                  id: '',
                  playerId: playerIdController.text.trim(),
                  playerName: playerNameController.text.trim(),
                  teamId: teamIdController.text.trim(),
                  teamName: teamNameController.text.trim(),
                  type: selectedType,
                  reason: reasonController.text.trim(),
                  issuedByUserId: _currentUser?.id ?? '',
                  issuedByName: _currentUser?.fullName ?? '',
                  issuedAt: DateTime.now(),
                  notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                );
                await _suspensionService.createSuspension(suspension);
                _loadData();
              },
              child: const Text('Erstellen'),
            ),
          ],
        ),
      ),
    );
  }
}
