import 'package:flutter/material.dart';

/// Stub for non-web platforms.
Widget buildVideoPlayer(String videoUrl, {VoidCallback? onEnded}) {
  return const Center(
    child: Text(
      'Video nur im Browser verfügbar.',
      style: TextStyle(color: Colors.white),
    ),
  );
}
