import 'package:flutter/material.dart';
import 'dart:async';
import '../models/club.dart';
import '../services/club_service.dart';
import '../utils/responsive_helper.dart';
import '../data/german_cities.dart';

class ClubManagementScreen extends StatefulWidget {
  const ClubManagementScreen({super.key});

  @override
  State<ClubManagementScreen> createState() => _ClubManagementScreenState();
}

class _ClubManagementScreenState extends State<ClubManagementScreen> {
  final ClubService _clubService = ClubService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _logoUrlController = TextEditingController();
  final _cityController = TextEditingController();

  String _selectedBundesland = 'Baden-Württemberg';
  String _filterBundesland = 'Alle';
  String _searchQuery = '';
  Club? _editingClub;
  GermanCity? _selectedCity;
  
  Timer? _autoSaveTimer;
  bool _isAutoSaving = false;
  bool _hasUnsavedChanges = false;

  // German Bundesländer and international regions
  final List<String> _bundeslaender = [
    'Baden-Württemberg',
    'Bayern',
    'Berlin',
    'Brandenburg',
    'Bremen',
    'Hamburg',
    'Hessen',
    'Mecklenburg-Vorpommern',
    'Niedersachsen',
    'Nordrhein-Westfalen',
    'Rheinland-Pfalz',
    'Saarland',
    'Sachsen',
    'Sachsen-Anhalt',
    'Schleswig-Holstein',
    'Thüringen',
    // International regions
    'Dänemark',
    'Norwegen',
    'Niederlande',
    'Serbien',
    'Frankreich',
  ];

  @override
  void initState() {
    super.initState();
    _setupAutoSaveListeners();
  }

  void _setupAutoSaveListeners() {
    _nameController.addListener(_onFormChanged);
    _contactEmailController.addListener(_onFormChanged);
    _contactPhoneController.addListener(_onFormChanged);
    _websiteController.addListener(_onFormChanged);
    _descriptionController.addListener(_onFormChanged);
    _logoUrlController.addListener(_onFormChanged);
    _cityController.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
    
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      if (_editingClub != null && _hasUnsavedChanges) {
        _autoSaveClub();
      }
    });
  }

  void _autoSaveClub() async {
    if (_editingClub == null || !_formKey.currentState!.validate()) return;
    
    setState(() {
      _isAutoSaving = true;
    });

    final updatedClub = Club(
      id: _editingClub!.id,
      name: _nameController.text.trim(),
      logoUrl: _logoUrlController.text.trim().isEmpty ? null : _logoUrlController.text.trim(),
      city: _cityController.text.trim(),
      bundesland: _selectedBundesland,
      contactEmail: _contactEmailController.text.trim().isEmpty ? null : _contactEmailController.text.trim(),
      contactPhone: _contactPhoneController.text.trim().isEmpty ? null : _contactPhoneController.text.trim(),
      website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      teamIds: _editingClub!.teamIds,
      createdAt: _editingClub!.createdAt,
    );

    final success = await _clubService.updateClub(_editingClub!.id, updatedClub);
    
    setState(() {
      _isAutoSaving = false;
      if (success) {
        _hasUnsavedChanges = false;
      }
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _nameController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    _websiteController.dispose();
    _descriptionController.dispose();
    _logoUrlController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = ResponsiveHelper.isDesktop(screenWidth);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Vereine verwalten'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          if (_hasUnsavedChanges && _isAutoSaving)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Speichern...',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left side - Club list
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildClubList()),
              ],
            ),
          ),
        ),
        // Right side - Club form
        Expanded(
          flex: 3,
          child: _buildClubForm(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return _editingClub == null 
        ? Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildClubList()),
            ],
          )
        : _buildClubForm();
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.business, color: Colors.blue),
              const SizedBox(width: 12),
              Text(
                'Vereine',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showClubDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Neuer Verein'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Search
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Vereinsname suchen...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              // Bundesland Filter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _filterBundesland,
                    items: [
                      const DropdownMenuItem(
                        value: 'Alle',
                        child: Text('Bundesland: Alle'),
                      ),
                      ..._bundeslaender.map((state) => DropdownMenuItem(
                        value: state,
                        child: Text('Bundesland: $state'),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filterBundesland = value!;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClubList() {
    return StreamBuilder<List<Club>>(
      stream: _clubService.getClubs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text('Fehler: ${snapshot.error}'),
          );
        }
        
        List<Club> clubs = snapshot.data ?? [];
        
        // Apply filters
        if (_filterBundesland != 'Alle') {
          clubs = clubs.where((club) => club.bundesland == _filterBundesland).toList();
        }
        
        if (_searchQuery.isNotEmpty) {
          clubs = clubs.where((club) => 
            club.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            club.city.toLowerCase().contains(_searchQuery.toLowerCase())
          ).toList();
        }
        
        if (clubs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.business_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty || _filterBundesland != 'Alle'
                      ? 'Keine Vereine gefunden'
                      : 'Noch keine Vereine vorhanden',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _searchQuery.isNotEmpty || _filterBundesland != 'Alle'
                      ? 'Versuchen Sie andere Suchkriterien'
                      : 'Erstellen Sie Ihren ersten Verein',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: clubs.length,
          itemBuilder: (context, index) {
            final club = clubs[index];
            return _buildClubCard(club);
          },
        );
      },
    );
  }

  Widget _buildClubCard(Club club) {
    final isSelected = _editingClub?.id == club.id;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        elevation: isSelected ? 2 : 1,
        child: InkWell(
          onTap: () => _editClub(club),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Club logo or placeholder
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: club.logoUrl != null && club.logoUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            club.logoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(Icons.business, color: Colors.blue);
                            },
                          ),
                        )
                      : Icon(Icons.business, color: Colors.blue),
                ),
                const SizedBox(width: 16),
                
                // Club info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        club.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${club.city}, ${club.bundesland}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      if (club.teamIds.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${club.teamIds.length} Team${club.teamIds.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            color: Colors.blue[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Actions
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _editClub(club);
                        break;
                      case 'delete':
                        _deleteClub(club);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Bearbeiten'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Löschen', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClubForm() {
    return Container(
      color: Colors.grey.shade50,
      child: Column(
        children: [
          // Form header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                if (ResponsiveHelper.isMobile(MediaQuery.of(context).size.width))
                  IconButton(
                    icon: Icon(Icons.arrow_back),
                    onPressed: () {
                      setState(() {
                        _editingClub = null;
                        _clearForm();
                      });
                    },
                  ),
                Icon(
                  _editingClub == null ? Icons.add_business : Icons.business,
                  color: Colors.blue,
                ),
                const SizedBox(width: 12),
                Text(
                  _editingClub == null ? 'Neuen Verein erstellen' : 'Verein bearbeiten',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                if (_editingClub != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _editingClub = null;
                        _clearForm();
                      });
                    },
                    child: Text('Abbrechen'),
                  ),
              ],
            ),
          ),
          
          // Form content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Information
                    _buildFormSection(
                      'Grunddaten',
                      Icons.info_outline,
                      [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Vereinsname *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.business),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Bitte geben Sie einen Vereinsnamen ein';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        Row(
                          children: [
                            Expanded(
                              child: _buildCityAutocomplete(),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedBundesland,
                                decoration: const InputDecoration(
                                  labelText: 'Bundesland *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.map),
                                ),
                                items: _bundeslaender.map((state) {
                                  return DropdownMenuItem(
                                    value: state,
                                    child: Text(state),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedBundesland = value!;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _logoUrlController,
                          decoration: const InputDecoration(
                            labelText: 'Logo URL (optional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.image),
                            hintText: 'https://example.com/logo.png',
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Contact Information
                    _buildFormSection(
                      'Kontaktdaten',
                      Icons.contact_mail,
                      [
                        TextFormField(
                          controller: _contactEmailController,
                          decoration: const InputDecoration(
                            labelText: 'E-Mail (optional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email),
                          ),
                          validator: (value) {
                            if (value != null && value.isNotEmpty && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[a-zA-Z]{2,}$').hasMatch(value)) {
                              return 'Bitte geben Sie eine gültige E-Mail-Adresse ein';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _contactPhoneController,
                          decoration: const InputDecoration(
                            labelText: 'Telefon (optional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _websiteController,
                          decoration: const InputDecoration(
                            labelText: 'Website (optional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.web),
                            hintText: 'https://example.com',
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Description
                    _buildFormSection(
                      'Beschreibung',
                      Icons.description,
                      [
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Vereinsbeschreibung (optional)',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveClub,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          _editingClub == null ? 'Verein erstellen' : 'Änderungen speichern',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.blue, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  void _showClubDialog() {
    setState(() {
      _editingClub = null;
      _clearForm();
    });
  }

  void _editClub(Club club) {
    setState(() {
      _editingClub = club;
      _nameController.text = club.name;
      _cityController.text = club.city;
      _selectedBundesland = club.bundesland;
      
      // Find matching city from German cities data
      _selectedCity = GermanCities.cities.firstWhere(
        (city) => city.name == club.city && city.state == club.bundesland,
        orElse: () => GermanCity(name: club.city, state: club.bundesland),
      );
      
      _contactEmailController.text = club.contactEmail ?? '';
      _contactPhoneController.text = club.contactPhone ?? '';
      _websiteController.text = club.website ?? '';
      _descriptionController.text = club.description ?? '';
      _logoUrlController.text = club.logoUrl ?? '';
      _hasUnsavedChanges = false;
    });
  }

  void _clearForm() {
    _nameController.clear();
    _cityController.clear();
    _contactEmailController.clear();
    _contactPhoneController.clear();
    _websiteController.clear();
    _descriptionController.clear();
    _logoUrlController.clear();
    _selectedBundesland = 'Baden-Württemberg';
    _selectedCity = null;
    _hasUnsavedChanges = false;
  }

  void _saveClub() async {
    if (!_formKey.currentState!.validate()) return;

    final club = Club(
      id: _editingClub?.id ?? '',
      name: _nameController.text.trim(),
      logoUrl: _logoUrlController.text.trim().isEmpty ? null : _logoUrlController.text.trim(),
      city: _cityController.text.trim(),
      bundesland: _selectedBundesland,
      contactEmail: _contactEmailController.text.trim().isEmpty ? null : _contactEmailController.text.trim(),
      contactPhone: _contactPhoneController.text.trim().isEmpty ? null : _contactPhoneController.text.trim(),
      website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      teamIds: _editingClub?.teamIds ?? [],
      createdAt: _editingClub?.createdAt ?? DateTime.now(),
    );

    bool success;
    if (_editingClub == null) {
      final clubId = await _clubService.createClub(club);
      success = clubId != null;
    } else {
      success = await _clubService.updateClub(_editingClub!.id, club);
    }

    if (success) {
      setState(() {
        _editingClub = null;
        _hasUnsavedChanges = false;
      });
      _clearForm();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verein erfolgreich ${_editingClub == null ? 'erstellt' : 'aktualisiert'}!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Speichern des Vereins'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _deleteClub(Club club) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verein löschen'),
        content: Text('Möchten Sie den Verein "${club.name}" wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _clubService.deleteClub(club.id);
      
      if (success) {
        if (_editingClub?.id == club.id) {
          setState(() {
            _editingClub = null;
          });
          _clearForm();
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verein erfolgreich gelöscht!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fehler beim Löschen des Vereins'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildCityAutocomplete() {
    return Autocomplete<GermanCity>(
      displayStringForOption: (GermanCity option) => option.name,
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<GermanCity>.empty();
        }
        return GermanCities.cities.where((GermanCity city) {
          return city.name.toLowerCase().contains(
            textEditingValue.text.toLowerCase(),
          );
        }).take(10); // Limit to 10 results for performance
      },
      onSelected: (GermanCity selection) {
        setState(() {
          _selectedCity = selection;
          _cityController.text = selection.name;
          _selectedBundesland = selection.state;
        });
      },
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController textEditingController,
        FocusNode focusNode,
        VoidCallback onFieldSubmitted,
      ) {
        // Sync the controller with our main city controller
        if (_cityController.text.isNotEmpty && textEditingController.text != _cityController.text) {
          textEditingController.text = _cityController.text;
        }
        
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Stadt *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_city),
            hintText: 'Stadt eingeben...',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Bitte geben Sie eine Stadt ein';
            }
            return null;
          },
          onChanged: (value) {
            _cityController.text = value;
            _onFormChanged();
          },
        );
      },
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<GermanCity> onSelected,
        Iterable<GermanCity> options,
      ) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              width: MediaQuery.of(context).size.width * 0.8,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final GermanCity option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(option.name),
                    subtitle: Text(option.state),
                    onTap: () {
                      onSelected(option);
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}