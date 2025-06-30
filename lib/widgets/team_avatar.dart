import 'package:flutter/material.dart';
import 'dart:math';

class TeamAvatar extends StatelessWidget {
  final String teamName;
  final String? logoUrl;
  final double size;
  final String? division;

  const TeamAvatar({
    super.key,
    required this.teamName,
    this.logoUrl,
    this.size = 40,
    this.division,
  });

  @override
  Widget build(BuildContext context) {
    if (logoUrl != null && logoUrl!.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            logoUrl!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _generateAvatar();
            },
          ),
        ),
      );
    } else {
      return _generateAvatar();
    }
  }

  Widget _generateAvatar() {
    String initials = _getInitials(teamName);
    Color backgroundColor = _generateColor(teamName);
    Color textColor = _getContrastColor(backgroundColor);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: textColor,
            fontSize: size * 0.35,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    List<String> words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return 'T';
    
    if (words.length == 1) {
      return words[0].isNotEmpty ? words[0][0].toUpperCase() : 'T';
    } else {
      String firstInitial = words[0].isNotEmpty ? words[0][0].toUpperCase() : '';
      String secondInitial = words[1].isNotEmpty ? words[1][0].toUpperCase() : '';
      return firstInitial + secondInitial;
    }
  }

  Color _generateColor(String name) {
    // Generate a consistent color based on the team name
    int hash = name.hashCode;
    Random random = Random(hash);
    
    List<Color> colors = [
      const Color(0xFFffd665),
      Colors.green.shade400,
      Colors.orange.shade400,
      Colors.purple.shade400,
      Colors.pink.shade400,
      Colors.teal.shade400,
      Colors.indigo.shade400,
      Colors.red.shade400,
      Colors.cyan.shade400,
      Colors.amber.shade400,
      Colors.lime.shade400,
      Colors.deepOrange.shade400,
      Colors.lightBlue.shade400,
      Colors.lightGreen.shade400,
      Colors.deepPurple.shade400,
    ];
    
    return colors[random.nextInt(colors.length)];
  }

  Color _getContrastColor(Color backgroundColor) {
    // Calculate luminance to determine if we should use dark or light text
    double luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }
} 