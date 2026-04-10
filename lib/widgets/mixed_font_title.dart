import 'package:flutter/material.dart';

class MixedFontTitle extends StatelessWidget {
  final double fontSize;
  final Color color;

  const MixedFontTitle({
    super.key,
    this.fontSize = 16,
    this.color = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      'ROLLSTUHLHANDBALL BUNDESLIGA',
      style: TextStyle(
        fontFamily: 'MyriadPro',
        fontFamilyFallback: const ['Roboto'],
        fontSize: fontSize + 4,
        fontWeight: FontWeight.bold,
        color: color,
        letterSpacing: 0.5,
      ),
    );
  }
} 