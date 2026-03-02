import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/city.dart';
import '../utils/firebase_cities_helper.dart';
import '../models/tournament.dart';
import '../models/user.dart' as app_user;
import '../services/tournament_service.dart';
import '../services/auth_service.dart';
import '../utils/app_colors.dart';
import 'tournament_creation_success_screen.dart';

// Helper widget for section titles
Widget _buildSectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    ),
  );
}

class TournamentCreationWizard extends StatefulWidget {
  const TournamentCreationWizard({super.key});

  @override
  State<TournamentCreationWizard> createState() => _TournamentCreationWizardState();
}

class _TournamentCreationWizardState extends State<TournamentCreationWizard> {
  final PageController _pageController = PageController();
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  int _currentPage = 0;
  bool _isLoading = false;

  // Basic Info
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _cityController;
  late final TextEditingController _bundeslandController;
  City? _selectedCity;
  bool _citiesLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _cityController = TextEditingController();
    _bundeslandController = TextEditingController();
  }


  
  // Dates
  DateTime? _startDate;
  DateTime? _endDate;
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();

  String _formatDateInput(String input) {
    // Remove any non-digits
    input = input.replaceAll(RegExp(r'[^\d]'), '');
    
    if (input.length <= 2) {
      return input;
    } else if (input.length <= 4) {
      return '${input.substring(0, 2)}.${input.substring(2)}';
    } else if (input.length <= 8) {
      return '${input.substring(0, 2)}.${input.substring(2, 4)}.${input.substring(4)}';
    }
    return '${input.substring(0, 2)}.${input.substring(2, 4)}.${input.substring(4, 8)}';
  }

  DateTime? _parseDate(String input) {
    try {
      final parts = input.split('.');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (e) {
      // Invalid date format
    }
    return null;
  }
  // Teams page state
  bool _isRegistrationOpen = true;
  DateTime? _registrationDeadline;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _cityController.dispose();
    _bundeslandController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Neues Turnier erstellen',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Main Content
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (page) {
                        setState(() {
                          _currentPage = page;
                        });
                      },
                      children: [
                        _buildBasicInfoPage(),
                        _buildDatesPage(),
                        _buildTeamsPage(),
                        _buildSummaryPage(),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Bottom Navigation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      offset: const Offset(0, -2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        4,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentPage == index
                                ? Colors.white
                                : Colors.white.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Navigation Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_currentPage > 0)
                          TextButton.icon(
                            onPressed: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            label: const Text('Zurück', style: TextStyle(color: Colors.white)),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.2),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : ElevatedButton.icon(
                          onPressed: () {
                            if (_currentPage == 3) {
                              _saveTournament();
                            } else {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          icon: Icon(
                            _currentPage == 3 ? Icons.check_circle :
                            _currentPage == 2 ? Icons.preview :
                            Icons.arrow_forward
                          ),
                          label: Text(
                            _currentPage == 3 ? 'Erstellen' :
                            _currentPage == 2 ? 'Überprüfen' :
                            'Weiter'
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Grundinformationen',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            // Tournament Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Turnier Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Bitte geben Sie einen Turnier Namen ein';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Beschreibung (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            
            // Location
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // City Autocomplete
                Autocomplete<City>(
                  displayStringForOption: (City option) => option.name,
                  optionsBuilder: (TextEditingValue textEditingValue) async {
                    if (textEditingValue.text.isEmpty) {
                      if (mounted) setState(() => _citiesLoading = false);
                      return const Iterable<City>.empty();
                    }
                    if (mounted) setState(() => _citiesLoading = true);
                    try {
                      final cities = await FirebaseCitiesHelper.searchCities(textEditingValue.text);
                      return cities.take(10);
                    } finally {
                      if (mounted) setState(() => _citiesLoading = false);
                    }
                  },
                  optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<City> onSelected, Iterable<City> options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4.0,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200, maxWidth: 400),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (BuildContext context, int index) {
                              final City option = options.elementAt(index);
                              return InkWell(
                                onTap: () {
                                  onSelected(option);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.location_city, size: 20, color: Colors.grey),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              option.name,
                                              style: const TextStyle(fontWeight: FontWeight.w500),
                                            ),
                                            Text(
                                              option.state,
                                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                            ),
                                          ],
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
                  onSelected: (City selection) {
                    if (mounted) {
                      setState(() {
                        _selectedCity = selection;
                        _cityController.text = selection.name;
                        _bundeslandController.text = selection.state;
                      });
                    }
                  },
                  fieldViewBuilder: (
                    BuildContext context,
                    TextEditingController textEditingController,
                    FocusNode focusNode,
                    VoidCallback onFieldSubmitted,
                  ) {
                    // Set initial value if we have a selected city
                    if (_selectedCity != null && textEditingController.text != _selectedCity!.name) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          textEditingController.text = _selectedCity!.name;
                        }
                      });
                    }
                    
                    return TextFormField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      enabled: !_citiesLoading || textEditingController.text.isNotEmpty,
                      decoration: InputDecoration(
                        labelText: 'Stadt *',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.location_city),
                        hintText: 'Stadt eingeben...',
                        suffixIcon: _citiesLoading
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFe63946),
                                  ),
                                ),
                              )
                            : null,
                        helperText: _citiesLoading ? 'Städte werden geladen...' : null,
                        helperStyle: const TextStyle(color: Color(0xFFe63946), fontSize: 12),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Bitte geben Sie eine Stadt ein';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        // Only clear the selected city and bundesland if the text no longer matches
                        if (_selectedCity != null && value != _selectedCity!.name) {
                          setState(() {
                            _selectedCity = null;
                            _bundeslandController.clear();
                          });
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Bundesland (read-only)
                TextFormField(
                  controller: _bundeslandController,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Bundesland',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.map),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatesPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Termine',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Start Date
          TextFormField(
            controller: _startDateController,
            decoration: InputDecoration(
              labelText: 'Startdatum * (DD.MM.YYYY)',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.calendar_today),
              suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () => _selectStartDate(),
              ),
            ),
            onChanged: (value) {
              final formattedValue = _formatDateInput(value);
              if (formattedValue != value) {
                _startDateController.value = TextEditingValue(
                  text: formattedValue,
                  selection: TextSelection.collapsed(offset: formattedValue.length),
                );
              }
              setState(() {
                _startDate = _parseDate(formattedValue);
              });
            },
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Bitte geben Sie ein Startdatum ein';
              }
              if (_parseDate(value) == null) {
                return 'Bitte geben Sie ein gültiges Datum ein';
              }
              return null;
            },
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
              LengthLimitingTextInputFormatter(8),
            ],
          ),
          const SizedBox(height: 16),

          // End Date
          TextFormField(
            controller: _endDateController,
            decoration: InputDecoration(
              labelText: 'Enddatum * (DD.MM.YYYY)',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.calendar_today),
              suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () => _selectEndDate(),
              ),
            ),
            onChanged: (value) {
              final formattedValue = _formatDateInput(value);
              if (formattedValue != value) {
                _endDateController.value = TextEditingValue(
                  text: formattedValue,
                  selection: TextSelection.collapsed(offset: formattedValue.length),
                );
              }
              setState(() {
                _endDate = _parseDate(formattedValue);
              });
            },
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Bitte geben Sie ein Enddatum ein';
              }
              if (_parseDate(value) == null) {
                return 'Bitte geben Sie ein gültiges Datum ein';
              }
              final endDate = _parseDate(value);
              final startDate = _startDate;
              if (startDate != null && endDate != null && endDate.isBefore(startDate)) {
                return 'Das Enddatum muss nach dem Startdatum liegen';
              }
              return null;
            },
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
              LengthLimitingTextInputFormatter(8),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Zusammenfassung'),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummarySection(
                    'Grundinformationen',
                    Icons.info_outline,
                    [
                      'Name: ${_nameController.text}',
                      'Beschreibung: ${_descriptionController.text}',
                      'Stadt: ${_cityController.text}',
                      'Bundesland: ${_bundeslandController.text}',
                    ],
                  ),
                  const Divider(),
                  _buildSummarySection(
                    'Teams',
                    Icons.group,
                    [
                      'Registrierung: ${_isRegistrationOpen ? 'Offen' : 'Geschlossen'}',
                      if (_registrationDeadline != null)
                        'Anmeldefrist: ${_registrationDeadline!.day}.${_registrationDeadline!.month}.${_registrationDeadline!.year}',
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Klicken Sie auf "Erstellen", um das Turnier zu erstellen.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(String title, IconData icon, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.black87),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(left: 28, bottom: 4),
          child: Text(
            item,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildTeamsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Team-Anmeldungen',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Konfigurieren Sie die Team-Anmeldungen für das Turnier',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),

          // Registration Settings
          _buildSectionTitle('Anmeldungseinstellungen'),
          SwitchListTile(
            title: const Text('Anmeldung geöffnet'),
            subtitle: const Text('Teams können sich für das Turnier anmelden'),
            value: _isRegistrationOpen,
            onChanged: (value) {
              setState(() {
                _isRegistrationOpen = value;
              });
            },
          ),
          ListTile(
            title: const Text('Anmeldeschluss'),
            subtitle: Text(_registrationDeadline != null
                ? '${_registrationDeadline!.day}.${_registrationDeadline!.month}.${_registrationDeadline!.year}'
                : 'Kein Anmeldeschluss gesetzt'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_registrationDeadline != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _registrationDeadline = null;
                      });
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _registrationDeadline ?? _startDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: _startDate?.add(const Duration(days: 365)) ?? DateTime.now().add(const Duration(days: 365)),
                      locale: const Locale('de'),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            dialogTheme: DialogThemeData(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (date != null) {
                      setState(() {
                        _registrationDeadline = date;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('de'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        _startDate = date;
        // Update the text controller to show the selected date
        _startDateController.text = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
      });
    }
  }

  void _selectEndDate() async {
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte wählen Sie zuerst ein Startdatum'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate!,
      firstDate: _startDate!,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('de'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        _endDate = date;
        // Update the text controller to show the selected date
        _endDateController.text = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
      });
    }
  }

  void _saveTournament() async {
    // Log what fields are missing
    print('=== TOURNAMENT SAVE ATTEMPT ===');
    print('Current page: $_currentPage');
    
    // Check individual field values
    print('Name: "${_nameController.text.trim()}"');
    print('Description: "${_descriptionController.text.trim()}"');
    print('City: "${_cityController.text.trim()}"');
    print('Bundesland: "${_bundeslandController.text.trim()}"');
    print('Start Date: $_startDate');
    print('End Date: $_endDate');
    print('Registration Deadline: $_registrationDeadline');
    
    // Validate required fields manually since we're not on the form page
    final missingFields = <String>[];
    
    if (_nameController.text.trim().isEmpty) {
      missingFields.add('Turnier Name');
    }
    
    if (_cityController.text.trim().isEmpty) {
      missingFields.add('Stadt');
    }
    
    if (_startDate == null) {
      missingFields.add('Startdatum');
    }
    
    if (_endDate == null) {
      missingFields.add('Enddatum');
    }
    
    if (missingFields.isNotEmpty) {
      print('❌ Missing required fields: $missingFields');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehlende Pflichtfelder: ${missingFields.join(', ')}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    print('✅ All required fields are present');
    print('================================');

    setState(() {
      _isLoading = true;
    });

    try {
      // Validate required fields
      if (_startDate == null || _endDate == null) {
        print('=== DATE VALIDATION FAILED ===');
        print('Start Date: $_startDate');
        print('End Date: $_endDate');
        print('Start Date Controller: "${_startDateController.text}"');
        print('End Date Controller: "${_endDateController.text}"');
        print('==============================');
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bitte geben Sie Start- und Enddatum an'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      print('=== CREATING TOURNAMENT ===');
      print('Name: "${_nameController.text.trim()}"');
      print('Description: "${_descriptionController.text.trim()}"');
      print('Location: "${_cityController.text.trim()}, ${_bundeslandController.text.trim()}"');
      print('Start Date: $_startDate');
      print('End Date: $_endDate');
      print('Registration Open: $_isRegistrationOpen');
      print('Registration Deadline: $_registrationDeadline');
      print('===========================');
      
      // Get current user to check if they are a Tournament Organizer
      final currentUser = await _authService.currentUser.first;
      String? tournamentOrganizerId;
      
      if (currentUser != null && currentUser.roles.contains(app_user.UserRole.tournamentOrganizer)) {
        tournamentOrganizerId = currentUser.id;
        print('🎯 Tournament Organizer creating tournament: ${currentUser.fullName} (${currentUser.id})');
      }

      final tournament = Tournament(
        id: '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        location: '${_cityController.text.trim()}, ${_bundeslandController.text.trim()}',
        startDate: _startDate!,
        endDate: _endDate!,
        isRegistrationOpen: _isRegistrationOpen,
        registrationDeadline: _registrationDeadline,
        status: 'upcoming',
        tournamentOrganizerId: tournamentOrganizerId,
        approvalStatus: 'pending_approval', // Set to pending approval
      );

      final createdTournament = await TournamentService().createTournament(tournament);

      if (mounted) {
        // Navigate to success screen, replacing the wizard in the stack
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => TournamentCreationSuccessScreen(
              tournament: createdTournament,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Erstellen des Turniers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}