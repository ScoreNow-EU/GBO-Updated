// ignore: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

import '../services/backup_service.dart';

class AdminBackupScreen extends StatefulWidget {
  const AdminBackupScreen({super.key});

  @override
  State<AdminBackupScreen> createState() => _AdminBackupScreenState();
}

class _AdminBackupScreenState extends State<AdminBackupScreen> {
  final BackupService _service = BackupService();

  bool _exporting = false;
  bool _importing = false;
  String? _statusMessage;

  Map<String, dynamic>? _pendingSnapshot;
  String? _pendingFileName;
  RestoreSummary? _pendingPreview;

  Future<void> _runExport() async {
    setState(() {
      _exporting = true;
      _statusMessage = 'Lese Firestore-Daten…';
    });
    try {
      final snapshot = await _service.exportAll(
        onProgress: (name, count) {
          if (!mounted) return;
          setState(() {
            _statusMessage = '$name: $count Dokumente';
          });
        },
      );
      final jsonText = _service.exportToJsonString(snapshot);
      final ts = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final filename = 'rhbl-backup-$ts.json';
      _downloadJson(jsonText, filename);
      if (!mounted) return;
      _showSuccess('Backup heruntergeladen: $filename');
      setState(() => _statusMessage = 'Export abgeschlossen.');
    } catch (e) {
      _showError('Export fehlgeschlagen: $e');
      setState(() => _statusMessage = null);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _downloadJson(String content, String filename) {
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _pickAndPreview() async {
    setState(() {
      _pendingSnapshot = null;
      _pendingPreview = null;
      _pendingFileName = null;
      _statusMessage = null;
    });

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) {
      _showError('Datei konnte nicht gelesen werden.');
      return;
    }

    setState(() {
      _importing = true;
      _statusMessage = 'Datei wird analysiert…';
    });
    try {
      final text = utf8.decode(file.bytes!);
      final snapshot = _service.parseSnapshot(text);
      final preview = await _service.restore(snapshot, dryRun: true);
      if (!mounted) return;
      setState(() {
        _pendingSnapshot = snapshot;
        _pendingFileName = file.name;
        _pendingPreview = preview;
        _statusMessage = null;
      });
    } catch (e) {
      _showError('Datei ungültig: $e');
      setState(() => _statusMessage = null);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _confirmAndRestore() async {
    final snapshot = _pendingSnapshot;
    final preview = _pendingPreview;
    if (snapshot == null || preview == null) return;

    final confirmed = await _showConfirmDialog(preview);
    if (confirmed != true) return;

    setState(() {
      _importing = true;
      _statusMessage = 'Backup wird wiederhergestellt…';
    });
    try {
      final summary = await _service.restore(
        snapshot,
        dryRun: false,
        onProgress: (name, written, total) {
          if (!mounted) return;
          setState(() {
            _statusMessage = '$name: $written / $total';
          });
        },
      );
      if (!mounted) return;
      _showSuccess(
        'Wiederhergestellt: ${summary.totalDocs} Dokumente in '
        '${summary.collections.length} Collections.',
      );
      setState(() {
        _statusMessage = 'Restore abgeschlossen.';
        _pendingSnapshot = null;
        _pendingPreview = null;
        _pendingFileName = null;
      });
    } catch (e) {
      _showError('Restore fehlgeschlagen: $e');
      setState(() => _statusMessage = null);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<bool?> _showConfirmDialog(RestoreSummary preview) {
    final controller = TextEditingController();
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final ok = controller.text.trim() == 'RESTORE';
            return AlertDialog(
              title: const Text('Backup wiederherstellen?'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Bestehende Dokumente mit identischer ID werden '
                      'überschrieben. Diese Aktion kann nicht rückgängig '
                      'gemacht werden.',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Datei: ${_pendingFileName ?? '-'}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text('Insgesamt: ${preview.totalDocs} Dokumente'),
                    const Divider(height: 20),
                    ...preview.collections.entries
                        .where((e) => e.value > 0)
                        .map((e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Expanded(child: Text(e.key)),
                                  Text('${e.value}'),
                                ],
                              ),
                            )),
                    const SizedBox(height: 16),
                    const Text(
                      'Tippe RESTORE um zu bestätigen:',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'RESTORE',
                      ),
                      onChanged: (_) => setLocal(() {}),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: ok ? () => Navigator.of(ctx).pop(true) : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: const Text('Wiederherstellen'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSuccess(String message) {
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.fillColored,
      title: const Text('Erfolg'),
      description: Text(message),
      autoCloseDuration: const Duration(seconds: 4),
    );
  }

  void _showError(String message) {
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.fillColored,
      title: const Text('Fehler'),
      description: Text(message),
      autoCloseDuration: const Duration(seconds: 5),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Backup & Wiederherstellung',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Vollständiger JSON-Export aller Datenkollektionen. '
              'Benutzerkonten, Tokens und Fehler-Logs sind aus '
              'Datenschutzgründen ausgeschlossen.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            _buildExportCard(),
            const SizedBox(height: 16),
            _buildImportCard(),
            if (_statusMessage != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.grey.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_statusMessage!)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExportCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.cloud_download, size: 28),
                SizedBox(width: 12),
                Text(
                  'Export',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Lädt eine JSON-Datei mit dem aktuellen Zustand aller '
              'Datenkollektionen herunter.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _exporting || _importing ? null : _runExport,
              icon: _exporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.download),
              label: Text(_exporting ? 'Exportiere…' : 'Backup herunterladen'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportCard() {
    final preview = _pendingPreview;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.cloud_upload, size: 28),
                SizedBox(width: 12),
                Text(
                  'Wiederherstellen',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Wählt eine zuvor heruntergeladene Backup-Datei aus und '
              'überschreibt damit Dokumente in Firestore.',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed:
                      _exporting || _importing ? null : _pickAndPreview,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Datei wählen…'),
                ),
                if (_pendingFileName != null) ...[
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      _pendingFileName!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                ],
              ],
            ),
            if (preview != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Vorschau: ${preview.totalDocs} Dokumente',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...preview.collections.entries
                  .where((e) => e.value > 0)
                  .map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(child: Text(e.key)),
                            Text('${e.value}'),
                          ],
                        ),
                      )),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed:
                    _exporting || _importing ? null : _confirmAndRestore,
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                icon: const Icon(Icons.restore),
                label: const Text('Wiederherstellen…'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
