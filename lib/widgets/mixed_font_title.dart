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
      'GERMAN BEACH OPEN',
      style: TextStyle(
        fontFamily: 'MyriadPro',
        fontSize: fontSize + 4,
        fontWeight: FontWeight.bold,
        color: color,
        letterSpacing: 0.5,
      ),
    );
  }
} 