import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../models/kampfgericht_member.dart';
import '../services/kampfgericht_service.dart';
import '../utils/responsive_helper.dart';

class KampfgerichtManagementScreen extends StatefulWidget {
  const KampfgerichtManagementScreen({super.key});

  @override
  State<KampfgerichtManagementScreen> createState() =>
      _KampfgerichtManagementScreenState();
}

class _KampfgerichtManagementScreenState
    extends State<KampfgerichtManagementScreen> {
  final KampfgerichtService _service = KampfgerichtService();
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _searchController = TextEditingController();
  final _streetController = TextEditingController();
  final _houseNumberController = TextEditingController();
  final _plzController = TextEditingController();
  final _cityController = TextEditingController();

  KampfgerichtMember? _editingMember;
  String _searchTerm = '';

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _searchController.dispose();
    _streetController.dispose();
    _houseNumberController.dispose();
    _plzController.dispose();
    _cityController.dispose();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMemberDialog(),
        backgroundColor: Colors.black87,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText:
                              'Suche nach Name, E-Mail oder Ort...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchTerm = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    StreamBuilder<List<KampfgerichtMember>>(
                      stream: _service.getMembers(),
                      builder: (context, snapshot) {
                        final count = snapshot.data?.length ?? 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: Colors.blue.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$count',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Gesamt',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Member List
            Expanded(
              child: StreamBuilder<List<KampfgerichtMember>>(
                stream: _service.getMembers(),
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
                        'Keine Kampfgericht-Mitglieder gefunden.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    );
                  }

                  List<KampfgerichtMember> members = snapshot.data!;

                  // Apply search filter
                  if (_searchTerm.isNotEmpty) {
                    final term = _searchTerm.toLowerCase();
                    members = members
                        .where((m) =>
                            m.firstName.toLowerCase().contains(term) ||
                            m.lastName.toLowerCase().contains(term) ||
                            m.email.toLowerCase().contains(term) ||
                            m.city.toLowerCase().contains(term))
                        .toList();
                  }

                  return _buildMemberList(members);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberList(List<KampfgerichtMember> members) {
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
            return _buildMobileList(members);
          } else {
            return _buildDesktopTable(members, availableWidth);
          }
        },
      ),
    );
  }

  Widget _buildMobileList(List<KampfgerichtMember> members) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      member.email,
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    if (member.city.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        member.city,
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue, size: 18),
                    onPressed: () => _showMemberDialog(member),
                    tooltip: 'Bearbeiten',
                    padding: const EdgeInsets.all(4),
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.delete, color: Colors.red, size: 18),
                    onPressed: () => _deleteMember(member),
                    tooltip: 'Löschen',
                    padding: const EdgeInsets.all(4),
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable(
      List<KampfgerichtMember> members, double availableWidth) {
    final isMobile = ResponsiveHelper.isMobile(availableWidth);

    return SingleChildScrollView(
      child: SizedBox(
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
                width: (availableWidth - 40) * 0.25,
                child: const Text('Name',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            DataColumn(
              label: SizedBox(
                width: (availableWidth - 40) * 0.30,
                child: const Text('E-Mail',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            DataColumn(
              label: SizedBox(
                width: (availableWidth - 40) * 0.20,
                child: const Text('Ort',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            DataColumn(
              label: SizedBox(
                width: (availableWidth - 40) * 0.15,
                child: const Text('Erstellt',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            DataColumn(
              label: SizedBox(
                width: (availableWidth - 40) * 0.10,
                child: const Text('Aktionen',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
          rows: members.map((member) {
            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: (availableWidth - 40) * 0.25,
                    child: Text(
                      member.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: (availableWidth - 40) * 0.30,
                    child: Text(
                      member.email,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: (availableWidth - 40) * 0.20,
                    child: Text(
                      member.city,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: (availableWidth - 40) * 0.15,
                    child: Text(
                      '${member.createdAt.day}.${member.createdAt.month}.${member.createdAt.year}',
                      style: TextStyle(color: Colors.grey[600]),
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
                          icon: const Icon(Icons.edit,
                              color: Colors.blue, size: 18),
                          onPressed: () => _showMemberDialog(member),
                          tooltip: 'Bearbeiten',
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                              minWidth: 32, minHeight: 32),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              color: Colors.red, size: 18),
                          onPressed: () => _deleteMember(member),
                          tooltip: 'Löschen',
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                              minWidth: 32, minHeight: 32),
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

  void _showMemberDialog([KampfgerichtMember? member]) {
    _editingMember = member;

    if (member != null) {
      _firstNameController.text = member.firstName;
      _lastNameController.text = member.lastName;
      _emailController.text = member.email;
      _streetController.text = member.street;
      _houseNumberController.text = member.houseNumber;
      _plzController.text = member.plz;
      _cityController.text = member.city;
    } else {
      _clearForm();
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(member == null
              ? 'Neues Kampfgericht-Mitglied hinzufügen'
              : 'Kampfgericht-Mitglied bearbeiten'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _firstNameController,
                      decoration:
                          const InputDecoration(labelText: 'Vorname *'),
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
                      decoration:
                          const InputDecoration(labelText: 'Nachname *'),
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
                      decoration:
                          const InputDecoration(labelText: 'E-Mail *'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Bitte geben Sie eine E-Mail-Adresse ein';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[a-zA-Z]{2,}$')
                            .hasMatch(value)) {
                          return 'Bitte geben Sie eine gültige E-Mail-Adresse ein';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Adresse',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _streetController,
                            decoration: const InputDecoration(
                                labelText: 'Straße'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _houseNumberController,
                            decoration:
                                const InputDecoration(labelText: 'Nr.'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _plzController,
                            decoration:
                                const InputDecoration(labelText: 'PLZ'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _cityController,
                            decoration:
                                const InputDecoration(labelText: 'Ort'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () => _saveMember(),
              child: Text(member == null ? 'Hinzufügen' : 'Speichern'),
            ),
          ],
        );
      },
    );
  }

  void _clearForm() {
    _firstNameController.clear();
    _lastNameController.clear();
    _emailController.clear();
    _streetController.clear();
    _houseNumberController.clear();
    _plzController.clear();
    _cityController.clear();
  }

  void _saveMember() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final now = DateTime.now();

      if (_editingMember == null) {
        final member = KampfgerichtMember(
          id: '',
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim(),
          street: _streetController.text.trim(),
          houseNumber: _houseNumberController.text.trim(),
          plz: _plzController.text.trim(),
          city: _cityController.text.trim(),
          createdAt: now,
          updatedAt: now,
        );

        await _service.addMember(member);

        if (mounted) {
          toastification.show(
            context: context,
            type: ToastificationType.success,
            style: ToastificationStyle.fillColored,
            title: const Text('Erfolg'),
            description: const Text(
                'Kampfgericht-Mitglied erfolgreich hinzugefügt'),
            alignment: Alignment.topRight,
            autoCloseDuration: const Duration(seconds: 3),
            showProgressBar: false,
          );
        }
      } else {
        final updatedMember = _editingMember!.copyWith(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim(),
          street: _streetController.text.trim(),
          houseNumber: _houseNumberController.text.trim(),
          plz: _plzController.text.trim(),
          city: _cityController.text.trim(),
          updatedAt: now,
        );

        await _service.updateMember(updatedMember);

        if (mounted) {
          toastification.show(
            context: context,
            type: ToastificationType.success,
            style: ToastificationStyle.fillColored,
            title: const Text('Erfolg'),
            description: const Text(
                'Kampfgericht-Mitglied erfolgreich aktualisiert'),
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

  void _deleteMember(KampfgerichtMember member) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Kampfgericht-Mitglied löschen'),
          content: Text(
              'Sind Sie sicher, dass Sie ${member.fullName} löschen möchten?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _service.deleteMember(member.id);
                  if (mounted) {
                    Navigator.of(context).pop();
                    toastification.show(
                      context: context,
                      type: ToastificationType.success,
                      style: ToastificationStyle.fillColored,
                      title: const Text('Erfolg'),
                      description: const Text(
                          'Kampfgericht-Mitglied erfolgreich gelöscht'),
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
              child: const Text('Löschen',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
