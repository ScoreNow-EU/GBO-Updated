import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/tournament.dart';
import '../models/game.dart';
import '../services/game_service.dart';
import '../utils/app_colors.dart';

class GraphicsControlScreen extends StatefulWidget {
  final Tournament tournament;

  const GraphicsControlScreen({
    super.key,
    required this.tournament,
  });

  @override
  State<GraphicsControlScreen> createState() => _GraphicsControlScreenState();
}

class _GraphicsControlScreenState extends State<GraphicsControlScreen> {
  final GameService _gameService = GameService();
  
  List<Game> games = [];
  String? selectedGameId;
  String selectedOverlayType = 'main_game';
  bool isLoading = true;

  final List<OverlayType> overlayTypes = [
    OverlayType(
      id: 'main_game',
      name: 'Main Game Overlay',
      description: 'Full game display with scores, teams, and timer',
      icon: Icons.sports_volleyball,
    ),
    OverlayType(
      id: 'score',
      name: 'Score Corner',
      description: 'Compact score display for screen corner',
      icon: Icons.scoreboard,
    ),
    OverlayType(
      id: 'standings',
      name: 'Tournament Standings',
      description: 'Current tournament standings and rankings',
      icon: Icons.leaderboard,
    ),
    OverlayType(
      id: 'schedule',
      name: 'Game Schedule',
      description: 'Upcoming games schedule',
      icon: Icons.schedule,
    ),
    OverlayType(
      id: 'player_info',
      name: 'Player Spotlight',
      description: 'Featured player information',
      icon: Icons.person,
    ),
    OverlayType(
      id: 'tournament_banner',
      name: 'Tournament Banner',
      description: 'Tournament title and information banner',
      icon: Icons.emoji_events,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    setState(() => isLoading = true);
    
    try {
      final gamesList = await _gameService.getGamesForTournament(widget.tournament.id).first;
      setState(() {
        games = gamesList;
        // Auto-select current live game or next scheduled game
        selectedGameId = games.firstWhere(
          (g) => g.status == GameStatus.inProgress,
          orElse: () => games.firstWhere(
            (g) => g.status == GameStatus.scheduled && g.scheduledTime != null,
            orElse: () => games.isNotEmpty ? games.first : Game(
              id: '',
              tournamentId: widget.tournament.id,
              teamAName: 'Team A',
              teamBName: 'Team B',
              gameType: GameType.pool,
              status: GameStatus.scheduled,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ),
        ).id;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading games: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('OBS Graphics Control'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadGames,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Games',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left panel - Controls
                  Expanded(
                    flex: 1,
                    child: _buildControlPanel(),
                  ),
                  
                  const SizedBox(width: 24),
                  
                  // Right panel - Preview and URLs
                  Expanded(
                    flex: 2,
                    child: _buildPreviewPanel(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildControlPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          'Tournament Info',
          Icons.info,
          [
            _buildInfoRow('Tournament', widget.tournament.name),
            _buildInfoRow('Location', widget.tournament.location),
            _buildInfoRow('Dates', _formatDateRange()),
            _buildInfoRow('Total Games', games.length.toString()),
          ],
        ),
        
        const SizedBox(height: 24),
        
        _buildSectionCard(
          'Game Selection',
          Icons.sports_volleyball,
          [
            const Text(
              'Select Game for Graphics:',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedGameId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              hint: const Text('Select Game'),
              items: games.map((game) {
                return DropdownMenuItem(
                  value: game.id,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${game.teamAName} vs ${game.teamBName}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${_getStatusText(game.status)} • ${game.scheduledTime != null ? _formatTime(game.scheduledTime!) : 'No time set'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedGameId = value;
                });
              },
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        _buildSectionCard(
          'Overlay Type',
          Icons.layers,
          [
            const Text(
              'Select Overlay Style:',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ...overlayTypes.map((overlay) => _buildOverlayOption(overlay)),
          ],
        ),
      ],
    );
  }

  Widget _buildPreviewPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          'OBS Browser Source URLs',
          Icons.link,
          [
            const Text(
              'Copy these URLs to your OBS Browser Sources:',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
            ),
            const SizedBox(height: 16),
            _buildUrlBox(
              'Primary Overlay URL',
              _generateOverlayUrl(),
              'Add this as Browser Source in OBS (1920x1080)',
            ),
            const SizedBox(height: 16),
            _buildUrlBox(
              'Mobile Preview URL',
              _generateMobileUrl(),
              'Preview on mobile device or smaller screen',
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        _buildSectionCard(
          'Quick Actions',
          Icons.flash_on,
          [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openPreview,
                    icon: const Icon(Icons.preview),
                    label: const Text('Preview'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _copyToClipboard,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy URL'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openInNewTab,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open in New Tab'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        _buildSectionCard(
          'OBS Setup Instructions',
          Icons.help,
          [
            _buildInstructionStep(
              '1',
              'Copy the overlay URL above',
            ),
            _buildInstructionStep(
              '2',
              'In OBS, add a new Browser Source',
            ),
            _buildInstructionStep(
              '3',
              'Paste the URL and set dimensions to 1920x1080',
            ),
            _buildInstructionStep(
              '4',
              'Position and resize the overlay as needed',
            ),
            _buildInstructionStep(
              '5',
              'The graphics will update automatically with live data',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primaryColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayOption(OverlayType overlay) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RadioListTile<String>(
        title: Row(
          children: [
            Icon(overlay.icon, size: 20, color: AppColors.primaryColor),
            const SizedBox(width: 8),
            Text(overlay.name),
          ],
        ),
        subtitle: Text(overlay.description),
        value: overlay.id,
        groupValue: selectedOverlayType,
        onChanged: (value) {
          setState(() {
            selectedOverlayType = value!;
          });
        },
      ),
    );
  }

  Widget _buildUrlBox(String title, String url, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(4),
            ),
            child: SelectableText(
              url,
              style: const TextStyle(
                color: Colors.green,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String number, String instruction) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.primaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              instruction,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  String _generateOverlayUrl() {
    final baseUrl = 'http://localhost:8080/#/obs-graphics';
    final params = <String, String>{
      'tournamentId': widget.tournament.id,
      'overlayType': selectedOverlayType,
    };
    
    if (selectedGameId != null && selectedGameId!.isNotEmpty) {
      params['gameId'] = selectedGameId!;
    }
    
    final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return '$baseUrl?$query';
  }

  String _generateMobileUrl() {
    return _generateOverlayUrl().replaceFirst('localhost:8080', 'your-domain.com');
  }

  String _formatDateRange() {
    final start = widget.tournament.startDate;
    final end = widget.tournament.endDate;
    
    if (start == null) return 'No dates set';
    if (end == null) return _formatDate(start);
    
    if (start.day == end.day && start.month == end.month && start.year == end.year) {
      return _formatDate(start);
    }
    return '${_formatDate(start)} - ${_formatDate(end)}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _getStatusText(GameStatus status) {
    switch (status) {
      case GameStatus.scheduled:
        return 'Scheduled';
      case GameStatus.inProgress:
        return 'LIVE';
      case GameStatus.completed:
        return 'Completed';
      case GameStatus.cancelled:
        return 'Cancelled';
    }
  }

  // Action methods
  void _openPreview() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _PreviewScreen(url: _generateOverlayUrl()),
      ),
    );
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _generateOverlayUrl()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('URL copied to clipboard!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _openInNewTab() {
    // This would open in a new tab on web
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('URL would open in new tab (web only)'),
      ),
    );
  }
}

class OverlayType {
  final String id;
  final String name;
  final String description;
  final IconData icon;

  OverlayType({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });
}

class _PreviewScreen extends StatelessWidget {
  final String url;

  const _PreviewScreen({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Overlay Preview'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.preview,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Preview Mode',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This would show the overlay preview',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'URL: $url',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
