import 'package:flutter/material.dart';

class GBOLoader extends StatefulWidget {
  final double size;
  final bool showBackground;
  
  const GBOLoader({
    super.key,
    this.size = 100,
    this.showBackground = true,
  });

  @override
  State<GBOLoader> createState() => _GBOLoaderState();
}

class _GBOLoaderState extends State<GBOLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showBackground) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFffd665).withOpacity(0.1),
              const Color(0xFFffd665).withOpacity(0.3),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSpinningLogo(),
              const SizedBox(height: 24),
              _buildGBOText(),
              const SizedBox(height: 8),
              _buildGermanBeachOpenText(),
              const SizedBox(height: 32),
              _buildGermanFlagStripe(),
            ],
          ),
        ),
      );
    } else {
      return _buildSpinningLogo();
    }
  }

  Widget _buildSpinningLogo() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2.0 * 3.14159,
          child: Image.asset(
            'logo_ball.png',
            width: widget.size,
            height: widget.size,
          ),
        );
      },
    );
  }

  Widget _buildGBOText() {
    return const Text(
      'GBO',
      style: TextStyle(
        fontFamily: 'CasanovaScotia',
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildGermanBeachOpenText() {
    return const Text(
      'GERMAN BEACH OPEN',
      style: TextStyle(
        fontFamily: 'MyriadPro',
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildGermanFlagStripe() {
    return Container(
      height: 6,
      width: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: [0.0, 0.3, 0.3001, 0.35, 0.3501, 0.65, 0.6501, 0.7, 0.7001, 1.0],
          colors: [
            Color(0xFF000000), // Black start
            Color(0xFF000000), // Black end at 30%
            Colors.transparent, // Transparent start at 30.01%
            Colors.transparent, // Transparent end at 35%
            Color(0xFFc10003), // Red start at 35.01%
            Color(0xFFc10003), // Red end at 65%
            Colors.transparent, // Transparent start at 65.01%
            Colors.transparent, // Transparent end at 70%
            Color(0xFFffd765), // Yellow start at 70.01%
            Color(0xFFffd765), // Yellow end at 100%
          ],
        ),
      ),
    );
  }
} 