import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:toastification/toastification.dart';
import '../models/referee.dart';
import '../services/referee_service.dart';
import '../utils/responsive_helper.dart';
import 'bulk_add_referees_screen.dart';

class RefereeManagementScreen extends StatefulWidget {
  const RefereeManagementScreen({super.key});

  @override
  State<RefereeManagementScreen> createState() => _RefereeManagementScreenState();
}

class _RefereeManagementScreenState extends State<RefereeManagementScreen> {
  final RefereeService _refereeService = RefereeService();
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _searchController = TextEditingController();

  String _selectedLicenseType = Referee.licenseTypes.first;
  String _filterLicenseType = 'Alle';
  Referee? _editingReferee;
  String _searchTerm = '';

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _searchController.dispose();
    _refereeService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRefereeDialog(),
                    backgroundColor: Colors.black87,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show bulk add button only on non-iOS platforms
            if (defaultTargetPlatform != TargetPlatform.iOS) ...[
              Row(
                children: [
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const BulkAddRefereesScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.group_add),
                    label: const Text('Bulk Hinzufügen'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Compact Search, Filter and Statistics Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Search and Filter Row
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Suche nach Name, E-Mail oder Lizenz...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              isDense: true,
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchTerm = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: DropdownButtonFormField<String>(
                            value: _filterLicenseType,
                            decoration: InputDecoration(
                              labelText: 'Lizenz filtern',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              isDense: true,
                            ),
                            isExpanded: true,
                            items: ['Alle', ...Referee.licenseTypes].map((String type) {
                              return DropdownMenuItem<String>(
                                value: type,
                                child: Text(
                                  type, 
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _filterLicenseType = newValue;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Compact Statistics Row (hidden on iOS)
                    if (defaultTargetPlatform != TargetPlatform.iOS)
                      _buildCompactStatisticsSection(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Referee List
            Expanded(
              child: StreamBuilder<List<Referee>>(
                stream: _refereeService.getReferees(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Fehler: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text(
                        'Keine Schiedsrichter gefunden.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    );
                  }

                  List<Referee> referees = snapshot.data!;

                  // Apply search filter (done locally since we already have all referees)
                  if (_searchTerm.isNotEmpty) {
                    final term = _searchTerm.toLowerCase();
                    referees = referees.where((r) => 
                      r.firstName.toLowerCase().contains(term) ||
                      r.lastName.toLowerCase().contains(term) ||
                      r.email.toLowerCase().contains(term) ||
                      r.licenseType.toLowerCase().contains(term)
                    ).toList();
                  }

                  // Apply license type filter
                  if (_filterLicenseType != 'Alle') {
                    referees = referees.where((r) => r.licenseType == _filterLicenseType).toList();
                  }

                  return _buildRefereeList(referees);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStatisticsSection() {
    return StreamBuilder<List<Referee>>(
      stream: _refereeService.getReferees(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final referees = snapshot.data!;
        final distribution = <String, int>{};
        for (final licenseType in Referee.licenseTypes) {
          distribution[licenseType] = referees.where((r) => r.licenseType == licenseType).length;
        }
        final totalReferees = referees.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.black87, size: 18),
                const SizedBox(width: 6),
                const Text(
                  'Statistiken',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildCompactStatCard('Gesamt', totalReferees.toString(), Colors.blue),
                ...distribution.entries.map((entry) => 
                  _buildCompactStatCard(entry.key, entry.value.toString(), _getLicenseColor(entry.key)),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatisticsSection() {
    return StreamBuilder<List<Referee>>(
      stream: _refereeService.getReferees(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final referees = snapshot.data!;
        final distribution = <String, int>{};
        for (final licenseType in Referee.licenseTypes) {
          distribution[licenseType] = referees.where((r) => r.licenseType == licenseType).length;
        }
        final totalReferees = referees.length;

        return Container(
          padding: const EdgeInsets.all(20),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text(
                    'Statistiken',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildStatCard('Gesamt', totalReferees.toString(), Colors.blue),
                  const SizedBox(width: 16),
                  ...distribution.entries.map((entry) => 
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: _buildStatCard(entry.key, entry.value.toString(), _getLicenseColor(entry.key)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefereeList(List<Referee> referees) {
    return Container(
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final isMobile = availableWidth < 800;
          
          if (isMobile) {
            // Mobile layout - use cards instead of table
            return _buildMobileRefereeList(referees);
          } else {
            // Desktop/tablet layout - use responsive table
            return _buildDesktopRefereeTable(referees, availableWidth);
          }
        },
      ),
    );
  }

  Widget _buildMobileRefereeList(List<Referee> referees) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: referees.length,
      itemBuilder: (context, index) {
        final referee = referees[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          referee.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          referee.email,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue, size: 18),
                        onPressed: () => _editReferee(referee),
                        tooltip: 'Bearbeiten',
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                        onPressed: () => _deleteReferee(referee),
                        tooltip: 'Löschen',
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _getLicenseColor(referee.licenseType).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      referee.licenseType,
                      style: TextStyle(
                        color: _getLicenseColor(referee.licenseType),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${referee.createdAt.day}.${referee.createdAt.month}.${referee.createdAt.year}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopRefereeTable(List<Referee> referees, double availableWidth) {
    final isMobile = ResponsiveHelper.isMobile(availableWidth);
    
    return SingleChildScrollView(
      child: Container(
        width: availableWidth,
        child: DataTable(
          columnSpacing: isMobile ? 8 : 12,
          horizontalMargin: isMobile ? 8 : 12,
          dataRowMinHeight: 48,
          dataRowMaxHeight: 56,
          headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
          headingTextStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isMobile ? 12 : 13,
            color: Colors.black87,
          ),
          dataTextStyle: TextStyle(
            fontSize: isMobile ? 12 : 13,
            color: Colors.black87,
          ),
          columns: [
            DataColumn(
              label: SizedBox(
                width: (availableWidth - 40) * 0.25, // 25% of available width
                child: Text(
                  'Name',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 12 : 13,
                  ),
                ),
              ),
            ),
            DataColumn(
              label: SizedBox(
                width: (availableWidth - 40) * 0.30, // 30% of available width
                child: Text(
                  'E-Mail',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 12 : 13,
                  ),
                ),
              ),
            ),
            DataColumn(
              label: SizedBox(
                width: (availableWidth - 40) * 0.20, // 20% of available width
                child: Text(
                  'Lizenz',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 12 : 13,
                  ),
                ),
              ),
            ),
            DataColumn(
              label: SizedBox(
                width: (availableWidth - 40) * 0.15, // 15% of available width
                child: Text(
                  'Erstellt',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 12 : 13,
                  ),
                ),
              ),
            ),
            DataColumn(
              label: SizedBox(
                width: (availableWidth - 40) * 0.10, // 10% of available width
                child: Text(
                  'Aktionen',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 12 : 13,
                  ),
                ),
              ),
            ),
          ],
          rows: referees.map((referee) {
            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: (availableWidth - 40) * 0.25,
                    child: Text(
                      referee.fullName,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: isMobile ? 12 : 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: (availableWidth - 40) * 0.30,
                    child: Text(
                      referee.email,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: isMobile ? 12 : 13),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: (availableWidth - 40) * 0.20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _getLicenseColor(referee.licenseType).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        referee.licenseType,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _getLicenseColor(referee.licenseType),
                          fontSize: isMobile ? 10 : 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: (availableWidth - 40) * 0.15,
                    child: Text(
                      '${referee.createdAt.day}.${referee.createdAt.month}.${referee.createdAt.year}',
                      style: TextStyle(
                        color: Colors.grey[600], 
                        fontSize: isMobile ? 11 : 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: (availableWidth - 40) * 0.10,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.edit, 
                            color: Colors.blue, 
                            size: isMobile ? 16 : 18,
                          ),
                          onPressed: () => _editReferee(referee),
                          tooltip: 'Bearbeiten',
                          padding: EdgeInsets.all(isMobile ? 2 : 4),
                          constraints: BoxConstraints(
                            minWidth: isMobile ? 28 : 32, 
                            minHeight: isMobile ? 28 : 32,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete, 
                            color: Colors.red, 
                            size: isMobile ? 16 : 18,
                          ),
                          onPressed: () => _deleteReferee(referee),
                          tooltip: 'Löschen',
                          padding: EdgeInsets.all(isMobile ? 2 : 4),
                          constraints: BoxConstraints(
                            minWidth: isMobile ? 28 : 32, 
                            minHeight: isMobile ? 28 : 32,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
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

  void _showRefereeDialog([Referee? referee]) {
    _editingReferee = referee;
    
    if (referee != null) {
      _firstNameController.text = referee.firstName;
      _lastNameController.text = referee.lastName;
      _emailController.text = referee.email;
      _selectedLicenseType = referee.licenseType;
    } else {
      _clearForm();
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(referee == null ? 'Neuen Schiedsrichter hinzufügen' : 'Schiedsrichter bearbeiten'),
              content: SizedBox(
                width: 400,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(labelText: 'Vorname *'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Bitte geben Sie einen Vornamen ein';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(labelText: 'Nachname *'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Bitte geben Sie einen Nachnamen ein';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'E-Mail *'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Bitte geben Sie eine E-Mail-Adresse ein';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[a-zA-Z]{2,}$').hasMatch(value)) {
                            return 'Bitte geben Sie eine gültige E-Mail-Adresse ein';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedLicenseType,
                        decoration: const InputDecoration(labelText: 'Lizenz *'),
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
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Abbrechen'),
                ),
                ElevatedButton(
                  onPressed: () => _saveReferee(),
                  child: Text(referee == null ? 'Hinzufügen' : 'Speichern'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _clearForm() {
    _firstNameController.clear();
    _lastNameController.clear();
    _emailController.clear();
    _selectedLicenseType = Referee.licenseTypes.first;
  }

  void _saveReferee() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final now = DateTime.now();
      
      if (_editingReferee == null) {
        // Create new referee (Firebase will generate the ID)
        final referee = Referee(
          id: '', // Empty ID - Firebase will generate this
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim(),
          licenseType: _selectedLicenseType,
          createdAt: now,
          updatedAt: now,
        );
        
        await _refereeService.addReferee(referee);
        
        if (mounted) {
          toastification.show(
            context: context,
            type: ToastificationType.success,
            style: ToastificationStyle.fillColored,
            title: const Text('Erfolg'),
            description: const Text('Schiedsrichter erfolgreich hinzugefügt'),
            alignment: Alignment.topRight,
            autoCloseDuration: const Duration(seconds: 3),
            showProgressBar: false,
          );
        }
      } else {
        // Update existing referee
        final updatedReferee = _editingReferee!.copyWith(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim(),
          licenseType: _selectedLicenseType,
          updatedAt: now,
        );
        
        await _refereeService.updateReferee(updatedReferee);
        
        if (mounted) {
          toastification.show(
            context: context,
            type: ToastificationType.success,
            style: ToastificationStyle.fillColored,
            title: const Text('Erfolg'),
            description: const Text('Schiedsrichter erfolgreich aktualisiert'),
            alignment: Alignment.topRight,
            autoCloseDuration: const Duration(seconds: 3),
            showProgressBar: false,
          );
        }
      }
      
      if (mounted) {
        Navigator.of(context).pop();
      }
      _clearForm();
      
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          title: const Text('Fehler'),
          description: Text('Fehler: ${e.toString()}'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 4),
          showProgressBar: false,
        );
      }
    }
  }

  void _editReferee(Referee referee) {
    _showRefereeDialog(referee);
  }

  void _deleteReferee(Referee referee) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Schiedsrichter löschen'),
          content: Text('Sind Sie sicher, dass Sie ${referee.fullName} löschen möchten?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _refereeService.deleteReferee(referee.id);
                  if (mounted) {
                    Navigator.of(context).pop();
                    toastification.show(
                      context: context,
                      type: ToastificationType.success,
                      style: ToastificationStyle.fillColored,
                      title: const Text('Erfolg'),
                      description: const Text('Schiedsrichter erfolgreich gelöscht'),
                      alignment: Alignment.topRight,
                      autoCloseDuration: const Duration(seconds: 3),
                      showProgressBar: false,
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.of(context).pop();
                    toastification.show(
                      context: context,
                      type: ToastificationType.error,
                      style: ToastificationStyle.fillColored,
                      title: const Text('Fehler'),
                      description: Text('Fehler: ${e.toString()}'),
                      alignment: Alignment.topRight,
                      autoCloseDuration: const Duration(seconds: 4),
                      showProgressBar: false,
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Löschen', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
} 