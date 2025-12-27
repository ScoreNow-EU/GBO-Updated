import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../utils/app_colors.dart';

/// Professional App Store submission splash screen
/// Full-screen, no navigation, uses all app assets
class AppStoreSplashScreen extends StatefulWidget {
  final Duration duration;
  final VoidCallback onComplete;
  final bool autoNavigate;

  const AppStoreSplashScreen({
    super.key,
    this.duration = const Duration(seconds: 4),
    required this.onComplete,
    this.autoNavigate = false,
  });

  @override
  State<AppStoreSplashScreen> createState() => _AppStoreSplashScreenState();
}

class _AppStoreSplashScreenState extends State<AppStoreSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeInAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();

    // Auto-navigate after duration
    if (widget.autoNavigate) {
      Future.delayed(widget.duration, () {
        if (mounted) {
          widget.onComplete();
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide > 600;
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
          ),
          child: Stack(
            children: [
              // Background decorative elements with assets
              Positioned.fill(
                child: _buildBackgroundAssets(context),
            ),

            // Main content - full screen layout
            FadeTransition(
              opacity: _fadeInAnimation,
              child: Column(
                children: [
                  // Top section - App icon
                  Expanded(
                    flex: 3,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Center(
                          child: SizedBox(
                            width: 300,
                            height: 300,
                            child: Image.asset(
                              'assets/icon.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Middle section - GBO text
                  Expanded(
                    flex: 1,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'German Beach Open',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .displaySmall
                                    ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 10,
                                      color: Colors.black.withOpacity(0.3),
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Tournament Management System',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                  letterSpacing: 0.5,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 5,
                                      color: Colors.black.withOpacity(0.2),
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Bottom section - GBO logo
                  Expanded(
                    flex: 3,
                    child: FadeTransition(
                      opacity: Tween<double>(begin: 0, end: 1)
                          .animate(
                            CurvedAnimation(
                              parent: _animationController,
                              curve: const Interval(0.3, 1, curve: Curves.easeIn),
                            ),
                          ),
                      child: Center(
                        child: SizedBox(
                          width: 120,
                          height: 120,
                          child: Image.asset(
                            'logo.png',
                            fit: BoxFit.contain,
                          ),
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
        ),
    );
  }

  /// Build background with decorative asset elements
  Widget _buildBackgroundAssets(BuildContext context) {
    return Stack(
      children: [
        // Custom paint background
        CustomPaint(
          painter: _SplashBackgroundPainter(),
        ),

        // Top-right palm decoration
        Positioned(
          top: -40,
          right: -30,
          child: Opacity(
            opacity: 0.15,
            child: Image.asset(
              'assets/palm_right.png',
              width: 250,
              height: 250,
              fit: BoxFit.cover,
            ),
          ),
        ),

        // Bottom-left palm decoration
        Positioned(
          bottom: -100,
          left: -100,
          child: Opacity(
            opacity: 0.12,
            child: Transform.flip(
              flipX: true,
              child: Image.asset(
                'assets/palm_left.png',
                width: 350,
                height: 350,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),

        // Sparkles - top right
        Positioned(
          top: 80,
          right: 30,
          child: Opacity(
            opacity: 0.3,
            child: Image.asset(
              'assets/sparkles.png',
              width: 60,
              height: 60,
              fit: BoxFit.cover,
            ),
          ),
        ),

        // Sparkles - bottom left
        Positioned(
          bottom: 150,
          left: 20,
          child: Opacity(
            opacity: 0.25,
            child: Image.asset(
              'assets/sparkles.png',
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter for background shapes
class _SplashBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Subtle circular gradient patterns
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    // Large background circles
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.3),
      200,
      paint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.7),
      250,
      paint,
    );

    // Subtle lines
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;

    for (double i = 0; i < size.height; i += 100) {
      canvas.drawLine(
        Offset(0, i),
        Offset(size.width, i + 50),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
