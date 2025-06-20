import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:toastification/toastification.dart';
import '../utils/responsive_helper.dart';
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
              const Color(0xFF1976D2), // Primary blue
              const Color(0xFF1565C0), // Darker blue
              const Color(0xFF0D47A1), // Deep blue
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
                              child: Container(
                                padding: EdgeInsets.all(isMobile ? 32 : 40),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
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
                color: const Color(0xFF1976D2).withOpacity(0.2),
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
                    color: const Color(0xFF1976D2),
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
            color: const Color(0xFF1976D2),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        
        // Subtitle
        Text(
          'Turnier Management System',
          style: TextStyle(
            fontSize: isMobile ? 14 : 16,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(bool isMobile) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // First Name Field (only for registration)
          if (!_isLoginMode) ...[
            TextFormField(
              controller: _firstNameController,
              keyboardType: TextInputType.name,
              decoration: InputDecoration(
                labelText: 'Vorname',
                hintText: 'Max',
                prefixIcon: Icon(
                  Icons.person_outline,
                  color: const Color(0xFF1976D2),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
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
              decoration: InputDecoration(
                labelText: 'Nachname',
                hintText: 'Mustermann',
                prefixIcon: Icon(
                  Icons.person_outline,
                  color: const Color(0xFF1976D2),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
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
            decoration: InputDecoration(
              labelText: 'E-Mail-Adresse',
              hintText: 'max.mustermann@example.com',
              prefixIcon: Icon(
                Icons.email_outlined,
                color: const Color(0xFF1976D2),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
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
            decoration: InputDecoration(
              labelText: 'Passwort',
              hintText: _isLoginMode ? 'Ihr Passwort eingeben' : 'Mindestens 6 Zeichen',
              prefixIcon: Icon(
                Icons.lock_outline,
                color: const Color(0xFF1976D2),
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
                borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
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
    );
  }

  Widget _buildLoginButton(bool isMobile) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : (_isLoginMode ? _handleLogin : _handleRegister),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1976D2),
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: const Color(0xFF1976D2).withOpacity(0.4),
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
                activeColor: const Color(0xFF1976D2),
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
            TextButton(
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
                foregroundColor: const Color(0xFF1976D2),
                backgroundColor: Colors.grey.shade100,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              ),
            ),
            
            // Forgot Password (only for login mode)
            if (_isLoginMode)
              TextButton(
                onPressed: _handleForgotPassword,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1976D2),
                  backgroundColor: Colors.grey.shade100,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

    setState(() {
      _isLoading = true;
    });

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (credential.user != null) {
        // Update the user's display name with first and last name
        await credential.user!.updateDisplayName(
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
        );
        
        _showSuccessToast('Registrierung erfolgreich! Sie sind jetzt angemeldet.');
        
        // Navigate to home screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
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
      _showErrorToast(errorMessage);
    } catch (e) {
      _showErrorToast('Ein unerwarteter Fehler ist aufgetreten');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (credential.user != null) {
        _showSuccessToast('Erfolgreich angemeldet');
        
        // Navigate to home screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
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
      _showErrorToast(errorMessage);
    } catch (e) {
      _showErrorToast('Ein unerwarteter Fehler ist aufgetreten');
    } finally {
      setState(() {
        _isLoading = false;
      });
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
} 