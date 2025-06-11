import 'package:flutter/material.dart';
import '../models/tournament.dart';
import '../services/tournament_service.dart';
import '../screens/tournament_detail_screen.dart';

class TournamentTimeline extends StatefulWidget {
  final String? selectedCategory; // Accept category filter from parent
  
  const TournamentTimeline({
    super.key,
    this.selectedCategory,
  });

  @override
  State<TournamentTimeline> createState() => _TournamentTimelineState();
}

class _TournamentTimelineState extends State<TournamentTimeline> {
  final TournamentService _tournamentService = TournamentService();
  final ScrollController _scrollController = ScrollController();

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

        String categoryFilter = widget.selectedCategory ?? 'Alle';
        List<Tournament> filteredTournaments = snapshot.data!
            .where((tournament) {
              // Filter by category
              return categoryFilter == 'Alle' || tournament.hasCategory(categoryFilter);
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

        return Container(
          padding: const EdgeInsets.all(24),
          child: _buildTimeline(filteredTournaments),
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
                _buildSectionHeader('Abgeschlossene Turniere', Icons.check_circle, Colors.grey),
                const SizedBox(height: 16),
                ...completedTournaments.map((tournament) => 
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildTournamentCard(tournament, isCompleted: true),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Timeline Center Line with current tournaments or "JETZT" indicator
              _buildTimelineCenter(currentTournaments),
              
              const SizedBox(height: 24),

              // Upcoming Tournaments (Below the line)
              if (upcomingTournaments.isNotEmpty) ...[
                _buildSectionHeader('Bevorstehende Turniere', Icons.schedule, Colors.orange),
                const SizedBox(height: 16),
                ...upcomingTournaments.map((tournament) => 
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildTournamentCard(tournament, isUpcoming: true),
                  ),
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

  Widget _buildTimelineCenter(List<Tournament> currentTournaments) {
    return Container(
      width: double.infinity,
      child: Column(
        children: [
          // Current tournaments if any - display horizontally with equal width
          if (currentTournaments.isNotEmpty) ...[
            Row(
              children: currentTournaments.asMap().entries.map((entry) {
                int index = entry.key;
                Tournament tournament = entry.value;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: index == 0 ? 0 : 8, // First item no left padding
                      right: index == currentTournaments.length - 1 ? 0 : 8, // Last item no right padding
                    ),
                    child: _buildTournamentCard(tournament, isCurrent: true),
                  ),
                );
              }).toList(),
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
                        Colors.blue.shade300,
                        Colors.blue.shade600,
                        Colors.blue.shade300,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // "JETZT" indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
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
    // Use the exact same design as the list view
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TournamentDetailScreen(tournament: tournament),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
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
          border: Border.all(
            color: isCurrent ? Colors.blue.shade400 : Colors.grey.shade200, 
            width: isCurrent ? 2 : 1
          ),
        ),
        child: Row(
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
                          return _buildGeneratedImage(tournament);
                        },
                      )
                    : _buildGeneratedImage(tournament),
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
                  const SizedBox(height: 8),
                  Text(
                    tournament.categoryDisplayNames,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
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
            
            // Points and Status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${tournament.points}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Punkte',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                _buildStatusBadge(tournament.status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneratedImage(Tournament tournament) {
    // Generate colors based on tournament name hash
    int nameHash = tournament.name.hashCode;
    int categoryHash = tournament.categories.join().hashCode;
    
    // Create color palette based on category
    List<Color> colors = [];
    if (tournament.isJuniors) {
      colors = [
        Color((nameHash & 0xFF6B73FF) | 0xFF000000), // Blue variants
        Color((nameHash & 0xFF4ECDC4) | 0xFF000000), // Teal variants
        Color((nameHash & 0xFF45B7D1) | 0xFF000000), // Light blue variants
      ];
    } else if (tournament.isSeniors) {
      colors = [
        Color((nameHash & 0xFFFF6B6B) | 0xFF000000), // Red variants
        Color((nameHash & 0xFFFFE66D) | 0xFF000000), // Yellow variants
        Color((nameHash & 0xFFFF8E53) | 0xFF000000), // Orange variants
      ];
    } else {
      colors = [
        Color((nameHash & 0xFF6C5CE7) | 0xFF000000), // Purple variants
        Color((nameHash & 0xFFA29BFE) | 0xFF000000), // Light purple variants
        Color((nameHash & 0xFF74B9FF) | 0xFF000000), // Blue variants
      ];
    }
    
    // Choose pattern type based on hash
    int patternType = nameHash.abs() % 4;
    
    return Container(
      width: 80,
      height: 60,
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
              tournament.isJuniors ? Icons.sports_volleyball : Icons.sports_basketball,
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

  String _getTournamentImage(String tournamentName) {
    if (tournamentName.toLowerCase().contains('herrenhäuser') || 
        tournamentName.toLowerCase().contains('herrenhausen')) {
      return 'assets/images/c23eafe6d142e505493614c3fb615049.png';
    } else if (tournamentName.toLowerCase().contains('verden')) {
      return 'assets/images/kJVjfNPZ_400x400.jpg';
    } else if (tournamentName.toLowerCase().contains('mob')) {
      return 'assets/images/72348f10bfa0314f12c8cccc85a3d43d.png';
    } else if (tournamentName.toLowerCase().contains('hvnb') || 
               tournamentName.toLowerCase().contains('cuxhaven')) {
      return 'assets/images/HVNB_Logo_RGB_ohneSubline_Favicon-768x768.jpg';
    } else {
      // Default fallback image or placeholder
      return 'assets/images/c23eafe6d142e505493614c3fb615049.png';
    }
  }

  Widget _buildStatusBadge(String status) {
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
          fontSize: 10,
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