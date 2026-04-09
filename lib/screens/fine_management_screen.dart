import 'package:flutter/material.dart';
import '../models/fine.dart';
import '../services/fine_service.dart';
import '../services/auth_service.dart';
import '../models/user.dart' as app_user;

class FineManagementScreen extends StatefulWidget {
  const FineManagementScreen({super.key});

  @override
  State<FineManagementScreen> createState() => _FineManagementScreenState();
}

class _FineManagementScreenState extends State<FineManagementScreen> {
  final FineService _fineService = FineService();
  final AuthService _authService = AuthService();

  app_user.User? _currentUser;
  List<Fine> _fines = [];
  bool _isLoading = true;
  String _filter = 'all'; // all, unpaid, paid

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _currentUser = await _authService.getCurrentUser();
      // Use stream to get all fines
      _fines = await _fineService.streamFines().first;
      if (_filter == 'unpaid') {
        _fines = _fines.where((f) => f.status == FineStatus.issued || f.status == FineStatus.appealed).toList();
      } else if (_filter == 'paid') {
        _fines = _fines.where((f) => f.status == FineStatus.paid).toList();
      }
    } catch (e) {
      debugPrint('Error loading fines: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.euro, size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Strafen & Bußgelder',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              // Filter chips
              ChoiceChip(
                label: const Text('Alle'),
                selected: _filter == 'all',
                onSelected: (_) {
                  setState(() => _filter = 'all');
                  _loadData();
                },
              ),
              const SizedBox(width: 4),
              ChoiceChip(
                label: const Text('Offen'),
                selected: _filter == 'unpaid',
                onSelected: (_) {
                  setState(() => _filter = 'unpaid');
                  _loadData();
                },
              ),
              const SizedBox(width: 4),
              ChoiceChip(
                label: const Text('Bezahlt'),
                selected: _filter == 'paid',
                onSelected: (_) {
                  setState(() => _filter = 'paid');
                  _loadData();
                },
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.add),
                label: const Text('Neue Strafe'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Summary bar
        if (!_isLoading) _buildSummaryBar(),

        // Fines list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _fines.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 48, color: Colors.green.shade300),
                          const SizedBox(height: 12),
                          Text(
                            'Keine Strafen vorhanden',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _fines.length,
                        itemBuilder: (context, index) => _buildFineTile(_fines[index]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildSummaryBar() {
    final unpaid = _fines.where((f) => f.status == FineStatus.issued).toList();
    final totalUnpaid = unpaid.fold<double>(0, (sum, f) => sum + f.amount);
    final paid = _fines.where((f) => f.status == FineStatus.paid).toList();
    final totalPaid = paid.fold<double>(0, (sum, f) => sum + f.amount);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          _buildSummaryChip('Gesamt', '${_fines.length}', Colors.blue),
          const SizedBox(width: 16),
          _buildSummaryChip('Offen', '${unpaid.length} · ${totalUnpaid.toStringAsFixed(2)} €', Colors.orange),
          const SizedBox(width: 16),
          _buildSummaryChip('Bezahlt', '${paid.length} · ${totalPaid.toStringAsFixed(2)} €', Colors.green),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Widget _buildFineTile(Fine fine) {
    final statusColor = switch (fine.status) {
      FineStatus.issued => Colors.orange,
      FineStatus.paid => Colors.green,
      FineStatus.appealed => Colors.purple,
      FineStatus.cancelled => Colors.grey,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.1),
          child: Icon(Icons.euro, color: statusColor),
        ),
        title: Row(
          children: [
            Expanded(child: Text(fine.targetName, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(
              '${fine.amount.toStringAsFixed(2)} €',
              style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 16),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fine.reason),
            Text(
              '${fine.targetType.name} · Erstellt: ${fine.issuedAt.day}.${fine.issuedAt.month}.${fine.issuedAt.year} von ${fine.issuedByName}',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleFineAction(fine, action),
          itemBuilder: (ctx) => [
            if (fine.status == FineStatus.issued) ...[
              const PopupMenuItem(value: 'pay', child: Text('Als bezahlt markieren')),
              const PopupMenuItem(value: 'cancel', child: Text('Stornieren')),
            ],
            if (fine.status == FineStatus.appealed)
              const PopupMenuItem(value: 'pay', child: Text('Als bezahlt markieren')),
            const PopupMenuItem(value: 'delete', child: Text('Löschen')),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  void _handleFineAction(Fine fine, String action) async {
    switch (action) {
      case 'pay':
        await _fineService.markAsPaid(fine.id);
        break;
      case 'cancel':
        await _fineService.cancelFine(fine.id);
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Strafe löschen?'),
            content: Text('Strafe für ${fine.targetName} (${fine.amount.toStringAsFixed(2)} €) wirklich löschen?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Löschen', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await _fineService.deleteFine(fine.id);
        }
        break;
    }
    _loadData();
  }

  void _showCreateDialog() {
    final targetNameController = TextEditingController();
    final targetIdController = TextEditingController();
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    final descriptionController = TextEditingController();
    FineTargetType selectedTargetType = FineTargetType.team;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Neue Strafe erstellen'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<FineTargetType>(
                  value: selectedTargetType,
                  decoration: const InputDecoration(labelText: 'Zieltyp', border: OutlineInputBorder()),
                  items: FineTargetType.values.map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(switch (t) {
                      FineTargetType.team => 'Team',
                      FineTargetType.player => 'Spieler',
                      FineTargetType.official => 'Offizieller',
                    }),
                  )).toList(),
                  onChanged: (val) => setDialogState(() => selectedTargetType = val!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetNameController,
                  decoration: const InputDecoration(labelText: 'Name *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetIdController,
                  decoration: const InputDecoration(labelText: 'ID *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Betrag (€) *', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(labelText: 'Begründung *', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Beschreibung (optional)', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text.trim());
                if (targetNameController.text.isEmpty ||
                    targetIdController.text.isEmpty ||
                    amount == null ||
                    reasonController.text.isEmpty) {
                  return;
                }
                Navigator.pop(ctx);
                final fine = Fine(
                  id: '',
                  targetType: selectedTargetType,
                  targetId: targetIdController.text.trim(),
                  targetName: targetNameController.text.trim(),
                  amount: amount,
                  reason: reasonController.text.trim(),
                  description: descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                  issuedByUserId: _currentUser?.id ?? '',
                  issuedByName: _currentUser?.fullName ?? '',
                  issuedAt: DateTime.now(),
                );
                await _fineService.createFine(fine);
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
