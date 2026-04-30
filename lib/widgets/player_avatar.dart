import 'package:flutter/material.dart';

/// Circular avatar that shows the player's photo if available, otherwise
/// generates a colored initials placeholder. No network call when [photoUrl]
/// is null/empty.
class PlayerAvatar extends StatelessWidget {
  final String? photoUrl;
  final String firstName;
  final String lastName;
  final double radius;

  const PlayerAvatar({
    super.key,
    required this.photoUrl,
    required this.firstName,
    required this.lastName,
    this.radius = 32,
  });

  String get _initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    final s = '$f$l'.toUpperCase();
    return s.isEmpty ? '?' : s;
  }

  Color get _bgColor {
    final seed = ('$firstName$lastName').hashCode;
    final palette = [
      Colors.blue,
      Colors.indigo,
      Colors.purple,
      Colors.teal,
      Colors.green,
      Colors.orange,
      Colors.brown,
      Colors.deepPurple,
      Colors.cyan,
    ];
    return palette[seed.abs() % palette.length].shade400;
  }

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(photoUrl!),
        backgroundColor: Colors.grey.shade200,
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: _bgColor,
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
