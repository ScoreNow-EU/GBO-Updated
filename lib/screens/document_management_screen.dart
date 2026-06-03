import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:toastification/toastification.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/document.dart';
import '../services/document_service.dart';
import '../services/auth_service.dart';

class DocumentManagementScreen extends StatefulWidget {
  const DocumentManagementScreen({super.key});

  @override
  State<DocumentManagementScreen> createState() => _DocumentManagementScreenState();
}

class _DocumentManagementScreenState extends State<DocumentManagementScreen> {
  final DocumentService _documentService = DocumentService();
  final AuthService _authService = AuthService();
  String _selectedCategory = 'all';
  bool _isUploading = false;

  final List<Map<String, dynamic>> _categories = [
    {'key': 'all', 'label': 'Alle', 'icon': Icons.folder, 'color': Colors.grey},
    {'key': 'spielordnung', 'label': 'Spielordnung', 'icon': Icons.gavel, 'color': Colors.blue},
    {'key': 'regularien', 'label': 'Regularien', 'icon': Icons.rule, 'color': Colors.orange},
    {'key': 'satzung', 'label': 'Satzung', 'icon': Icons.description, 'color': Colors.green},
    {'key': 'sonstiges', 'label': 'Sonstiges', 'icon': Icons.folder_open, 'color': Colors.purple},
  ];

  Future<void> _uploadDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xlsx', 'xls'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    // Show upload dialog
    String? selectedCategory;
    String? documentName;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        selectedCategory = _selectedCategory == 'all' ? 'sonstiges' : _selectedCategory;
        documentName = file.name.split('.').first;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Dokument hochladen'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: documentName,
                  decoration: const InputDecoration(
                    labelText: 'Dokumentname',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => documentName = value,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Kategorie',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories
                      .where((c) => c['key'] != 'all')
                      .map((c) => DropdownMenuItem(
                            value: c['key'] as String,
                            child: Text(c['label'] as String),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedCategory = value);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.attach_file, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${file.name} (${_formatFileSize(file.size)})',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Abbrechen'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Hochladen'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true || documentName == null || selectedCategory == null) return;

    setState(() => _isUploading = true);

    try {
      final currentUser = _authService.currentFirebaseUser;
      await _documentService.uploadDocument(
        name: documentName!,
        category: selectedCategory!,
        fileBytes: file.bytes!,
        fileName: file.name,
        mimeType: file.extension == 'pdf' ? 'application/pdf' : 'application/octet-stream',
        uploadedByUserId: currentUser?.uid ?? 'unknown',
      );

      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          title: const Text('Erfolg'),
          description: const Text('Dokument wurde hochgeladen.'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          title: const Text('Fehler'),
          description: Text('Upload fehlgeschlagen: $e'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _deleteDocument(Document doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dokument löschen'),
        content: Text('Möchten Sie "${doc.name}" wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _documentService.deleteDocument(doc);
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          title: const Text('Gelöscht'),
          description: Text('"${doc.name}" wurde gelöscht.'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          title: const Text('Fehler'),
          description: Text('Löschen fehlgeschlagen: $e'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    }
  }

  void _openDocument(Document doc) async {
    final uri = Uri.parse(doc.storageUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.folder_special, color: Colors.deepPurple.shade700, size: 32),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dokumentenverwaltung',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      Text(
                        'Spielordnung, Regularien, Satzung und weitere Dokumente',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (_isUploading)
                  const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: CircularProgressIndicator(),
                  ),
                ElevatedButton.icon(
                  onPressed: _isUploading ? null : _uploadDocument,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Hochladen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Category Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat['key'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(cat['label'] as String),
                      avatar: Icon(cat['icon'] as IconData, size: 18),
                      selectedColor: (cat['color'] as Color).withOpacity(0.2),
                      onSelected: (_) {
                        setState(() => _selectedCategory = cat['key'] as String);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Document List
          Expanded(
            child: StreamBuilder<List<Document>>(
              stream: _selectedCategory == 'all'
                  ? _documentService.getDocuments()
                  : _documentService.getDocumentsByCategory(_selectedCategory),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final documents = snapshot.data ?? [];

                if (documents.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_off, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'Keine Dokumente vorhanden',
                          style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Laden Sie ein Dokument hoch, um zu beginnen.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: documents.length,
                  itemBuilder: (context, index) {
                    final doc = documents[index];
                    return _buildDocumentCard(doc);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(Document doc) {
    final catData = _categories.firstWhere(
      (c) => c['key'] == doc.category,
      orElse: () => _categories.last,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (catData['color'] as Color).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            doc.mimeType.contains('pdf') ? Icons.picture_as_pdf : Icons.insert_drive_file,
            color: catData['color'] as Color,
          ),
        ),
        title: Text(doc.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${Document.categoryDisplayName(doc.category)} · v${doc.version} · ${doc.fileSizeFormatted} · ${_formatDate(doc.uploadedAt)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Öffnen',
              onPressed: () => _openDocument(doc),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Löschen',
              onPressed: () => _deleteDocument(doc),
            ),
          ],
        ),
        onTap: () => _openDocument(doc),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
