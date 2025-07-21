import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:toastification/toastification.dart';
import '../utils/responsive_helper.dart';
import '../services/team_manager_service.dart';
import '../services/auth_service.dart';
import '../services/face_id_service.dart';
import '../models/user.dart' as app_user;
import '../widgets/login_face_id_overlay.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onNavigateBack;
  
  const LoginScreen({super.key, this.onNavigateBack});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final TeamManagerService _teamManagerService = TeamManagerService();
  final AuthService _authService = AuthService();
  final FaceIdService _faceIdService = FaceIdService();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoginMode = true; // Toggle between login and registration
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = ResponsiveHelper.isMobile(screenWidth);
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFffeb99), // Brighter yellow
              const Color(0xFFffd665), // Main yellow (#ffd665)
              const Color(0xFFffcc32), // Darker yellow
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Back button
              Positioned(
                top: 16,
                left: 16,
                child: IconButton(
                  onPressed: () {
                    if (widget.onNavigateBack != null) {
                      widget.onNavigateBack!();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 24,
                  ),
                  tooltip: 'Zurück',
                ),
              ),
              // Main content
              Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 24 : 32),
                  child: AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: isMobile ? double.infinity : 450,
                              maxHeight: screenHeight * 0.9,
                            ),
                            child: Card(
                              elevation: 24,
                              shadowColor: Colors.black.withOpacity(0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Column(
                                  children: [
                                    // Main content area
                                    Expanded(
                                      child: Container(
                                        padding: EdgeInsets.all(isMobile ? 32 : 40),
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                        ),
                                        child: SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _buildHeader(isMobile),
                                              const SizedBox(height: 40),
                                              _buildLoginForm(isMobile),
                                              const SizedBox(height: 32),
                                              _buildLoginButton(isMobile),
                                              const SizedBox(height: 24),
                                              _buildRememberMeAndForgotPassword(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    // German flag stripes
                                    _buildGermanFlagStripes(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Column(
      children: [
        // Logo
        Container(
          width: isMobile ? 120 : 140,
          height: isMobile ? 120 : 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black87.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.sports_handball,
                    size: 80,
                    color: Colors.white,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        // Title
        Text(
          _isLoginMode ? 'Anmelden' : 'Registrieren',
          style: TextStyle(
            fontSize: isMobile ? 24 : 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        

      ],
    );
  }

  Widget _buildLoginForm(bool isMobile) {
    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // First Name Field (only for registration)
            if (!_isLoginMode) ...[
              TextFormField(
                controller: _firstNameController,
                keyboardType: TextInputType.name,
                autofillHints: const [AutofillHints.givenName],
                decoration: InputDecoration(
                  labelText: 'Vorname',
                  hintText: 'Max',
                  prefixIcon: Icon(
                    Icons.person_outline,
                    color: Colors.black54,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black87, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bitte geben Sie Ihren Vornamen ein';
                  }
                  if (value.trim().length < 2) {
                    return 'Der Vorname muss mindestens 2 Zeichen lang sein';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              // Last Name Field (only for registration)
              TextFormField(
                controller: _lastNameController,
                keyboardType: TextInputType.name,
                autofillHints: const [AutofillHints.familyName],
                decoration: InputDecoration(
                  labelText: 'Nachname',
                  hintText: 'Mustermann',
                  prefixIcon: Icon(
                    Icons.person_outline,
                    color: Colors.black54,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black87, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bitte geben Sie Ihren Nachnamen ein';
                  }
                  if (value.trim().length < 2) {
                    return 'Der Nachname muss mindestens 2 Zeichen lang sein';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
            ],
            
            // Email Field
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                labelText: 'E-Mail-Adresse',
                hintText: 'max.mustermann@example.com',
                prefixIcon: Icon(
                  Icons.email_outlined,
                  color: Colors.black54,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black87, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Bitte geben Sie Ihre E-Mail-Adresse ein';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[a-zA-Z]{2,}$').hasMatch(value)) {
                  return 'Bitte geben Sie eine gültige E-Mail-Adresse ein';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            
            // Password Field
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              enableSuggestions: false,
              autocorrect: false,
              autofillHints: _isLoginMode 
                ? const [AutofillHints.password]
                : const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Passwort',
                hintText: _isLoginMode ? 'Ihr Passwort eingeben' : 'Mindestens 6 Zeichen',
                prefixIcon: Icon(
                  Icons.lock_outline,
                  color: Colors.black54,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black87, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Bitte geben Sie Ihr Passwort ein';
                }
                if (value.length < 6) {
                  return 'Das Passwort muss mindestens 6 Zeichen lang sein';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginButton(bool isMobile) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : (_isLoginMode ? _handleLoginWithOverlay : _handleRegister),
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFFffd665),
          foregroundColor: Colors.black,
          elevation: 4,
          shadowColor: Colors.black87.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                _isLoginMode ? 'Anmelden' : 'Registrieren',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  Widget _buildRememberMeAndForgotPassword() {
    return Column(
      children: [
        // Remember Me (only for login mode)
        if (_isLoginMode) ...[
          Row(
            children: [
              Checkbox(
                value: _rememberMe,
                onChanged: (value) {
                  setState(() {
                    _rememberMe = value ?? false;
                  });
                },
                activeColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Angemeldet bleiben',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        
        // Mode toggle and Forgot Password side by side
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Mode toggle
            Flexible(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _isLoginMode = !_isLoginMode;
                    // Clear form when switching modes
                    _formKey.currentState?.reset();
                    _emailController.clear();
                    _passwordController.clear();
                    _firstNameController.clear();
                    _lastNameController.clear();
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black87,
                  backgroundColor: Colors.grey.shade100,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _isLoginMode ? 'Registrieren' : 'Anmelden',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Forgot Password (only for login mode)
            if (_isLoginMode)
              Flexible(
                child: TextButton(
                  onPressed: _handleForgotPassword,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black87,
                    backgroundColor: Colors.grey.shade100,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Passwort vergessen?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _authService.registerWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );

      if (user != null) {
        String successMessage = 'Registrierung erfolgreich! Sie sind jetzt angemeldet.';
        
        // If user is not a referee, create/link team manager profile
        if (!user.roles.contains(app_user.UserRole.referee)) {
          final linkedToTeamManager = await _teamManagerService.linkUserToTeamManager(
            user.email,
            user.id,
          );
          if (linkedToTeamManager) {
            successMessage += ' Ihr Team Manager-Konto wurde verknüpft.';
          }
        } else {
          successMessage += ' Willkommen als Schiedsrichter!';
        }
        
        // Trigger iOS password save prompt
        TextInput.finishAutofillContext(shouldSave: true);
        
        if (mounted) {
          _showSuccessToast(successMessage);
          
          // Small delay to allow iOS save prompt to appear before navigation
          await Future.delayed(const Duration(milliseconds: 100));
          
          if (mounted) {
            // Navigate to home screen
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'Das Passwort ist zu schwach';
          break;
        case 'email-already-in-use':
          errorMessage = 'Ein Konto mit dieser E-Mail-Adresse existiert bereits';
          break;
        case 'invalid-email':
          errorMessage = 'Ungültige E-Mail-Adresse';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Registrierung ist derzeit nicht verfügbar';
          break;
        default:
          errorMessage = 'Registrierung fehlgeschlagen: ${e.message}';
      }
      if (mounted) {
        _showErrorToast(errorMessage);
      }
    } catch (e) {
      if (mounted) {
        _showErrorToast('Ein unerwarteter Fehler ist aufgetreten');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleLoginWithOverlay() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if device supports Face ID
    final isDeviceSupported = await _faceIdService.isDeviceSupported();
    
    if (isDeviceSupported) {
      // Check if Face ID is already enabled for this email
      final isFaceIdEnabled = await _faceIdService.isFaceIdEnabledForEmail(_emailController.text.trim());
      
      if (isFaceIdEnabled) {
        // Face ID is already set up, authenticate directly
        setState(() {
          _isLoading = true;
        });
        
        try {
          final authenticated = await _faceIdService.authenticateForLogin();
          
          if (authenticated) {
            // Face ID successful, proceed with login
            final user = await _authService.signInWithEmailAndPassword(
              _emailController.text.trim(),
              _passwordController.text.trim(),
            );

            if (user != null) {
              // Trigger iOS password save prompt
              TextInput.finishAutofillContext(shouldSave: true);
              
              if (mounted) {
                _showSuccessToast('Erfolgreich mit Face ID angemeldet');
                
                // Navigate to home screen
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              }
            }
          } else {
            // Face ID failed, fall back to manual login
            if (mounted) {
              _showErrorToast('Face ID-Authentifizierung fehlgeschlagen');
            }
          }
        } catch (e) {
          if (mounted) {
            _showErrorToast('Fehler bei der Face ID-Authentifizierung');
          }
        } finally {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      } else {
        // Face ID not set up yet, show overlay to allow setup
        await showLoginFaceIdOverlay(
          context,
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          onLoginComplete: (success, message) {
            if (mounted) {
              Navigator.of(context).pop(); // Close the overlay
              
              if (success) {
                // Trigger iOS password save prompt
                TextInput.finishAutofillContext(shouldSave: true);
                
                if (message != null) {
                  _showSuccessToast(message);
                }
                
                // Navigate to home screen
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              } else {
                if (message != null) {
                  _showErrorToast(message);
                }
              }
            }
          },
          onManualLogin: () {
            Navigator.of(context).pop(); // Close the overlay
            _handleLogin(); // Proceed with manual login
          },
        );
      }
    } else {
      // Device doesn't support Face ID, proceed with manual login
      await _handleLogin();
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _authService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (user != null) {
        // Trigger iOS password save prompt
        TextInput.finishAutofillContext(shouldSave: true);
        
        if (mounted) {
          _showSuccessToast('Erfolgreich angemeldet');
          
          // Small delay to allow iOS save prompt to appear before navigation
          await Future.delayed(const Duration(milliseconds: 100));
          
          if (mounted) {
            // Navigate to home screen
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'Kein Benutzer mit dieser E-Mail-Adresse gefunden';
          break;
        case 'wrong-password':
          errorMessage = 'Falsches Passwort';
          break;
        case 'invalid-email':
          errorMessage = 'Ungültige E-Mail-Adresse';
          break;
        case 'user-disabled':
          errorMessage = 'Dieser Benutzer wurde deaktiviert';
          break;
        case 'too-many-requests':
          errorMessage = 'Zu viele Anmeldeversuche. Bitte versuchen Sie es später erneut';
          break;
        default:
          errorMessage = 'Anmeldung fehlgeschlagen: ${e.message}';
      }
      if (mounted) {
        _showErrorToast(errorMessage);
      }
    } catch (e) {
      if (mounted) {
        _showErrorToast('Ein unerwarteter Fehler ist aufgetreten');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      _showErrorToast('Bitte geben Sie Ihre E-Mail-Adresse ein');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      _showSuccessToast('Passwort-Reset-E-Mail wurde gesendet');
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'Kein Benutzer mit dieser E-Mail-Adresse gefunden';
          break;
        case 'invalid-email':
          errorMessage = 'Ungültige E-Mail-Adresse';
          break;
        default:
          errorMessage = 'Fehler beim Senden der Reset-E-Mail: ${e.message}';
      }
      _showErrorToast(errorMessage);
    }
  }

  void _showSuccessToast(String message) {
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

  void _showErrorToast(String message) {
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

  Widget _buildGermanFlagStripes() {
    return SizedBox(
      height: 6,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Black stripe - 30%
          Flexible(
            flex: 30,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black,
              ),
            ),
          ),
          // White gap - 5%
          Flexible(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
            ),
          ),
          // Red stripe - 30%
          Flexible(
            flex: 30,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFDD0000), // German flag red
              ),
            ),
          ),
          // White gap - 5%
          Flexible(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
            ),
          ),
          // Gold/Yellow stripe - 30%
          Flexible(
            flex: 30,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFffd665), // Your brand yellow
              ),
            ),
          ),
        ],
      ),
    );
  }
} 