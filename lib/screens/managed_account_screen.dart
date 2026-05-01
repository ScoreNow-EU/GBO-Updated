import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:toastification/toastification.dart';
import '../models/managed_account.dart';
import '../models/tournament.dart';
import '../models/court.dart';
import '../services/managed_account_service.dart';
import '../services/tournament_service.dart';
import '../utils/responsive_helper.dart';

class ManagedAccountScreen extends StatefulWidget {
  final int? initialTabIndex;
  
  const ManagedAccountScreen({super.key, this.initialTabIndex});

  @override
  State<ManagedAccountScreen> createState() => _ManagedAccountScreenState();
}

class _ManagedAccountScreenState extends State<ManagedAccountScreen> {
  final ManagedAccountService _managedAccountService = ManagedAccountService();
  final TournamentService _tournamentService = TournamentService();
  
  String _selectedTab = 'tablets'; // 'tablets' or 'medics'
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Set initial tab based on optional index parameter
    if (widget.initialTabIndex != null) {
      switch (widget.initialTabIndex) {
        case 0:
          _selectedTab = 'tablets';
          break;
        case 1:
          _selectedTab = 'medics';
          break;
        default:
          _selectedTab = 'tablets';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          _buildHeader(screenWidth, isDesktop),
          _buildTabBar(),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(double screenWidth, bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFffd665).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.tablet_android,
              color: Color(0xFFffd665),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verwaltete Accounts',
                  style: TextStyle(
                    fontSize: isDesktop ? 28 : 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Verwalten Sie Scoring-Tablets und Sanitäter-Accounts',
                  style: TextStyle(
                    fontSize: isDesktop ? 16 : 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          _buildCreateButton(),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    return ElevatedButton.icon(
      onPressed: () => _showCreateDialog(),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFffd665),
        foregroundColor: Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      icon: const Icon(Icons.add, size: 20),
      label: const Text(
        'Neuen Account erstellen',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: Row(
        children: [
          _buildTab('tablets', 'Scoring Tablets', Icons.tablet_android),
          _buildTab('medics', 'Sanitäter', Icons.medical_services),
        ],
      ),
    );
  }

  Widget _buildTab(String tabKey, String title, IconData icon) {
    final isSelected = _selectedTab == tabKey;
    
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = tabKey),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? const Color(0xFFffd665) : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFFffd665) : Colors.grey.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.black87 : Colors.grey.shade600,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final accountType = _selectedTab == 'tablets' 
        ? ManagedAccountType.scoringTablet 
        : ManagedAccountType.medic;

    return StreamBuilder<List<ManagedAccount>>(
      stream: _managedAccountService.getManagedAccountsByType(accountType),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Fehler: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final accounts = snapshot.data!;

        if (accounts.isEmpty) {
          return _buildEmptyState();
        }

        return _buildAccountsList(accounts);
      },
    );
  }

  Widget _buildEmptyState() {
    final isTablets = _selectedTab == 'tablets';
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isTablets ? Icons.tablet_android : Icons.medical_services,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isTablets ? 'Keine Scoring Tablets vorhanden' : 'Keine Sanitäter-Accounts vorhanden',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isTablets
                ? 'Erstellen Sie Tablet-Accounts für die Live-Punktevergabe'
                : 'Erstellen Sie Sanitäter-Accounts für Notfallbenachrichtigungen',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCreateDialog(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFffd665),
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add),
            label: Text(
              isTablets ? 'Erstes Tablet erstellen' : 'Ersten Sanitäter-Account erstellen',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsList(List<ManagedAccount> accounts) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTableHeader(),
          Expanded(
            child: ListView.separated(
              itemCount: accounts.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: Colors.grey.shade200,
              ),
              itemBuilder: (context, index) => _buildAccountRow(accounts[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            flex: 2,
            child: Text(
              'Name',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text(
              'E-Mail',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
          if (_selectedTab == 'tablets') ...[
            const Expanded(
              flex: 2,
              child: Text(
                'Turnier',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
            const Expanded(
              flex: 1,
              child: Text(
                'Court',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
          ] else ...[
            const Expanded(
              flex: 2,
              child: Text(
                'Turnier',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
          ],
          const Expanded(
            flex: 1,
            child: Text(
              'Status',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 100), // Actions column
        ],
      ),
    );
  }

  Widget _buildAccountRow(ManagedAccount account) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (account.notes?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    account.notes!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              account.email,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontFamily: 'monospace',
              ),
            ),
          ),
          if (_selectedTab == 'tablets') ...[
            Expanded(
              flex: 2,
              child: _buildTournamentInfo(account),
            ),
            Expanded(
              flex: 1,
              child: _buildCourtInfo(account),
            ),
          ] else ...[
            Expanded(
              flex: 2,
              child: _buildTournamentInfo(account),
            ),
          ],
          Expanded(
            flex: 1,
            child: _buildStatusChip(account),
          ),
          SizedBox(
            width: 100,
            child: _buildActionButtons(account),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentInfo(ManagedAccount account) {
    if (account.tournamentId == null) {
      return Text(
        'Nicht zugewiesen',
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade500,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return FutureBuilder<Tournament?>(
      future: _tournamentService.getTournamentById(account.tournamentId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        final tournament = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tournament.name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              tournament.location,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCourtInfo(ManagedAccount account) {
    if (account.courtId == null) {
      return Text(
        'Kein Court',
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade500,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    if (account.tournamentId == null) {
      return Text(
        'Fehler',
        style: TextStyle(
          fontSize: 13,
          color: Colors.red.shade600,
        ),
      );
    }

    return FutureBuilder<Tournament?>(
      future: _tournamentService.getTournamentById(account.tournamentId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        final tournament = snapshot.data!;
        final court = tournament.courts.firstWhere(
          (c) => c.id == account.courtId,
          orElse: () => Court(
            id: account.courtId!,
            name: 'Unbekannt',
          ),
        );

        return Text(
          court.name,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(ManagedAccount account) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: account.isActive ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        account.isActive ? 'Aktiv' : 'Inaktiv',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: account.isActive ? Colors.green.shade700 : Colors.red.shade700,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildActionButtons(ManagedAccount account) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          onPressed: () => _showEditDialog(account),
          icon: const Icon(Icons.edit, size: 18),
          tooltip: 'Bearbeiten',
          style: IconButton.styleFrom(
            backgroundColor: Colors.blue.shade50,
            foregroundColor: Colors.blue.shade600,
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: () => _showDeleteDialog(account),
          icon: const Icon(Icons.delete, size: 18),
          tooltip: 'Löschen',
          style: IconButton.styleFrom(
            backgroundColor: Colors.red.shade50,
            foregroundColor: Colors.red.shade600,
          ),
        ),
      ],
    );
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (context) => _CreateAccountDialog(
        accountType: _selectedTab == 'tablets' 
            ? ManagedAccountType.scoringTablet 
            : ManagedAccountType.medic,
        managedAccountService: _managedAccountService,
        tournamentService: _tournamentService,
        onSuccess: () {
          toastification.show(
            context: context,
            type: ToastificationType.success,
            style: ToastificationStyle.fillColored,
            title: const Text('Account erfolgreich erstellt'),
            autoCloseDuration: const Duration(seconds: 3),
          );
        },
      ),
    );
  }

  void _showEditDialog(ManagedAccount account) {
    showDialog(
      context: context,
      builder: (context) => _AccountDetailsDialog(
        account: account,
        onSuccess: () {
          toastification.show(
            context: context,
            type: ToastificationType.success,
            style: ToastificationStyle.fillColored,
            title: const Text('Account-Details angezeigt'),
            autoCloseDuration: const Duration(seconds: 3),
          );
        },
      ),
    );
  }

  void _showDeleteDialog(ManagedAccount account) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account löschen'),
        content: Text(
          'Sind Sie sicher, dass Sie den Account "${account.name}" löschen möchten? Diese Aktion kann nicht rückgängig gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              final success = await _managedAccountService.deleteManagedAccount(account.id);
              
              if (success) {
                toastification.show(
                  context: context,
                  type: ToastificationType.success,
                  style: ToastificationStyle.fillColored,
                  title: const Text('Account erfolgreich gelöscht'),
                  description: const Text('Der Account wurde aus der Datenbank entfernt.'),
                  autoCloseDuration: const Duration(seconds: 3),
                );
              } else {
                toastification.show(
                  context: context,
                  type: ToastificationType.error,
                  style: ToastificationStyle.fillColored,
                  title: const Text('Fehler beim Löschen des Accounts'),
                  autoCloseDuration: const Duration(seconds: 3),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }
}

class _CreateAccountDialog extends StatefulWidget {
  final ManagedAccountType accountType;
  final ManagedAccountService managedAccountService;
  final TournamentService tournamentService;
  final VoidCallback onSuccess;

  const _CreateAccountDialog({
    required this.accountType,
    required this.managedAccountService,
    required this.tournamentService,
    required this.onSuccess,
  });

  @override
  State<_CreateAccountDialog> createState() => _CreateAccountDialogState();
}

class _CreateAccountDialogState extends State<_CreateAccountDialog> {
  bool _isLoading = false;
  Tournament? _selectedTournament;
  Court? _selectedCourt;
  List<Tournament> _tournaments = [];
  List<Court> _availableCourts = [];
  ManagedAccount? _createdAccount;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    // Load tournaments
    final tournamentsStream = widget.tournamentService.getTournaments();
    final tournaments = await tournamentsStream.first;
    setState(() {
      _tournaments = tournaments;
    });
  }

  Future<void> _loadCourts() async {
    if (_selectedTournament != null) {
      final courts = await widget.managedAccountService.getAvailableCourtsForTournament(
        _selectedTournament!.id,
      );
      
      setState(() {
        _availableCourts = courts;
        _selectedCourt = null; // Reset court selection
      });
    }
  }

  String _generateAccountName() {
    if (_selectedTournament == null) return '';
    
    if (widget.accountType == ManagedAccountType.scoringTablet && _selectedCourt != null) {
      return 'Scoring Tablet ${_selectedCourt!.name} (${_selectedTournament!.name})';
    } else if (widget.accountType == ManagedAccountType.medic) {
      return 'Sanitäter (${_selectedTournament!.name})';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: _createdAccount != null ? 600 : 1000,
        height: _createdAccount != null ? 550 : 700,
        padding: const EdgeInsets.all(24),
        child: _createdAccount != null
            ? _buildSuccessStep()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  Expanded(child: _buildSelectionStep()),
                  _buildFooter(),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFffd665).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            widget.accountType == ManagedAccountType.scoringTablet
                ? Icons.tablet_android
                : Icons.medical_services,
            color: const Color(0xFFffd665),
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Neuen Account erstellen',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                widget.accountType == ManagedAccountType.scoringTablet ? 'Punktetablet' : 'Sanitäter',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessStep() {
    if (_createdAccount == null) return Container();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.green.shade600,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account erfolgreich erstellt',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _createdAccount!.name,
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
        const SizedBox(height: 24),
        Expanded(
          child: Row(
            children: [
              // Account details
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Account-Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildDetailRow('Name', _createdAccount!.name),
                          _buildDetailRow('E-Mail', _createdAccount!.email),
                          _buildDetailRow('Passwort', _createdAccount!.password),
                          _buildDetailRow('Code', _createdAccount!.oneTimeCode ?? 'Nicht verfügbar'),
                          if (_createdAccount!.tournamentId != null)
                            FutureBuilder<Tournament?>(
                              future: widget.tournamentService.getTournamentById(_createdAccount!.tournamentId!),
                              builder: (context, snapshot) {
                                return _buildDetailRow('Turnier', snapshot.data?.name ?? 'Lädt...');
                              },
                            ),
                          if (_createdAccount!.courtId != null)
                            _buildDetailRow('Court', _selectedCourt?.name ?? 'Unbekannt'),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _copyToClipboard(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade50,
                                foregroundColor: Colors.blue.shade700,
                              ),
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('Daten kopieren'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // One-Time Code
              Container(
                width: 200,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Einmaliger Login-Code',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFffd665).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFffd665).withOpacity(0.3)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.pin,
                            size: 28,
                            color: const Color(0xFFffd665),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            _createdAccount!.oneTimeCode ?? 'Fehler',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Text(
                        'Nur einmalig verwendbar',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Schließen'),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onSuccess();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFffd665),
                foregroundColor: Colors.black87,
              ),
              child: const Text('Fertig'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard() {
    final data = '''
Account-Details:
Name: ${_createdAccount!.name}
E-Mail: ${_createdAccount!.email}
Passwort: ${_createdAccount!.password}
Einmaliger Code: ${_createdAccount!.oneTimeCode ?? 'Nicht verfügbar'}
${_selectedTournament != null ? 'Turnier: ${_selectedTournament!.name}' : ''}
${_selectedCourt != null ? 'Court: ${_selectedCourt!.name}' : ''}
''';
    
    Clipboard.setData(ClipboardData(text: data));
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.fillColored,
      title: const Text('Account-Daten in Zwischenablage kopiert'),
      autoCloseDuration: const Duration(seconds: 2),
    );
  }

  Widget _buildSelectionStep() {
    return Row(
      children: [
        // Tournament selection panel
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Turnier auswählen',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tournaments.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final tournament = _tournaments[index];
                      return _buildTournamentCard(tournament);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(width: 24),
        
        // Court selection panel (only for scoring tablets)
        if (widget.accountType == ManagedAccountType.scoringTablet)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Court auswählen',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _selectedTournament == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.sports_tennis,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Bitte wählen Sie zuerst ein Turnier aus',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _availableCourts.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 48,
                                      color: Colors.orange.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Keine verfügbaren Courts',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Alle Courts sind bereits vergeben',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: _availableCourts.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final court = _availableCourts[index];
                                  return _buildCourtCard(court);
                                },
                              ),
                  ),
                ),
              ],
            ),
          )
        else
          // For medics, show preview
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Account-Vorschau',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _selectedTournament == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.medical_services,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Bitte wählen Sie ein Turnier aus',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Account wird erstellt:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.medical_services,
                                            color: Colors.green.shade600,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _generateAccountName(),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Automatisch generierte E-Mail und Passwort',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTournamentCard(Tournament tournament) {
    final isSelected = _selectedTournament?.id == tournament.id;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTournament = tournament;
          _selectedCourt = null; // Reset court selection
        });
        _loadCourts();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFffd665) : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tournament.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFFffd665) : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFffd665),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tournament.dateString,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tournament.location,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Spacer(),
                Text(
                  '${tournament.courts.length} Courts',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourtCard(Court court) {
    final isSelected = _selectedCourt?.id == court.id;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCourt = court;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFffd665) : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? const Color(0xFFffd665).withOpacity(0.2)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.sports_tennis,
                    color: isSelected ? const Color(0xFFffd665) : Colors.grey.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    court.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFFffd665) : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFffd665),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'COURT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: Colors.green.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  'Verfügbar',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: _canCreateAccount() ? (_isLoading ? null : _createAccount) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFffd665),
            foregroundColor: Colors.black87,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Account erstellen'),
        ),
      ],
    );
  }

  bool _canCreateAccount() {
    if (_selectedTournament == null) return false;
    if (widget.accountType == ManagedAccountType.scoringTablet && _selectedCourt == null) return false;
    return true;
  }

  void _createAccount() async {
    setState(() => _isLoading = true);

    try {
      final name = _generateAccountName();
      final email = widget.managedAccountService.generateUniqueEmail(
        widget.accountType,
        _selectedTournament!.name,
        courtName: _selectedCourt?.name,
      );
      final password = widget.managedAccountService.generateTemporaryPassword();

      final account = ManagedAccount(
        id: '',
        name: name,
        email: email,
        password: password,
        type: widget.accountType,
        tournamentId: _selectedTournament?.id,
        courtId: widget.accountType == ManagedAccountType.scoringTablet ? _selectedCourt?.id : null,
        isActive: true,
        createdAt: DateTime.now(),
      );

      final createdAccount = await widget.managedAccountService.createManagedAccount(account);
      
      if (createdAccount != null) {
        setState(() {
          _createdAccount = createdAccount;
          _isLoading = false;
        });
      } else {
        throw Exception('Unbekannter Fehler');
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          title: Text('Fehler: ${e.toString().replaceAll('Exception: ', '')}'),
          autoCloseDuration: const Duration(seconds: 4),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}

// New dialog for viewing account details (when editing)
class _AccountDetailsDialog extends StatefulWidget {
  final ManagedAccount account;
  final VoidCallback onSuccess;

  const _AccountDetailsDialog({
    required this.account,
    required this.onSuccess,
  });

  @override
  State<_AccountDetailsDialog> createState() => _AccountDetailsDialogState();
}

class _AccountDetailsDialogState extends State<_AccountDetailsDialog> {
  final ManagedAccountService _managedAccountService = ManagedAccountService();
  late ManagedAccount _currentAccount;
  bool _isRegenerating = false;

  @override
  void initState() {
    super.initState();
    _currentAccount = widget.account;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFffd665).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.account.type == ManagedAccountType.scoringTablet
                        ? Icons.tablet_android
                        : Icons.medical_services,
                    color: const Color(0xFFffd665),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Account-Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.account.name,
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
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Name', _currentAccount.name),
                  _buildDetailRow('E-Mail', _currentAccount.email),
                  _buildDetailRow('Passwort', _currentAccount.password),
                  _buildDetailRow('Code', _currentAccount.oneTimeCode ?? 'Nicht verfügbar'),
                  _buildDetailRow('Code-Status', _currentAccount.isOneTimeCodeUsed ? 'Bereits verwendet' : 'Verfügbar'),
                  _buildDetailRow('Typ', _currentAccount.type == ManagedAccountType.scoringTablet ? 'Punktetablet' : 'Sanitäter'),
                  _buildDetailRow('Status', _currentAccount.isActive ? 'Aktiv' : 'Inaktiv'),
                  if (_currentAccount.notes?.isNotEmpty == true)
                    _buildDetailRow('Notizen', _currentAccount.notes!),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Schließen'),
                ),
                const SizedBox(width: 16),
                if (_currentAccount.isOneTimeCodeUsed)
                  ElevatedButton.icon(
                    onPressed: _isRegenerating ? null : () => _regenerateOneTimeCode(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade50,
                      foregroundColor: Colors.orange.shade700,
                    ),
                    icon: _isRegenerating 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 16),
                    label: const Text('Neuen Code generieren'),
                  ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _copyToClipboard(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFffd665),
                    foregroundColor: Colors.black87,
                  ),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Daten kopieren'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    final data = '''
Account-Details:
Name: ${_currentAccount.name}
E-Mail: ${_currentAccount.email}
Passwort: ${_currentAccount.password}
Einmaliger Code: ${_currentAccount.oneTimeCode ?? 'Nicht verfügbar'}
Code-Status: ${_currentAccount.isOneTimeCodeUsed ? 'Bereits verwendet' : 'Verfügbar'}
Typ: ${_currentAccount.type == ManagedAccountType.scoringTablet ? 'Punktetablet' : 'Sanitäter'}
Status: ${_currentAccount.isActive ? 'Aktiv' : 'Inaktiv'}
${_currentAccount.notes?.isNotEmpty == true ? 'Notizen: ${_currentAccount.notes}' : ''}
''';
    
    Clipboard.setData(ClipboardData(text: data));
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.fillColored,
      title: const Text('Account-Daten in Zwischenablage kopiert'),
      autoCloseDuration: const Duration(seconds: 2),
    );
  }

  void _regenerateOneTimeCode(BuildContext context) async {
    setState(() => _isRegenerating = true);
    
    try {
      final newCode = await _managedAccountService.generateNewOneTimeCode(_currentAccount.id);
      
      if (newCode != null) {
        setState(() {
          _currentAccount = _currentAccount.copyWith(
            oneTimeCode: newCode,
            isOneTimeCodeUsed: false,
            oneTimeCodeUsedAt: null,
          );
          _isRegenerating = false;
        });
        
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          title: const Text('Neuer Code erfolgreich generiert'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      } else {
        throw Exception('Code konnte nicht generiert werden');
      }
    } catch (e) {
      setState(() => _isRegenerating = false);
      
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        title: Text('Fehler: ${e.toString().replaceAll('Exception: ', '')}'),
        autoCloseDuration: const Duration(seconds: 4),
      );
    }
  }
} 