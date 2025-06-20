import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../models/delegate.dart';
import '../services/delegate_service.dart';

class BulkAddDelegatesScreen extends StatefulWidget {
  const BulkAddDelegatesScreen({super.key});

  @override
  State<BulkAddDelegatesScreen> createState() => _BulkAddDelegatesScreenState();
}

class _BulkAddDelegatesScreenState extends State<BulkAddDelegatesScreen> {
  final DelegateService _delegateService = DelegateService();
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false;
  String _selectedLicenseType = Delegate.licenseTypes.first;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delegierte Bulk Hinzufügen'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Format',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Geben Sie die Delegierten-Daten in folgendem Format ein (eine Person pro Zeile):',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: const Text(
                        'Vorname Nachname, email@example.com\n\nBeispiel:\nHans Müller, hans.mueller@example.com\nPetra Schmidt, petra.schmidt@example.com',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Lizenz-Typ für alle:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 16),
                        DropdownButton<String>(
                          value: _selectedLicenseType,
                          items: Delegate.licenseTypes.map((String licenseType) {
                            return DropdownMenuItem<String>(
                              value: licenseType,
                              child: Text(licenseType),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedLicenseType = newValue;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Delegierten-Daten',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          maxLines: null,
                          expands: true,
                          decoration: const InputDecoration(
                            hintText: 'Hans Müller, hans.mueller@example.com\nPetra Schmidt, petra.schmidt@example.com\n...',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          textAlignVertical: TextAlignVertical.top,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Abbrechen'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _processBulkAdd,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Delegierte hinzufügen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processBulkAdd() async {
    if (_textController.text.trim().isEmpty) {
      _showErrorToast('Bitte geben Sie Delegierten-Daten ein');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final lines = _textController.text.trim().split('\n');
      final delegates = <Delegate>[];
      final errors = <String>[];

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final parts = line.split(',');
        if (parts.length != 2) {
          errors.add('Zeile ${i + 1}: Ungültiges Format');
          continue;
        }

        final name = parts[0].trim();
        final email = parts[1].trim();

        if (name.isEmpty || email.isEmpty) {
          errors.add('Zeile ${i + 1}: Name oder E-Mail fehlt');
          continue;
        }

        final nameParts = name.split(' ');
        if (nameParts.length < 2) {
          errors.add('Zeile ${i + 1}: Vor- und Nachname erforderlich');
          continue;
        }

        final firstName = nameParts.first;
        final lastName = nameParts.skip(1).join(' ');

        // Email validation
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[a-zA-Z]{2,}$').hasMatch(email)) {
          errors.add('Zeile ${i + 1}: Ungültige E-Mail-Adresse');
          continue;
        }

        delegates.add(Delegate(
          id: '',
          firstName: firstName,
          lastName: lastName,
          email: email,
          licenseType: _selectedLicenseType,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }

      if (errors.isNotEmpty) {
        _showErrorDialog('Fehler beim Verarbeiten', errors);
        setState(() {
          _isLoading = false;
        });
        return;
      }

      if (delegates.isEmpty) {
        _showErrorToast('Keine gültigen Delegierten-Daten gefunden');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Add delegates
      int successCount = 0;
      final addErrors = <String>[];

      for (int i = 0; i < delegates.length; i++) {
        try {
          await _delegateService.addDelegate(delegates[i]);
          successCount++;
        } catch (e) {
          addErrors.add('${delegates[i].fullName}: $e');
        }
      }

      setState(() {
        _isLoading = false;
      });

      if (addErrors.isNotEmpty) {
        _showErrorDialog('Einige Delegierte konnten nicht hinzugefügt werden', addErrors);
      }

      if (successCount > 0) {
        _showSuccessToast('$successCount Delegierte erfolgreich hinzugefügt');
        _textController.clear();
        
        if (addErrors.isEmpty) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorToast('Unerwarteter Fehler: $e');
    }
  }

  void _showErrorDialog(String title, List<String> errors) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Folgende Fehler sind aufgetreten:'),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: errors.map((error) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '• $error',
                          style: const TextStyle(color: Colors.red),
                        ),
                      )).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessToast(String message) {
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.flatColored,
      title: Text(message),
      autoCloseDuration: const Duration(seconds: 3),
      alignment: Alignment.topRight,
    );
  }

  void _showErrorToast(String message) {
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.flatColored,
      title: Text(message),
      autoCloseDuration: const Duration(seconds: 5),
      alignment: Alignment.topRight,
    );
  }
} 