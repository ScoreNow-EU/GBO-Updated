import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/story.dart';

// Native <video> element for web; stub for other platforms
import 'story_player_web.dart'
    if (dart.library.io) 'story_player_stub.dart' as platform_view;

/// Full-screen overlay viewer for Stories.
///
/// Usage:
/// ```dart
/// showDialog(
///   context: context,
///   builder: (_) => StoriesViewer(stories: stories, initialIndex: 0),
/// );
/// ```
class StoriesViewer extends StatefulWidget {
  final List<Story> stories;
  final int initialIndex;

  const StoriesViewer({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });

  @override
  State<StoriesViewer> createState() => _StoriesViewerState();
}

class _StoriesViewerState extends State<StoriesViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.stories.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _prev() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _next() {
    if (_currentIndex < widget.stories.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Story pages
          PageView.builder(
            controller: _pageController,
            itemCount: widget.stories.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) {
              return _StoryPage(
                story: widget.stories[index],
                onEnded: _next,
              );
            },
          ),

          // Tap zones: left = prev, right = next
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _prev,
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _next,
                  ),
                ),
              ],
            ),
          ),

          // Top bar: dots + close button
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    // Progress dots
                    Expanded(
                      child: Row(
                        children: [
                          for (int i = 0; i < widget.stories.length; i++)
                            Expanded(
                              child: Container(
                                height: 3,
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 2),
                                decoration: BoxDecoration(
                                  color: i <= _currentIndex
                                      ? Colors.white
                                      : Colors.white38,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Close button
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.close, color: Colors.white,
                          size: 28),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom title overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 32),
              child: SafeArea(
                top: false,
                child: Text(
                  widget.stories[_currentIndex].title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(color: Colors.black54, blurRadius: 8)
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Single story page ─────────────────────────────────────────────────────────

class _StoryPage extends StatefulWidget {
  final Story story;
  final VoidCallback onEnded;

  const _StoryPage({required this.story, required this.onEnded});

  @override
  State<_StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<_StoryPage> {
  @override
  Widget build(BuildContext context) {
    if (widget.story.videoUrl.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return platform_view.buildVideoPlayer(
      widget.story.videoUrl,
      onEnded: widget.onEnded,
    );
  }
}
