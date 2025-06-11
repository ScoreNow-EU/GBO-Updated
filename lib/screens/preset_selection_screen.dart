import 'package:flutter/material.dart';
import 'dart:math';
import '../models/tournament.dart';
import '../utils/bracket_templates.dart';
import '../services/preset_service.dart';

class PresetSelectionScreen extends StatefulWidget {
  final String divisionName;
  final Function(List<CustomBracketNode>, Map<String, List<String>>) onPresetSelected;

  const PresetSelectionScreen({
    super.key,
    required this.divisionName,
    required this.onPresetSelected,
  });

  @override
  State<PresetSelectionScreen> createState() => _PresetSelectionScreenState();
}

class _PresetSelectionScreenState extends State<PresetSelectionScreen> {
  String? hoveredPreset;
  List<CustomBracketNode>? previewNodes;
  List<BracketPreset> _savedPresets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedPresets();
  }

  void _loadSavedPresets() async {
    try {
      final presetService = PresetService();
      final presets = await presetService.getPresetsForDivision(widget.divisionName);
      setState(() {
        _savedPresets = presets;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading saved presets: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final templates = BracketTemplates.getAllTemplates();
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          // Left sidebar with preset list
          Container(
            width: 400,
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
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.blue),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Preset auswählen',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              widget.divisionName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Preset list
                Expanded(
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Saved presets section
                          if (_savedPresets.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                'Gespeicherte Presets',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            ..._savedPresets.map((preset) => _buildPresetCard(
                              preset.name,
                              preset.description,
                              Icons.bookmark,
                              Colors.green,
                              isCustomPreset: true,
                              preset: preset,
                            )).toList(),
                            const SizedBox(height: 24),
                          ],
                          
                          // Built-in templates section
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Eingebaute Vorlagen',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                          ...templates.keys.map((templateName) => _buildPresetCard(
                            templateName,
                            _getPresetDescription(templateName),
                            _getPresetIcon(templateName),
                            _getPresetColor(templateName),
                            isCustomPreset: false,
                            templateName: templateName,
                          )).toList(),
                        ],
                      ),
                ),
              ],
            ),
          ),
          
          // Right side - Preview area
          Expanded(
            child: Container(
              color: Colors.grey[100],
              child: Column(
                children: [
                  // Preview header
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
                          Icons.visibility_outlined,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          hoveredPreset != null ? 'Vorschau: $hoveredPreset' : 'Vorschau',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Preview content
                  Expanded(
                    child: previewNodes != null
                        ? _buildPreview()
                        : _buildEmptyPreview(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetCard(
    String name,
    String description,
    IconData icon,
    Color color, {
    required bool isCustomPreset,
    BracketPreset? preset,
    String? templateName,
  }) {
    final presetKey = isCustomPreset ? 'custom_${preset!.id}' : 'template_$templateName';
    final isHovered = hoveredPreset == presetKey;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: MouseRegion(
        onEnter: (_) => _onPresetHover(presetKey, isCustomPreset, preset, templateName),
        onExit: (_) => _onPresetExit(),
        child: GestureDetector(
          onTap: () => _onPresetTap(presetKey, isCustomPreset, preset, templateName),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isHovered ? Colors.blue.shade50 : Colors.white,
              border: Border.all(
                color: isHovered ? Colors.blue.shade300 : Colors.grey.shade300,
                width: isHovered ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: isHovered ? [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ] : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isHovered ? Colors.blue.shade700 : Colors.black87,
                                  ),
                                ),
                              ),
                              if (isCustomPreset)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Eigenes',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (isHovered)
                      Icon(
                        Icons.chevron_right,
                        color: Colors.blue.shade400,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onPresetHover(String presetKey, bool isCustomPreset, BracketPreset? preset, String? templateName) {
    setState(() {
      hoveredPreset = presetKey;
      
      if (isCustomPreset && preset != null) {
        previewNodes = preset.nodes;
      } else if (!isCustomPreset && templateName != null) {
        final templates = BracketTemplates.getAllTemplates();
        if (templates.containsKey(templateName)) {
          previewNodes = templates[templateName]!(widget.divisionName);
        }
      }
    });
  }

  void _onPresetExit() {
    setState(() {
      hoveredPreset = null;
      previewNodes = null;
    });
  }

  void _onPresetTap(String presetKey, bool isCustomPreset, BracketPreset? preset, String? templateName) {
    String presetName;
    List<CustomBracketNode> nodes;
    
    if (isCustomPreset && preset != null) {
      presetName = preset.name;
      nodes = preset.nodes;
    } else if (!isCustomPreset && templateName != null) {
      presetName = templateName;
      final templates = BracketTemplates.getAllTemplates();
      if (templates.containsKey(templateName)) {
        nodes = templates[templateName]!(widget.divisionName);
      } else {
        return;
      }
    } else {
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preset übernehmen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Möchten Sie das Preset "$presetName" laden?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Dies wird die aktuelle Struktur überschreiben.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              Map<String, List<String>> poolTeams = {};
              if (isCustomPreset && preset != null) {
                poolTeams = preset.poolTeams;
              }
              widget.onPresetSelected(nodes, poolTeams);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close preset selection screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Preset laden'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (previewNodes == null || previewNodes!.isEmpty) {
      return _buildEmptyPreview();
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background grid
            Positioned.fill(
              child: CustomPaint(
                painter: GridPainter(),
              ),
            ),
            
            // Interactive preview area
            Positioned.fill(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Container(
                    width: 1600,
                    height: 1000,
                    child: Stack(
                      children: [
                        // Nodes
                        ...previewNodes!.map((node) => _buildEnhancedPreviewNode(node)),
                        
                        // Connections
                        ..._buildEnhancedPreviewConnections(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // Preview overlay with info
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_in, color: Colors.blue.shade700, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Scrollen zum Vergrößern/Verkleinern',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPreview() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mouse_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Bewegen Sie den Mauszeiger über ein Preset,\num eine Vorschau zu sehen',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedPreviewNode(CustomBracketNode node) {
    Color color;
    IconData icon;
    double width, height;
    
    switch (node.nodeType) {
      case 'pool':
        color = Colors.purple;
        icon = Icons.workspaces;
        width = 300;
        height = 180;
        break;
      case 'match':
        color = Colors.blue;
        icon = Icons.sports_handball;
        width = 200;
        height = 100;
        break;
      case 'placement':
        color = Colors.orange;
        icon = Icons.emoji_events;
        width = 160;
        height = 80;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
        width = 200;
        height = 100;
    }

    return Positioned(
      left: node.x - (width / 2),
      top: node.y - (height / 2),
      child: _buildDetailedNode(node, color, icon, width, height),
    );
  }

  Widget _buildDetailedNode(CustomBracketNode node, Color color, IconData icon, double width, double height) {
    if (node.nodeType == 'pool') {
      return Stack(
        children: [
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: color, width: 2),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Pool header
                Container(
                  height: 40,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10),
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Icon(icon, color: color, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          node.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Pool content - sample teams
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        _buildSampleTeam('Team 1', 0),
                        const SizedBox(height: 4),
                        _buildSampleTeam('Team 2', 1),
                        const SizedBox(height: 4),
                        _buildSampleTeam('Team 3', 2),
                        const SizedBox(height: 4),
                        _buildSampleTeam('Team 4', 3),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Output connection points (right side) - one for each team position
          ..._buildPoolOutputPoints(4, height),
        ],
      );
    } else if (node.nodeType == 'match') {
      return Stack(
        children: [
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: color, width: 2),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Match header
                Container(
                  height: 30,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      topRight: Radius.circular(6),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: color, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        node.title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Match content
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildMatchTeamSlot('1st aus Pool A', true),
                      const SizedBox(height: 4),
                      Text('VS', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                      const SizedBox(height: 4),
                      _buildMatchTeamSlot('2nd aus Pool B', false),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Input connection points (left side)
          ..._buildMatchInputPoints(height),
          
          // Output connection point (right side)
          _buildMatchOutputPoint(width, height),
        ],
      );
    } else {
      // Placement node
      return Stack(
        children: [
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: color, width: 2),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 4),
                Text(
                  node.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (node.matchId != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      node.matchId!,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Input connection points (left side)
          ..._buildPlacementInputPoints(height),
        ],
      );
    }
  }

  Widget _buildSampleTeam(String name, int index) {
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.red];
    final color = colors[index % colors.length];
    
    return Container(
      height: 24,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchTeamSlot(String description, bool isWinner) {
    return Container(
      height: 20,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isWinner ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isWinner ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Center(
        child: Text(
          description,
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // Build output connection points for pool nodes
  List<Widget> _buildPoolOutputPoints(int teamCount, double height) {
    final points = <Widget>[];
    
    for (int i = 0; i < teamCount; i++) {
      // Position points along the right edge, aligned with team positions
      final yPosition = 40.0 + 8.0 + 12.0 + (i * 28.0); // Header + padding + half team height + team spacing
      
      points.add(
        Positioned(
          right: -6, // Extend beyond the node border
          top: yPosition,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return points;
  }

  // Build input connection points for match nodes
  List<Widget> _buildMatchInputPoints(double height) {
    return [
      // First input (upper)
      Positioned(
        left: -6,
        top: height * 0.35,
        child: _buildConnectionPoint(),
      ),
      // Second input (lower)
      Positioned(
        left: -6,
        top: height * 0.65,
        child: _buildConnectionPoint(),
      ),
    ];
  }

  // Build output connection point for match nodes
  Widget _buildMatchOutputPoint(double width, double height) {
    return Positioned(
      right: -6,
      top: height * 0.5,
      child: _buildConnectionPoint(),
    );
  }

  // Build input connection points for placement nodes
  List<Widget> _buildPlacementInputPoints(double height) {
    return [
      // Single input
      Positioned(
        left: -6,
        top: height * 0.5,
        child: _buildConnectionPoint(),
      ),
    ];
  }

  // Helper method to build a connection point
  Widget _buildConnectionPoint() {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: Colors.orange,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEnhancedPreviewConnections() {
    final connections = <Widget>[];
    
    for (final node in previewNodes!) {
      for (final inputId in node.inputConnections) {
        final sourceNode = previewNodes!.firstWhere(
          (n) => n.id == inputId,
          orElse: () => CustomBracketNode(id: '', nodeType: '', title: '', x: 0, y: 0),
        );
        
        if (sourceNode.id.isNotEmpty) {
          connections.add(
            Positioned.fill(
              child: CustomPaint(
                painter: EnhancedConnectionLinePainter(
                  start: Offset(sourceNode.x, sourceNode.y),
                  end: Offset(node.x, node.y),
                ),
              ),
            ),
          );
        }
      }
    }
    
    return connections;
  }

  Color _getPresetColor(String templateName) {
    if (templateName.contains('Simple')) return Colors.green;
    if (templateName.contains('Seniors')) return Colors.blue;
    if (templateName.contains('Fun')) return Colors.orange;
    return Colors.purple;
  }

  IconData _getPresetIcon(String templateName) {
    if (templateName.contains('Simple')) return Icons.account_tree;
    if (templateName.contains('Seniors')) return Icons.emoji_events;
    if (templateName.contains('Fun')) return Icons.sports_esports;
    return Icons.schema;
  }

  String _getPresetDescription(String templateName) {
    if (templateName.contains('Simple')) {
      return 'Einfaches Turnier mit Gruppenphase und direkten Finalspielen';
    }
    if (templateName.contains('Seniors')) {
      return 'Komplexes Turnier mit mehreren K.O.-Runden und Platzierungsspielen';
    }
    if (templateName.contains('Fun')) {
      return 'Nur Gruppenphase ohne K.O.-Runden';
    }
    return 'Turnier-Struktur Vorlage';
  }
}

// Custom painter for grid background
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final lightPaint = Paint()
      ..color = Colors.grey.withOpacity(0.05)
      ..strokeWidth = 1;

    final darkPaint = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..strokeWidth = 1;

    const spacing = 50.0;
    const majorSpacing = 200.0;

    // Draw minor grid lines
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        lightPaint,
      );
    }

    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        lightPaint,
      );
    }

    // Draw major grid lines
    for (double x = 0; x <= size.width; x += majorSpacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        darkPaint,
      );
    }

    for (double y = 0; y <= size.height; y += majorSpacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        darkPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom painter for connection lines
class ConnectionLinePainter extends CustomPainter {
  final Offset start;
  final Offset end;

  ConnectionLinePainter({required this.start, required this.end});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(start, end, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Enhanced connection line painter for better preview
class EnhancedConnectionLinePainter extends CustomPainter {
  final Offset start;
  final Offset end;

  EnhancedConnectionLinePainter({required this.start, required this.end});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Calculate control points for a curved line
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    
    final controlPoint1 = Offset(start.dx + dx * 0.5, start.dy);
    final controlPoint2 = Offset(start.dx + dx * 0.5, end.dy);

    final path = Path();
    path.moveTo(start.dx, start.dy);
    path.cubicTo(
      controlPoint1.dx, controlPoint1.dy,
      controlPoint2.dx, controlPoint2.dy,
      end.dx, end.dy,
    );

    canvas.drawPath(path, paint);

    // Draw arrow at the end
    _drawArrow(canvas, end, dx, dy);
  }

  void _drawArrow(Canvas canvas, Offset end, double dx, double dy) {
    final arrowPaint = Paint()
      ..color = Colors.blue.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final arrowSize = 8.0;
    final angle = atan2(dy, dx);

    final arrowPath = Path();
    arrowPath.moveTo(end.dx, end.dy);
    arrowPath.lineTo(
      end.dx - arrowSize * cos(angle - 0.5),
      end.dy - arrowSize * sin(angle - 0.5),
    );
    arrowPath.lineTo(
      end.dx - arrowSize * cos(angle + 0.5),
      end.dy - arrowSize * sin(angle + 0.5),
    );
    arrowPath.close();

    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}