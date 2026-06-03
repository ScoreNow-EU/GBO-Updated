import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../models/tournament.dart';
import '../services/tournament_service.dart';
import '../screens/tournament_detail_screen.dart';

class TournamentTimeline extends StatefulWidget {
  final String? selectedSeason; // Accept season filter from parent
  
  const TournamentTimeline({
    super.key,
    this.selectedSeason,
  });

  @override
  State<TournamentTimeline> createState() => _TournamentTimelineState();
}

class _TournamentTimelineState extends State<TournamentTimeline> {
  final TournamentService _tournamentService = TournamentService();
  final ScrollController _scrollController = ScrollController();
  
  // Collapsible sections state
  bool _isUpcomingExpanded = true;
  bool _isOngoingExpanded = true;
  bool _isCompletedExpanded = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Tournament>>(
      stream: _tournamentService.getTournaments(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'Keine Turniere gefunden.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        String seasonFilter = widget.selectedSeason ?? '2025';
        List<Tournament> filteredTournaments = snapshot.data!
            .where((tournament) {
              // Filter out non-approved tournaments from public view
              if (tournament.approvalStatus != 'approved') {
                return false;
              }
              
              // Filter by category and season
              bool matchesSeason = tournament.season == seasonFilter;
              return matchesSeason;
            })
            .toList();

        if (filteredTournaments.isEmpty) {
          return const Center(
            child: Text(
              'Keine Turniere in der gewählten Kategorie gefunden.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            return Container(
              padding: EdgeInsets.all(isMobile ? 8 : 24),
              child: _buildTimeline(filteredTournaments),
            );
          },
        );
      },
    );
  }

  Widget _buildTimeline(List<Tournament> tournaments) {
    // Separate tournaments by status
    List<Tournament> completedTournaments = tournaments
        .where((t) => t.status == 'completed')
        .toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate)); // Oldest first (top to bottom)

    List<Tournament> currentTournaments = tournaments
        .where((t) => t.status == 'ongoing')
        .toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate)); // Earliest first

    List<Tournament> upcomingTournaments = tournaments
        .where((t) => t.status == 'upcoming')
        .toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate)); // Nearest first (top to bottom)

    return LayoutBuilder(
      builder: (context, constraints) {
        // Account for container padding (24px top and bottom = 48px total)
        double availableHeight = constraints.maxHeight - 48;
        
        // Calculate precise heights
        const double cardHeight = 116.0; // Tournament card + bottom padding
        const double sectionHeaderHeight = 56.0; // Header + spacing below
        const double timelineHeight = 50.0; // JETZT line or current tournaments
        const double sectionSpacing = 24.0;
        
        // Calculate completed section height
        double completedSectionHeight = 0;
        if (completedTournaments.isNotEmpty) {
          completedSectionHeight = sectionHeaderHeight + 
                                  (completedTournaments.length * cardHeight) + 
                                  sectionSpacing;
        }
        
        // Calculate the position where we want the timeline center to be
        double timelineStartPosition = completedSectionHeight;
        double timelineCenterPosition = timelineStartPosition + (timelineHeight / 2);
        
        // Calculate scroll position to center the timeline in viewport
        double targetScrollPosition = timelineCenterPosition - (availableHeight / 2);
        
        // Set scroll position after layout
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            double maxScroll = _scrollController.position.maxScrollExtent;
            double scrollTo = targetScrollPosition.clamp(0.0, maxScroll);
            _scrollController.animateTo(
              scrollTo,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        });

        return SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            children: [
              // Completed Tournaments (Above the line)
              if (completedTournaments.isNotEmpty) ...[
                _buildCollapsibleTimelineSection(
                  title: 'Abgeschlossene Turniere',
                  icon: Icons.check_circle,
                  color: Colors.grey,
                  count: completedTournaments.length,
                  isExpanded: _isCompletedExpanded,
                  onToggle: (expanded) => setState(() => _isCompletedExpanded = expanded),
                  tournaments: completedTournaments,
                  sectionType: 'completed',
                ),
                const SizedBox(height: 24),
              ],

              // Timeline Center Line with current tournaments or "JETZT" indicator
              if (currentTournaments.isNotEmpty)
                _buildCollapsibleTimelineSection(
                  title: 'Laufende Turniere',
                  icon: Icons.play_circle,
                  color: Colors.green,
                  count: currentTournaments.length,
                  isExpanded: _isOngoingExpanded,
                  onToggle: (expanded) => setState(() => _isOngoingExpanded = expanded),
                  tournaments: currentTournaments,
                  sectionType: 'ongoing',
                )
              else
                _buildTimelineCenter(currentTournaments),
              
              const SizedBox(height: 24),

              // Upcoming Tournaments (Below the line)
              if (upcomingTournaments.isNotEmpty) ...[
                _buildCollapsibleTimelineSection(
                  title: 'Bevorstehende Turniere',
                  icon: Icons.schedule,
                  color: Colors.orange,
                  count: upcomingTournaments.length,
                  isExpanded: _isUpcomingExpanded,
                  onToggle: (expanded) => setState(() => _isUpcomingExpanded = expanded),
                  tournaments: upcomingTournaments,
                  sectionType: 'upcoming',
                ),
              ],
              
              // Add extra bottom padding for better scrolling
              const SizedBox(height: 300),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            height: 1,
            color: color.withOpacity(0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsibleTimelineSection({
    required String title,
    required IconData icon,
    required Color color,
    required int count,
    required bool isExpanded,
    required ValueChanged<bool> onToggle,
    required List<Tournament> tournaments,
    required String sectionType,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobileScreen = screenWidth < 600;

    return Column(
      children: [
        ExpansionTile(
          shape: isMobileScreen ? const Border() : null,
          collapsedShape: isMobileScreen ? const Border() : null,
          tilePadding: EdgeInsets.symmetric(
            horizontal: isMobileScreen ? 8 : 16,
            vertical: isMobileScreen ? 6 : 12,
          ),
          childrenPadding: EdgeInsets.only(bottom: isMobileScreen ? 8 : 16),
          initiallyExpanded: isExpanded,
          onExpansionChanged: onToggle,
          leading: Icon(icon, color: color, size: isMobileScreen ? 18 : 20),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  '$title ($count)',
                  style: TextStyle(
                    fontSize: isMobileScreen ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isMobileScreen) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    height: 1,
                    color: color.withOpacity(0.3),
                  ),
                ),
              ],
            ],
          ),
          subtitle: isMobileScreen
              ? null
              : Text(
                  '$count Turnier${count == 1 ? '' : 'e'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
          children: tournaments.map((tournament) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                return Padding(
                  padding: EdgeInsets.only(bottom: isMobile ? 12 : 16),
                  child: _buildTournamentCard(
                    tournament,
                    isCompleted: sectionType == 'completed',
                    isUpcoming: sectionType == 'upcoming',
                    isCurrent: sectionType == 'ongoing',
                  ),
                );
              },
            );
          }).toList(),
        ),
        SizedBox(height: isMobileScreen ? 8 : 16),
      ],
    );
  }

  Widget _buildTimelineCenter(List<Tournament> currentTournaments) {
    return Container(
      width: double.infinity,
      child: Column(
        children: [
          // Current tournaments if any - display vertically on mobile, horizontally on desktop
          if (currentTournaments.isNotEmpty) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                
                if (isMobile) {
                  // Mobile: Display vertically like other sections
                  return Column(
                    children: currentTournaments.asMap().entries.map((entry) {
                      int index = entry.key;
                      Tournament tournament = entry.value;
                      return Padding(
                        padding: EdgeInsets.only(bottom: index == currentTournaments.length - 1 ? 0 : 8),
                        child: _buildTournamentCard(tournament, isCurrent: true),
                      );
                    }).toList(),
                  );
                } else {
                  // Desktop: Display horizontally with scroll
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: currentTournaments.asMap().entries.map((entry) {
                        int index = entry.key;
                        Tournament tournament = entry.value;
                        return Container(
                          width: 350,
                          margin: EdgeInsets.only(
                            left: index == 0 ? 0 : 8,
                            right: index == currentTournaments.length - 1 ? 0 : 8,
                          ),
                          child: _buildTournamentCard(tournament, isCurrent: true),
                        );
                      }).toList(),
                    ),
                  );
                }
              },
            ),
          ],
          
          // Timeline line with "JETZT" indicator - only show when no active tournaments
          if (currentTournaments.isEmpty) ...[
            Stack(
              alignment: Alignment.center,
              children: [
                // Main timeline line
                Container(
                  height: 4,
                  width: double.infinity,
                  decoration: BoxDecoration(
                            gradient: LinearGradient(
          colors: [
            AppColors.rhdGold.withOpacity(0.5),
            AppColors.rhdGold,
            AppColors.rhdGold.withOpacity(0.5),
          ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // "JETZT" indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.rhdGold,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.rhdGold.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'JETZT',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTournamentCard(Tournament tournament, {
    bool isCompleted = false,
    bool isCurrent = false,
    bool isUpcoming = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        
        final statusLabel = isCompleted
            ? 'Abgeschlossen'
            : isCurrent
                ? 'Läuft aktuell'
                : isUpcoming
                    ? 'Bevorstehend'
                    : '';
        return Semantics(
          button: true,
          label: 'Turnier ${tournament.name}'
              '${statusLabel.isNotEmpty ? ', $statusLabel' : ''}'
              '. Details öffnen.',
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => TournamentDetailScreen(tournament: tournament),
                  settings: const RouteSettings(name: 'TournamentDetailScreen'),
                ),
              );
            },
            child: Container(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isMobile ? 0.06 : 0.05),
                  blurRadius: isMobile ? 6 : 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: isMobile
                  ? (isCurrent ? Border.all(color: AppColors.rhdGold, width: 2) : null)
                  : Border.all(
                      color: isCurrent ? AppColors.rhdGold : Colors.grey.shade200,
                      width: isCurrent ? 2 : 1,
                    ),
            ),
            child: isMobile ? _buildMobileLayout(tournament, isCurrent) : _buildDesktopLayout(tournament, isCurrent),
          ),
        ),
        );
      },
    );
  }

  Widget _buildMobileLayout(Tournament tournament, bool isCurrent) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tournament Logo - compact, no border
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 52,
            height: 52,
            child: tournament.imageUrl != null && tournament.imageUrl!.isNotEmpty
                ? Image.network(
                    tournament.imageUrl!,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildGeneratedImage(tournament, width: 52, height: 52);
                    },
                  )
                : _buildGeneratedImage(tournament, width: 52, height: 52),
          ),
        ),
        const SizedBox(width: 12),
        // Info column
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tournament.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (isCurrent)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'AKTIV',
                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w500),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      tournament.dateString,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  _buildStatusBadge(tournament.status, isCompact: true),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.location_on, size: 12, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      tournament.location,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(Tournament tournament, bool isCurrent) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tournament Logo
        Container(
          width: 80,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: tournament.imageUrl != null && tournament.imageUrl!.isNotEmpty
                ? Image.network(
                    tournament.imageUrl!,
                    width: 80,
                    height: 60,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 80,
                        height: 60,
                        color: Colors.grey.shade100,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
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
                      return _buildGeneratedImage(tournament, width: 80, height: 60);
                    },
                  )
                : _buildGeneratedImage(tournament, width: 80, height: 60),
          ),
        ),
        const SizedBox(width: 20),
        
        // Tournament Details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tournament name with current indicator
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tournament.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                  if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'AKTIV',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    tournament.dateString,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tournament.location,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Status
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildStatusBadge(tournament.status),
          ],
        ),
      ],
    );
  }

  Widget _buildGeneratedImage(Tournament tournament, {double width = 80, double height = 60}) {
    // Generate colors based on tournament name hash
    int nameHash = tournament.name.hashCode;

    
    // Create color palette based on category
    List<Color> colors = [];
    colors = [
      Color((nameHash & 0xFF6C5CE7) | 0xFF000000), // Purple variants
      Color((nameHash & 0xFFA29BFE) | 0xFF000000), // Light purple variants
      Color((nameHash & 0xFF74B9FF) | 0xFF000000), // Blue variants
    ];
    
    // Choose pattern type based on hash
    int patternType = nameHash.abs() % 4;
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildPattern(patternType, colors, tournament),
      ),
    );
  }
  
  Widget _buildPattern(int patternType, List<Color> colors, Tournament tournament) {
    switch (patternType) {
      case 0:
        return _buildGradientPattern(colors);
      case 1:
        return _buildGeometricPattern(colors, tournament);
      case 2:
        return _buildWavePattern(colors);
      case 3:
        return _buildCirclePattern(colors, tournament);
      default:
        return _buildGradientPattern(colors);
    }
  }
  
  Widget _buildGradientPattern(List<Color> colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.take(2).toList(),
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
  
  Widget _buildGeometricPattern(List<Color> colors, Tournament tournament) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors.take(2).toList(),
        ),
      ),
      child: Stack(
        children: [
          // Geometric shapes
          Positioned(
            top: -10,
            right: -10,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: colors.length > 2 ? colors[2].withOpacity(0.3) : Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -15,
            left: -15,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.length > 2 ? colors[2].withOpacity(0.2) : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          // Tournament initials
          Center(
            child: Text(
              _getTournamentInitials(tournament.name),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    offset: Offset(1, 1),
                    blurRadius: 2,
                    color: Colors.black26,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildWavePattern(List<Color> colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.take(3).toList(),
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: WavePainter(
          waveColor: Colors.white.withOpacity(0.2),
        ),
        size: const Size(80, 60),
      ),
    );
  }
  
  Widget _buildCirclePattern(List<Color> colors, Tournament tournament) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.8,
          colors: colors.take(2).toList(),
          stops: const [0.0, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: 5,
            left: 5,
            child: Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 20,
            right: 15,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Center icon
          Center(
            child: Icon(
              Icons.sports_handball,
              color: Colors.white.withOpacity(0.8),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
  
  String _getTournamentInitials(String name) {
    List<String> words = name.split(' ');
    if (words.length >= 2) {
      return (words[0].isNotEmpty ? words[0][0] : '') + 
             (words[1].isNotEmpty ? words[1][0] : '');
    } else if (words.isNotEmpty && words[0].length >= 2) {
      return words[0].substring(0, 2);
    }
    return 'T';
  }

  String? _getTournamentImage(String tournamentName) {
    // Return null to use placeholder/icon instead of hardcoded images
    return null;
  }

  Widget _buildStatusBadge(String status, {bool isCompact = false}) {
    Color color;
    String label;
    
    switch (status) {
      case 'upcoming':
        color = Colors.orange;
        label = 'Bevorstehend';
        break;
      case 'ongoing':
        color = Colors.green;
        label = 'Laufend';
        break;
      case 'completed':
        color = Colors.grey;
        label = 'Abgeschlossen';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: isCompact ? 9 : 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// Custom painter for wave pattern
class WavePainter extends CustomPainter {
  final Color waveColor;
  
  WavePainter({required this.waveColor});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = waveColor
      ..style = PaintingStyle.fill;
    
    final path = Path();
    path.moveTo(0, size.height * 0.3);
    
    // Create wave using quadratic bezier curves
    path.quadraticBezierTo(
      size.width * 0.25, size.height * 0.1,
      size.width * 0.5, size.height * 0.3,
    );
    path.quadraticBezierTo(
      size.width * 0.75, size.height * 0.5,
      size.width, size.height * 0.3,
    );
    
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
} 