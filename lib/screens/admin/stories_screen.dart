import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/story.dart';
import '../../services/story_service.dart';
import '../../utils/app_colors.dart';

/// Admin screen to manage Stories (upload, reorder, delete).
///
/// Stories are short vertical video clips hosted on YouTube (unlisted)
/// and shown publicly as Instagram-style bubbles in the tournament overview.
class StoriesAdminScreen extends StatefulWidget {
  const StoriesAdminScreen({super.key});

  @override
  State<StoriesAdminScreen> createState() => _StoriesAdminScreenState();
}

class _StoriesAdminScreenState extends State<StoriesAdminScreen> {
  final StoryService _service = StoryService();
  bool _uploading = false;
  double _uploadProgress = 0;
  String _uploadStatusText = '';

  Future<void> _startUpload() async {
    // Step 1: Pick a video file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showError('Datei konnte nicht gelesen werden.');
      return;
    }

    // Step 2: Show upload dialog
    String title = '';
    DateTime? expiresAt;
    String? groupTitle;

    // Collect existing group names for autocomplete
    final existingGroups = await _service.getGroupTitles();

    if (!mounted) return;
    final shouldUpload = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UploadConfigDialog(
        filename: file.name,
        existingGroups: existingGroups,
        onConfirm: (t, e, g) {
          title = t;
          expiresAt = e;
          groupTitle = g;
        },
      ),
    );
    if (shouldUpload != true || title.trim().isEmpty) return;

    // Step 3: Upload
    setState(() {
      _uploading = true;
      _uploadProgress = 0;
      _uploadStatusText = 'Wird hochgeladen…';
    });

    try {
      await _service.uploadStory(
        bytes: Uint8List.fromList(bytes),
        filename: file.name,
        title: title.trim(),
        expiresAt: expiresAt,
        groupTitle: groupTitle,
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _uploadProgress = p;
            if (p < 0.05) {
              _uploadStatusText = 'Lade hoch…';
            } else if (p < 0.95) {
              _uploadStatusText = 'Lade hoch… ${(p * 100).toStringAsFixed(0)} %';
            } else {
              _uploadStatusText = 'Wird abgeschlossen…';
            }
          });
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story hochgeladen!')),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Upload fehlgeschlagen: $e');
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadProgress = 0;
          _uploadStatusText = '';
        });
      }
    }
  }

  Future<void> _deleteStory(Story story) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Story löschen?'),
        content: Text(
            '"${story.title}" wird aus der App entfernt\n'
            'und das Video aus Firebase Storage gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _service.deleteStory(story);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story gelöscht.')),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Fehler: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Stories',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _uploading ? null : _startUpload,
                icon: const Icon(Icons.upload),
                label: const Text('Story hochladen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Kurze Hochkant-Videos die oben im öffentlichen '
            'Turnierübersichts-Screen als Story-Bubbles angezeigt werden. '
            'Videos werden in Firebase Storage gespeichert.',
            style: TextStyle(color: Colors.grey),
          ),
          if (_uploading) ...[
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_uploadStatusText),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: _uploadProgress),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          StreamBuilder<List<Story>>(
            stream: _service.getAllStories(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final stories = snap.data ?? [];
              if (stories.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: Text(
                      'Noch keine Stories.\nLade eine Story hoch, um zu beginnen.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }
              return _StoriesGrid(
                stories: stories,
                onMoveUp: (s) => _service.moveUp(s, stories),
                onMoveDown: (s) => _service.moveDown(s, stories),
                onDelete: _deleteStory,
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Grid ─────────────────────────────────────────────────────────────────────

class _StoriesGrid extends StatelessWidget {
  final List<Story> stories;
  final Future<void> Function(Story) onMoveUp;
  final Future<void> Function(Story) onMoveDown;
  final Future<void> Function(Story) onDelete;

  const _StoriesGrid({
    required this.stories,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        for (int i = 0; i < stories.length; i++)
          _StoryCard(
            story: stories[i],
            isFirst: i == 0,
            isLast: i == stories.length - 1,
            onMoveUp: () => onMoveUp(stories[i]),
            onMoveDown: () => onMoveDown(stories[i]),
            onDelete: () => onDelete(stories[i]),
          ),
      ],
    );
  }
}

class _StoryCard extends StatelessWidget {
  final Story story;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDelete;

  const _StoryCard({
    required this.story,
    required this.isFirst,
    required this.isLast,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
  });

  Color get _statusColor {
    if (story.status == 'uploading') return Colors.orange;
    if (story.isExpired) return Colors.grey;
    return Colors.green;
  }

  String get _statusLabel {
    if (story.status == 'uploading') return 'Uploading…';
    if (story.isExpired) return 'Abgelaufen';
    return 'Aktiv';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Stack(
              children: [
                Container(
                  width: 200,
                  height: 112,
                  color: Colors.grey.shade800,
                  child: story.videoUrl.isNotEmpty
                      ? const Center(
                          child: Icon(Icons.play_circle_fill,
                              color: Colors.white54, size: 40))
                      : const Center(child: CircularProgressIndicator()),
                ),
                // Status badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor.withAlpha(220),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _statusLabel,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Text(
                story.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (story.expiresAt != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: Text(
                  'Läuft ab: ${DateFormat('dd.MM.yy HH:mm').format(story.expiresAt!.toLocal())}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Nach oben',
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  onPressed: isFirst ? null : onMoveUp,
                ),
                IconButton(
                  tooltip: 'Nach unten',
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  onPressed: isLast ? null : onMoveDown,
                ),
                IconButton(
                  tooltip: 'Löschen',
                  icon: const Icon(Icons.delete_outline, size: 18,
                      color: Colors.red),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Upload Config Dialog ──────────────────────────────────────────────────────

class _UploadConfigDialog extends StatefulWidget {
  final String filename;
  final List<String> existingGroups;
  final void Function(String title, DateTime? expiresAt, String? groupTitle) onConfirm;

  const _UploadConfigDialog({
    required this.filename,
    required this.existingGroups,
    required this.onConfirm,
  });

  @override
  State<_UploadConfigDialog> createState() => _UploadConfigDialogState();
}

class _UploadConfigDialogState extends State<_UploadConfigDialog> {
  final _titleController = TextEditingController();
  final _groupController = TextEditingController();
  String _expiry = 'forever';

  @override
  void initState() {
    super.initState();
    final name = widget.filename;
    final dot = name.lastIndexOf('.');
    _titleController.text = dot > 0 ? name.substring(0, dot) : name;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _groupController.dispose();
    super.dispose();
  }

  DateTime? get _expiresAt {
    switch (_expiry) {
      case '24h':
        return DateTime.now().add(const Duration(hours: 24));
      case '7d':
        return DateTime.now().add(const Duration(days: 7));
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Story hochladen'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Datei: ${widget.filename}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Titel *',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Autocomplete<String>(
              optionsBuilder: (v) => widget.existingGroups
                  .where((g) => g.toLowerCase()
                      .contains(v.text.toLowerCase()))
                  .toList(),
              onSelected: (g) => _groupController.text = g,
              fieldViewBuilder:
                  (ctx, ctrl, focusNode, onSubmit) {
                // Sync external controller
                ctrl.text = _groupController.text;
                ctrl.addListener(
                    () => _groupController.text = ctrl.text);
                return TextField(
                  controller: ctrl,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Gruppe (optional)',
                    hintText: 'z. B. "Spieltag 3"',
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            const Text('Ablaufzeit'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '24h', label: Text('24 Std')),
                ButtonSegment(value: '7d', label: Text('7 Tage')),
                ButtonSegment(value: 'forever', label: Text('Dauerhaft')),
              ],
              selected: {_expiry},
              onSelectionChanged: (s) =>
                  setState(() => _expiry = s.first),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_titleController.text.trim().isEmpty) return;
            widget.onConfirm(
              _titleController.text.trim(),
              _expiresAt,
              _groupController.text.trim().isEmpty
                  ? null
                  : _groupController.text.trim(),
            );
            Navigator.of(context).pop(true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Hochladen'),
        ),
      ],
    );
  }
}
