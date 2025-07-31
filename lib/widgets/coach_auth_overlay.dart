import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../models/coach_auth_request.dart';
import '../services/coach_auth_monitoring_service.dart';
import '../services/face_id_service.dart';
import '../models/user.dart' as app_user;

class CoachAuthOverlay extends StatefulWidget {
  final List<CoachAuthRequest> pendingRequests;
  final app_user.User currentUser;
  final VoidCallback onCompleted;
  final VoidCallback? onPending;

  const CoachAuthOverlay({
    super.key,
    required this.pendingRequests,
    required this.currentUser,
    required this.onCompleted,
    this.onPending,
  });

  @override
  State<CoachAuthOverlay> createState() => _CoachAuthOverlayState();
}

class _CoachAuthOverlayState extends State<CoachAuthOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  
  int _currentIndex = 0;
  bool _isProcessing = false;
  bool _isAuthenticating = false;
  final FaceIdService _faceIdService = FaceIdService();
  String _biometricTypeName = 'Face ID';

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _loadBiometricType();
  }

  void _initializeAnimation() {
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

  Future<void> _loadBiometricType() async {
    try {
      final availableBiometrics = await _faceIdService.getAvailableBiometrics();
      final biometricName = _faceIdService.getBiometricTypeName(availableBiometrics);
      
      if (mounted) {
        setState(() {
          _biometricTypeName = biometricName;
        });
      }
    } catch (e) {
      setState(() {
        _biometricTypeName = 'Face ID';
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  CoachAuthRequest get _currentRequest => widget.pendingRequests[_currentIndex];
  bool get _isLastRequest => _currentIndex >= widget.pendingRequests.length - 1;

  Future<void> _handleResponse(CoachAuthStatus response) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // For approve/decline responses, require biometric authentication
      if (response == CoachAuthStatus.approved || response == CoachAuthStatus.declined) {
        setState(() {
          _isAuthenticating = true;
        });

        // Check if biometric authentication is available
        final isAvailable = await _faceIdService.isBiometricAvailable();
        if (!isAvailable) {
          if (mounted) {
            toastification.show(
              context: context,
              type: ToastificationType.error,
              style: ToastificationStyle.fillColored,
              title: const Text('Fehler'),
              description: Text('$_biometricTypeName ist nicht verfügbar'),
              autoCloseDuration: const Duration(seconds: 3),
            );
          }
          setState(() {
            _isAuthenticating = false;
            _isProcessing = false;
          });
          return;
        }

        // Perform biometric authentication
        final authenticated = await _faceIdService.authenticate();
        setState(() {
          _isAuthenticating = false;
        });

        if (!authenticated) {
          if (mounted) {
            toastification.show(
              context: context,
              type: ToastificationType.error,
              style: ToastificationStyle.fillColored,
              title: const Text('Authentifizierung fehlgeschlagen'),
              description: const Text('Biometrische Authentifizierung war nicht erfolgreich'),
              autoCloseDuration: const Duration(seconds: 3),
            );
          }
          setState(() {
            _isProcessing = false;
          });
          return;
        }
      }

      // Update the request status
      String responseString;
      String message;
      
      switch (response) {
        case CoachAuthStatus.approved:
          responseString = 'approved';
          message = 'Kader wurde genehmigt';
          break;
        case CoachAuthStatus.declined:
          responseString = 'declined';
          message = 'Kader wurde abgelehnt';
          break;
        default:
          throw Exception('Invalid response type');
      }

      // Send response to monitoring service
      final success = await CoachAuthMonitoringService.respondToRequest(
        _currentRequest.id,
        widget.currentUser.email,
        responseString,
      );

      if (!success) {
        throw Exception('Failed to update request');
      }

      // Show success message
      if (mounted) {
        toastification.show(
          context: context,
          type: response == CoachAuthStatus.approved 
              ? ToastificationType.success 
              : ToastificationType.info,
          style: ToastificationStyle.fillColored,
          title: Text(
            response == CoachAuthStatus.approved ? 'Genehmigt!' : 'Abgelehnt!',
            style: const TextStyle(decoration: TextDecoration.none),
          ),
          description: Text(
            message,
            style: const TextStyle(decoration: TextDecoration.none),
          ),
          autoCloseDuration: const Duration(seconds: 2),
        );
      }

      // Move to next request or close overlay
      if (_isLastRequest) {
        // All done, close overlay
        await _dismissOverlay();
      } else {
        // Move to next request
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
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _dismissOverlay() async {
    await _animationController.reverse();
    if (mounted) {
      Navigator.of(context).pop();
      widget.onCompleted();
    }
  }

  String _formatTimeRemaining(DateTime expiresAt) {
    final difference = expiresAt.difference(DateTime.now());
    if (difference.isNegative) return 'Abgelaufen';
    
    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    } else {
      return '${minutes}min';
    }
  }

  Color _getUrgencyColor(CoachAuthRequest request) {
    if (request.isExpired) return Colors.red;
    if (request.isTimeCritical) return Colors.orange;
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, MediaQuery.of(context).size.height * _slideAnimation.value),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: _getUrgencyColor(_currentRequest).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Icon(
                              Icons.sports_basketball,
                              color: _getUrgencyColor(_currentRequest),
                              size: 25,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kader-Freigabe erforderlich',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  '${_currentIndex + 1} von ${widget.pendingRequests.length}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getUrgencyColor(_currentRequest).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _formatTimeRemaining(_currentRequest.expiresAt),
                              style: TextStyle(
                                color: _getUrgencyColor(_currentRequest),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Request details
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Game info card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentRequest.gameTitle,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.group, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    _currentRequest.teamName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_currentRequest.gameDate.day}.${_currentRequest.gameDate.month}.${_currentRequest.gameDate.year} ${_currentRequest.gameDate.hour.toString().padLeft(2, '0')}:${_currentRequest.gameDate.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Angefragt von: ${_currentRequest.requestedByName}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Instructions
                        Text(
                          'Als Trainer müssen Sie die Kader-Auswahl für dieses Spiel genehmigen oder ablehnen.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                        
                        if (_isAuthenticating) ...[
                          const SizedBox(height: 32),
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFffd665).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(40),
                                  ),
                                  child: Icon(
                                    _biometricTypeName == 'Face ID' ? Icons.face : Icons.fingerprint,
                                    color: const Color(0xFFffd665),
                                    size: 40,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Authentifizierung läuft...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Verwenden Sie $_biometricTypeName zur Bestätigung',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
                
                // Action buttons
                if (!_isAuthenticating)
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Approve button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isProcessing ? null : () => _handleResponse(CoachAuthStatus.approved),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _isProcessing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Kader genehmigen',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Decline button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: TextButton(
                            onPressed: _isProcessing ? null : () => _handleResponse(CoachAuthStatus.declined),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.red.shade300),
                              ),
                            ),
                            child: const Text(
                              'Kader ablehnen',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Show coach authentication overlay as bottom sheet
Future<void> showCoachAuthOverlay(
  BuildContext context, {
  required List<CoachAuthRequest> pendingRequests,
  required app_user.User currentUser,
  required VoidCallback onCompleted,
  VoidCallback? onPending,
}) async {
  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    pageBuilder: (context, animation, secondaryAnimation) {
      return CoachAuthOverlay(
        pendingRequests: pendingRequests,
        currentUser: currentUser,
        onCompleted: onCompleted,
        onPending: onPending,
      );
    },
  );
} 