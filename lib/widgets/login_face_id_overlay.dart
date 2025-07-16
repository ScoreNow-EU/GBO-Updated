import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../services/face_id_service.dart';
import '../services/auth_service.dart';

class LoginFaceIdOverlay extends StatefulWidget {
  final String email;
  final String password;
  final Function(bool success, String? message) onLoginComplete;
  final VoidCallback onManualLogin;

  const LoginFaceIdOverlay({
    super.key,
    required this.email,
    required this.password,
    required this.onLoginComplete,
    required this.onManualLogin,
  });

  @override
  State<LoginFaceIdOverlay> createState() => _LoginFaceIdOverlayState();
}

class _LoginFaceIdOverlayState extends State<LoginFaceIdOverlay> {
  final FaceIdService _faceIdService = FaceIdService();
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _isFaceIdEnabled = false;
  bool _isPasswordSaved = false;
  String _biometricTypeName = 'Face ID';
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _checkFaceIdStatus();
  }

  Future<void> _checkFaceIdStatus() async {
    try {
      final isEnabled = await _faceIdService.isFaceIdEnabled();
      final isDeviceSupported = await _faceIdService.isDeviceSupported();
      final availableBiometrics = await _faceIdService.getAvailableBiometrics();
      final biometricName = _faceIdService.getBiometricTypeName(availableBiometrics);
      
      // For now, we'll assume password is saved if Face ID is enabled
      // In a real app, you might want to check keychain/secure storage
      final isPasswordSaved = isEnabled;
      
      if (mounted) {
        setState(() {
          _isFaceIdEnabled = isEnabled && isDeviceSupported;
          _isPasswordSaved = isPasswordSaved;
          _biometricTypeName = biometricName;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFaceIdEnabled = false;
          _isPasswordSaved = false;
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
      final authenticated = await _faceIdService.authenticateForLogin();
      
      if (authenticated) {
        // Face ID successful, proceed with login
        await _performLogin();
      } else {
        // Face ID failed
        if (mounted) {
          setState(() {
            _isAuthenticating = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
      
      // Show error message to user
      widget.onLoginComplete(false, 'Fehler bei der $_biometricTypeName-Authentifizierung');
    }
  }

  Future<void> _performLogin() async {
    try {
      final user = await _authService.signInWithEmailAndPassword(
        widget.email,
        widget.password,
      );

      if (user != null) {
        widget.onLoginComplete(true, 'Erfolgreich mit $_biometricTypeName angemeldet');
      } else {
        widget.onLoginComplete(false, 'Anmeldung fehlgeschlagen');
      }
    } catch (e) {
      widget.onLoginComplete(false, 'Anmeldung fehlgeschlagen: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  Future<void> _enableFaceIdAndSavePassword() async {
    setState(() {
      _isAuthenticating = true;
    });

    try {
      // Test Face ID first
      final authenticated = await _faceIdService.authenticateForLogin();
      
      if (authenticated) {
        // Enable Face ID
        await _faceIdService.setFaceIdEnabled(true);
        
        // Proceed with login
        await _performLogin();
      } else {
        // Face ID setup failed
        if (mounted) {
          setState(() {
            _isAuthenticating = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
      
      // Show error message to user
      widget.onLoginComplete(false, 'Fehler beim Aktivieren von $_biometricTypeName');
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
                  Text('Biometric-Status wird überprüft...'),
                ],
              ),
            ),
          ] else if (_isFaceIdEnabled && _isPasswordSaved) ...[
            // Face ID is enabled and password is saved
            _buildFaceIdEnabledView(),
          ] else ...[
            // Face ID not enabled or password not saved
            _buildEnableFaceIdView(),
          ],
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFaceIdEnabledView() {
    return Column(
      children: [
        // Icon and title
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
          '$_biometricTypeName aktiviert',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        
        Text(
          'Verwenden Sie $_biometricTypeName für eine schnelle und sichere Anmeldung.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        
        // Face ID login button
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
                        'Mit $_biometricTypeName anmelden',
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
        
        // Manual login button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: TextButton(
            onPressed: widget.onManualLogin,
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: const Text(
              'Manuell anmelden',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnableFaceIdView() {
    return Column(
      children: [
        // Icon and title
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(40),
          ),
          child: Icon(
            _biometricTypeName == 'Face ID' ? Icons.face : Icons.fingerprint,
            color: Colors.blue.shade600,
            size: 40,
          ),
        ),
        const SizedBox(height: 16),
        
        Text(
          '$_biometricTypeName aktivieren?',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        
        Text(
          'Aktivieren Sie $_biometricTypeName für eine schnelle und sichere Anmeldung in Zukunft.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        
        // Benefits box
        Container(
          padding: const EdgeInsets.all(16),
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
                  Icon(Icons.security, color: Colors.blue.shade600, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Vorteile:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '• Passwort wird sicher gespeichert\n• Schnelle Anmeldung mit biometrischen Daten\n• Schutz für Admin-Bereiche',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        
        // Enable Face ID button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isAuthenticating ? null : _enableFaceIdAndSavePassword,
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
                        '$_biometricTypeName aktivieren & anmelden',
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
        
        // Skip button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: TextButton(
            onPressed: widget.onManualLogin,
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: const Text(
              'Nicht jetzt - manuell anmelden',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Show login Face ID overlay as bottom sheet
Future<void> showLoginFaceIdOverlay(
  BuildContext context, {
  required String email,
  required String password,
  required Function(bool success, String? message) onLoginComplete,
  required VoidCallback onManualLogin,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => LoginFaceIdOverlay(
      email: email,
      password: password,
      onLoginComplete: onLoginComplete,
      onManualLogin: onManualLogin,
    ),
  );
} 