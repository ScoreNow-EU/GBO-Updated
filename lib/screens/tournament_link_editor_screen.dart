import 'package:flutter/material.dart';
import '../models/tournament_link.dart';

class TournamentLinkEditorScreen extends StatefulWidget {
  final TournamentLink? link;
  final String linkType; // 'agb' or 'social'

  const TournamentLinkEditorScreen({
    Key? key,
    this.link,
    required this.linkType,
  }) : super(key: key);

  @override
  State<TournamentLinkEditorScreen> createState() =>
      _TournamentLinkEditorScreenState();
}

class _TournamentLinkEditorScreenState
    extends State<TournamentLinkEditorScreen> {
  late TextEditingController _labelController;
  late TextEditingController _urlController;
  late String _selectedIcon;
  late Color _selectedColor;
  late int _sortOrder;

  // Available icons for social media and AGBs
  final Map<String, IconData> availableIcons = {
    'facebook': Icons.facebook,
    'instagram': Icons.camera_alt,
    'twitter': Icons.share,
    'linkedin': Icons.business,
    'youtube': Icons.play_circle,
    'web': Icons.language,
    'download': Icons.download,
    'document': Icons.description,
    'link': Icons.link,
    'email': Icons.email,
    'phone': Icons.phone,
    'location': Icons.location_on,
  };

  // Available colors
  final List<Color> availableColors = [
    Colors.blue,
    Colors.blue[600]!,
    Colors.red,
    Colors.purple,
    Colors.pink,
    Colors.orange,
    Colors.green,
    Colors.teal,
    Colors.indigo,
    Colors.amber,
    Colors.cyan,
    Colors.lime,
  ];

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.link?.label ?? '');
    _urlController = TextEditingController(text: widget.link?.url ?? '');
    _selectedIcon = widget.link?.iconName ?? 'language';
    _selectedColor = Color(widget.link?.colorValue ?? Colors.blue.value);
    _sortOrder = widget.link?.sortOrder ?? 0;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _saveLink() {
    if (_labelController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte geben Sie einen Label ein')),
      );
      return;
    }

    if (_urlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte geben Sie eine URL ein')),
      );
      return;
    }

    final newLink = TournamentLink(
      id: widget.link?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      label: _labelController.text,
      url: _urlController.text,
      iconName: _selectedIcon,
      colorValue: _selectedColor.value,
      type: widget.linkType,
      sortOrder: _sortOrder,
    );

    Navigator.of(context).pop(newLink);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.link == null ? 'Link hinzufügen' : 'Link bearbeiten',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label Input
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Label (z.B. Facebook, Ausschreibung)',
                border: OutlineInputBorder(),
                hintText: 'Geben Sie einen aussagekräftigen Namen ein',
              ),
            ),
            const SizedBox(height: 16),

            // URL Input
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                border: OutlineInputBorder(),
                hintText: 'https://example.com',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 24),

            // Icon Selector
            Text(
              'Icon auswählen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableIcons.entries.map((entry) {
                final isSelected = entry.key == _selectedIcon;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIcon = entry.key;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                    ),
                    child: Icon(entry.value, size: 24),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Color Selector
            Text(
              'Farbe auswählen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: availableColors.map((color) {
                final isSelected = color.value == _selectedColor.value;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.grey,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Preview
            Text(
              'Vorschau',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _selectedColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    availableIcons[_selectedIcon],
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _labelController.text.isNotEmpty
                        ? _labelController.text
                        : 'Label',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Abbrechen'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saveLink,
                  child: const Text('Speichern'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
