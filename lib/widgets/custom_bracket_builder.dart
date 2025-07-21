import 'package:flutter/material.dart';
import 'dart:math';
import 'package:toastification/toastification.dart';
import '../models/tournament.dart';
import '../models/team.dart';
import '../models/game.dart';
import '../services/game_service.dart';
import '../utils/bracket_id_helper.dart';
import '../utils/bracket_templates.dart';
import '../screens/preset_selection_screen.dart';

class CustomBracketBuilder extends StatefulWidget {
  final List<CustomBracketNode> initialNodes;
  final Function(List<CustomBracketNode>) onBracketChanged;
  final String divisionName;
  final List<Team> availableTeams;
  final Function(Team, CustomBracketNode) onTeamDrop;
  final Map<String, List<String>> poolTeams; // poolId -> list of team IDs
  final List<Team> allTeams; // All teams for pool display
  final Function(String, List<String>)? onPresetTeamsLoaded; // callback for preset team assignments
  final Function(String, String)? onTeamRemove; // callback for team removal (poolId, teamId)
  final Map<String, List<String>> placeholderTeams; // poolId -> list of placeholder team IDs
  final Tournament tournament; // Add tournament reference
  final bool showLeftSidebar; // Add parameter to control sidebar visibility
  final List<String>? divisions; // Available divisions (optional)
  final String? selectedDivision; // Currently selected division (optional)
  final Function(String?)? onDivisionChanged; // Division change callback (optional)

  const CustomBracketBuilder({
    Key? key,
    required this.initialNodes,
    required this.onBracketChanged,
    required this.divisionName,
    this.availableTeams = const [],
    required this.onTeamDrop,
    this.poolTeams = const {},
    this.allTeams = const [],
    this.onPresetTeamsLoaded,
    this.onTeamRemove,
    this.placeholderTeams = const {},
    required this.tournament,
    this.showLeftSidebar = true,
    this.divisions,
    this.selectedDivision,
    this.onDivisionChanged,
  }) : super(key: key);

  @override
  State<CustomBracketBuilder> createState() => _CustomBracketBuilderState();
}

class _CustomBracketBuilderState extends State<CustomBracketBuilder> {
  List<CustomBracketNode> nodes = [];
  CustomBracketNode? selectedNode;
  CustomBracketNode? connectingFromNode;
  String? hoveredNodeId;
  String selectedLeftPanel = 'teams'; // 'teams' or 'palette'
  
  final ScrollController _scrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  final double canvasWidth = 2000;
  final double canvasHeight = 1200;
  
  // GlobalKey to get the canvas container render box for proper positioning
  final GlobalKey _canvasKey = GlobalKey();
  
  late final GameService _gameService;
  
  // Node templates with clearer names
  final Map<String, Map<String, dynamic>> nodeTemplates = {
    'Pool': {
      'nodeType': 'pool',
      'color': Colors.purple,
      'icon': Icons.workspaces,
      'width': 300.0,
      'height': 120.0,
    },
    '1v1 Match': {
      'nodeType': 'match',
      'color': Colors.blue,
      'icon': Icons.sports_handball,
      'width': 200.0,
      'height': 100.0,
    },
    'Placement': {
      'nodeType': 'placement',
      'color': Colors.orange,
      'icon': Icons.emoji_events,
      'width': 160.0,
      'height': 80.0,
    },
  };

  @override
  void initState() {
    super.initState();
    nodes = List.from(widget.initialNodes);
    _gameService = GameService();
    _preloadGames();
  }

  void _preloadGames() async {
    try {
      await _gameService.preloadGames(widget.tournament.id);
      print('🎮 Custom Bracket: Games preloaded for tournament ${widget.tournament.id}');
    } catch (e) {
      print('❌ Error preloading games in custom bracket: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 600,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildToolbar(),
          Expanded(
            child: widget.showLeftSidebar 
                ? Row(
              children: [
                _buildLeftSidebar(),
                Expanded(child: _buildCanvas()),
              ],
                  )
                : _buildCanvas(),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Icon(Icons.account_tree, color: Colors.blue, size: 20),
          const SizedBox(width: 8),
          // Division Selector or Title
          if (widget.divisions != null && widget.onDivisionChanged != null)
            DropdownButton<String>(
              value: widget.selectedDivision,
              hint: const Text('Division auswählen'),
              items: widget.divisions!.map((division) {
                return DropdownMenuItem(
                  value: division,
                  child: Text(division),
                );
              }).toList(),
              onChanged: widget.onDivisionChanged,
            )
          else
            Text(
              'Custom Bracket Builder - ${widget.divisionName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          const Spacer(),
          if (connectingFromNode != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Connecting from: ${connectingFromNode!.title}',
                style: TextStyle(
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => setState(() => connectingFromNode = null),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
          ],

          // Template buttons
          IconButton(
            icon: const Icon(Icons.account_tree_outlined),
            tooltip: 'Template laden',
            onPressed: _openPresetSelection,
          ),
          // Selected node actions
          if (selectedNode != null) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showRenameDialog(selectedNode!),
              tooltip: 'Rename Selected Node',
              color: Colors.blue,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteSelectedNode(),
              tooltip: 'Delete Selected Node',
              color: Colors.red,
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () => _deleteConnectedNodes(),
              tooltip: 'Delete All Connected Nodes',
              color: Colors.red.shade700,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearCanvas,
            tooltip: 'Clear Canvas',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveBracket,
            tooltip: 'Save Bracket',
          ),
        ],
      ),
    );
  }



  Widget _buildLeftSidebar() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          _buildLeftSidebarNavbar(),
          Expanded(
            child: selectedLeftPanel == 'teams' 
                ? _buildTeamsView()
                : _buildNodePalette(),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftSidebarNavbar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => selectedLeftPanel = 'teams'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selectedLeftPanel == 'teams' 
                      ? Colors.blue.shade50 
                      : Colors.transparent,
                  border: selectedLeftPanel == 'teams'
                      ? Border(bottom: BorderSide(color: Colors.blue, width: 2))
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.group,
                      size: 16,
                      color: selectedLeftPanel == 'teams' 
                          ? Colors.blue 
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Teams',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selectedLeftPanel == 'teams' 
                            ? FontWeight.bold 
                            : FontWeight.normal,
                        color: selectedLeftPanel == 'teams' 
                            ? Colors.blue 
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => selectedLeftPanel = 'palette'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selectedLeftPanel == 'palette' 
                      ? Colors.blue.shade50 
                      : Colors.transparent,
                  border: selectedLeftPanel == 'palette'
                      ? Border(bottom: BorderSide(color: Colors.blue, width: 2))
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_tree_outlined,
                      size: 16,
                      color: selectedLeftPanel == 'palette' 
                          ? Colors.blue 
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Palette',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selectedLeftPanel == 'palette' 
                            ? FontWeight.bold 
                            : FontWeight.normal,
                        color: selectedLeftPanel == 'palette' 
                            ? Colors.blue 
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Available Teams (${widget.availableTeams.length})',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: widget.availableTeams.isEmpty
              ? Center(
                  child: Text(
                    'All teams assigned\nto pools',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: widget.availableTeams.length,
                  itemBuilder: (context, index) {
                    final team = widget.availableTeams[index];
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Draggable<Team>(
                        data: team,
                        feedback: Material(
                          color: Colors.transparent,
                          child: _buildTeamFeedback(team),
                        ),
                        feedbackOffset: Offset.zero,
                        child: _buildTeamItem(team, index + 1),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTeamItem(Team team, int position) {
    Color divisionColor = _getDivisionColor(_getTeamDisplayDivision(team));
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: divisionColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                '$position',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  team.city,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.drag_indicator, color: Colors.grey[400], size: 14),
        ],
      ),
    );
  }

  Widget _buildCompactTeamItem(Team team, int position, {bool isProceeding = true}) {
    Color divisionColor = _getDivisionColor(_getTeamDisplayDivision(team));
    
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isProceeding ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isProceeding ? Colors.grey.shade300 : Colors.grey.shade400,
          style: isProceeding ? BorderStyle.solid : BorderStyle.solid,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: isProceeding ? divisionColor : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Center(
              child: Text(
                '$position',
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
              team.name,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isProceeding ? Colors.black87 : Colors.grey.shade600,
                fontSize: 10,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          if (!isProceeding) 
            Icon(Icons.block, color: Colors.grey[500], size: 10)
          else
            Icon(Icons.drag_indicator, color: Colors.grey[400], size: 12),
          if (!isProceeding)
            const SizedBox(width: 2),
        ],
      ),
    );
  }

  Widget _buildTeamFeedback(Team team) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                team.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  team.city,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTeamDisplayDivision(Team team) {
    // If this is a Senior team in a Fun tournament, display as Fun
    if (team.division.contains('Seniors') && widget.divisionName.contains('FUN')) {
      // Check if they're the same gender
      if ((team.division.contains('Women') && widget.divisionName.contains('Women')) ||
          (team.division.contains('Men') && widget.divisionName.contains('Men'))) {
        return widget.divisionName; // Use tournament division for display
      }
    }
    
    return team.division; // Use team's original division
  }

  Color _getDivisionColor(String division) {
    if (division.contains('Women')) {
      if (division.contains('FUN')) return Colors.pink;
      if (division.contains('U14')) return Colors.purple;
      if (division.contains('U16')) return Colors.deepPurple;
      if (division.contains('U18')) return Colors.indigo;
      return Colors.blue; // Women's Seniors
    } else {
      if (division.contains('FUN')) return Colors.orange;
      if (division.contains('U14')) return Colors.green;
      if (division.contains('U16')) return Colors.teal;
      if (division.contains('U18')) return Colors.cyan;
      return Colors.red; // Men's Seniors
    }
  }

  Widget _buildNodePalette() {
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Node Palette',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: nodeTemplates.entries.map((entry) {
                final name = entry.key;
                final template = entry.value;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Draggable<Map<String, dynamic>>(
                    data: {'type': name, 'template': template},
                    feedback: Material(
                      color: Colors.transparent,
                      child: _buildNodeWidget(
                        CustomBracketNode(
                          id: 'temp',
                          nodeType: template['nodeType'],
                          title: name,
                          x: 0,
                          y: 0,
                        ),
                        template,
                        isDragging: true,
                      ),
                    ),
                    feedbackOffset: Offset.zero,
                    child: _buildPaletteItem(name, template),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaletteItem(String name, Map<String, dynamic> template) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            template['icon'],
            color: template['color'],
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    return DragTarget<Object>(
      onAcceptWithDetails: (details) {
        final data = details.data;
        if (data is Map<String, dynamic> && data['type'] != null) {
          _addNodeFromTemplateAtPosition(data['type'], data['template'], details.offset);
        } else if (data is Team && selectedNode != null && selectedNode!.nodeType == 'pool') {
          widget.onTeamDrop(data, selectedNode!);
        }
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          color: candidateData.isNotEmpty ? Colors.blue.withOpacity(0.1) : Colors.white,
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              controller: _verticalScrollController,
              scrollDirection: Axis.vertical,
              child: Container(
                width: canvasWidth,
                height: canvasHeight,
                key: _canvasKey,
                child: Stack(
                  children: [
                    // Grid background
                    CustomPaint(
                      size: Size(canvasWidth, canvasHeight),
                      painter: GridPainter(),
                    ),
                    // Connection lines
                    CustomPaint(
                      size: Size(canvasWidth, canvasHeight),
                      painter: ConnectionPainter(nodes),
                    ),
                    // Connection drag handles
                    ..._buildConnectionHandles(),
                    // Nodes
                    ...nodes.map((node) => _buildDraggableNode(node)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDraggableNode(CustomBracketNode node) {
    final template = _getTemplateForNode(node);
    
    return Positioned(
      left: node.x,
      top: node.y,
      child: Draggable<CustomBracketNode>(
        data: node,
        feedback: Material(
          color: Colors.transparent,
          child: _buildNodeWidget(node, template, isDragging: true),
        ),
        feedbackOffset: Offset.zero,
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: _buildNodeWidget(node, template),
        ),
        onDragEnd: (details) {
          // Get the canvas container render box using the GlobalKey
          final canvasRenderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
          if (canvasRenderBox != null) {
            final localPosition = canvasRenderBox.globalToLocal(details.offset);
            
            setState(() {
              final index = nodes.indexWhere((n) => n.id == node.id);
              if (index != -1) {
                // Position top-left corner at cursor position
                nodes[index] = node.copyWith(
                  x: localPosition.dx.clamp(0, canvasWidth - (template['width'] as double)),
                  y: localPosition.dy.clamp(0, canvasHeight - (template['height'] as double)),
                );
              }
            });
          }
        },
        child: DragTarget<CustomBracketNode>(
          onAcceptWithDetails: (details) {
            // Removed automatic connection logic - connections only via connection points
          },
          builder: (context, candidateData, rejectedData) {
            final isHovering = candidateData.isNotEmpty && connectingFromNode != null;
            return _buildNodeWidget(
              node, 
              template, 
              isSelected: selectedNode?.id == node.id,
              isConnectable: isHovering,
            );
          },
        ),
      ),
    );
  }

  Widget _buildNodeWidget(
    CustomBracketNode node, 
    Map<String, dynamic> template, {
    bool isDragging = false,
    bool isSelected = false,
    bool isConnectable = false,
  }) {
    final width = template['width'] as double;
    final color = template['color'] as Color;
    final icon = template['icon'] as IconData;

    if (node.nodeType == 'pool') {
      return _buildPoolNodeWidget(node, template, 
          isDragging: isDragging, isSelected: isSelected, isConnectable: isConnectable);
    }

    // Match nodes can also accept team drops
    if (node.nodeType == 'match') {
      return _buildMatchNodeWidget(node, template,
          isDragging: isDragging, isSelected: isSelected, isConnectable: isConnectable);
    }

    // Placement nodes can also accept team drops
    if (node.nodeType == 'placement') {
      return _buildPlacementNodeWidget(node, template,
          isDragging: isDragging, isSelected: isSelected, isConnectable: isConnectable);
    }

    return GestureDetector(
      onTap: () => _selectNode(node),
      onDoubleTap: () => _editNode(node),
      child: Container(
        width: width,
        height: template['height'] as double,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
                ? Colors.blue 
                : isConnectable 
                    ? Colors.green 
                    : color.withOpacity(0.5),
            width: isSelected || isConnectable ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDragging ? 0.3 : 0.1),
              blurRadius: isDragging ? 12 : 4,
              offset: Offset(0, isDragging ? 4 : 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              node.title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            if (node.matchId != null) ...[
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  node.matchId!,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPoolNodeWidget(
    CustomBracketNode node, 
    Map<String, dynamic> template, {
    bool isDragging = false,
    bool isSelected = false,
    bool isConnectable = false,
  }) {
    final width = template['width'] as double;
    final color = template['color'] as Color;
    final icon = template['icon'] as IconData;

    // Calculate dynamic height based on number of teams
    final poolId = '${widget.divisionName}_${node.title}';
    final assignedTeams = widget.poolTeams[poolId] ?? [];
    final teamItemHeight = 40.0;
    final headerHeight = 32.0;
    final padding = 16.0;
    final minContentHeight = 40.0;
    
    final contentHeight = assignedTeams.isEmpty 
        ? minContentHeight 
        : (assignedTeams.length * teamItemHeight);
    
    final dynamicHeight = headerHeight + contentHeight + padding;

    return GestureDetector(
      onTap: () => _selectNode(node),
      onDoubleTap: () => _editNode(node),
      child: Stack(
        children: [
          // Main pool container
          DragTarget<Team>(
            onWillAccept: (team) => true, // Always allow drops
            onAccept: (team) {
              // Pass both team and node to the callback for proper assignment
              widget.onTeamDrop(team, node);
              
              // Show success feedback
              toastification.show(
                context: context,
                type: ToastificationType.success,
                style: ToastificationStyle.fillColored,
                title: const Text('Erfolg'),
                description: Text('${team.name} zu ${node.title} hinzugefügt'),
                alignment: Alignment.topRight,
                autoCloseDuration: const Duration(seconds: 2),
                showProgressBar: false,
              );
            },
            builder: (context, candidateData, rejectedData) {
              final isHoveringTeam = candidateData.isNotEmpty;
              
              return Container(
                width: width,
                height: dynamicHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected 
                        ? Colors.blue 
                        : isConnectable 
                            ? Colors.green 
                            : isHoveringTeam
                                ? color
                                : color.withOpacity(0.5),
                    width: isSelected || isConnectable || isHoveringTeam ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDragging ? 0.3 : 0.1),
                      blurRadius: isDragging ? 12 : 4,
                      offset: Offset(0, isDragging ? 4 : 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pool header
                    Container(
                      height: headerHeight,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(11),
                          topRight: Radius.circular(11),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(icon, size: 16, color: color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              node.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: color,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Pool content
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: _buildPoolContent(node),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Connection points
          ..._buildPoolOutputPoints(node, assignedTeams, dynamicHeight, width),
        ],
      ),
    );
  }

  Widget _buildMatchNodeWidget(
    CustomBracketNode node, 
    Map<String, dynamic> template, {
    bool isDragging = false,
    bool isSelected = false,
    bool isConnectable = false,
  }) {
    final width = template['width'] as double;
    final height = template['height'] as double;
    final color = template['color'] as Color;
    final icon = template['icon'] as IconData;

    // Get assigned teams for this match
    final matchId = '${widget.divisionName}_${node.title}';
    final assignedTeams = widget.poolTeams[matchId] ?? [];
    final bestOf = node.properties['bestOf'] as String? ?? 'one';

    return GestureDetector(
      onTap: () => _selectNode(node),
      onDoubleTap: () => _editNode(node),
      child: Stack(
        children: [
          // Main match container
          DragTarget<Team>(
            onAcceptWithDetails: (details) {
              final team = details.data;
              // Only allow 2 teams max in a 1v1 match
              if (assignedTeams.length < 2) {
                widget.onTeamDrop(team, node);
                
                toastification.show(
                  context: context,
                  type: ToastificationType.success,
                  style: ToastificationStyle.fillColored,
                  title: const Text('Erfolg'),
                  description: Text('${team.name} zu ${node.title} hinzugefügt'),
                  alignment: Alignment.topRight,
                  autoCloseDuration: const Duration(seconds: 2),
                  showProgressBar: false,
                );
              } else {
                toastification.show(
                  context: context,
                  type: ToastificationType.warning,
                  style: ToastificationStyle.fillColored,
                  title: const Text('Warnung'),
                  description: Text('${node.title} ist bereits voll (max. 2 Teams)'),
                  alignment: Alignment.topRight,
                  autoCloseDuration: const Duration(seconds: 2),
                  showProgressBar: false,
                );
              }
            },
            builder: (context, candidateData, rejectedData) {
              final isHoveringTeam = candidateData.isNotEmpty;
              
              return Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected 
                        ? Colors.blue 
                        : isConnectable 
                            ? Colors.green 
                            : isHoveringTeam
                                ? color
                                : color.withOpacity(0.5),
                    width: isSelected || isConnectable || isHoveringTeam ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDragging ? 0.3 : 0.1),
                      blurRadius: isDragging ? 12 : 4,
                      offset: Offset(0, isDragging ? 4 : 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Match header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isHoveringTeam ? color.withOpacity(0.1) : Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(icon, color: color, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              node.title,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          // Best of indicator
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Best of ${bestOf == 'one' ? '1' : bestOf == 'three' ? '3' : '5'}',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w500,
                                color: color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Individual match button
                          _buildMatchActionButton(node, assignedTeams),
                        ],
                      ),
                    ),
                    
                    // Match content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: _buildMatchContent(node, assignedTeams),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          // Input connection points (left side) - 2 inputs for teams
          ..._buildMatchInputPoints(node, width, height),
          
          // Output connection points (right side) - 2 outputs for winner/loser
          ..._buildMatchOutputPoints(node, width, height),
        ],
      ),
    );
  }

  // Helper method to build match content
  Widget _buildMatchContent(CustomBracketNode node, List<String> assignedTeams) {
    final bestOf = node.properties['bestOf'] as String? ?? 'one';
    final subMatches = (node.properties['subMatches'] as List<Map<String, int>>?) ?? [];
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Team slots
        ...List.generate(2, (index) {
          final teamId = assignedTeams.length > index ? assignedTeams[index] : null;
          final team = teamId != null 
              ? widget.allTeams.firstWhere((t) => t.id == teamId, orElse: () => Team(
                  id: '',
                  name: 'TBD',
                  city: '',
                  bundesland: '',
                  division: '',
                  createdAt: DateTime.now(),
                ))
              : null;
          
          return Container(
            margin: EdgeInsets.only(bottom: index == 0 ? 4 : 0),
            child: team != null && team.id.isNotEmpty
                ? _buildMatchTeamItem(team)
                : _buildEmptyTeamSlot(),
          );
        }),
        
        // Show sub-matches for best of 3/5
        if (bestOf != 'one' && subMatches.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: subMatches.map((match) {
                final team1Score = match['team1'] ?? 0;
                final team2Score = match['team2'] ?? 0;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    '$team1Score:$team2Score',
                    style: const TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyTeamSlot() {
    return Container(
      height: 16,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: const Center(
        child: Text(
          'TBD',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey,
            fontSize: 9,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildPlacementNodeWidget(
    CustomBracketNode node, 
    Map<String, dynamic> template, {
    bool isDragging = false,
    bool isSelected = false,
    bool isConnectable = false,
  }) {
    final width = template['width'] as double;
    final height = template['height'] as double;
    final color = template['color'] as Color;
    final icon = template['icon'] as IconData;

    // Get assigned team for this placement
    final placementId = '${widget.divisionName}_${node.title}';
    final assignedTeams = widget.poolTeams[placementId] ?? [];

    // Extract placement position from matchId (e.g., "3" for 3rd place)
    final placementPosition = node.matchId != null ? int.tryParse(node.matchId!) ?? 1 : 1;

    return GestureDetector(
      onTap: () => _selectNode(node),
      onDoubleTap: () => _showPlacementEditDialog(node),
      child: Stack(
        children: [
          // Main placement container
          DragTarget<Team>(
            onAcceptWithDetails: (details) {
              final team = details.data;
              // Only allow 1 team max in a placement
              if (assignedTeams.isEmpty) {
                widget.onTeamDrop(team, node);
                
                toastification.show(
                  context: context,
                  type: ToastificationType.success,
                  style: ToastificationStyle.fillColored,
                  title: const Text('Erfolg'),
                  description: Text('${team.name} zu ${node.title} hinzugefügt'),
                  alignment: Alignment.topRight,
                  autoCloseDuration: const Duration(seconds: 2),
                  showProgressBar: false,
                );
              } else {
                toastification.show(
                  context: context,
                  type: ToastificationType.warning,
                  style: ToastificationStyle.fillColored,
                  title: const Text('Warnung'),
                  description: Text('${node.title} hat bereits ein Team zugewiesen'),
                  alignment: Alignment.topRight,
                  autoCloseDuration: const Duration(seconds: 2),
                  showProgressBar: false,
                );
              }
            },
            builder: (context, candidateData, rejectedData) {
              final isHoveringTeam = candidateData.isNotEmpty;
              
              return Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected 
                        ? Colors.blue 
                        : isConnectable 
                            ? Colors.green 
                            : isHoveringTeam
                                ? color
                                : color.withOpacity(0.5),
                    width: isSelected || isConnectable || isHoveringTeam ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDragging ? 0.3 : 0.1),
                      blurRadius: isDragging ? 12 : 4,
                      offset: Offset(0, isDragging ? 4 : 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Placement header with position
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isHoveringTeam ? color.withOpacity(0.1) : Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(icon, color: color, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              node.title,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          // Position indicator
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_getOrdinalNumber(placementPosition)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Placement content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: _buildPlacementContent(node, assignedTeams),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          // Input connection point (left side) - 1 input for team
          ..._buildPlacementInputPoints(node, width, height),
        ],
      ),
    );
  }

  Widget _buildPlacementContent(CustomBracketNode node, List<String> assignedTeams) {
    // Check for input connections to show connected teams
    final connectedInputs = _getConnectedInputs(node);
    
    if (assignedTeams.isEmpty && connectedInputs.isEmpty) {
      return Center(
        child: Text(
          'Drop team here\nfor placement',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    // Show connected input first, then assigned team
    if (connectedInputs.isNotEmpty && connectedInputs[0].isNotEmpty) {
      return Center(child: _buildConnectedInputItem(connectedInputs[0]));
    } else if (assignedTeams.isNotEmpty) {
      final team = widget.allTeams.firstWhere((t) => t.id == assignedTeams[0]);
      return Center(
        child: Draggable<Team>(
          data: team,
          feedback: Material(
            color: Colors.transparent,
            child: _buildTeamFeedback(team),
          ),
          feedbackOffset: Offset.zero,
          child: _buildPlacementTeamItem(team),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildPlacementTeamItem(Team team) {
    return Container(
      height: 20,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _getDivisionColor(_getTeamDisplayDivision(team)).withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _getDivisionColor(_getTeamDisplayDivision(team)).withOpacity(0.3)),
      ),
      child: Center(
        child: Text(
          team.name,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.black87,
            fontSize: 10,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  List<Widget> _buildPlacementInputPoints(CustomBracketNode node, double width, double height) {
    final points = <Widget>[];
    
    // Single input connection point (left side)
    points.add(
      Positioned(
        left: -8, // Slightly outside the container on the left
        top: height / 2 - 8, // Center vertically
        child: GestureDetector(
          onTap: () {
            // Handle input connection
            if (connectingFromNode != null) {
              _connectToPlacementInput(connectingFromNode!, node);
              setState(() => connectingFromNode = null);
            }
          },
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_forward,
              color: Colors.white,
              size: 8,
            ),
          ),
        ),
      ),
    );
    
    // Add label for the input
    points.add(
      Positioned(
        left: -35,
        top: height / 2 - 6,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'Team',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w500,
              color: Colors.orange.shade700,
            ),
          ),
        ),
      ),
    );
    
    return points;
  }

  void _connectToPlacementInput(CustomBracketNode fromNode, CustomBracketNode toNode) {
    setState(() {
      final fromIndex = nodes.indexWhere((n) => n.id == fromNode.id);
      final toIndex = nodes.indexWhere((n) => n.id == toNode.id);
      
      if (fromIndex != -1 && toIndex != -1) {
        // Get the output index from the fromNode's stored matchId
        int outputIndex = 1; // Default
        if (fromNode.matchId != null && fromNode.matchId!.startsWith('output_')) {
          outputIndex = int.tryParse(fromNode.matchId!.split('_').last) ?? 1;
        }
        
        // Add connection with specific input/output information
        // Format: targetNodeId_input_inputIndex_source_sourceNodeId_output_outputIndex
        final connectionId = '${toNode.id}_input_0_source_${fromNode.id}_output_$outputIndex';
        
        nodes[fromIndex] = nodes[fromIndex].copyWith(
          outputConnections: [...nodes[fromIndex].outputConnections, connectionId],
        );
        
        nodes[toIndex] = nodes[toIndex].copyWith(
          inputConnections: [...nodes[toIndex].inputConnections, connectionId],
        );
      }
    });
  }

  void _showPlacementEditDialog(CustomBracketNode node) {
    final titleController = TextEditingController(text: node.title);
    final positionController = TextEditingController(text: node.matchId ?? '1');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Placement Node'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: positionController,
              decoration: const InputDecoration(
                labelText: 'Final Position (1, 2, 3, etc.)',
                border: OutlineInputBorder(),
                hintText: 'Enter position number',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => _deleteNode(node),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              final position = int.tryParse(positionController.text) ?? 1;
              _updateNode(node, titleController.text, position.toString());
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _getOrdinalNumber(int number) {
    if (number >= 11 && number <= 13) {
      return '${number}th';
    }
    switch (number % 10) {
      case 1: return '${number}st';
      case 2: return '${number}nd';
      case 3: return '${number}rd';
      default: return '${number}th';
    }
  }

  // Pool action button with tooltip
  Widget _buildPoolActionButton(CustomBracketNode node, List<String> assignedTeams) {
    final poolId = '${widget.divisionName}_${node.title}';
    final hasGames = _hasPoolGames(poolId);
    final possibleGames = _calculatePossiblePoolGames(assignedTeams.length);
    final canGenerateGames = assignedTeams.length >= 2;
    
    return _buildCustomTooltip(
      content: _buildPoolTooltipContent(node, assignedTeams),
      child: MouseRegion(
        cursor: canGenerateGames ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
        child: GestureDetector(
          onTap: canGenerateGames ? () => _generatePoolGames(node, assignedTeams) : null,
          child: Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: canGenerateGames 
                  ? (hasGames ? Colors.orange : Colors.blue)
                  : Colors.grey,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              hasGames ? Icons.refresh : (canGenerateGames ? Icons.sports_handball : Icons.block),
              color: Colors.white,
              size: 14,
            ),
          ),
        ),
      ),
    );
  }

  // Match action button with tooltip
  Widget _buildMatchActionButton(CustomBracketNode node, List<String> assignedTeams) {
    final matchId = '${widget.divisionName}_${node.title}';
    final hasGame = _hasMatchGame(node);
    final connectedInputs = _getConnectedInputs(node);
    
    // Count actual teams (assigned) and placeholder teams (connected inputs)
    int totalTeams = assignedTeams.length;
    for (String input in connectedInputs) {
      if (input.isNotEmpty) totalTeams++;
    }
    
    final canGenerateGame = totalTeams >= 2;
    
    return _buildCustomTooltip(
      content: _buildMatchTooltipContent(node, assignedTeams, connectedInputs),
      child: MouseRegion(
        cursor: canGenerateGame ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
        child: GestureDetector(
          onTap: canGenerateGame ? () => _generateMatchGame(node, assignedTeams, connectedInputs) : null,
          child: Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: canGenerateGame 
                  ? (hasGame ? Colors.orange : Colors.green)
                  : Colors.grey,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              hasGame ? Icons.refresh : (canGenerateGame ? Icons.play_arrow : Icons.block),
              color: Colors.white,
              size: 12,
            ),
          ),
        ),
      ),
    );
  }

  // Build custom tooltip wrapper
  Widget _buildCustomTooltip({required Widget content, required Widget child}) {
    return Tooltip(
      richMessage: WidgetSpan(child: content),
      waitDuration: const Duration(milliseconds: 500),
      showDuration: const Duration(seconds: 10),
      preferBelow: false,
      verticalOffset: 10,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: child,
    );
  }

  // Build pool tooltip content with team-item styling
  Widget _buildPoolTooltipContent(CustomBracketNode node, List<String> assignedTeams) {
    if (assignedTeams.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(8),
        child: Text(
          'Keine Spiele möglich',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    final teams = assignedTeams.map((teamId) {
      final team = widget.allTeams.firstWhere((t) => t.id == teamId, orElse: () => Team(id: teamId, name: teamId, city: '', bundesland: '', division: '', createdAt: DateTime.now()));
      return team;
    }).toList();

    // Generate all possible pool games
    final games = <Widget>[];
    int gameIndex = 1;
    for (int i = 0; i < teams.length; i++) {
      for (int j = i + 1; j < teams.length; j++) {
        games.add(_buildGameItem('${teams[i].name} vs ${teams[j].name}', gameIndex));
        gameIndex++;
      }
    }

    if (games.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(8),
        child: Text(
          'Keine Spiele möglich',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 350, maxHeight: 400),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: games,
        ),
      ),
    );
  }

  // Build match tooltip content
  Widget _buildMatchTooltipContent(CustomBracketNode node, List<String> assignedTeams, List<String> connectedInputs) {
    // Count total teams available (assigned + connected placeholders)
    int totalTeams = assignedTeams.length;
    for (String input in connectedInputs) {
      if (input.isNotEmpty) totalTeams++;
    }
    
    if (totalTeams == 0) {
      return Container(
        padding: const EdgeInsets.all(8),
        child: Text(
          'Kein Spiel möglich',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    String gameText;
    String team1Name = '';
    String team2Name = '';
    
    // Determine team 1
    if (assignedTeams.isNotEmpty) {
      final team = widget.allTeams.firstWhere((t) => t.id == assignedTeams[0], orElse: () => Team(id: assignedTeams[0], name: assignedTeams[0], city: '', bundesland: '', division: '', createdAt: DateTime.now()));
      team1Name = team.name;
    } else if (connectedInputs.isNotEmpty && connectedInputs[0].isNotEmpty) {
      team1Name = connectedInputs[0];
    }
    
    // Determine team 2
    if (assignedTeams.length >= 2) {
      final team = widget.allTeams.firstWhere((t) => t.id == assignedTeams[1], orElse: () => Team(id: assignedTeams[1], name: assignedTeams[1], city: '', bundesland: '', division: '', createdAt: DateTime.now()));
      team2Name = team.name;
    } else if (connectedInputs.length >= 2 && connectedInputs[1].isNotEmpty) {
      team2Name = connectedInputs[1];
    } else if (assignedTeams.length == 1 && connectedInputs.isNotEmpty && connectedInputs[0].isNotEmpty) {
      team2Name = connectedInputs[0];
    }
    
    if (team1Name.isNotEmpty && team2Name.isNotEmpty) {
      gameText = '$team1Name vs $team2Name';
    } else if (team1Name.isNotEmpty) {
      gameText = '$team1Name vs Wartend...';
    } else {
      gameText = 'Bereit für Planung';
    }

    // Smaller constraints for match tooltips since they only show one game
    return Container(
      constraints: const BoxConstraints(maxWidth: 250, maxHeight: 100),
      padding: const EdgeInsets.all(4),
      child: _buildGameItem(gameText, 1),
    );
  }

  // Build individual game item with team boxes and vs
  Widget _buildGameItem(String gameText, int index) {
    // Parse team names from "Team A vs Team B" format
    final parts = gameText.split(' vs ');
    final teamA = parts.isNotEmpty ? parts[0] : 'Team A';
    final teamB = parts.length > 1 ? parts[1] : 'Team B';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          // Team A
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.blue.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                teamA,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // Game number and VS in the middle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$index',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Text(
                  'vs',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          // Team B
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.red.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                teamB,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Check if pool has games
  bool _hasPoolGames(String poolId) {
    final games = _gameService.getPoolGames(widget.tournament.id, poolId);
    return games.isNotEmpty;
  }

  // Check if match has game
  bool _hasMatchGame(CustomBracketNode node) {
    // Check for games that match this node
    final allGames = _gameService.getGamesForTournamentSync(widget.tournament.id);
    
    // Debug logging
    print('Checking for games for node: ${node.title}');
    print('Total games in tournament: ${allGames.length}');
    
    for (final game in allGames) {
      print('Game ID: ${game.id}');
      if (game.gameType == GameType.elimination && game.id.contains('_match_${node.title}_')) {
        print('Found matching game for ${node.title}');
        return true;
      }
    }
    
    print('No games found for ${node.title}');
    return false;
  }

  // Calculate possible pool games
  int _calculatePossiblePoolGames(int teamCount) {
    if (teamCount < 2) return 0;
    return (teamCount * (teamCount - 1)) ~/ 2; // n choose 2
  }

  // Generate pool games
  Future<void> _generatePoolGames(CustomBracketNode node, List<String> assignedTeams) async {
    if (assignedTeams.length < 2) {
      _showError('Pool "${node.title}" benötigt mindestens 2 Teams für Spiele');
      return;
    }

    try {
      final poolName = node.title;
      final teams = assignedTeams.map((teamId) => 
        widget.allTeams.firstWhere((t) => t.id == teamId, orElse: () => Team(id: teamId, name: teamId, city: '', bundesland: '', division: '', createdAt: DateTime.now()))
      ).toList();

      // Generate the games list for display
      final games = <String>[];
      for (int i = 0; i < teams.length; i++) {
        for (int j = i + 1; j < teams.length; j++) {
          games.add('${teams[i].name} vs ${teams[j].name}');
        }
      }

      await _gameService.generatePoolGames(
        widget.tournament.id,
        poolName,
        teams,
      );

      _showSuccess(
        'Pool "${poolName}" Spiele generiert:\n${games.join('\n')}\n\nInsgesamt: ${games.length} Spiele'
      );
      
      // Refresh the UI to update button states
      setState(() {});
    } catch (e) {
      _showError('Fehler beim Generieren der Pool-Spiele: $e');
    }
  }

  // Generate match game
  Future<void> _generateMatchGame(CustomBracketNode node, List<String> assignedTeams, List<String> connectedInputs) async {
    // Count total teams available (assigned + connected placeholders)
    int totalTeams = assignedTeams.length;
    for (String input in connectedInputs) {
      if (input.isNotEmpty) totalTeams++;
    }
    
    if (totalTeams < 2) {
      _showError('Match "${node.title}" benötigt 2 Teams für ein Spiel');
      return;
    }

    try {
      String team1Name = '';
      String team2Name = '';
      String? team1Id;
      String? team2Id;
      
      // Determine team 1
      if (assignedTeams.isNotEmpty) {
        final team = widget.allTeams.firstWhere((t) => t.id == assignedTeams[0], orElse: () => Team(id: assignedTeams[0], name: assignedTeams[0], city: '', bundesland: '', division: '', createdAt: DateTime.now()));
        team1Name = team.name;
        team1Id = team.id;
      } else if (connectedInputs.isNotEmpty && connectedInputs[0].isNotEmpty) {
        team1Name = connectedInputs[0]; // Placeholder like "2nd from Pool B"
        team1Id = null; // No actual team ID yet
      }
      
      // Determine team 2
      if (assignedTeams.length >= 2) {
        final team = widget.allTeams.firstWhere((t) => t.id == assignedTeams[1], orElse: () => Team(id: assignedTeams[1], name: assignedTeams[1], city: '', bundesland: '', division: '', createdAt: DateTime.now()));
        team2Name = team.name;
        team2Id = team.id;
      } else if (connectedInputs.length >= 2 && connectedInputs[1].isNotEmpty) {
        team2Name = connectedInputs[1]; // Placeholder like "Winner from 2nd Chance 1"
        team2Id = null; // No actual team ID yet
      } else if (assignedTeams.length == 1 && connectedInputs.isNotEmpty && connectedInputs[0].isNotEmpty) {
        team2Name = connectedInputs[0];
        team2Id = null;
      }

      // Create a game with placeholder support
      final gameId = '${widget.tournament.id}_match_${node.title}_${team1Id ?? 'placeholder1'}_${team2Id ?? 'placeholder2'}';
      final game = Game(
        id: gameId,
        tournamentId: widget.tournament.id,
        teamAId: team1Id,
        teamBId: team2Id,
        teamAName: team1Name,
        teamBName: team2Name,
        gameType: GameType.elimination,
        status: GameStatus.scheduled,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Add the game to the service
      await _gameService.addGame(game);

      _showSuccess(
        'Match "${node.title}" generiert:\n\n$team1Name\nvs\n$team2Name\n\nSpiel erfolgreich erstellt!\n${team1Id == null || team2Id == null ? '\n(Mit Platzhaltern für Planung)' : ''}'
      );
      
      // Refresh the UI to update button states
      setState(() {});
    } catch (e) {
      _showError('Fehler beim Generieren des Spiels: $e');
    }
  }

  // Show success message
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

  // Show error message
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

  void _openPresetSelection() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PresetSelectionScreen(
          divisionName: widget.divisionName,
          onPresetSelected: (templateNodes, presetPoolTeams) {
            setState(() {
              nodes = List.from(templateNodes);
              selectedNode = null;
              connectingFromNode = null;
            });
            
            // Load preset team assignments and preserve them
            _loadPresetTeamAssignments(presetPoolTeams);
            
            widget.onBracketChanged(nodes);
            
            toastification.show(
              context: context,
              type: ToastificationType.success,
              style: ToastificationStyle.fillColored,
              title: const Text('Erfolg'),
              description: const Text('Preset erfolgreich geladen!'),
              alignment: Alignment.topRight,
              autoCloseDuration: const Duration(seconds: 2),
              showProgressBar: false,
            );
          },
        ),
      ),
    );
  }

  void _showRenameDialog(CustomBracketNode node) {
    final titleController = TextEditingController(text: node.title);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rename Node'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'Title',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _updateNode(node, titleController.text, node.matchId ?? '');
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteSelectedNode() {
    if (selectedNode != null) {
      _deleteNode(selectedNode!);
    }
  }

  void _deleteConnectedNodes() {
    if (selectedNode != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Connected Nodes'),
          content: Text('Are you sure you want to delete all nodes connected to "${selectedNode!.title}"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _performDeleteConnectedNodes();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete All'),
            ),
          ],
        ),
      );
    }
  }

  void _clearCanvas() {
    setState(() {
      nodes.clear();
      selectedNode = null;
      connectingFromNode = null;
    });
  }

  void _saveBracket() {
    widget.onBracketChanged(nodes);
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.fillColored,
      title: const Text('Erfolg'),
      description: const Text('Bracket-Struktur gespeichert!'),
      alignment: Alignment.topRight,
      autoCloseDuration: const Duration(seconds: 2),
      showProgressBar: false,
    );
  }

  void _addNodeFromTemplateAtPosition(String templateName, Map<String, dynamic> template, Offset globalPosition) {
    // Get the canvas container render box using the GlobalKey
    final canvasRenderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (canvasRenderBox != null) {
      final localPosition = canvasRenderBox.globalToLocal(globalPosition);
      
      String finalTitle = templateName;
      
      // Generate unique pool names
      if (template['nodeType'] == 'pool') {
        final existingPoolCount = nodes.where((n) => n.nodeType == 'pool').length;
        final poolLetter = String.fromCharCode(65 + existingPoolCount); // A, B, C, etc.
        finalTitle = 'Pool $poolLetter';
      }
      
      // Generate unique match names
      if (template['nodeType'] == 'match') {
        final existingMatchCount = nodes.where((n) => n.nodeType == 'match').length;
        finalTitle = 'Match ${existingMatchCount + 1}';
      }
      
      // Generate unique placement names
      if (template['nodeType'] == 'placement') {
        final existingPlacementCount = nodes.where((n) => n.nodeType == 'placement').length;
        finalTitle = 'Placement ${existingPlacementCount + 1}';
      }
      
      // Place top-left corner at drop position
      final nodeWidth = template['width'] as double;
      final nodeHeight = template['height'] as double;
      
      final node = CustomBracketNode(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nodeType: template['nodeType'],
        title: finalTitle,
        x: localPosition.dx.clamp(0, canvasWidth - nodeWidth),
        y: localPosition.dy.clamp(0, canvasHeight - nodeHeight),
        properties: template['nodeType'] == 'match' ? {'bestOf': 'one'} : {},
      );
      
      setState(() {
        nodes.add(node);
      });
    }
  }

  List<Widget> _buildConnectionHandles() {
    final handles = <Widget>[];
    for (final node in nodes) {
      for (final outputId in node.outputConnections) {
        final targetNode = nodes.firstWhere(
          (n) => n.id == outputId,
          orElse: () => CustomBracketNode(id: '', nodeType: '', title: '', x: 0, y: 0),
        );
        
        if (targetNode.id.isNotEmpty) {
          final startX = node.x + 60; // Center of source node
          final startY = node.y + 40;
          final endX = targetNode.x + 60; // Center of target node
          final endY = targetNode.y + 40;

          handles.add(
            Positioned(
              left: startX,
              top: startY,
              child: Draggable<CustomBracketNode>(
                data: node,
                feedback: Material(
                  color: Colors.transparent,
                  child: _buildConnectionHandle(node, targetNode),
                ),
                feedbackOffset: Offset.zero,
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: _buildConnectionHandle(node, targetNode),
                ),
                child: _buildConnectionHandle(node, targetNode),
                onDragEnd: (details) {
                  // Get the canvas container render box using the GlobalKey
                  final canvasRenderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                  if (canvasRenderBox != null) {
                    final localPosition = canvasRenderBox.globalToLocal(details.offset);
                    
                    setState(() {
                      final fromIndex = nodes.indexWhere((n) => n.id == node.id);
                      final toIndex = nodes.indexWhere((n) => n.id == targetNode.id);
                      if (fromIndex != -1 && toIndex != -1) {
                        nodes[fromIndex] = node.copyWith(
                          outputConnections: [...node.outputConnections.where((id) => id != targetNode.id)],
                        );
                        nodes[toIndex] = targetNode.copyWith(
                          inputConnections: [...targetNode.inputConnections.where((id) => id != node.id)],
                        );
                      }
                    });
                  }
                },
              ),
            ),
          );
        }
      }
    }
    return handles;
  }

  Map<String, dynamic> _getTemplateForNode(CustomBracketNode node) {
    for (final entry in nodeTemplates.entries) {
      if (entry.value['nodeType'] == node.nodeType) {
        return entry.value;
      }
    }
    return nodeTemplates.values.first;
  }

  void _selectNode(CustomBracketNode node) {
    setState(() {
      selectedNode = node;
    });
  }

  void _editNode(CustomBracketNode node) {
    if (node.nodeType == 'pool') {
      _showPlacementEditDialog(node);
    } else if (node.nodeType == 'match') {
      _showMatchEditDialog(node);
    } else if (node.nodeType == 'placement') {
      _showPlacementEditDialog(node);
    }
  }

  void _updateNode(CustomBracketNode node, String newTitle, String newMatchId) {
    setState(() {
      final index = nodes.indexWhere((n) => n.id == node.id);
      if (index != -1) {
        nodes[index] = node.copyWith(title: newTitle, matchId: newMatchId);
      }
    });
  }

  void _deleteNode(CustomBracketNode node) {
    setState(() {
      nodes.removeWhere((n) => n.id == node.id);
      selectedNode = null;
      connectingFromNode = null;
    });
  }

  void _performDeleteConnectedNodes() {
    if (selectedNode != null) {
      setState(() {
        nodes.removeWhere((node) {
          final isConnected = node.outputConnections.any((id) => id == selectedNode!.id) ||
                              node.inputConnections.any((id) => id == selectedNode!.id);
          return isConnected;
        });
        selectedNode = null;
        connectingFromNode = null;
      });
    }
  }

  List<String> _getConnectedInputs(CustomBracketNode node) {
    final connectedInputs = <String>[];
    for (final outputId in node.outputConnections) {
      final parts = outputId.split('_');
      if (parts.length >= 7 && parts[1] == 'input' && parts[3] == 'source' && parts[5] == 'output') {
        final sourceNodeId = parts[6]; // source_node_id
        final sourceOutputIndex = int.tryParse(parts[2]) ?? 0; // input_index
        final sourceNode = nodes.firstWhere(
          (n) => n.id == sourceNodeId,
          orElse: () => CustomBracketNode(id: '', nodeType: '', title: '', x: 0, y: 0),
        );
        if (sourceNode.id.isNotEmpty) {
          final sourceOutputPoint = _getOutputPoint(sourceNode, sourceOutputIndex);
          final localPosition = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
          if (localPosition != null) {
            final globalPosition = localPosition.localToGlobal(sourceOutputPoint);
            connectedInputs.add(globalPosition.toString());
          }
        }
      } else if (parts.length >= 3) {
        // Handle old format for backward compatibility
        final sourceNodeId = parts[0]; // target_node_id
        final connectionType = parts[1]; // 'input' or 'output'
        final connectionIndex = int.tryParse(parts[2]) ?? 0; // input_index or output_index
        final sourceNode = nodes.firstWhere(
          (n) => n.id == sourceNodeId,
          orElse: () => CustomBracketNode(id: '', nodeType: '', title: '', x: 0, y: 0),
        );
        if (sourceNode.id.isNotEmpty) {
          final sourceOutputPoint = _getOutputPoint(sourceNode, connectionIndex);
          final localPosition = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
          if (localPosition != null) {
            final globalPosition = localPosition.localToGlobal(sourceOutputPoint);
            connectedInputs.add(globalPosition.toString());
          }
        }
      } else {
        // Handle very old-style connections (backward compatibility)
        final sourceNode = nodes.firstWhere(
          (n) => n.id == outputId,
          orElse: () => CustomBracketNode(id: '', nodeType: '', title: '', x: 0, y: 0),
        );
        if (sourceNode.id.isNotEmpty) {
          final sourceOutputPoint = Offset(sourceNode.x + 60, sourceNode.y + 40); // Center of source node
          final localPosition = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
          if (localPosition != null) {
            final globalPosition = localPosition.localToGlobal(sourceOutputPoint);
            connectedInputs.add(globalPosition.toString());
          }
        }
      }
    }
    return connectedInputs;
  }

  Widget _buildConnectedInputItem(String globalPositionString) {
    final localPosition = _offsetFromString(globalPositionString);
    final node = nodes.firstWhere(
      (n) => n.outputConnections.any((id) => id == globalPositionString),
      orElse: () => CustomBracketNode(id: '', nodeType: '', title: '', x: 0, y: 0),
    );

    if (node.id.isNotEmpty) {
      final template = _getTemplateForNode(node);
      final width = template['width'] as double;
      final height = template['height'] as double;
      final color = template['color'] as Color;
      final icon = template['icon'] as IconData;

      return Positioned(
        left: localPosition.dx - width / 2,
        top: localPosition.dy - height / 2,
        child: Draggable<CustomBracketNode>(
          data: node,
          feedback: Material(
            color: Colors.transparent,
            child: _buildNodeWidget(node, _getTemplateForNode(node), isDragging: true),
          ),
          feedbackOffset: Offset.zero,
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: _buildNodeWidget(node, _getTemplateForNode(node)),
          ),
          child: _buildNodeWidget(node, _getTemplateForNode(node), isSelected: true, isConnectable: false),
          onDragEnd: (details) {
            final canvasRenderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
            if (canvasRenderBox != null) {
              final newLocalPosition = canvasRenderBox.globalToLocal(details.offset);
              final globalPosition = _getGlobalPosition(_canvasKey.currentContext!, newLocalPosition);

              setState(() {
                final index = nodes.indexWhere((n) => n.id == node.id);
                if (index != -1) {
                  nodes[index] = node.copyWith(
                    x: newLocalPosition.dx.clamp(0, canvasWidth - (template['width'] as double)),
                    y: newLocalPosition.dy.clamp(0, canvasHeight - (template['height'] as double)),
                  );
                }
              });
            }
          },
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildConnectionHandle(CustomBracketNode fromNode, CustomBracketNode toNode) {
    final template = _getTemplateForNode(fromNode);
    final width = template['width'] as double;
    final height = template['height'] as double;
    final color = template['color'] as Color;
    final icon = template['icon'] as IconData;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            fromNode.title,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _loadPresetTeamAssignments(Map<String, List<String>> presetPoolTeams) {
    // This method loads preset team assignments and treats them as placeholders
    // These placeholders will be replaced when real teams are dropped
    for (String poolId in presetPoolTeams.keys) {
      final teamIds = presetPoolTeams[poolId] ?? [];
      if (teamIds.isNotEmpty) {
        // Create a callback to notify parent about the preset team assignments
        if (widget.onPresetTeamsLoaded != null) {
          widget.onPresetTeamsLoaded!(poolId, teamIds);
        }
      }
    }
  }

  void _showMatchEditDialog(CustomBracketNode node) {
    final titleController = TextEditingController(text: node.title);
    final matchIdController = TextEditingController(text: node.matchId ?? '');
    String bestOf = node.properties['bestOf'] as String? ?? 'one';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Match bearbeiten'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: matchIdController,
                  decoration: const InputDecoration(
                    labelText: 'Match ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: bestOf,
                  decoration: const InputDecoration(
                    labelText: 'Best of',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'one',
                      child: const Text('Best of One'),
                    ),
                    DropdownMenuItem(
                      value: 'three',
                      child: const Text('Best of Three'),
                    ),
                    DropdownMenuItem(
                      value: 'five',
                      child: const Text('Best of Five'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      bestOf = value!;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Abbrechen'),
              ),
              TextButton(
                onPressed: () => _deleteNode(node),
                child: const Text('Löschen', style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                onPressed: () {
                  final index = nodes.indexWhere((n) => n.id == node.id);
                  if (index != -1) {
                    nodes[index] = node.copyWith(
                      title: titleController.text,
                      matchId: matchIdController.text.isEmpty ? null : matchIdController.text,
                      properties: {...node.properties, 'bestOf': bestOf},
                    );
                  }
                  Navigator.pop(context);
                },
                child: const Text('Speichern'),
              ),
            ],
          );
        },
      ),
    );
  }

  Offset _getOutputPoint(CustomBracketNode node, int outputIndex) {
    final template = _getTemplateForNode(node);
    final width = template['width'] as double;
    final height = template['height'] as double;
    
    // Calculate output point position based on node type and output index
    if (node.nodeType == 'match') {
      // Match output points on the right side
      return Offset(
        node.x + width + 8, // Right side of match + offset
        node.y + 25 + (outputIndex * 35.0), // Spaced vertically
      );
    } else if (node.nodeType == 'pool') {
      // Pool output points on the right side
      return Offset(
        node.x + width + 8, // Right side of pool + offset
        node.y + 32 + (outputIndex * 40.0), // Spaced vertically
      );
    } else {
      // Default center point
      return Offset(node.x + width / 2, node.y + height / 2);
    }
  }

  List<Widget> _buildMatchInputPoints(CustomBracketNode node, double width, double height) {
    final points = <Widget>[];
    final labels = ['Team 1', 'Team 2'];
    
    // Input connection points (left side) - 2 inputs for teams
    for (int i = 0; i < 2; i++) {
      final yPosition = 25.0 + (i * 35.0); // Evenly spaced vertically
      
      points.add(
        Positioned(
          left: -8, // Slightly outside the container on the left
          top: yPosition,
          child: GestureDetector(
            onTap: () {
              // Handle input connection
              if (connectingFromNode != null) {
                _connectToMatchInput(connectingFromNode!, node, i);
                setState(() => connectingFromNode = null);
              }
            },
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_forward,
                color: Colors.white,
                size: 8,
              ),
            ),
          ),
        ),
      );
      
      // Add label for the input
      points.add(
        Positioned(
          left: -45,
          top: yPosition + 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              labels[i],
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w500,
                color: Colors.blue.shade700,
              ),
            ),
          ),
        ),
      );
    }
    
    return points;
  }

  List<Widget> _buildMatchOutputPoints(CustomBracketNode node, double width, double height) {
    final points = <Widget>[];
    final labels = ['Winner', 'Loser'];
    final colors = [Colors.green, Colors.red];
    
    // Output connection points (right side) - winner and loser
    for (int i = 0; i < 2; i++) {
      final yPosition = 25.0 + (i * 35.0); // Evenly spaced vertically
      
      points.add(
        Positioned(
          right: -8, // Slightly outside the container on the right
          top: yPosition,
          child: GestureDetector(
            onTap: () {
              setState(() {
                connectingFromNode = node.copyWith(
                  matchId: 'output_$i', // Store which output point (0=winner, 1=loser)
                );
              });
            },
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: colors[i],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_forward,
                color: Colors.white,
                size: 8,
              ),
            ),
          ),
        ),
      );
      
      // Add label for the output
      points.add(
        Positioned(
          right: 18,
          top: yPosition + 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: colors[i].withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              labels[i],
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w500,
                color: colors[i].shade700,
              ),
            ),
          ),
        ),
      );
    }
    
    return points;
  }

  void _connectToMatchInput(CustomBracketNode fromNode, CustomBracketNode toNode, int inputIndex) {
    setState(() {
      final fromIndex = nodes.indexWhere((n) => n.id == fromNode.id);
      final toIndex = nodes.indexWhere((n) => n.id == toNode.id);
      
      if (fromIndex != -1 && toIndex != -1) {
        // Get the output index from the fromNode's stored matchId
        int outputIndex = 1; // Default
        if (fromNode.matchId != null && fromNode.matchId!.startsWith('output_')) {
          outputIndex = int.tryParse(fromNode.matchId!.split('_').last) ?? 1;
        }
        
        // Add connection with specific input/output information
        // Format: targetNodeId_input_inputIndex_source_sourceNodeId_output_outputIndex
        final connectionId = '${toNode.id}_input_${inputIndex}_source_${fromNode.id}_output_$outputIndex';
        
        nodes[fromIndex] = nodes[fromIndex].copyWith(
          outputConnections: [...nodes[fromIndex].outputConnections, connectionId],
        );
        
        nodes[toIndex] = nodes[toIndex].copyWith(
          inputConnections: [...nodes[toIndex].inputConnections, connectionId],
        );
      }
    });
  }

  Widget _buildPoolContent(CustomBracketNode node) {
    final poolId = '${widget.divisionName}_${node.title}';
    final assignedTeams = widget.poolTeams[poolId] ?? [];
    
    if (assignedTeams.isEmpty) {
      return Center(
        child: Text(
          'Drop teams here',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 10,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: assignedTeams.map((teamId) {
        final team = widget.allTeams.firstWhere(
          (t) => t.id == teamId,
          orElse: () => Team(
            id: '',
            name: 'TBD',
            city: '',
            bundesland: '',
            division: '',
            createdAt: DateTime.now(),
          ),
        );
        
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          child: team.id.isNotEmpty
              ? _buildMatchTeamItem(team)
              : _buildEmptyTeamSlot(),
        );
      }).toList(),
    );
  }

  List<Widget> _buildPoolOutputPoints(CustomBracketNode node, List<String> assignedTeams, double dynamicHeight, double width) {
    final points = <Widget>[];
    final teamCount = assignedTeams.length;
    
    if (teamCount == 0) return points; // No output points if no teams
    
    // Create output points for each ranking position
    for (int i = 0; i < teamCount; i++) {
      final position = i + 1; // 1st, 2nd, 3rd, etc.
      final yPosition = 32.0 + 8.0 + 16.0 + (i * 40.0); // Center of each team item
      
      points.add(
        Positioned(
          right: -8, // Slightly outside the container
          top: yPosition,
          child: GestureDetector(
            onTap: () {
              setState(() {
                connectingFromNode = node.copyWith(
                  matchId: 'output_$position', // Store which output point was selected
                );
              });
            },
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$position',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      
      // Add label for the position
      points.add(
        Positioned(
          right: -45,
          top: yPosition - 6, // Adjust to center with the circle
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _getPositionLabel(position),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.orange.shade700,
              ),
            ),
          ),
        ),
      );
    }
    
    return points;
  }

  Widget _buildMatchTeamItem(Team team) {
    return Container(
      height: 16,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Center(
        child: Text(
          team.name,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.black87,
            fontSize: 9,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  String _getPositionLabel(int position) {
    switch (position) {
      case 1: return '1st';
      case 2: return '2nd';
      case 3: return '3rd';
      default: return '${position}th';
    }
  }

  // Replace Offset.fromString with a custom string parsing
  Offset _offsetFromString(String str) {
    final parts = str.split(',');
    if (parts.length == 2) {
      final x = double.tryParse(parts[0]) ?? 0.0;
      final y = double.tryParse(parts[1]) ?? 0.0;
      return Offset(x, y);
    }
    return Offset.zero;
  }

  // Replace BuildContext.localToGlobal with RenderBox.localToGlobal
  Offset _getGlobalPosition(BuildContext context, Offset localPosition) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      return renderBox.localToGlobal(localPosition);
    }
    return localPosition;
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.1)
      ..strokeWidth = 1;

    const gridSpacing = 50.0;

    // Draw vertical lines
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ConnectionPainter extends CustomPainter {
  final List<CustomBracketNode> nodes;

  ConnectionPainter(this.nodes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final arrowPaint = Paint()
      ..color = Colors.blue.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    for (final node in nodes) {
      for (final outputId in node.outputConnections) {
        // Parse new connection format: targetNodeId_input_inputIndex_source_sourceNodeId_output_outputIndex
        final parts = outputId.split('_');
        if (parts.length >= 7 && parts[1] == 'input' && parts[3] == 'source' && parts[5] == 'output') {
              final targetNodeId = parts[0];
          final inputIndex = int.tryParse(parts[2]) ?? 0;
          final outputIndex = int.tryParse(parts[6]) ?? 1;
          
          final targetNode = nodes.firstWhere(
            (n) => n.id == targetNodeId,
            orElse: () => CustomBracketNode(id: '', nodeType: '', title: '', x: 0, y: 0),
          );
          
          if (targetNode.id.isNotEmpty) {
            // Calculate connection points based on node types and connection indices
            Offset startPoint = _getOutputPoint(node, outputIndex); 
            Offset endPoint = _getInputPoint(targetNode, inputIndex);
            
            // Draw connection line
            canvas.drawLine(startPoint, endPoint, paint);

            // Draw arrow at the end
            _drawArrow(canvas, endPoint, startPoint, arrowPaint);
          }
        } else if (parts.length >= 3) {
          // Handle old format for backward compatibility
          final targetNodeId = parts[0];
          final connectionType = parts[1]; // 'input' or 'output'
          final connectionIndex = int.tryParse(parts[2]) ?? 0;
          
          final targetNode = nodes.firstWhere(
            (n) => n.id == targetNodeId,
            orElse: () => CustomBracketNode(id: '', nodeType: '', title: '', x: 0, y: 0),
          );
          
          if (targetNode.id.isNotEmpty) {
            // Get the output index from the source node's stored matchId
            final sourceOutputIndex = int.tryParse(node.matchId?.split('_').last ?? '1') ?? 1;
            
            // Calculate connection points based on node types and connection indices
            Offset startPoint = _getOutputPoint(node, sourceOutputIndex); 
            Offset endPoint = _getInputPoint(targetNode, connectionIndex);
            
            // Draw connection line
            canvas.drawLine(startPoint, endPoint, paint);

            // Draw arrow at the end
            _drawArrow(canvas, endPoint, startPoint, arrowPaint);
          }
        } else {
          // Handle very old-style connections (backward compatibility)
          final targetNode = nodes.firstWhere(
            (n) => n.id == outputId,
            orElse: () => CustomBracketNode(id: '', nodeType: '', title: '', x: 0, y: 0),
          );
          
          if (targetNode.id.isNotEmpty) {
            final startX = node.x + 60; // Center of source node
            final startY = node.y + 40;
            final endX = targetNode.x + 60; // Center of target node
            final endY = targetNode.y + 40;

            // Draw connection line
            canvas.drawLine(
              Offset(startX, startY),
              Offset(endX, endY),
              paint,
            );

            // Draw arrow at the end
            _drawArrow(canvas, Offset(endX, endY), Offset(startX, startY), arrowPaint);
          }
        }
      }
    }
  }

  Offset _getOutputPoint(CustomBracketNode node, int outputIndex) {
    if (node.nodeType == 'pool') {
      // Pool output points on the right side, aligned with team positions
      final teamItemY = 32.0 + 8.0 + 16.0 + ((outputIndex - 1) * 40.0); // -1 because outputIndex is 1-based
      return Offset(
        node.x + 300 + 8, // Right side of pool + offset (new width)
        node.y + teamItemY, // Aligned with team center
      );
    } else if (node.nodeType == 'match') {
      // Match output points on the right side
      return Offset(
        node.x + 200 + 8, // Right side of match + offset (new width)
        node.y + 25 + (outputIndex * 35.0), // Spaced vertically
      );
    } else {
      // Default center point
      return Offset(node.x + 60, node.y + 40);
    }
  }

  Offset _getInputPoint(CustomBracketNode node, int inputIndex) {
    if (node.nodeType == 'match') {
      // Match input points on the left side
      return Offset(
        node.x - 8, // Left side of match + offset
        node.y + 25 + (inputIndex * 35.0), // Spaced vertically
      );
    } else {
      // Default center point
      return Offset(node.x + 60, node.y + 40);
    }
  }

  void _drawArrow(Canvas canvas, Offset tip, Offset tail, Paint paint) {
    const arrowLength = 10.0;
    const arrowAngle = 0.5;
    
    final direction = (tip - tail).direction;
    final leftDirection = direction + arrowAngle;
    final rightDirection = direction - arrowAngle;
    
    final leftPoint = Offset(
      tip.dx - arrowLength * cos(leftDirection),
      tip.dy - arrowLength * sin(leftDirection),
    );
    
    final rightPoint = Offset(
      tip.dx - arrowLength * cos(rightDirection),
      tip.dy - arrowLength * sin(rightDirection),
    );

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(leftPoint.dx, leftPoint.dy)
      ..lineTo(rightPoint.dx, rightPoint.dy)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 