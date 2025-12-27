import 'package:flutter/material.dart';
import 'dart:io';
import '../utils/app_colors.dart';

/// Wallpaper/Splash screen for both iPhone and iPad
class WallpaperScreen extends StatelessWidget {
  final VoidCallback? onTap;
  final bool showContent;

  const WallpaperScreen({
    super.key,
    this.onTap,
    this.showContent = true,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide > 600;
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: isTablet
            ? _buildIpadWallpaper(context)
            : _buildIphoneWallpaper(context),
      ),
    );
  }

  /// iPhone wallpaper design
  Widget _buildIphoneWallpaper(BuildContext context) {
    return Stack(
      children: [
        // Background gradient with accent shapes
        Positioned.fill(
          child: CustomPaint(
            painter: _IphoneBackgroundPainter(),
          ),
        ),
        
        // Main content
        Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo/Brand area
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: _buildLogoContainer(),
                  ),
                  const SizedBox(height: 40),
                  
                  // Title
                  Text(
                    'German Beach Open',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Subtitle
                  Text(
                    'Tournament Management',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white70,
                      letterSpacing: 0.5,
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Bottom decorative elements
                  if (showContent)
                    Column(
                      children: [
                        Container(
                          height: 3,
                          width: 60,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Tap to continue',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        
        // Tap area
        if (onTap != null)
          Positioned.fill(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.translucent,
            ),
          ),
      ],
    );
  }

  /// iPad wallpaper design (landscape optimized)
  Widget _buildIpadWallpaper(BuildContext context) {
    return Stack(
      children: [
        // Background with custom shapes
        Positioned.fill(
          child: CustomPaint(
            painter: _IpadBackgroundPainter(),
          ),
        ),
        
        // Two-column layout for iPad
        Row(
          children: [
            // Left side - Decorative
            Expanded(
              flex: 1,
              child: CustomPaint(
                painter: _IpadLeftDecoratorPainter(),
              ),
            ),
            
            // Right side - Content
            Expanded(
              flex: 1,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: _buildLogoContainer(),
                      ),
                      const SizedBox(height: 50),
                      
                      // Title
                      Text(
                        'German Beach Open',
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Subtitle
                      Text(
                        'Professional Tournament Management System',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white70,
                          letterSpacing: 0.5,
                        ),
                      ),
                      
                      const SizedBox(height: 50),
                      
                      // Features list
                      if (showContent)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFeatureItem('📋 Tournament Planning', context),
                            const SizedBox(height: 16),
                            _buildFeatureItem('👥 Team Management', context),
                            const SizedBox(height: 16),
                            _buildFeatureItem('🏆 Live Scoring', context),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        
        // Tap area
        if (onTap != null)
          Positioned.fill(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.translucent,
            ),
          ),
      ],
    );
  }

  /// Logo container with shadow effect
  Widget _buildLogoContainer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.sports_volleyball,
          size: 60,
          color: Colors.white,
        ),
      ),
    );
  }

  /// Feature item for iPad
  Widget _buildFeatureItem(String text, BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          text,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

/// Custom painter for iPhone background
class _IphoneBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // Decorative circles
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.2),
      150,
      paint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.7),
      100,
      paint,
    );

    // Decorative lines
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 2;

    for (double i = 0; i < size.height; i += 80) {
      canvas.drawLine(
        Offset(0, i),
        Offset(size.width, i + 40),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for iPad background
class _IpadBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    // Large decorative circles
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.3),
      250,
      paint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.8),
      200,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for iPad left side decorations
class _IpadLeftDecoratorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Vertical gradient lines
    final paint = Paint()
      ..strokeWidth = 1
      ..color = Colors.white.withOpacity(0.15);

    for (double i = 0; i < size.width; i += 20) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i, size.height),
        paint,
      );
    }

    // Accent shapes
    final accentPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.2),
      150,
      accentPaint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.3, size.height * 0.7),
      100,
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
