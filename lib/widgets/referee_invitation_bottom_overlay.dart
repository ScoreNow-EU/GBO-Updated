import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../models/tournament.dart';
import '../services/tournament_service.dart';

class RefereeInvitationBottomOverlay extends StatefulWidget {
  final List<Tournament> pendingTournaments;
  final String refereeId;
  final VoidCallback onCompleted;
  final VoidCallback? onPending;

  const RefereeInvitationBottomOverlay({
    super.key,
    required this.pendingTournaments,
    required this.refereeId,
    required this.onCompleted,
    this.onPending,
  });

  @override
  State<RefereeInvitationBottomOverlay> createState() => _RefereeInvitationBottomOverlayState();
}

class _RefereeInvitationBottomOverlayState extends State<RefereeInvitationBottomOverlay>
    with SingleTickerProviderStateMixin {
  final TournamentService _tournamentService = TournamentService();
  int _currentIndex = 0;
  bool _isProcessing = false;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  Tournament get currentTournament => widget.pendingTournaments[_currentIndex];
  bool get isLastTournament => _currentIndex >= widget.pendingTournaments.length - 1;
  bool get hasMultipleTournaments => widget.pendingTournaments.length > 1;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Start the animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * MediaQuery.of(context).size.height),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Minimal tap to dismiss area
                GestureDetector(
                  onTap: () => _dismissOverlay(),
                  child: Container(
                    height: 30,
                    color: Colors.transparent,
                  ),
                ),
                // Bottom overlay content - full height
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          // Handle bar
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          
                          // Main content area - no scrolling
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header with counter - compact
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.sports_handball,
                                          color: Colors.orange.shade700,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Turnier-Einladung',
                                              style: TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                                decoration: TextDecoration.none,
                                              ),
                                            ),
                                            if (hasMultipleTournaments)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade100,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  '${_currentIndex + 1} von ${widget.pendingTournaments.length}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.blue.shade700,
                                                    decoration: TextDecoration.none,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),

                                  // Tournament image
                                  Container(
                                    width: double.infinity,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                        width: 1,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(11),
                                      child: currentTournament.imageUrl != null && currentTournament.imageUrl!.isNotEmpty
                                          ? Image.network(
                                              currentTournament.imageUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return _buildImagePlaceholder();
                                              },
                                              loadingBuilder: (context, child, loadingProgress) {
                                                if (loadingProgress == null) return child;
                                                return Center(
                                                  child: CircularProgressIndicator(
                                                    value: loadingProgress.expectedTotalBytes != null
                                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                        : null,
                                                  ),
                                                );
                                              },
                                            )
                                          : _buildImagePlaceholder(),
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // Tournament name and category in same row
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          currentTournament.name,
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                            decoration: TextDecoration.none,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: currentTournament.isJuniors 
                                              ? Colors.green.shade100 
                                              : Colors.purple.shade100,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              currentTournament.isJuniors 
                                                  ? Icons.school 
                                                  : Icons.workspace_premium,
                                              color: currentTournament.isJuniors 
                                                  ? Colors.green.shade700 
                                                  : Colors.purple.shade700,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              currentTournament.isJuniors 
                                                  ? 'Juniors' 
                                                  : 'Seniors',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: currentTournament.isJuniors 
                                                    ? Colors.green.shade700 
                                                    : Colors.purple.shade700,
                                                decoration: TextDecoration.none,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),

                                  // Main tournament details in cards - more compact
                                  Row(
                                    children: [
                                      // Location & Date card
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.blue.shade200),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.location_on,
                                                    color: Colors.blue.shade700,
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  const Text(
                                                    'Ort',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.black54,
                                                      decoration: TextDecoration.none,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                currentTournament.location,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                  decoration: TextDecoration.none,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.calendar_today,
                                                    color: Colors.blue.shade700,
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  const Text(
                                                    'Datum',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.black54,
                                                      decoration: TextDecoration.none,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                currentTournament.dateString,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                  decoration: TextDecoration.none,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Points card
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade50,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.amber.shade200),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.star,
                                              color: Colors.amber.shade700,
                                              size: 28,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${currentTournament.points}',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.amber.shade700,
                                                decoration: TextDecoration.none,
                                              ),
                                            ),
                                            Text(
                                              'Punkte',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.amber.shade700,
                                                decoration: TextDecoration.none,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),

                                  // Divisions section - compact
                                  if (currentTournament.divisions.isNotEmpty) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.category,
                                                color: Colors.grey.shade700,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 6),
                                              const Text(
                                                'Kategorien',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                  decoration: TextDecoration.none,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: currentTournament.divisions.map((division) {
                                              final isWomens = division.toLowerCase().contains('women');
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: isWomens 
                                                      ? Colors.pink.shade100 
                                                      : Colors.blue.shade100,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  division,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: isWomens 
                                                        ? Colors.pink.shade700 
                                                        : Colors.blue.shade700,
                                                    decoration: TextDecoration.none,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],

                                  // Question - compact
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.orange.shade50,
                                          Colors.blue.shade50,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.orange.shade200),
                                    ),
                                    child: const Text(
                                      'Möchtest Du an diesem Turnier als Schiedsrichter teilnehmen?',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                        decoration: TextDecoration.none,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  // Action buttons - compact
                                  if (_isProcessing)
                                    const Expanded(
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            CircularProgressIndicator(),
                                            SizedBox(height: 12),
                                            Text(
                                              'Antwort wird gespeichert...',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey,
                                                decoration: TextDecoration.none,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else
                                    Flexible(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Accept button
                                          SizedBox(
                                            width: double.infinity,
                                            height: 40,
                                            child: ElevatedButton(
                                              onPressed: () => _respondToInvitation('accepted'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green.shade600,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                elevation: 2,
                                              ),
                                              child: const Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.check_circle, size: 16),
                                                  SizedBox(width: 6),
                                                  Text(
                                                    'Ja, ich kann teilnehmen',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                      decoration: TextDecoration.none,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          // Decline button
                                          SizedBox(
                                            width: double.infinity,
                                            height: 40,
                                            child: ElevatedButton(
                                              onPressed: () => _respondToInvitation('declined'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red.shade600,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                elevation: 2,
                                              ),
                                              child: const Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.cancel, size: 16),
                                                  SizedBox(width: 6),
                                                  Text(
                                                    'Nein, ich kann nicht',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                      decoration: TextDecoration.none,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          // Maybe later button
                                          SizedBox(
                                            width: double.infinity,
                                            height: 40,
                                            child: OutlinedButton(
                                              onPressed: () => _respondToInvitation('pending'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.orange.shade700,
                                                side: BorderSide(color: Colors.orange.shade700, width: 2),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                              child: const Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.schedule, size: 16),
                                                  SizedBox(width: 6),
                                                  Text(
                                                    'Später entscheiden',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                      decoration: TextDecoration.none,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
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
        );
      },
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.shade200,
            Colors.blue.shade200,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events,
            size: 36,
            color: Colors.orange.shade700,
          ),
          const SizedBox(width: 8),
          Text(
            'GBO Tournament',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.blue.shade700,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _respondToInvitation(String response) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final success = await _tournamentService.respondToRefereeInvitation(
        currentTournament.id,
        widget.refereeId,
        response,
      );

      if (!success) {
        if (mounted) {
          toastification.show(
            context: context,
            type: ToastificationType.error,
            style: ToastificationStyle.fillColored,
            title: const Text(
              'Fehler',
              style: TextStyle(decoration: TextDecoration.none),
            ),
            description: const Text(
              'Antwort konnte nicht gespeichert werden.',
              style: TextStyle(decoration: TextDecoration.none),
            ),
            autoCloseDuration: const Duration(seconds: 3),
          );
        }
        return;
      }

      // Show success message
      String message = '';
      switch (response) {
        case 'accepted':
          message = 'Zusage erfolgreich gesendet!';
          break;
        case 'declined':
          message = 'Absage erfolgreich gesendet.';
          break;
        case 'pending':
          message = 'Als unentschieden markiert. Sie können später noch antworten.';
          break;
      }

      if (mounted) {
        toastification.show(
          context: context,
          type: response == 'accepted' 
              ? ToastificationType.success 
              : ToastificationType.info,
          style: ToastificationStyle.fillColored,
          title: Text(
            response == 'accepted' ? 'Zusage!' : 
                     response == 'declined' ? 'Absage!' : 'Unentschieden',
            style: const TextStyle(decoration: TextDecoration.none),
          ),
          description: Text(
            message,
            style: const TextStyle(decoration: TextDecoration.none),
          ),
          autoCloseDuration: const Duration(seconds: 2),
        );
      }

      // Special handling for pending response
      if (response == 'pending') {
        if (widget.onPending != null) {
          widget.onPending!();
        }
        // Close the overlay when "Später entscheiden" is clicked
        _dismissOverlay();
        return;
      }

      // Move to next tournament or close overlay
      if (isLastTournament) {
        // All done, close overlay
        _dismissOverlay();
      } else {
        // Move to next tournament
        setState(() {
          _currentIndex++;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          title: const Text('Fehler'),
          description: const Text('Ein Fehler ist aufgetreten.'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    }

    setState(() {
      _isProcessing = false;
    });
  }

  Future<void> _dismissOverlay() async {
    await _animationController.reverse();
    if (mounted) {
      Navigator.of(context).pop();
      widget.onCompleted();
    }
  }
} 