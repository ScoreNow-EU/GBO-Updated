import 'package:flutter/material.dart';

import '../models/story.dart';
import '../services/story_service.dart';
import 'stories_viewer.dart';

// A visual group: either a named group of stories or a single ungrouped story.
class _StoryGroup {
  final String label;       // bubble label (group title or story title)
  final List<Story> stories;
  bool get isGroup => stories.length > 1;

  const _StoryGroup({required this.label, required this.stories});
}

/// Horizontal strip of story bubbles. Stories sharing a [groupTitle] are
/// collapsed into a single bubble (like Instagram's grouped stories).
class StoriesStrip extends StatelessWidget {
  const StoriesStrip({super.key});

  /// Build ordered list of groups from active stories.
  static List<_StoryGroup> _buildGroups(List<Story> stories) {
    final groups = <_StoryGroup>[];
    final seen = <String>{};

    for (final story in stories) {
      final g = story.groupTitle;
      if (g != null && g.isNotEmpty) {
        if (!seen.contains(g)) {
          seen.add(g);
          final groupStories =
              stories.where((s) => s.groupTitle == g).toList();
          groups.add(_StoryGroup(label: g, stories: groupStories));
        }
      } else {
        groups.add(_StoryGroup(label: story.title, stories: [story]));
      }
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Story>>(
      stream: StoryService().getActiveStories(),
      builder: (context, snap) {
        final stories = snap.data ?? [];
        if (stories.isEmpty) return const SizedBox.shrink();

        final groups = _buildGroups(stories);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Stories',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
              ),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: groups.length,
                itemBuilder: (context, i) => _GroupBubble(
                  group: groups[i],
                  onTap: () => _openViewer(context, groups[i].stories),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  void _openViewer(BuildContext context, List<Story> stories) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => StoriesViewer(
          stories: stories,
          initialIndex: 0,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }
}

// ── Group bubble ──────────────────────────────────────────────────────────────

class _GroupBubble extends StatelessWidget {
  final _StoryGroup group;
  final VoidCallback onTap;

  const _GroupBubble({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Outer ring — double ring for groups
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF4CAF50), Color(0xFF2196F3),
                          Color(0xFF9C27B0),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(60),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(2.5),
                    child: ClipOval(
                      child: Container(
                        color: Colors.grey.shade800,
                        child: Icon(
                          group.isGroup
                              ? Icons.collections
                              : Icons.play_circle_fill,
                          color: Colors.white70,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                  // Story count badge for groups
                  if (group.isGroup)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${group.stories.length}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                group.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
