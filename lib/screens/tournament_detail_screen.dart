import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tournament.dart';
import '../models/game.dart';
import '../models/game_event.dart';
import '../services/game_service.dart';
import '../services/live_scoring_service.dart';
import '../widgets/responsive_layout.dart';
import '../utils/responsive_helper.dart';
import '../widgets/gbo_loader.dart';
import '../utils/app_colors.dart';
import 'package:timeline_tile/timeline_tile.dart';

class TournamentDetailScreen extends StatefulWidget {
  final Tournament tournament;

  const TournamentDetailScreen({
    super.key,
    required this.tournament,
  });

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  final GameService _gameService = GameService();
  final LiveScoringService _liveScoringService = LiveScoringService();
  String selectedCategory = 'Alle';
  String selectedRound = 'Alle';
  String selectedTeams = 'Alle';
  String selectedResultTab = 'U16-Weiblich';
  String selectedSection = 'turniere'; // Current section

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      selectedSection: selectedSection,
      onSectionChanged: (section) {
        if (section != 'turniere') {
          // Navigate back to home with selected section
          Navigator.of(context).pop();
          // You could add additional navigation logic here if needed
        }
      },
      title: widget.tournament.name,
      showBackButton: true,
      onBackPressed: () => Navigator.of(context).pop(),
      body: _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveHelper.isMobile(screenWidth);
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTournamentHeader(),
          SizedBox(height: isMobile ? 24 : 32),
          _buildMatchesSection(),
          SizedBox(height: isMobile ? 24 : 32),
          _buildResultsSection(),
          SizedBox(height: isMobile ? 24 : 32),
          _buildCriteriaSection(),
          SizedBox(height: isMobile ? 24 : 32),
          _buildOrganizationSection(),
        ],
      ),
    );
  }

  Widget _buildTournamentHeader() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveHelper.isMobile(screenWidth);
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isMobile ? _buildMobileHeader() : _buildDesktopHeader(),
    );
  }

  Widget _buildMobileHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tournament Logo
        Center(
          child: Container(
            width: double.infinity,
            height: 200,
            constraints: const BoxConstraints(maxWidth: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200, width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: widget.tournament.imageUrl != null && widget.tournament.imageUrl!.isNotEmpty
                  ? Image.network(
                      widget.tournament.imageUrl!,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: double.infinity,
                          height: 200,
                          color: Colors.grey.shade100,
                          child: Center(
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / 
                                      loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: double.infinity,
                          height: 200,
                          color: Colors.grey.shade200,
                          child: Icon(
                            Icons.sports_volleyball,
                            color: Colors.grey.shade400,
                            size: 60,
                          ),
                        );
                      },
                    )
                  : Container(
                      width: double.infinity,
                      height: 200,
                      color: Colors.grey.shade200,
                      child: Icon(
                        Icons.sports_volleyball,
                        color: Colors.grey.shade400,
                        size: 60,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        
        // Tournament Details
        Text(
          widget.tournament.dateString,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        
        // Location
        Row(
          children: [
            const Icon(Icons.location_on, size: 18, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.tournament.location,
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Points
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${widget.tournament.points} Punkte',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Download AGB
        GestureDetector(
          onTap: _downloadAGBs,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
                                              color: AppColors.primaryColorLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryColor),
            ),
            child: Row(
              children: [
                const Icon(Icons.download, size: 18, color: Colors.black87),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ausschreibung/AGBs herunterladen',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Social Media
        const Text(
          'Social Media',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildSocialButton('Facebook', Colors.blue[600]!, Icons.facebook),
            _buildSocialButton('Instagram', Colors.purple[400]!, Icons.camera_alt),
            _buildSocialButton('Homepage', Colors.blue[400]!, Icons.language),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tournament Logo
        Container(
          width: 180,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: widget.tournament.imageUrl != null && widget.tournament.imageUrl!.isNotEmpty
                ? Image.network(
                    widget.tournament.imageUrl!,
                    width: 180,
                    height: 120,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 180,
                        height: 120,
                        color: Colors.grey.shade100,
                        child: Center(
                          child: SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / 
                                    loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 180,
                        height: 120,
                        color: Colors.grey.shade200,
                        child: Icon(
                          Icons.sports_volleyball,
                          color: Colors.grey.shade400,
                          size: 40,
                        ),
                      );
                    },
                  )
                : Container(
                    width: 180,
                    height: 120,
                    color: Colors.grey.shade200,
                    child: Icon(
                      Icons.sports_volleyball,
                      color: Colors.grey.shade400,
                      size: 40,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 24),
        
        // Tournament Details (middle section)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.tournament.dateString,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _downloadAGBs,
                child: Row(
                  children: [
                    const Icon(Icons.download, size: 16, color: Colors.black87),
                    const SizedBox(width: 8),
                    Text(
                      'Ausschreibung/AGBs',
                      style: const TextStyle(
                        color: Colors.black87,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.tournament.location,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${widget.tournament.points}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Punkte',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Social Media (right side, stacked vertically)
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'Social Media',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildSocialButton('Facebook', Colors.blue[600]!, Icons.facebook),
            const SizedBox(height: 8),
            _buildSocialButton('Instagram', Colors.purple[400]!, Icons.camera_alt),
            const SizedBox(height: 8),
            _buildSocialButton('Homepage', Colors.blue[400]!, Icons.language),
          ],
        ),
      ],
    );
  }

  String? _getTournamentImage(String tournamentName) {
    // Return null to use placeholder/icon instead of hardcoded images
    return null;
  }

  Widget _buildSocialButton(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _downloadAGBs() {
    // Show download dialog or trigger download
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Download Ausschreibung/AGBs'),
          content: Text('Download für ${widget.tournament.name} wird gestartet...'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Schließen'),
            ),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement actual download functionality
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Download gestartet...'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Download'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMatchesSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveHelper.isMobile(screenWidth);
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          const Text(
            'Matches',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 20),
          
          // Games Display
          StreamBuilder<List<Game>>(
            stream: _gameService.getGamesForTournament(widget.tournament.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Container(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Fehler beim Laden der Spiele: ${snapshot.error}',
                          style: TextStyle(fontSize: isMobile ? 13 : 14),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final allGames = snapshot.data ?? [];
              
              if (allGames.isEmpty) {
                return Container(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Noch keine Spiele für dieses Turnier erstellt.',
                          style: TextStyle(fontSize: isMobile ? 13 : 14),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Categorize games
              final now = DateTime.now();
              
              // Current games: live games or games within 2 hours of start
              final currentGames = allGames.where((game) {
                if (game.status == GameStatus.inProgress) return true;
                if (game.scheduledTime == null) return false;
                
                final timeDiff = game.scheduledTime!.difference(now).inMinutes;
                return timeDiff >= -30 && timeDiff <= 120; // Started up to 30min ago or starting within 2 hours
              }).toList();

              // Upcoming games: future games not in current list
              final upcomingGames = allGames.where((game) {
                if (currentGames.contains(game)) return false;
                if (game.status == GameStatus.completed) return false;
                if (game.scheduledTime == null) return true; // Unscheduled games
                
                return game.scheduledTime!.isAfter(now);
              }).toList();

              // Sort games
              currentGames.sort((a, b) {
                if (a.status == GameStatus.inProgress && b.status != GameStatus.inProgress) return -1;
                if (b.status == GameStatus.inProgress && a.status != GameStatus.inProgress) return 1;
                return (a.scheduledTime ?? DateTime(2100)).compareTo(b.scheduledTime ?? DateTime(2100));
              });
              
              upcomingGames.sort((a, b) => (a.scheduledTime ?? DateTime(2100)).compareTo(b.scheduledTime ?? DateTime(2100)));

              return FutureBuilder<List<Game>>(
                future: _getGamesWithActiveScoringTablets(allGames),
                builder: (context, activeScoringGamesSnapshot) {
                  final gamesWithActiveScoring = activeScoringGamesSnapshot.data ?? [];
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Live Scoring Games (Top Priority)
                      if (gamesWithActiveScoring.isNotEmpty) ...[
                        _buildLiveScoringSection(
                          games: gamesWithActiveScoring,
                          isMobile: isMobile,
                        ),
                        SizedBox(height: isMobile ? 16 : 20),
                      ],
                      
                      // Current/Live Games
                      if (currentGames.isNotEmpty) ...[
                        _buildGamesSubsection(
                          title: 'Aktuelle Spiele',
                          icon: Icons.play_circle_filled,
                          iconColor: Colors.green,
                          games: currentGames.where((game) => !gamesWithActiveScoring.contains(game)).toList(),
                          isMobile: isMobile,
                        ),
                        SizedBox(height: isMobile ? 16 : 20),
                      ],
                      
                      // Upcoming Games
                      if (upcomingGames.isNotEmpty) ...[
                        _buildGamesSubsection(
                          title: 'Kommende Spiele',
                          icon: Icons.schedule,
                          iconColor: Colors.blue,
                          games: upcomingGames.take(6).toList(), // Limit to first 6
                          isMobile: isMobile,
                        ),
                      ],
                      
                      // Show "View All Games" button if there are more games
                      if (allGames.length > (currentGames.length + 6)) ...[
                        const SizedBox(height: 16),
                        Center(
                          child: TextButton.icon(
                            onPressed: () {
                              // TODO: Navigate to detailed games view
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Detaillierte Spieleansicht wird implementiert')),
                              );
                            },
                            icon: const Icon(Icons.list),
                            label: Text('Alle ${allGames.length} Spiele anzeigen'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGamesSubsection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Game> games,
    required bool isMobile,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${games.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: isMobile ? 12 : 16),
        
        // Games List
        ...games.map((game) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildGameCard(game, isMobile),
        )).toList(),
      ],
    );
  }

  Widget _buildGameCard(Game game, bool isMobile) {
    final isLive = game.status == GameStatus.inProgress;
    final now = DateTime.now();
    String timeDisplay = 'TBD';
    String dateDisplay = '';
    
    if (game.scheduledTime != null) {
      final gameTime = game.scheduledTime!;
      timeDisplay = '${gameTime.hour.toString().padLeft(2, '0')}:${gameTime.minute.toString().padLeft(2, '0')}';
      
      if (gameTime.day == now.day && gameTime.month == now.month && gameTime.year == now.year) {
        dateDisplay = 'Heute';
      } else if (gameTime.day == now.day + 1 && gameTime.month == now.month && gameTime.year == now.year) {
        dateDisplay = 'Morgen';
      } else {
        dateDisplay = '${gameTime.day.toString().padLeft(2, '0')}.${gameTime.month.toString().padLeft(2, '0')}.${gameTime.year}';
      }
    }

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: isLive ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLive ? Colors.green.shade300 : Colors.grey.shade200,
          width: isLive ? 2 : 1,
        ),
      ),
      child: isMobile ? _buildMobileGameCard(game, isLive, timeDisplay, dateDisplay) : _buildDesktopGameCard(game, isLive, timeDisplay, dateDisplay),
    );
  }

  Widget _buildMobileGameCard(Game game, bool isLive, String timeDisplay, String dateDisplay) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time and Status
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isLive ? Colors.green : Colors.blue,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                timeDisplay,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (dateDisplay.isNotEmpty)
              Text(
                dateDisplay,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            const Spacer(),
            if (isLive) ...[
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        
        // Teams
        Text(
          '${game.teamAName} vs ${game.teamBName}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        
        // Game Type and Court Info
        const SizedBox(height: 8),
        Row(
          children: [
            if (game.courtId != null) ...[
              Icon(Icons.sports_tennis, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                'Court ${game.courtId}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(width: 12),
            ],
            Icon(Icons.category, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              _getGameTypeDisplay(game),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopGameCard(Game game, bool isLive, String timeDisplay, String dateDisplay) {
    return Row(
      children: [
        // Time
        Container(
          width: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isLive ? Colors.green : Colors.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  timeDisplay,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (dateDisplay.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  dateDisplay,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Teams
        Expanded(
          child: Text(
            '${game.teamAName} vs ${game.teamBName}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        
        // Court Info
        if (game.courtId != null) ...[
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sports_tennis, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Court ${game.courtId}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
        
        // Game Type
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Text(
            _getGameTypeDisplay(game),
            style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.w500),
          ),
        ),
        
        // Live indicator
        if (isLive) ...[
          const SizedBox(width: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _getGameTypeDisplay(Game game) {
    if (game.gameType == GameType.pool) {
      return game.poolId != null ? 'Pool ${game.poolId}' : 'Poolspiel';
    } else if (game.gameType == GameType.elimination && game.bracketRound != null) {
      switch (game.bracketRound!) {
        case 1:
          return 'Achtelfinale';
        case 2:
          return 'Viertelfinale';
        case 3:
          return 'Halbfinale';
        case 4:
          return 'Finale';
        case 5:
          return 'Spiel um Platz 3';
        default:
          return 'K.O.-Runde ${game.bracketRound}';
      }
    } else if (game.gameType == GameType.elimination) {
      return 'K.O.-Spiel';
    }
    
    return 'Spiel';
  }

  Future<List<Game>> _getGamesWithActiveScoringTablets(List<Game> allGames) async {
    List<Game> gamesWithActiveScoring = [];
    
    print('🎯 Checking ${allGames.length} games for active scoring tablets...');
    
    for (final game in allGames) {
      try {
        // First priority: Games that are currently in progress
        if (game.status == GameStatus.inProgress) {
          print('✅ Game ${game.id.substring(game.id.length - 8)} is in progress - adding to live scoring');
          gamesWithActiveScoring.add(game);
          continue;
        }
        
        // Second priority: Check if there's recent GameState activity (within last 10 minutes)
        final gameStateDoc = await FirebaseFirestore.instance
            .collection('gameStates')
            .doc(game.id)
            .get();
        
        if (gameStateDoc.exists) {
          print('📋 Found gameState for ${game.id.substring(game.id.length - 8)}');
          final data = gameStateDoc.data()!;
          
          // Check if the game has any scoring activity indicators
          bool hasActivity = false;
          String activityReason = '';
          
          // Check 1: Has lastUpdated timestamp within 10 minutes
          final lastUpdated = data['lastUpdated'] != null 
              ? (data['lastUpdated'] as Timestamp).toDate()
              : null;
          
          if (lastUpdated != null) {
            final now = DateTime.now();
            final timeDiff = now.difference(lastUpdated).inMinutes;
            print('⏰ Game ${game.id.substring(game.id.length - 8)} last updated ${timeDiff} minutes ago');
            
            if (timeDiff <= 10) {
              hasActivity = true;
              activityReason = 'recent update';
            }
          }
          
          // Check 2: Game timer is running
          if (!hasActivity && data['isRunning'] == true) {
            hasActivity = true;
            activityReason = 'timer running';
          }
          
          // Check 3: Has any game time (indicates scoring tablet has been used)
          if (!hasActivity && ((data['minutes'] != null && data['minutes'] > 0) || (data['seconds'] != null && data['seconds'] > 0))) {
            hasActivity = true;
            activityReason = 'has game time';
          }
          
          // Check 4: Check for recent game events
          if (!hasActivity) {
            try {
              final eventsSnapshot = await FirebaseFirestore.instance
                  .collection('gameEvents')
                  .where('gameId', isEqualTo: game.id)
                  .get();
              
              if (eventsSnapshot.docs.isNotEmpty) {
                hasActivity = true;
                activityReason = 'has game events';
                print('📝 Game ${game.id.substring(game.id.length - 8)} has ${eventsSnapshot.docs.length} events');
              }
            } catch (e) {
              print('❌ Error checking events for ${game.id.substring(game.id.length - 8)}: $e');
            }
          }
          
          if (hasActivity) {
            print('✅ Game ${game.id.substring(game.id.length - 8)} has activity ($activityReason) - adding to live scoring');
            gamesWithActiveScoring.add(game);
          } else {
            print('⚠️ Game ${game.id.substring(game.id.length - 8)} has gameState but no detectable activity');
          }
        } else {
          print('❌ No gameState found for ${game.id.substring(game.id.length - 8)}');
        }
      } catch (e) {
        // Skip games with errors
        print('❌ Error checking game state for ${game.id.substring(game.id.length - 8)}: $e');
      }
    }
    
    print('🎯 Found ${gamesWithActiveScoring.length} games with active scoring tablets');
    return gamesWithActiveScoring;
  }

  Widget _buildLiveScoringSection({
    required List<Game> games,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade50, Colors.orange.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tablet, color: Colors.red, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Live Scoring - Aktive Tablets',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${games.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 12 : 16),
          
          // Live Scoring Games
          ...games.map((game) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildLiveScoringGameCard(game, isMobile),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildLiveScoringGameCard(Game game, bool isMobile) {
    return StreamBuilder<GameState>(
      stream: _liveScoringService.streamGameState(game.id),
      builder: (context, snapshot) {
        final gameState = snapshot.data;
        
        return InkWell(
          onTap: () => _showLiveScoringDetails(game, gameState),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade300, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isMobile 
                ? _buildMobileLiveScoringCard(game, gameState)
                : _buildDesktopLiveScoringCard(game, gameState),
          ),
        );
      },
    );
  }

  Widget _buildMobileLiveScoringCard(Game game, GameState? gameState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with live indicator
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'LIVE SCORING',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const Spacer(),
            if (gameState?.gameTime != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  gameState!.gameTime.displayTime,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Teams and Score
        Row(
          children: [
            Expanded(
              child: Text(
                game.teamAName,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
                         if (gameState != null && game.teamAId != null && game.teamBId != null) ...[
               Text(
                 '${gameState.getCurrentSetScore(game.teamAId!)}',
                 style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
               ),
               const Text(' - ', style: TextStyle(fontSize: 16)),
               Text(
                 '${gameState.getCurrentSetScore(game.teamBId!)}',
                 style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
               ),
            ] else ...[
              const Text('0 - 0', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                game.teamBName,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        
        // Set wins
        if (gameState != null) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Sätze: ${gameState.teamASetWins} - ${gameState.teamBSetWins}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDesktopLiveScoringCard(Game game, GameState? gameState) {
    return Row(
      children: [
        // Live indicator
        Column(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'LIVE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        
        const SizedBox(width: 16),
        
        // Game time
        Container(
          width: 60,
          child: gameState?.gameTime != null
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    gameState!.gameTime.displayTime,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : const Text('--:--', style: TextStyle(fontSize: 12)),
        ),
        
        const SizedBox(width: 16),
        
        // Team A
        Expanded(
          flex: 2,
          child: Text(
            game.teamAName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        
        // Score
                 Container(
           width: 80,
           child: gameState != null && game.teamAId != null && game.teamBId != null
               ? Text(
                   '${gameState.getCurrentSetScore(game.teamAId!)} - ${gameState.getCurrentSetScore(game.teamBId!)}',
                   style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                   textAlign: TextAlign.center,
                 )
               : const Text('0 - 0', 
                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                   textAlign: TextAlign.center,
                 ),
         ),
        
        // Team B
        Expanded(
          flex: 2,
          child: Text(
            game.teamBName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Set wins
        Container(
          width: 60,
          child: gameState != null
              ? Text(
                  '${gameState.teamASetWins}-${gameState.teamBSetWins}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                )
              : const Text('0-0', 
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
        ),
      ],
    );
  }

  void _showLiveScoringDetails(Game game, GameState? gameState) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LiveScoringDetailsScreen(
          game: game,
          liveScoringService: _liveScoringService,
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label*',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    if (label == 'Kategorie') selectedCategory = newValue;
                    if (label == 'Spielrunde') selectedRound = newValue;
                    if (label == 'Teams') selectedTeams = newValue;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveHelper.isMobile(screenWidth);
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          const Text(
            'Ergebnisse',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 20),
          
          // Tabs - Mobile: Use scrollable row, Desktop: Normal row
          if (isMobile)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildResultTab('U16-Weiblich', true),
                  const SizedBox(width: 12),
                  _buildResultTab('U16-Männlich', false),
                  const SizedBox(width: 12),
                  _buildResultTab('U18-Weiblich', false),
                  const SizedBox(width: 12),
                  _buildResultTab('U18-Männlich', false),
                ],
              ),
            )
          else
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _buildResultTab('U16-Weiblich', true),
                _buildResultTab('U16-Männlich', false),
                _buildResultTab('U18-Weiblich', false),
                _buildResultTab('U18-Männlich', false),
              ],
            ),
          
          SizedBox(height: isMobile ? 16 : 20),
          
          // Expandable sections
          _buildExpandableSection('Teams / Ranking', Icons.keyboard_arrow_down),
          SizedBox(height: isMobile ? 6 : 8),
          _buildExpandableSection('Gruppenphase', Icons.keyboard_arrow_down),
          SizedBox(height: isMobile ? 6 : 8),
          _buildExpandableSection('Final & Platzierungsrunde', Icons.keyboard_arrow_down),
          SizedBox(height: isMobile ? 6 : 8),
          _buildExpandableSection('Spielerstatistiken', Icons.keyboard_arrow_down),
        ],
      ),
    );
  }

  Widget _buildResultTab(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue[600] : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isSelected ? Colors.blue[600]! : Colors.grey[300]!,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildExpandableSection(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          Icon(icon, color: Colors.grey[600], size: 20),
        ],
      ),
    );
  }

  Widget _buildCriteriaSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveHelper.isMobile(screenWidth);
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          const Text(
            'Kriterien allgemein',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 20),
          _buildExpandableSection('Kriterien allgemein', Icons.keyboard_arrow_down),
          SizedBox(height: isMobile ? 6 : 8),
          _buildExpandableSection('Kriterium Referee', Icons.keyboard_arrow_down),
          SizedBox(height: isMobile ? 6 : 8),
          _buildExpandableSection('Kriterium Delegate', Icons.keyboard_arrow_down),
          SizedBox(height: isMobile ? 6 : 8),
          _buildExpandableSection('Kriterium Scouter', Icons.keyboard_arrow_down),
        ],
      ),
    );
  }

  Widget _buildOrganizationSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveHelper.isMobile(screenWidth);
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
                width: isMobile ? 36 : 40,
                height: isMobile ? 36 : 40,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(isMobile ? 18 : 20),
                ),
                child: Center(
                  child: Text(
                    '01',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 14 : 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Team. Orga.',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 20),
          Row(
            children: [
              Icon(Icons.emoji_events, size: isMobile ? 18 : 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Turnierorganisator GBO',
                  style: TextStyle(fontSize: isMobile ? 13 : 14),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 10 : 12),
          Row(
            children: [
              Icon(Icons.email, size: isMobile ? 18 : 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'beachcup-herrenhausen@online.de',
                  style: TextStyle(fontSize: isMobile ? 13 : 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LiveScoringDetailsScreen extends StatefulWidget {
  final Game game;
  final LiveScoringService liveScoringService;

  const LiveScoringDetailsScreen({
    super.key,
    required this.game,
    required this.liveScoringService,
  });

  @override
  State<LiveScoringDetailsScreen> createState() => _LiveScoringDetailsScreenState();
}

class _LiveScoringDetailsScreenState extends State<LiveScoringDetailsScreen>
    with TickerProviderStateMixin {
  Timer? _refreshTimer;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  GameState? _currentGameState;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController.forward();
    
    // Start 1-second refresh timer
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // This will trigger a rebuild and refresh the StreamBuilder
        });
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    
    return Theme(
      data: Theme.of(context).copyWith(
        appBarTheme: AppBarTheme(
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1A1A2E),
                const Color(0xFF16213E),
                const Color(0xFF0F3460),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildCustomAppBar(isMobile),
                Expanded(
                  child: StreamBuilder<GameState>(
                    stream: widget.liveScoringService.streamGameState(widget.game.id),
                    builder: (context, snapshot) {
                      final gameState = snapshot.data;
                      _currentGameState = gameState;
                      
                      if (snapshot.connectionState == ConnectionState.waiting && gameState == null) {
                        return _buildLoadingView(isMobile);
                      }
                      
                      if (snapshot.hasError) {
                        return _buildErrorView(snapshot.error.toString(), isMobile);
                      }
                      
                      return AnimatedBuilder(
                        animation: _slideController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, 50 * (1 - _slideController.value)),
                            child: Opacity(
                              opacity: _slideController.value,
                              child: SingleChildScrollView(
                                padding: EdgeInsets.all(isMobile ? 16 : 24),
                                child: gameState == null
                                    ? _buildNoDataView(isMobile)
                                    : _buildGameStateContent(gameState, isMobile),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar(bool isMobile) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.shade600,
            Colors.red.shade700,
            Colors.red.shade800,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
          // Enhanced Logo
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'GBO',
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Live Scoring',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.game.teamAName} vs ${widget.game.teamBName}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.2 + 0.1 * _pulseController.value),
                      Colors.white.withOpacity(0.1 + 0.1 * _pulseController.value),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.5),
                            blurRadius: 4 + 2 * _pulseController.value,
                            spreadRadius: 1 + _pulseController.value,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: const Center(
        child: GBOLoader(size: 80, showBackground: false),
      ),
    );
  }

  Widget _buildErrorView(String error, bool isMobile) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.red.shade900.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade700, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Fehler beim Laden der Live-Daten',
              style: TextStyle(
                fontSize: 18,
                color: Colors.red.shade300,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataView(bool isMobile) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.grey.shade800.withOpacity(0.3),
              Colors.grey.shade900.withOpacity(0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_empty, size: 64, color: Colors.white.withOpacity(0.6)),
            const SizedBox(height: 20),
            Text(
              'Warte auf Live-Daten...',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Spiel: ${widget.game.teamAName} vs ${widget.game.teamBName}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameStateContent(GameState gameState, bool isMobile) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Game Time and Status
          _buildTimeSection(gameState, isMobile),
          const SizedBox(height: 20),
          
          // Current Score
          _buildCurrentScoreSection(gameState, isMobile),
          const SizedBox(height: 20),
          
          // Set History
          if (gameState.setScores.isNotEmpty) ...[
            _buildSetHistorySection(gameState, isMobile),
            const SizedBox(height: 20),
          ],
          
          // Recent Events
          _buildRecentEventsSection(gameState, isMobile),
        ],
      ),
    );
  }

  Widget _buildTimeSection(GameState gameState, bool isMobile) {
    // Determine the current set/period display
    String periodText;
    if (gameState.gameTime.isFullTime && gameState.teamASetWins == gameState.teamBSetWins) {
      periodText = 'Shootout';
    } else {
      periodText = 'Satz ${gameState.currentSet}';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade800.withOpacity(0.3),
            Colors.grey.shade900.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Top row: Home team - Time with status - Guest team
          Row(
            children: [
              // Home team (left)
              Expanded(
                child: Text(
                  widget.game.teamAName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.left,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              // Center: Time with status indicator
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      gameState.gameTime.displayTime,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: gameState.isRunning ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (gameState.isRunning ? Colors.green : Colors.red).withOpacity(0.6),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Guest team (right)
              Expanded(
                child: Text(
                  widget.game.teamBName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Bottom: Period/Set indicator
          Text(
            periodText,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.7),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentScoreSection(GameState gameState, bool isMobile) {
    if (widget.game.teamAId == null || widget.game.teamBId == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.grey.shade700.withOpacity(0.3),
              Colors.grey.shade900.withOpacity(0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Text(
          'Team-IDs nicht verfügbar für Anzeigetafel',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 16,
          ),
        ),
      );
    }

    final teamAScore = gameState.getCurrentSetScore(widget.game.teamAId!);
    final teamBScore = gameState.getCurrentSetScore(widget.game.teamBId!);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade600.withOpacity(0.2),
            Colors.blue.shade800.withOpacity(0.1),
            Colors.purple.shade800.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade400.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 25,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Text(
              'Aktueller Satz ${gameState.currentSet}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Text(
                        widget.game.teamAName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                      ),
                      child: Center(
                        child: Text(
                          '$teamAScore',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Text(
                        widget.game.teamBName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                      ),
                      child: Center(
                        child: Text(
                          '$teamBScore',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Text(
              'Sätze: ${gameState.teamASetWins} - ${gameState.teamBSetWins}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.9),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetHistorySection(GameState gameState, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.shade600.withOpacity(0.2),
            Colors.purple.shade800.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.shade400.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 0,
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
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade400, Colors.purple.shade600],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.history, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Satz-Historie',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...gameState.setScores.map((setScore) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple.shade300, Colors.purple.shade500],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${setScore.setNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Satz ${setScore.setNumber}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${setScore.teamAScore} - ${setScore.teamBScore}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (setScore.isCompleted) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade400, Colors.green.shade600],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 14),
                  ),
                ],
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildRecentEventsSection(GameState gameState, bool isMobile) {
    final recentEvents = gameState.events.reversed.take(10).toList();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.shade600.withOpacity(0.2),
            Colors.orange.shade800.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade400.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 0,
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
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade400, Colors.orange.shade600],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.event_note, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Letzte Ereignisse',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${recentEvents.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentEvents.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.white.withOpacity(0.6),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Noch keine Ereignisse',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            ...recentEvents.map((event) => TimelineTile(
              alignment: TimelineAlign.center,
              isFirst: recentEvents.indexOf(event) == 0,
              isLast: recentEvents.indexOf(event) == recentEvents.length - 1,
              lineXY: 0.2, // Reduces the vertical gap between timeline dots
              indicatorStyle: IndicatorStyle(
                width: 45,
                height: 20,
                padding: const EdgeInsets.symmetric(vertical: 2), // Reduces padding around the indicator
                indicator: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    ),
                  child: Center(
                    child: Text(
                      '${event.gameMinute}:00',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              beforeLineStyle: LineStyle(
                color: Colors.white.withOpacity(0.3),
                thickness: 1,
              ),
              afterLineStyle: LineStyle(
                color: Colors.white.withOpacity(0.3),
                thickness: 1,
                          ),
              startChild: event.teamId == widget.game.teamAId ? _buildEventTile(event, true) : null,
              endChild: event.teamId == widget.game.teamBId ? _buildEventTile(event, false) : null,
            )).toList(),
                      ],
                    ),
    );
  }

  Widget _buildEventTile(GameEvent event, bool isHomeTeam) {
    return Container(
      margin: EdgeInsets.only(
        left: isHomeTeam ? 0 : 16,
        right: isHomeTeam ? 16 : 0,
        bottom: 2,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
            _getEventColor(event.eventType).withOpacity(0.3),
            _getEventColor(event.eventType).withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getEventIconColor(event.eventType).withOpacity(0.4),
          width: 1,
        ),
                    ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: isHomeTeam ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isHomeTeam) ...[
                Icon(
                  _getEventIcon(event.eventType),
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                event.playerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                  fontSize: 13,
                    ),
                  ),
              if (isHomeTeam) ...[
                const SizedBox(width: 6),
                Icon(
                  _getEventIcon(event.eventType),
                  size: 14,
                  color: Colors.white,
                ),
              ],
                ],
              ),
          const SizedBox(height: 2),
          Text(
            event.displayName,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Color _getEventColor(GameEventType eventType) {
    switch (eventType) {
      case GameEventType.onePoint:
      case GameEventType.twoPoints:
      case GameEventType.sixMeterHit:
        return Colors.green.shade600;
      case GameEventType.suspension:
        return Colors.orange.shade600;
      case GameEventType.redCard:
        return Colors.red.shade600;
      case GameEventType.sixMeterMiss:
        return Colors.grey.shade600;
      default:
        return Colors.blue.shade600;
    }
  }

  IconData _getEventIcon(GameEventType eventType) {
    switch (eventType) {
      case GameEventType.onePoint:
      case GameEventType.twoPoints:
        return Icons.sports_volleyball;
      case GameEventType.suspension:
        return Icons.warning;
      case GameEventType.redCard:
        return Icons.block;
      case GameEventType.timeout:
        return Icons.pause;
      case GameEventType.substitution:
        return Icons.swap_horiz;
      case GameEventType.sixMeterHit:
        return Icons.my_location;
      case GameEventType.sixMeterMiss:
        return Icons.location_off;
    }
  }

  Color _getEventIconColor(GameEventType eventType) {
    switch (eventType) {
      case GameEventType.onePoint:
      case GameEventType.twoPoints:
      case GameEventType.sixMeterHit:
        return Colors.green;
      case GameEventType.suspension:
        return Colors.orange;
      case GameEventType.redCard:
        return Colors.red;
      case GameEventType.sixMeterMiss:
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }
} 