import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:toastification/toastification.dart';
import '../services/face_id_service.dart';

class FaceIdDialog extends StatefulWidget {
  const FaceIdDialog({super.key});

  @override
  State<FaceIdDialog> createState() => _FaceIdDialogState();
}

class _FaceIdDialogState extends State<FaceIdDialog> {
  final FaceIdService _faceIdService = FaceIdService();
  String _biometricTypeName = 'Biometric';
  bool _isLoading = true;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricType();
  }

  Future<void> _loadBiometricType() async {
    try {
      // Check if user is logged in first
      if (!_faceIdService.isUserLoggedIn()) {
        if (mounted) {
          _showErrorToast('Sie müssen angemeldet sein, um Face ID zu aktivieren');
          Navigator.of(context).pop(false);
        }
        return;
      }
      
      final availableBiometrics = await _faceIdService.getAvailableBiometrics();
      final biometricName = _faceIdService.getBiometricTypeName(availableBiometrics);
      
      if (mounted) {
        setState(() {
          _biometricTypeName = biometricName;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _biometricTypeName = 'Biometric';
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorToast(String message) {
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.flatColored,
      title: Text(message),
      alignment: Alignment.topCenter,
      autoCloseDuration: const Duration(seconds: 4),
      showProgressBar: false,
      backgroundColor: Colors.red.shade400,
    );
  }

  void _showSuccessToast(String message) {
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.flatColored,
      title: Text(message),
      alignment: Alignment.topCenter,
      autoCloseDuration: const Duration(seconds: 3),
      showProgressBar: false,
      backgroundColor: Colors.green.shade400,
    );
  }

  Future<void> _handleFaceIdActivation() async {
    setState(() {
      _isAuthenticating = true;
    });

    try {
      // Test authentication first
      final success = await _faceIdService.authenticate();
      
      if (success) {
        // Authentication successful, enable Face ID
        await _faceIdService.setFaceIdEnabled(true);
        
        if (mounted) {
          _showSuccessToast('$_biometricTypeName erfolgreich aktiviert');
          Navigator.of(context).pop(true);
        }
      } else {
        // Authentication failed, mark as asked but don't enable
        await _faceIdService.markAskedAboutFaceId();
        
        if (mounted) {
          _showErrorToast('$_biometricTypeName-Authentifizierung fehlgeschlagen');
          Navigator.of(context).pop(false);
        }
      }
    } catch (e) {
      // Handle any errors during the process
      try {
        await _faceIdService.markAskedAboutFaceId();
      } catch (markError) {
        // Log the error but don't fail the UI
        debugPrint('Error marking as asked: $markError');
      }
      
      if (mounted) {
        _showErrorToast('Fehler beim Aktivieren von $_biometricTypeName');
        Navigator.of(context).pop(false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  Future<void> _handleNotNow() async {
    try {
      await _faceIdService.setFaceIdEnabled(false);
      if (mounted) {
        Navigator.of(context).pop(false);
      }
    } catch (e) {
      // Even if this fails, we should still close the dialog
      if (mounted) {
        Navigator.of(context).pop(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFffd665).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _biometricTypeName == 'Face ID' ? Icons.face : Icons.fingerprint,
              color: const Color(0xFFffd665),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$_biometricTypeName aktivieren?',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
      content: _isLoading
          ? const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Lade Biometric-Informationen...'),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Möchten Sie $_biometricTypeName für den schnellen Zugriff auf Admin-Bereiche aktivieren?',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                // Benefits container
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vorteile:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildBenefitRow(Icons.speed, 'Schnellerer Zugriff'),
                      _buildBenefitRow(Icons.security, 'Höhere Sicherheit'),
                      _buildBenefitRow(Icons.lock, 'Keine Passwort-Eingabe'),
                    ],
                  ),
                ),
                if (_isAuthenticating) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Authentifizierung läuft...',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
      actions: _isLoading
          ? []
          : [
              TextButton(
                onPressed: _isAuthenticating ? null : _handleNotNow,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text(
                  'Nicht jetzt',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _isAuthenticating ? null : _handleFaceIdActivation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isAuthenticating ? Colors.grey.shade300 : const Color(0xFFffd665),
                  foregroundColor: _isAuthenticating ? Colors.grey.shade600 : Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isAuthenticating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                        ),
                      )
                    : Text(
                        '$_biometricTypeName aktivieren',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Show Face ID dialog and return whether Face ID was enabled
Future<bool?> showFaceIdDialog(BuildContext context) async {
  return await showDialog<bool>(
    context: context,
    barrierDismissible: false, // User must make a choice
    builder: (context) => const FaceIdDialog(),
  );
} 