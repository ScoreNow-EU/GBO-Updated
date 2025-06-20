import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:toastification/toastification.dart';
import '../models/delegate.dart';
import '../services/delegate_service.dart';
import '../utils/responsive_helper.dart';
import 'bulk_add_delegates_screen.dart';

class DelegateManagementScreen extends StatefulWidget {
  const DelegateManagementScreen({super.key});

  @override
  State<DelegateManagementScreen> createState() => _DelegateManagementScreenState();
}

class _DelegateManagementScreenState extends State<DelegateManagementScreen> {
  final DelegateService _delegateService = DelegateService();
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _searchController = TextEditingController();

  String _selectedLicenseType = Delegate.licenseTypes.first;
  String _filterLicenseType = 'Alle';
  Delegate? _editingDelegate;
  String _searchTerm = '';

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _searchController.dispose();
    _delegateService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Row(
              children: [
                const Icon(
                  Icons.account_balance,
                  size: 32,
                  color: Colors.black87,
                ),
                const SizedBox(width: 16),
                const Text(
                  'Delegierte Verwaltung',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                // Add Delegate Buttons
                ElevatedButton.icon(
                  onPressed: () => _showDelegateDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Neuen Delegierten hinzufügen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    elevation: 2,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const BulkAddDelegatesScreen(),
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
                            items: ['Alle', ...Delegate.licenseTypes].map((String type) {
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

            // Delegate List
            Expanded(
              child: StreamBuilder<List<Delegate>>(
                stream: _delegateService.getDelegates(),
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
                        'Keine Delegierten gefunden.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    );
                  }

                  List<Delegate> delegates = snapshot.data!;

                  // Apply search filter (done locally since we already have all delegates)
                  if (_searchTerm.isNotEmpty) {
                    final term = _searchTerm.toLowerCase();
                    delegates = delegates.where((d) => 
                      d.firstName.toLowerCase().contains(term) ||
                      d.lastName.toLowerCase().contains(term) ||
                      d.email.toLowerCase().contains(term) ||
                      d.licenseType.toLowerCase().contains(term)
                    ).toList();
                  }

                  // Apply license type filter
                  if (_filterLicenseType != 'Alle') {
                    delegates = delegates.where((d) => d.licenseType == _filterLicenseType).toList();
                  }

                  return _buildDelegateList(delegates);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStatisticsSection() {
    return StreamBuilder<List<Delegate>>(
      stream: _delegateService.getDelegates(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final delegates = snapshot.data!;
        final distribution = <String, int>{};
        for (final licenseType in Delegate.licenseTypes) {
          distribution[licenseType] = delegates.where((d) => d.licenseType == licenseType).length;
        }
        final totalDelegates = delegates.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.blue, size: 18),
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
                _buildCompactStatCard('Gesamt', totalDelegates.toString(), Colors.blue),
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

  Widget _buildDelegateList(List<Delegate> delegates) {
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
            return _buildMobileDelegateList(delegates);
          } else {
            // Desktop/tablet layout - use responsive table
            return _buildDesktopDelegateTable(delegates, availableWidth);
          }
        },
      ),
    );
  }

  Widget _buildMobileDelegateList(List<Delegate> delegates) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: delegates.length,
      itemBuilder: (context, index) {
        final delegate = delegates[index];
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
                          delegate.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          delegate.email,
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
                        onPressed: () => _editDelegate(delegate),
                        tooltip: 'Bearbeiten',
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                        onPressed: () => _deleteDelegate(delegate),
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
                      color: _getLicenseColor(delegate.licenseType).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      delegate.licenseType,
                      style: TextStyle(
                        color: _getLicenseColor(delegate.licenseType),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${delegate.createdAt.day}.${delegate.createdAt.month}.${delegate.createdAt.year}',
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

  Widget _buildDesktopDelegateTable(List<Delegate> delegates, double availableWidth) {
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
                width: (availableWidth - 40) * 0.25, // 25% of available width
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
                width: (availableWidth - 40) * 0.05, // 5% of available width
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
          rows: delegates.map((delegate) {
            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: (availableWidth - 40) * 0.25,
                    child: Text(
                      delegate.fullName,
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
                      delegate.email,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: isMobile ? 12 : 13),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: (availableWidth - 40) * 0.25,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _getLicenseColor(delegate.licenseType).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        delegate.licenseType,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _getLicenseColor(delegate.licenseType),
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
                      '${delegate.createdAt.day}.${delegate.createdAt.month}.${delegate.createdAt.year}',
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
                    width: (availableWidth - 40) * 0.05,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.edit, 
                            color: Colors.blue, 
                            size: isMobile ? 16 : 18,
                          ),
                          onPressed: () => _editDelegate(delegate),
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
                          onPressed: () => _deleteDelegate(delegate),
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
      case 'EHF Delegate':
        return Colors.purple;
      case 'DHB National Delegate':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  void _showDelegateDialog([Delegate? delegate]) {
    _editingDelegate = delegate;
    
    if (delegate != null) {
      _firstNameController.text = delegate.firstName;
      _lastNameController.text = delegate.lastName;
      _emailController.text = delegate.email;
      _selectedLicenseType = delegate.licenseType;
    } else {
      _clearForm();
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(delegate == null ? 'Neuen Delegierten hinzufügen' : 'Delegierten bearbeiten'),
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
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Abbrechen'),
                ),
                ElevatedButton(
                  onPressed: () => _saveDelegate(),
                  child: Text(delegate == null ? 'Erstellen' : 'Speichern'),
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
    _selectedLicenseType = Delegate.licenseTypes.first;
  }

  Future<void> _saveDelegate() async {
    if (_formKey.currentState!.validate()) {
      try {
        final delegate = Delegate(
          id: _editingDelegate?.id ?? '',
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim(),
          licenseType: _selectedLicenseType,
          createdAt: _editingDelegate?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );

        if (_editingDelegate == null) {
          await _delegateService.addDelegate(delegate);
          _showSuccessToast('Delegierter erfolgreich hinzugefügt');
        } else {
          await _delegateService.updateDelegate(delegate);
          _showSuccessToast('Delegierter erfolgreich aktualisiert');
        }

        Navigator.of(context).pop();
        _clearForm();
      } catch (e) {
        _showErrorToast('Fehler: $e');
      }
    }
  }

  void _editDelegate(Delegate delegate) {
    _showDelegateDialog(delegate);
  }

  Future<void> _deleteDelegate(Delegate delegate) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delegierten löschen'),
          content: Text('Sind Sie sicher, dass Sie ${delegate.fullName} löschen möchten?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await _delegateService.deleteDelegate(delegate.id);
        _showSuccessToast('Delegierter erfolgreich gelöscht');
      } catch (e) {
        _showErrorToast('Fehler beim Löschen: $e');
      }
    }
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