import 'package:flutter/material.dart';
import '../models/tournament.dart';
import '../models/team.dart';
import '../widgets/custom_bracket_builder.dart';
import '../utils/bracket_templates.dart';
import '../services/preset_service.dart';
import 'package:toastification/toastification.dart';

class PresetManagementScreen extends StatefulWidget {
  const PresetManagementScreen({super.key});

  @override
  State<PresetManagementScreen> createState() => _PresetManagementScreenState();
}

class _PresetManagementScreenState extends State<PresetManagementScreen> {
  final PresetService _presetService = PresetService();
  String _selectedDivision = 'Women\'s Seniors';
  List<CustomBracketNode> _currentNodes = [];
  List<Team> _sampleTeams = [];
  Map<String, List<String>> _poolTeams = {};
  List<BracketPreset> _savedPresets = [];
  bool _isLoading = false;
  
  final List<String> _divisions = [
    'Women\'s U14',
    'Women\'s U16', 
    'Women\'s U18',
    'Women\'s Seniors',
    'Women\'s FUN',
    'Men\'s U14',
    'Men\'s U16',
    'Men\'s U18', 
    'Men\'s Seniors',
    'Men\'s FUN',
  ];

  @override
  void initState() {
    super.initState();
    _generateSampleTeams();
    _loadPresets();
  }

  void _generateSampleTeams() {
    _sampleTeams = List.generate(99, (index) {
      final teamNumber = index + 1;
      return Team(
        id: 'team_$teamNumber',
        name: 'Team $teamNumber',
        city: 'Stadt $teamNumber',
        bundesland: 'Baden-Württemberg',
        division: _selectedDivision,
        createdAt: DateTime.now(),
        teamManager: 'Manager $teamNumber',
        logoUrl: null,
      );
    });
  }

  void _loadPresets() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final presets = await _presetService.getPresetsForDivision(_selectedDivision);
      setState(() {
        _savedPresets = presets;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Fehler beim Laden der Presets: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          // Left sidebar - Settings navigation
          _buildLeftSidebar(),
          
          // Main content
          Expanded(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _buildMainContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftSidebar() {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.architecture,
                  color: Colors.blue,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Preset Verwaltung',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Division selection
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Division',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedDivision,
                      isExpanded: true,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedDivision = value;
                            _generateSampleTeams();
                          });
                          _loadPresets();
                        }
                      },
                      items: _divisions.map((division) {
                        return DropdownMenuItem<String>(
                          value: division,
                          child: Text(division),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Preset actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preset Aktionen',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                
                // Save preset button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _currentNodes.isNotEmpty ? _savePreset : null,
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text('Preset speichern'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                
                // Clear current bracket button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _currentNodes.isNotEmpty ? _clearBracket : null,
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Bracket leeren'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Template loading
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vorlagen laden',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                
                // Template buttons
                ...BracketTemplates.getAllTemplates().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _loadTemplate(entry.key, entry.value),
                        icon: const Icon(Icons.download, size: 14),
                        label: Text(
                          entry.key,
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          
          // Saved presets
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gespeicherte Presets',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _savedPresets.isEmpty
                            ? Center(
                                child: Text(
                                  'Keine Presets für\n$_selectedDivision',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : ListView.builder(
                                itemCount: _savedPresets.length,
                                itemBuilder: (context, index) {
                                  final preset = _savedPresets[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      dense: true,
                                      title: Text(
                                        preset.name,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(
                                        preset.description,
                                        style: const TextStyle(fontSize: 11),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'load') {
                                            _loadPreset(preset);
                                          } else if (value == 'delete') {
                                            _deletePreset(preset);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'load',
                                            child: Text('Laden'),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Löschen'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_tree,
            color: Colors.blue,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            'Preset Builder - $_selectedDivision',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${_sampleTeams.length} Test-Teams verfügbar',
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: CustomBracketBuilder(
        initialNodes: _currentNodes,
        divisionName: _selectedDivision,
        availableTeams: _getAvailableTeams(),
        poolTeams: _poolTeams,
        allTeams: _sampleTeams,
        tournament: Tournament(
          id: 'preset_${_selectedDivision}',
          name: 'Preset Tournament',
          categories: [_selectedDivision],
          location: 'Preset Location',
          startDate: DateTime.now(),
          endDate: DateTime.now(),
          points: 0,
          status: 'upcoming',
        ),
        onTeamDrop: _handleTeamDrop,
        onBracketChanged: _handleBracketChanged,
      ),
    );
  }

  List<Team> _getAvailableTeams() {
    // Return teams that are not assigned to any pool
    final assignedTeamIds = <String>{};
    for (final poolTeamList in _poolTeams.values) {
      assignedTeamIds.addAll(poolTeamList);
    }
    
    return _sampleTeams.where((team) => !assignedTeamIds.contains(team.id)).toList();
  }

  void _handleTeamDrop(Team team, CustomBracketNode node) {
    if (node.nodeType == 'pool') {
      setState(() {
        final poolId = '${_selectedDivision}_${node.title}';
        
        // Remove team from any other pools first
        for (String existingPoolId in _poolTeams.keys.toList()) {
          if (existingPoolId.startsWith('${_selectedDivision}_') && existingPoolId != poolId) {
            if (_poolTeams[existingPoolId]!.contains(team.id)) {
              _poolTeams[existingPoolId]!.remove(team.id);
              if (_poolTeams[existingPoolId]?.isEmpty ?? false) {
                _poolTeams.remove(existingPoolId);
              }
            }
          }
        }
        
        // Initialize pool if it doesn't exist
        if (!_poolTeams.containsKey(poolId)) {
          _poolTeams[poolId] = [];
        }
        
        // Add team to pool if not already there
        if (!_poolTeams[poolId]!.contains(team.id)) {
          _poolTeams[poolId]!.add(team.id);
        }
      });
    }
  }

  void _handleBracketChanged(List<CustomBracketNode> nodes) {
    setState(() {
      _currentNodes = nodes;
    });
  }

  void _loadTemplate(String templateName, List<CustomBracketNode> Function(String) templateFunc) {
    final nodes = templateFunc(_selectedDivision);
    setState(() {
      _currentNodes = nodes;
      _poolTeams.clear(); // Clear existing pool assignments
    });
    
    _showSuccess('Vorlage "$templateName" geladen');
  }

  void _clearBracket() {
    setState(() {
      _currentNodes.clear();
      _poolTeams.clear();
    });
    _showSuccess('Bracket geleert');
  }

  void _savePreset() {
    if (_currentNodes.isEmpty) {
      _showError('Kein Bracket zum Speichern vorhanden');
      return;
    }

    // Show dialog to get preset name and description
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preset speichern'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Preset Name',
                hintText: 'z.B. "Seniors Komplex Bracket"',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Beschreibung',
                hintText: 'Kurze Beschreibung des Presets',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                _showError('Bitte geben Sie einen Namen ein');
                return;
              }

              final preset = BracketPreset(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameController.text.trim(),
                description: descriptionController.text.trim(),
                division: _selectedDivision,
                nodes: _currentNodes,
                poolTeams: _poolTeams,
                createdAt: DateTime.now(),
              );

              try {
                await _presetService.savePreset(preset);
                Navigator.pop(context);
                _showSuccess('Preset "${preset.name}" gespeichert');
                _loadPresets(); // Refresh the list
              } catch (e) {
                _showError('Fehler beim Speichern: $e');
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  void _loadPreset(BracketPreset preset) {
    setState(() {
      _currentNodes = List.from(preset.nodes);
      _poolTeams = Map.from(preset.poolTeams);
    });
    _showSuccess('Preset "${preset.name}" geladen');
  }

  void _deletePreset(BracketPreset preset) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preset löschen'),
        content: Text('Möchten Sie das Preset "${preset.name}" wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _presetService.deletePreset(preset.id);
                Navigator.pop(context);
                _showSuccess('Preset "${preset.name}" gelöscht');
                _loadPresets(); // Refresh the list
              } catch (e) {
                _showError('Fehler beim Löschen: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String message) {
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.fillColored,
      title: const Text('Erfolg'),
      description: Text(message),
      alignment: Alignment.topRight,
      autoCloseDuration: const Duration(seconds: 3),
      showProgressBar: false,
    );
  }

  void _showError(String message) {
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.fillColored,
      title: const Text('Fehler'),
      description: Text(message),
      alignment: Alignment.topRight,
      autoCloseDuration: const Duration(seconds: 4),
      showProgressBar: false,
    );
  }
} 