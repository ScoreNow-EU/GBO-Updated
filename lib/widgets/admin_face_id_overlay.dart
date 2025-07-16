import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../services/face_id_service.dart';

class AdminFaceIdOverlay extends StatefulWidget {
  final Function(bool success, String? message) onAuthenticationComplete;
  final VoidCallback onCancel;

  const AdminFaceIdOverlay({
    super.key,
    required this.onAuthenticationComplete,
    required this.onCancel,
  });

  @override
  State<AdminFaceIdOverlay> createState() => _AdminFaceIdOverlayState();
}

class _AdminFaceIdOverlayState extends State<AdminFaceIdOverlay> {
  final FaceIdService _faceIdService = FaceIdService();
  bool _isLoading = true;
  String _biometricTypeName = 'Face ID';
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricType();
  }

  Future<void> _loadBiometricType() async {
    try {
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
          _biometricTypeName = 'Face ID';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _authenticateWithFaceId() async {
    setState(() {
      _isAuthenticating = true;
    });

    try {
      final authenticated = await _faceIdService.authenticate();
      
      if (authenticated) {
        widget.onAuthenticationComplete(true, 'Erfolgreich authentifiziert');
      } else {
        widget.onAuthenticationComplete(false, 'Authentifizierung fehlgeschlagen');
      }
    } catch (e) {
      widget.onAuthenticationComplete(false, 'Fehler bei der Authentifizierung');
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          if (_isLoading) ...[
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Lade Authentifizierungsinformationen...'),
                ],
              ),
            ),
          ] else ...[
            // Icon and title
            Center(
              child: Container(
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
            ),
            const SizedBox(height: 16),
            
            Text(
              'Authentifizierung erforderlich',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            
            Text(
              'Verwenden Sie $_biometricTypeName, um auf Admin-Bereiche zuzugreifen.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            
            // Face ID authentication button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isAuthenticating ? null : _authenticateWithFaceId,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFffd665),
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isAuthenticating
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _biometricTypeName == 'Face ID' ? Icons.face : Icons.fingerprint,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Authentifizieren & Fortfahren',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Cancel button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: TextButton(
                onPressed: _isAuthenticating ? null : widget.onCancel,
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: const Text(
                  'Abbrechen',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Show admin Face ID authentication overlay as bottom sheet
Future<void> showAdminFaceIdOverlay(
  BuildContext context, {
  required Function(bool success, String? message) onAuthenticationComplete,
  required VoidCallback onCancel,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    builder: (context) => AdminFaceIdOverlay(
      onAuthenticationComplete: onAuthenticationComplete,
      onCancel: onCancel,
    ),
  );
} 