import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:toastification/toastification.dart';

import 'dart:math';
import '../utils/responsive_helper.dart';
import '../utils/app_colors.dart';
import '../services/team_manager_service.dart';
import '../services/auth_service.dart';
import '../services/face_id_service.dart';
import '../services/recent_accounts_service.dart';
import '../models/user.dart' as app_user;
import '../widgets/login_face_id_overlay.dart';
import '../widgets/recent_accounts_widget.dart';
import 'home_screen.dart';

class Sparkle {
  double x;
  double y;
  double size;
  double opacity;
  double delay;
  
  Sparkle({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.delay,
  });
}

class SparkleOverlay extends StatefulWidget {
  const SparkleOverlay({super.key});

  @override
  State<SparkleOverlay> createState() => _SparkleOverlayState();
}

class _SparkleOverlayState extends State<SparkleOverlay>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  List<Sparkle> _sparkles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    
    _generateSparkles();
  }

  void _generateSparkles() {
    final random = Random();
    _sparkles = List.generate(100, (index) {
      return Sparkle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * 3 + 1,
        opacity: random.nextDouble() * 0.8 + 0.2,
        delay: random.nextDouble() * 2,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: SparklePainter(_sparkles, _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class SparklePainter extends CustomPainter {
  final List<Sparkle> sparkles;
  final double animationValue;

  SparklePainter(this.sparkles, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (final sparkle in sparkles) {
      final progress = ((animationValue + sparkle.delay) % 1.0);
      final opacity = (sin(progress * pi * 2) * 0.5 + 0.5) * sparkle.opacity;
      
      paint.color = Colors.white.withOpacity(opacity);
      
      final x = sparkle.x * size.width;
      final y = sparkle.y * size.height;
      
      // Draw 4-pointed star
      final path = Path();
      final centerX = x;
      final centerY = y;
      final outerRadius = sparkle.size;
      final innerRadius = sparkle.size * 0.4;
      
      // Top point
      path.moveTo(centerX, centerY - outerRadius);
      path.lineTo(centerX - innerRadius * 0.3, centerY - innerRadius * 0.3);
      // Left point
      path.lineTo(centerX - outerRadius, centerY);
      path.lineTo(centerX - innerRadius * 0.3, centerY + innerRadius * 0.3);
      // Bottom point
      path.lineTo(centerX, centerY + outerRadius);
      path.lineTo(centerX + innerRadius * 0.3, centerY + innerRadius * 0.3);
      // Right point
      path.lineTo(centerX + outerRadius, centerY);
      path.lineTo(centerX + innerRadius * 0.3, centerY - innerRadius * 0.3);
      path.close();
      
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

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
  final RecentAccountsService _recentAccountsService = RecentAccountsService();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoginMode = true; // Toggle between login and registration
  bool _isOneTimeCodeMode = false; // Toggle for one-time code login
  bool _isSigningInFromRecentAccount = false; // Track if login is from recent account selection
  
  final _oneTimeCodeController = TextEditingController();
  
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
    _oneTimeCodeController.dispose();
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
          gradient: AppColors.primaryGradient,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Fullscreen grid pattern
              Positioned.fill(
                child: Opacity(
                  opacity: 0.8,
                  child: Image.asset(
                    'assets/grid.png',
                    fit: BoxFit.cover,
                    repeat: ImageRepeat.repeat,
                  ),
                ),
              ),
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
              _buildMainContent(screenWidth, screenHeight, isMobile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(double screenWidth, double screenHeight, bool isMobile) {
    final isWideScreen = screenWidth >= ResponsiveHelper.desktopBreakpoint; // 1200px or wider
    
    return Stack(
      children: [
        // Main login card - always centered
        Center(
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isMobile ? double.infinity : 450,
                        maxHeight: screenHeight * 0.9,
                      ),
                      child: _buildLoginCard(isMobile),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        
        // Recent accounts card - only on wide screens, positioned on left
        if (isWideScreen)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(-0.3, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: _slideController,
                        curve: Curves.easeOutCubic,
                      )),
                      child: SizedBox(
                        width: 320,
                        child: _buildRecentAccountsCard(screenHeight),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLoginCard(bool isMobile) {
    return Card(
      elevation: 24,
      shadowColor: Colors.black.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          // Main content area
          Padding(
            padding: EdgeInsets.only(
              left: isMobile ? 24 : 32,
              right: isMobile ? 24 : 32,
              top: isMobile ? 24 : 32,
              bottom: (isMobile ? 24 : 32) + 8, // Extra padding for flag stripes
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(isMobile),
                  SizedBox(height: isMobile ? 24 : 32),
                  _buildLoginForm(isMobile),
                  SizedBox(height: isMobile ? 20 : 24),
                  _buildLoginButton(isMobile),
                  SizedBox(height: isMobile ? 12 : 16),
                  _buildRememberMeAndForgotPassword(),
                ],
              ),
            ),
          ),
          // German flag stripes at the bottom edge
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildGermanFlagStripes(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAccountsCard(double screenHeight) {
    return FutureBuilder<int>(
      future: _getRecentAccountsCount(),
      builder: (context, snapshot) {
        final accountCount = snapshot.data ?? 0;
        
        // Calculate dynamic height based on content
        double dynamicHeight;
        if (accountCount == 0) {
          // Empty state: header + icon + text + padding
          dynamicHeight = 300; // Slightly more compact empty state
        } else {
          // Calculate based on account count with extra buffer
          // Header (18px) + spacing (16px) + accounts + padding + buffer
          const headerHeight = 18.0;
          const spacing = 16.0;
          const accountCardHeight = 88.0; // Increased from 80 to account for actual size
          const accountSpacing = 12.0; // Space between account cards
          const totalPadding = 64.0; // 32px on each side
          const buffer = 20.0; // Extra buffer to prevent overflow
          
          dynamicHeight = totalPadding + headerHeight + spacing + 
                         (accountCount * accountCardHeight) + 
                         ((accountCount - 1) * accountSpacing) + buffer;
        }
        
        // Ensure minimum height and respect maximum
        dynamicHeight = dynamicHeight.clamp(200.0, screenHeight * 0.85);
        
        return Card(
          elevation: 24,
          shadowColor: Colors.black.withOpacity(0.3),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(24),
              bottomRight: Radius.circular(24),
              topLeft: Radius.zero,
              bottomLeft: Radius.zero,
            ),
          ),
          margin: EdgeInsets.zero,
          child: Container(
            height: dynamicHeight,
            width: 320,
            padding: const EdgeInsets.all(32),
            child: RecentAccountsWidget(
              onAccountSelected: _onRecentAccountSelected,
              onAccountDeleted: () {
                // Trigger rebuild to recalculate size
                setState(() {});
              },
            ),
          ),
        );
      },
    );
  }

  Future<int> _getRecentAccountsCount() async {
    try {
      final accounts = await _recentAccountsService.getRecentAccounts();
      return accounts.length;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _onRecentAccountSelected(String email) async {
    // Fill the email field with the selected account
    _emailController.text = email;
    
    // Try to get stored password and auto-login
    final storedPassword = await _recentAccountsService.getStoredPassword(email);
    if (storedPassword != null && storedPassword.isNotEmpty) {
      // Set flag to indicate this is a recent account login
      _isSigningInFromRecentAccount = true;
      
      // Auto-fill password and attempt login
      _passwordController.text = storedPassword;
      await _handleLogin();
      
      // Reset flag after login attempt
      _isSigningInFromRecentAccount = false;
    } else {
      // No stored password, focus on password field for user to enter password
      FocusScope.of(context).requestFocus(FocusNode());
    }
  }

  Widget _buildHeader(bool isMobile) {
    return Column(
      children: [
        // Add padding at the top to prevent shadow cutoff
        SizedBox(height: 20),
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
        autovalidateMode: AutovalidateMode.disabled,
        child: Column(
          children: [
            // One-Time Code Field (only for one-time code mode)
            if (_isOneTimeCodeMode) ...[
              TextFormField(
                controller: _oneTimeCodeController,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.characters,
                maxLength: 8,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.oneTimeCode],
                decoration: InputDecoration(
                  labelText: 'Einmaliger Code',
                  hintText: 'ABC12345',
                  prefixIcon: Icon(
                    Icons.pin,
                    color: Colors.black54,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  counterText: '',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bitte geben Sie den einmaligen Code ein';
                  }
                  if (value.trim().length != 8) {
                    return 'Der Code muss genau 8 Zeichen lang sein';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              // Password field for one-time code login
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _handleOneTimeCodeLogin(),
                decoration: InputDecoration(
                  labelText: 'Passwort',
                  hintText: 'Ihr Passwort',
                  prefixIcon: const Icon(
                    Icons.lock,
                    color: Colors.black54,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      color: Colors.black54,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Bitte geben Sie Ihr Passwort ein';
                  }
                  if (value.length < 6) {
                    return 'Das Passwort muss mindestens 6 Zeichen lang sein';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
            ],
            
            // First Name Field (only for registration)
            if (!_isLoginMode && !_isOneTimeCodeMode) ...[
              TextFormField(
                controller: _firstNameController,
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autocorrect: false,
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
                    borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
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
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autocorrect: false,
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
                    borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
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
            
            // Email Field (not shown in one-time code mode)
            if (!_isOneTimeCodeMode)
              TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: _isLoginMode 
                ? const [AutofillHints.email] 
                : const [AutofillHints.email],
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
                  borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
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
            if (!_isOneTimeCodeMode) ...[
              const SizedBox(height: 20),
              
              // Password Field (not shown in one-time code mode)
              TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              enableSuggestions: false,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              autofillHints: _isLoginMode 
                ? const [AutofillHints.password]
                : const [AutofillHints.newPassword],
              onFieldSubmitted: (_) => _isLoginMode ? _handleLoginWithOverlay() : _handleRegister(),
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
                  borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
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
          ],
        ),
      ),
    );
  }

  Widget _buildLoginButton(bool isMobile) {
    return Column(
      children: [
        // Main login button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _getLoginHandler(),
            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
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
                    _getLoginButtonText(),
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
            ),
        ),
        

             ],
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
                activeColor: AppColors.primaryColor,
                checkColor: Colors.black87,
                fillColor: MaterialStateProperty.resolveWith<Color>(
                  (Set<MaterialState> states) {
                    if (states.contains(MaterialState.selected)) {
                      return AppColors.primaryColor;
                    }
                    return AppColors.primaryColor;
                  },
                ),
                side: BorderSide(
                  color: AppColors.primaryColor,
                  width: 1.5,
                ),
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
        if (_isLoginMode && !_isOneTimeCodeMode)
          Row(
            children: [
              // Mode toggle button
              Expanded(
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
                      _oneTimeCodeController.clear();
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
              // Forgot Password button
              Expanded(
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
              const SizedBox(width: 8),
              // One-time code button
              Expanded(
                child: TextButton.icon(
                  onPressed: _isLoading ? null : () {
                    setState(() {
                      _isOneTimeCodeMode = true;
                      _formKey.currentState?.reset();
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
                  icon: const Icon(Icons.pin, size: 16),
                  label: const Text(
                    'Einmalcode',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          )
        else
          // Back button for one-time code mode
          TextButton(
            onPressed: () {
              setState(() {
                if (_isOneTimeCodeMode) {
                  _isOneTimeCodeMode = false;
                } else {
                  _isLoginMode = !_isLoginMode;
                }
                _formKey.currentState?.reset();
                _emailController.clear();
                _passwordController.clear();
                _firstNameController.clear();
                _lastNameController.clear();
                _oneTimeCodeController.clear();
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
              _isOneTimeCodeMode ? 'Zurück' : (_isLoginMode ? 'Registrieren' : 'Anmelden'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
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
        
        // Save to recent accounts
        await _recentAccountsService.addRecentAccount(user, password: _passwordController.text.trim());
        
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
    final isBiometricAvailable = await _faceIdService.isBiometricAvailable();
    final availableBiometrics = await _faceIdService.getAvailableBiometrics();
    
    debugPrint('[LoginScreen] Device supported: $isDeviceSupported, Biometric available: $isBiometricAvailable, Available biometrics count: ${availableBiometrics.length}');
    
    if (isDeviceSupported && isBiometricAvailable && availableBiometrics.isNotEmpty) {
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
              // Save to recent accounts
              await _recentAccountsService.addRecentAccount(user, password: _passwordController.text.trim());
              
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
          onLoginComplete: (success, message) async {
            if (mounted) {
              Navigator.of(context).pop(); // Close the overlay
              
              if (success) {
                // Get user to save to recent accounts
                final user = await _authService.getCurrentUser();
                if (user != null) {
                  await _recentAccountsService.addRecentAccount(user, password: _passwordController.text.trim());
                }
                
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
        // Only save to recent accounts if this is NOT a recent account login
        if (!_isSigningInFromRecentAccount) {
          await _recentAccountsService.addRecentAccount(user, password: _passwordController.text.trim());
        }
        
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

  // Handle one-time code login
  Future<void> _handleOneTimeCodeLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _authService.signInWithOneTimeCode(
        _oneTimeCodeController.text.trim().toUpperCase(),
      );

      if (user != null) {
        // Save to recent accounts
        await _recentAccountsService.addRecentAccount(user);
        
        if (mounted) {
          _showSuccessToast('Erfolgreich mit Einmalcode angemeldet');
          
          // Navigate to home screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Anmeldung fehlgeschlagen';
        if (e.toString().contains('Code')) {
          errorMessage = 'Ungültiger oder bereits verwendeter Code';
        } else if (e.toString().contains('user-not-found')) {
          errorMessage = 'Kein Account für diesen Code gefunden';
        }
        _showErrorToast(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Get the appropriate login handler based on current mode
  VoidCallback _getLoginHandler() {
    if (_isOneTimeCodeMode) {
      return _handleOneTimeCodeLogin;
    } else if (_isLoginMode) {
      return _handleLoginWithOverlay;
    } else {
      return _handleRegister;
    }
  }

  // Get the appropriate button text based on current mode
  String _getLoginButtonText() {
    if (_isOneTimeCodeMode) {
      return 'Mit Code anmelden';
    } else if (_isLoginMode) {
      return 'Anmelden';
    } else {
      return 'Registrieren';
    }
  }

  Widget _buildGermanFlagStripes() {
    return Container(
      height: 8,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Black stripe - 30%
            Expanded(
              flex: 30,
              child: Container(color: Colors.black),
            ),
            // White gap - 5%
            Expanded(
              flex: 5,
              child: Container(color: Colors.white),
            ),
            // Red stripe - 30%
            Expanded(
              flex: 30,
              child: Container(color: const Color(0xFFDD0000)), // German flag red
            ),
            // White gap - 5%
            Expanded(
              flex: 5,
              child: Container(color: Colors.white),
            ),
            // Gold/Yellow stripe - 30%
            Expanded(
              flex: 30,
              child: Container(color: const Color(0xFFffd763)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleQRCodeScan() async {
    try {
      // Show QR code scanner dialog
      final result = await showDialog<Map<String, String>>(
        context: context,
        builder: (context) => _QRCodeScannerDialog(),
      );

      if (result != null && result.containsKey('email') && result.containsKey('password')) {
        // Auto-fill login fields with scanned data
        _emailController.text = result['email']!;
        _passwordController.text = result['password']!;
        
        // Show success toast
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          title: const Text('QR-Code erfolgreich gescannt'),
          description: const Text('Login-Daten wurden automatisch eingefügt'),
          autoCloseDuration: const Duration(seconds: 3),
        );

        // Automatically attempt login
        await _handleLogin();
      }
    } catch (e) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        title: const Text('QR-Code Scan fehlgeschlagen'),
        description: Text('Fehler: ${e.toString()}'),
        autoCloseDuration: const Duration(seconds: 4),
      );
    }
  }
}

// QR Code Scanner Dialog
class _QRCodeScannerDialog extends StatefulWidget {
  @override
  State<_QRCodeScannerDialog> createState() => _QRCodeScannerDialogState();
}

class _QRCodeScannerDialogState extends State<_QRCodeScannerDialog> {
  bool _hasPermission = false;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    // TODO: Check camera permission
    setState(() {
      _hasPermission = true; // Placeholder
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 400,
        height: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColorLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner,
                    color: AppColors.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QR-Code scannen',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Scannen Sie den QR-Code vom Account',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _hasPermission
                    ? _buildScannerView()
                    : _buildPermissionView(),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Abbrechen'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isScanning ? null : _simulateQRScan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.black87,
                    ),
                    child: _isScanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Test-Scan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerView() {
    return Stack(
      children: [
        // Camera preview placeholder
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.qr_code_scanner,
                size: 64,
                color: Colors.white.withOpacity(0.7),
              ),
              const SizedBox(height: 16),
              Text(
                'Kamera wird gestartet...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Halten Sie den QR-Code in den Rahmen',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        
        // Scanning overlay
        Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.primaryColor,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _isScanning
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Scanne...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.camera_alt_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Kamera-Berechtigung erforderlich',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Um QR-Codes zu scannen, benötigt die App Zugriff auf Ihre Kamera',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _checkPermission,
            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.black87,
            ),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Berechtigung erteilen'),
          ),
        ],
      ),
    );
  }

  Future<void> _simulateQRScan() async {
    setState(() {
      _isScanning = true;
    });

    // Simulate scanning delay
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isScanning = false;
      });

      // Return simulated QR data
      Navigator.of(context).pop({
        'email': 'tablet-example-court1@rollstuhlhandball.de',
        'password': 'ABC123XY',
      });
    }
  }
} 




