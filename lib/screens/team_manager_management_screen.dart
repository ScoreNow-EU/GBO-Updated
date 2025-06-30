import 'package:flutter/material.dart';
import '../models/team_manager.dart';
import '../services/team_manager_service.dart';
import '../utils/responsive_helper.dart';
import '../widgets/responsive_layout.dart';

class TeamManagerManagementScreen extends StatefulWidget {
  const TeamManagerManagementScreen({super.key});

  @override
  State<TeamManagerManagementScreen> createState() => _TeamManagerManagementScreenState();
}

class _TeamManagerManagementScreenState extends State<TeamManagerManagementScreen> {
  final TeamManagerService _teamManagerService = TeamManagerService();
  
  List<TeamManager> _teamManagers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final teamManagers = await _teamManagerService.getAllTeamManagers();
      
      setState(() {
        _teamManagers = teamManagers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Fehler beim Laden der Daten: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ResponsiveLayout(
        selectedSection: 'team_manager_management',
        onSectionChanged: (section) {
          Navigator.of(context).pop();
        },
        title: 'Team Manager Verwaltung',
        body: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildSearchBar(),
            const SizedBox(height: 24),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildTeamManagersList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTeamManagerDialog(),
        backgroundColor: Colors.black87,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(
          Icons.supervisor_account,
          size: 32,
          color: Colors.black87,
        ),
        const SizedBox(width: 12),
        const Text(
          'Team Manager',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Team Manager suchen...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
    );
  }

  Widget _buildTeamManagersList() {
    List<TeamManager> filteredManagers = _teamManagers;
    
    if (_searchQuery.isNotEmpty) {
      filteredManagers = _teamManagers.where((manager) =>
        manager.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        manager.email.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    if (filteredManagers.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      itemCount: filteredManagers.length,
      itemBuilder: (context, index) {
        final manager = filteredManagers[index];
        return _buildTeamManagerCard(manager);
      },
    );
  }

  Widget _buildTeamManagerCard(TeamManager manager) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: manager.isActive ? Colors.black87 : Colors.grey,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Text(
              manager.name.isNotEmpty ? manager.name[0].toUpperCase() : 'M',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Text(
          manager.name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(manager.email),
            if (manager.userId != null)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFffd665).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Verknüpft',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _showTeamManagerDialog(manager: manager);
                break;
              case 'delete':
                _deleteTeamManager(manager);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, color: Colors.black87, size: 18),
                  SizedBox(width: 8),
                  Text('Bearbeiten'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Text('Löschen', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.supervisor_account_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Keine Team Manager gefunden',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Erstellen Sie Ihren ersten Team Manager',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _showTeamManagerDialog({TeamManager? manager}) {
    final nameController = TextEditingController(text: manager?.name ?? '');
    final emailController = TextEditingController(text: manager?.email ?? '');
    final phoneController = TextEditingController(text: manager?.phone ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(manager == null ? 'Neuer Team Manager' : 'Team Manager bearbeiten'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'E-Mail *',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Telefon (optional)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => _saveTeamManager(
              manager,
              nameController.text,
              emailController.text,
              phoneController.text.isEmpty ? null : phoneController.text,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
            ),
            child: Text(manager == null ? 'Erstellen' : 'Speichern'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTeamManager(
    TeamManager? existingManager,
    String name,
    String email,
    String? phone,
  ) async {
    if (name.trim().isEmpty || email.trim().isEmpty) {
      _showError('Name und E-Mail sind erforderlich');
      return;
    }

    Navigator.of(context).pop();

    final teamManager = TeamManager(
      id: existingManager?.id ?? '',
      name: name.trim(),
      email: email.trim().toLowerCase(),
      phone: phone?.trim(),
      teamIds: existingManager?.teamIds ?? [],
      isActive: existingManager?.isActive ?? true,
      createdAt: existingManager?.createdAt ?? DateTime.now(),
      lastLoginAt: existingManager?.lastLoginAt,
      userId: existingManager?.userId,
    );

    bool success;
    if (existingManager == null) {
      success = await _teamManagerService.createTeamManager(teamManager);
    } else {
      success = await _teamManagerService.updateTeamManager(existingManager.id, teamManager);
    }

    if (success) {
      _showSuccess(existingManager == null 
          ? 'Team Manager erfolgreich erstellt!'
          : 'Team Manager erfolgreich aktualisiert!');
      _loadData();
    } else {
      _showError('Fehler beim Speichern des Team Managers');
    }
  }

  Future<void> _deleteTeamManager(TeamManager manager) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Team Manager löschen'),
        content: Text('Möchten Sie "${manager.name}" wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _teamManagerService.deleteTeamManager(manager.id);
      if (success) {
        _showSuccess('Team Manager erfolgreich gelöscht!');
        _loadData();
      } else {
        _showError('Fehler beim Löschen des Team Managers');
      }
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
} 