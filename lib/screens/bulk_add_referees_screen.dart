import 'package:flutter/material.dart';
import '../models/referee.dart';
import '../services/referee_service.dart';

class BulkAddRefereesScreen extends StatefulWidget {
  const BulkAddRefereesScreen({super.key});

  @override
  State<BulkAddRefereesScreen> createState() => _BulkAddRefereesScreenState();
}

class _BulkAddRefereesScreenState extends State<BulkAddRefereesScreen> {
  final RefereeService _refereeService = RefereeService();
  final _formKey = GlobalKey<FormState>();

  String _selectedLicenseType = Referee.licenseTypes.first;
  bool _isLoading = false;

  // List to hold referee data
  List<RefereeFormData> _referees = [
    RefereeFormData(), // Start with one empty referee
    RefereeFormData(), // Always have one extra for adding new referees
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schiedsrichter Bulk Hinzufügen'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Container(
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Text(
                    'Schiedsrichter hinzufügen',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_referees.where((r) => r.firstName.text.isNotEmpty).length} Schiedsrichter werden erstellt',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Geben Sie für jeden Schiedsrichter individuelle Daten ein. Alle Schiedsrichter werden mit der gleichen Lizenz erstellt.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),

              // License Type Selection (shared)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sports_hockey, color: Colors.blue),
                    const SizedBox(width: 12),
                    const Text(
                      'Lizenz für alle Schiedsrichter:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedLicenseType,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: Referee.licenseTypes.map((String license) {
                          return DropdownMenuItem<String>(
                            value: license,
                            child: Text(license),
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
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Referees List
              Expanded(
                child: ListView.builder(
                  itemCount: _referees.length,
                  itemBuilder: (context, index) {
                    return _buildRefereeCard(index);
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Abbrechen'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _previewReferees,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                        : const Text('Schiedsrichter Vorschau'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRefereeCard(int index) {
    final referee = _referees[index];
    final isLast = index == _referees.length - 1;
    final isEmpty = referee.firstName.text.isEmpty && referee.lastName.text.isEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEmpty && !isLast ? Colors.grey.shade50 : Colors.white,
        border: Border.all(
          color: isEmpty && !isLast ? Colors.grey.shade300 : Colors.grey.shade400,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                isLast ? 'Schiedsrichter ${index + 1} hinzufügen' : 'Schiedsrichter ${index + 1}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isEmpty && !isLast ? Colors.grey : Colors.black87,
                ),
              ),
              const Spacer(),
              if (!isLast && !isEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _removeReferee(index),
                  tooltip: 'Schiedsrichter entfernen',
                ),
            ],
          ),
          const SizedBox(height: 12),

          // All fields in one row
          Row(
            children: [
              // First Name
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: referee.firstName,
                  decoration: const InputDecoration(
                    labelText: 'Vorname *',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (value) => _onRefereeNameChanged(index, value),
                  validator: isLast ? null : (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vorname eingeben';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Last Name
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: referee.lastName,
                  decoration: const InputDecoration(
                    labelText: 'Nachname *',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (value) => _onRefereeNameChanged(index, value),
                  validator: isLast ? null : (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nachname eingeben';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Email
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: referee.email,
                  decoration: const InputDecoration(
                    labelText: 'E-Mail *',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: isLast ? null : (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'E-Mail eingeben';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Gültige E-Mail eingeben';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onRefereeNameChanged(int index, String value) {
    // If this is the last (empty) referee and user starts typing, add a new empty referee
    if (index == _referees.length - 1 && value.isNotEmpty) {
      setState(() {
        _referees.add(RefereeFormData());
      });
    }
    
    setState(() {
      // Update the counter in the header
    });
  }

  void _removeReferee(int index) {
    if (_referees.length > 2 && index < _referees.length) { // Keep at least one referee + one empty
      setState(() {
        // Safely dispose the referee data before removal
        try {
          _referees[index].dispose();
        } catch (e) {
          // Ignore disposal errors
        }
        _referees.removeAt(index);
      });
    }
  }

  void _previewReferees() {
    if (!_formKey.currentState!.validate()) return;

    // Get only referees with names (exclude the last empty one)
    List<RefereeFormData> refereesToPreview = _referees
        .where((referee) => referee.firstName.text.trim().isNotEmpty && 
                           referee.lastName.text.trim().isNotEmpty && 
                           !referee._disposed)
        .toList();

    if (refereesToPreview.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte geben Sie mindestens einen Schiedsrichter ein'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check for duplicate emails
    List<String> emails = refereesToPreview.map((r) => r.email.text.trim().toLowerCase()).toList();
    Set<String> uniqueEmails = emails.toSet();
    if (emails.length != uniqueEmails.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Duplicate E-Mail-Adressen gefunden. Bitte verwenden Sie eindeutige E-Mail-Adressen.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Convert to Referee objects for preview
    List<Referee> previewReferees = [];
    final now = DateTime.now();
    
    for (RefereeFormData refereeData in refereesToPreview) {
      Referee referee = Referee(
        id: '',
        firstName: refereeData.firstName.text.trim(),
        lastName: refereeData.lastName.text.trim(),
        email: refereeData.email.text.trim(),
        licenseType: _selectedLicenseType,
        createdAt: now,
        updatedAt: now,
      );

      previewReferees.add(referee);
    }

    // Navigate to confirmation screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RefereeConfirmationScreen(
          referees: previewReferees,
          onConfirm: _bulkAddReferees,
        ),
      ),
    );
  }

  Future<void> _bulkAddReferees(List<Referee> referees) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Add each referee
      for (Referee referee in referees) {
        // Generate unique ID for each referee
        final refereeWithId = referee.copyWith(
          id: DateTime.now().millisecondsSinceEpoch.toString() + '_' + referees.indexOf(referee).toString(),
        );
        await _refereeService.addReferee(refereeWithId);
      }

      Navigator.of(context).pop(); // Close confirmation screen
      Navigator.of(context).pop(); // Close bulk add screen
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${referees.length} Schiedsrichter erfolgreich hinzugefügt'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // Dispose all referee form data safely
    for (int i = 0; i < _referees.length; i++) {
      try {
        if (!_referees[i]._disposed) {
          _referees[i].dispose();
        }
      } catch (e) {
        // Ignore disposal errors for individual referees
        print('Error disposing referee $i: $e');
      }
    }
    super.dispose();
  }
}

class RefereeFormData {
  final TextEditingController firstName = TextEditingController();
  final TextEditingController lastName = TextEditingController();
  final TextEditingController email = TextEditingController();
  bool _disposed = false;

  void dispose() {
    if (!_disposed) {
      try {
        firstName.dispose();
        lastName.dispose();
        email.dispose();
        _disposed = true;
      } catch (e) {
        // Ignore disposal errors
        _disposed = true;
      }
    }
  }
}

class RefereeConfirmationScreen extends StatelessWidget {
  final List<Referee> referees;
  final Future<void> Function(List<Referee>) onConfirm;

  const RefereeConfirmationScreen({
    super.key,
    required this.referees,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schiedsrichter Bestätigen'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Text(
                  'Schiedsrichter Vorschau',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Text(
                  '${referees.length} Schiedsrichter werden hinzugefügt',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Überprüfen Sie die Schiedsrichter-Details bevor Sie sie hinzufügen.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),

            // Referees Preview Table
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
                    columns: const [
                      DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('E-Mail', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Lizenz', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: referees.map((referee) {
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              referee.fullName,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          DataCell(Text(referee.email)),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getLicenseColor(referee.licenseType).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                referee.licenseType,
                                style: TextStyle(
                                  color: _getLicenseColor(referee.licenseType),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Zurück'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => onConfirm(referees),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text('${referees.length} Schiedsrichter Hinzufügen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getLicenseColor(String licenseType) {
    switch (licenseType) {
      case 'Basis-Lizenz':
        return Colors.green;
      case 'Perspektivkader':
        return Colors.blue;
      case 'DHB Stamm+Anschlusskader':
        return Colors.orange;
      case 'DHB Elitekader':
        return Colors.red;
      case 'EBT Referee':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
} 