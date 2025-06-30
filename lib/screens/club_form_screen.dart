import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/club.dart';
import '../services/club_service.dart';
import '../data/german_cities.dart';
import 'team_form_screen.dart';

class ClubFormScreen extends StatefulWidget {
  final Club? club; // null for new club, existing club for editing
  
  const ClubFormScreen({super.key, this.club});

  @override
  State<ClubFormScreen> createState() => _ClubFormScreenState();
}

class _ClubFormScreenState extends State<ClubFormScreen> {
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
  GermanCity? _selectedCity;
  bool _isLoading = false;

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
    _initializeForm();
  }

  void _initializeForm() {
    if (widget.club != null) {
      // Editing existing club
      final club = widget.club!;
      _nameController.text = club.name;
      _cityController.text = club.city;
      _selectedBundesland = club.bundesland;
      _contactEmailController.text = club.contactEmail ?? '';
      _contactPhoneController.text = club.contactPhone ?? '';
      _websiteController.text = club.website ?? '';
      _descriptionController.text = club.description ?? '';
      _logoUrlController.text = club.logoUrl ?? '';
      
      // Find matching city from German cities data
      _selectedCity = GermanCities.cities.firstWhere(
        (city) => city.name == club.city && city.state == club.bundesland,
        orElse: () => GermanCity(name: club.city, state: club.bundesland),
      );
    }
  }

  @override
  void dispose() {
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
    final isEditing = widget.club != null;
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(isEditing ? 'Verein bearbeiten' : 'Neuer Verein'),
        backgroundColor: const Color(0xFFffd665),
        foregroundColor: Colors.black87,
        elevation: 2,
        actions: [
          if (isEditing)
            IconButton(
              onPressed: () => _navigateToAddTeam(),
              icon: const Icon(Icons.group_add),
              tooltip: 'Team hinzufügen',
            ),
          if (isEditing)
            IconButton(
              onPressed: _deleteClub,
              icon: const Icon(Icons.delete),
              tooltip: 'Verein löschen',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBasicInfoSection(),
              const SizedBox(height: 24),
              _buildLocationSection(),
              const SizedBox(height: 24),
              _buildContactSection(),
              const SizedBox(height: 24),
              _buildAdditionalInfoSection(),
              const SizedBox(height: 32),
              _buildSaveButton(isEditing),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.business, color: Colors.black87),
                const SizedBox(width: 8),
                const Text(
                  'Grundinformationen',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Vereinsname *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
                hintText: 'z.B. Beach Volleyball Club München',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Bitte geben Sie einen Vereinsnamen ein';
                }
                return null;
              },
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
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  try {
                    Uri.parse(value);
                  } catch (e) {
                    return 'Bitte geben Sie eine gültige URL ein';
                  }
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.black87),
                const SizedBox(width: 8),
                const Text(
                  'Standort',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildCityAutocomplete(),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedBundesland,
              decoration: const InputDecoration(
                labelText: 'Bundesland *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.map),
              ),
              items: _bundeslaender.map((state) => DropdownMenuItem(
                value: state,
                child: Text(state),
              )).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedBundesland = value!;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Bitte wählen Sie ein Bundesland';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.contact_mail, color: Colors.black87),
                const SizedBox(width: 8),
                const Text(
                  'Kontaktinformationen',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactEmailController,
              decoration: const InputDecoration(
                labelText: 'E-Mail (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
                hintText: 'kontakt@verein.de',
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Bitte geben Sie eine gültige E-Mail-Adresse ein';
                  }
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
                hintText: '+49 123 456789',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _websiteController,
              decoration: const InputDecoration(
                labelText: 'Website (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.language),
                hintText: 'https://www.verein.de',
              ),
              keyboardType: TextInputType.url,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  try {
                    Uri.parse(value);
                  } catch (e) {
                    return 'Bitte geben Sie eine gültige URL ein';
                  }
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description, color: Colors.black87),
                const SizedBox(width: 8),
                const Text(
                  'Zusätzliche Informationen',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Beschreibung (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
                hintText: 'Kurze Beschreibung des Vereins...',
              ),
              maxLines: 4,
              maxLength: 500,
            ),
          ],
        ),
      ),
    );
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
        }).take(10);
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
            elevation: 4.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final GermanCity option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            option.state,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSaveButton(bool isEditing) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _saveClub,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: _isLoading 
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(isEditing ? Icons.save : Icons.add),
        label: Text(
          _isLoading 
              ? 'Speichern...' 
              : (isEditing ? 'Änderungen speichern' : 'Verein erstellen'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _saveClub() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final club = Club(
        id: widget.club?.id ?? '',
        name: _nameController.text.trim(),
        logoUrl: _logoUrlController.text.trim().isEmpty ? null : _logoUrlController.text.trim(),
        city: _cityController.text.trim(),
        bundesland: _selectedBundesland,
        contactEmail: _contactEmailController.text.trim().isEmpty ? null : _contactEmailController.text.trim(),
        contactPhone: _contactPhoneController.text.trim().isEmpty ? null : _contactPhoneController.text.trim(),
        website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        teamIds: widget.club?.teamIds ?? [],
        createdAt: widget.club?.createdAt ?? DateTime.now(),
      );

      bool success;
      if (widget.club == null) {
        final clubId = await _clubService.createClub(club);
        success = clubId != null;
      } else {
        success = await _clubService.updateClub(widget.club!.id, club);
      }

      if (success) {
        _showSuccess(widget.club == null 
            ? 'Verein erfolgreich erstellt!' 
            : 'Verein erfolgreich aktualisiert!');
        
        // Navigate back
        Navigator.of(context).pop(true);
      } else {
        _showError('Fehler beim Speichern des Vereins');
      }
    } catch (e) {
      _showError('Ein unerwarteter Fehler ist aufgetreten: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteClub() async {
    if (widget.club == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verein löschen'),
        content: Text('Möchten Sie den Verein "${widget.club!.name}" wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.'),
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
      setState(() {
        _isLoading = true;
      });

      try {
        final success = await _clubService.deleteClub(widget.club!.id);
        
        if (success) {
          _showSuccess('Verein erfolgreich gelöscht!');
          Navigator.of(context).pop(true);
        } else {
          _showError('Fehler beim Löschen des Vereins');
        }
      } catch (e) {
        _showError('Ein unerwarteter Fehler ist aufgetreten: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToAddTeam() {
    if (widget.club == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte speichern Sie den Verein zuerst'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TeamFormScreen(preselectedClub: widget.club),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
} 