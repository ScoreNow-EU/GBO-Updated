import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/german_cities.dart';
import '../models/tournament.dart';
import '../models/tournament_criteria.dart';
import '../services/tournament_service.dart';
import '../utils/app_colors.dart';

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
  int _currentPage = 0;
  bool _isLoading = false;

  // Basic Info
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _cityController;
  late final TextEditingController _bundeslandController;
  GermanCity? _selectedCity;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _cityController = TextEditingController();
    _bundeslandController = TextEditingController(text: 'Baden-Württemberg');
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
  // Categories and Divisions
  final List<String> _availableCategories = [
    'GBO Juniors Cup',
    'GBO Seniors Cup',
  ];
  List<String> _selectedCategories = [];
  List<String> _selectedDivisions = [];
  Map<String, int> _divisionMaxTeams = {};
  
  // Criteria
  TournamentCriteria _criteria = TournamentCriteria();
  bool _skipCriteria = false;
  
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
                        _buildCategoriesPage(),
                        if (!_skipCriteria) ...[
                          _buildCriteriaPage1(),
                          _buildCriteriaPage2(),
                          _buildCriteriaPage3(),
                          _buildCriteriaPage4(),
                        ],
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
                        _skipCriteria ? 4 : 9,
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
                            if (_currentPage == (_skipCriteria ? 3 : 8)) {
                              _saveTournament();
                            } else {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          icon: Icon(
                            _currentPage == (_skipCriteria ? 3 : 8) ? Icons.check_circle :
                            _currentPage == (_skipCriteria ? 2 : 7) ? Icons.preview :
                            Icons.arrow_forward
                          ),
                          label: Text(
                            _currentPage == (_skipCriteria ? 3 : 8) ? 'Erstellen' :
                            _currentPage == (_skipCriteria ? 2 : 7) ? 'Überprüfen' :
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
                Autocomplete<GermanCity>(
                  displayStringForOption: (GermanCity option) => option.name,
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<GermanCity>.empty();
                    }
                    return GermanCities.searchCities(textEditingValue.text).take(10);
                  },
                  onSelected: (GermanCity selection) {
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
                        if (_selectedCity != null && value != _selectedCity!.name) {
                          setState(() {
                            _selectedCity = null;
                            _bundeslandController.text = '';
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

  Widget _buildCategoriesPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kategorien & Divisionen',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Categories
          const Text(
            'Wählen Sie die Kategorien:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableCategories.map((category) {
              final isSelected = _selectedCategories.contains(category);
              return FilterChip(
                label: Text(category),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedCategories.add(category);
                    } else {
                      _selectedCategories.remove(category);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Divisions (only show if categories are selected)
          if (_selectedCategories.isNotEmpty) ...[
            const Text(
              'Wählen Sie die Divisionen:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ..._selectedCategories.map((category) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category == 'GBO Juniors Cup' ? 'Jugend Divisionen:' : 'Senioren Divisionen:',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _getAvailableDivisionsForCategory(category).map((division) {
                      final isSelected = _selectedDivisions.contains(division);
                      return FilterChip(
                        label: Text(division),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedDivisions.add(division);
                              _divisionMaxTeams[division] = 32; // Default max teams
                            } else {
                              _selectedDivisions.remove(division);
                              _divisionMaxTeams.remove(division);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  List<String> _getAvailableDivisionsForCategory(String category) {
    if (category == 'GBO Juniors Cup') {
      return [
        'Women\'s U14',
        'Women\'s U16',
        'Women\'s U18',
        'Men\'s U14',
        'Men\'s U16',
        'Men\'s U18',
      ];
    } else {
      return [
        'Women\'s Seniors',
        'Women\'s FUN',
        'Men\'s Seniors',
        'Men\'s FUN',
      ];
    }
  }

  // Basic Rules & Requirements
  Widget _buildCriteriaPage1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Grundlegende Regeln & Anforderungen',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Diese Kriterien sind grundlegend für die Turnierqualität',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),

          // MUST Criteria Section
          _buildSectionTitle('MUST Kriterien (je 30 Punkte)'),
          CheckboxListTile(
            title: const Text('Offizielle Beachhandball-Regeln'),
            subtitle: const Text('Spiele werden nach offiziellen Regeln durchgeführt'),
            value: _criteria.officialBeachhandballRules,
            onChanged: (value) {
              setState(() {
                _criteria = _criteria.copyWith(officialBeachhandballRules: value);
              });
            },
          ),
          CheckboxListTile(
            title: const Text('Zwei Schiedsrichter pro Spiel'),
            subtitle: const Text('Jedes Spiel wird von zwei Schiedsrichtern geleitet'),
            value: _criteria.twoRefereesPerGame,
            onChanged: (value) {
              setState(() {
                _criteria = _criteria.copyWith(twoRefereesPerGame: value);
              });
            },
          ),
          CheckboxListTile(
            title: const Text('Clean Zone'),
            subtitle: const Text('Spielfeld und Umgebung sind sauber und professionell'),
            value: _criteria.cleanZone,
            onChanged: (value) {
              setState(() {
                _criteria = _criteria.copyWith(cleanZone: value);
              });
            },
          ),
          CheckboxListTile(
            title: const Text('Ausspielen Platz 1-8'),
            subtitle: const Text('Platzierungsspiele für die Top 8 Teams'),
            value: _criteria.ausspielenPlatz1To8,
            onChanged: (value) {
              setState(() {
                _criteria = _criteria.copyWith(ausspielenPlatz1To8: value);
              });
            },
          ),

          const SizedBox(height: 24),
          // Basic Setup Section
          _buildSectionTitle('Grundlegende Einrichtung'),
          CheckboxListTile(
            title: const Text('Technisches Meeting (20 Punkte)'),
            subtitle: const Text('Verpflichtend für Supercup'),
            value: _criteria.technicalMeeting,
            onChanged: (value) {
              setState(() {
                _criteria = _criteria.copyWith(technicalMeeting: value);
              });
            },
          ),
          ListTile(
            title: const Text('Turniertage'),
            subtitle: const Text('Mehrtägige Turniere erhalten 20 Zusatzpunkte'),
            trailing: DropdownButton<int>(
              value: _criteria.tournamentDays,
              items: List.generate(5, (index) => index + 1).map((days) {
                return DropdownMenuItem(
                  value: days,
                  child: Text('$days ${days == 1 ? 'Tag' : 'Tage'}'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _criteria = _criteria.copyWith(tournamentDays: value);
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // Placeholder widgets for remaining criteria pages
  // Referees & Officials
  Widget _buildCriteriaPage2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Schiedsrichter & Offizielle',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Maximale Punktzahl: 250 für Schiedsrichter, 180 für Offizielle',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),

          // Referees Section
          _buildSectionTitle('Schiedsrichter (max. 250 Punkte)'),
          ListTile(
            title: const Text('EHF Kader (25 Punkte pro Person)'),
            trailing: DropdownButton<int>(
              value: _criteria.ehfKaderReferees,
              items: List.generate(11, (index) => index).map((count) {
                return DropdownMenuItem(
                  value: count,
                  child: Text(count.toString()),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _criteria = _criteria.copyWith(ehfKaderReferees: value);
                  });
                }
              },
            ),
          ),
          ListTile(
            title: const Text('DHB Elite Kader (20 Punkte pro Person)'),
            trailing: DropdownButton<int>(
              value: _criteria.dhbEliteKaderReferees,
              items: List.generate(11, (index) => index).map((count) {
                return DropdownMenuItem(
                  value: count,
                  child: Text(count.toString()),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _criteria = _criteria.copyWith(dhbEliteKaderReferees: value);
                  });
                }
              },
            ),
          ),
          ListTile(
            title: const Text('DHB Stamm Kader (15 Punkte pro Person)'),
            trailing: DropdownButton<int>(
              value: _criteria.dhbStammKaderReferees,
              items: List.generate(11, (index) => index).map((count) {
                return DropdownMenuItem(
                  value: count,
                  child: Text(count.toString()),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _criteria = _criteria.copyWith(dhbStammKaderReferees: value);
                  });
                }
              },
            ),
          ),
          ListTile(
            title: const Text('Perspektiv Kader (10 Punkte pro Person)'),
            trailing: DropdownButton<int>(
              value: _criteria.perspektivKaderReferees,
              items: List.generate(11, (index) => index).map((count) {
                return DropdownMenuItem(
                  value: count,
                  child: Text(count.toString()),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _criteria = _criteria.copyWith(perspektivKaderReferees: value);
                  });
                }
              },
            ),
          ),
          ListTile(
            title: const Text('Basis Lizenz (5 Punkte pro Person, max. 50 Punkte)'),
            trailing: DropdownButton<int>(
              value: _criteria.basisLizenzReferees,
              items: List.generate(11, (index) => index).map((count) {
                return DropdownMenuItem(
                  value: count,
                  child: Text(count.toString()),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _criteria = _criteria.copyWith(basisLizenzReferees: value);
                  });
                }
              },
            ),
          ),

          const SizedBox(height: 24),
          // Officials Section
          _buildSectionTitle('Offizielle (max. 180 Punkte)'),
          CheckboxListTile(
            title: const Text('EBT Delegierter (100 Punkte)'),
            value: _criteria.ebtDelegate,
            onChanged: (value) {
              setState(() {
                _criteria = _criteria.copyWith(ebtDelegate: value);
              });
            },
          ),
          CheckboxListTile(
            title: const Text('DHB National Delegierter (80 Punkte)'),
            value: _criteria.dhbNationalDelegate,
            onChanged: (value) {
              setState(() {
                _criteria = _criteria.copyWith(dhbNationalDelegate: value);
              });
            },
          ),
          CheckboxListTile(
            title: const Text('Zeitnehmer gestellt (20 Punkte)'),
            value: _criteria.zeitnehmerGestellt,
            onChanged: (value) {
              setState(() {
                _criteria = _criteria.copyWith(zeitnehmerGestellt: value);
              });
            },
          ),
        ],
      ),
    );
  }
  // Infrastructure & Equipment
  Widget _buildCriteriaPage3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Infrastruktur & Ausstattung',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Technische Ausstattung und Spielfeldeinrichtung',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),

          // Court & Equipment Section
          _buildSectionTitle('Spielfeld & Ausstattung'),
          CheckboxListTile(
            title: const Text('Fangnetze/Zäune (30 Punkte)'),
            value: _criteria.fangneatzeZaeune,
            onChanged: (value) {
              setState(() {
                _criteria = _criteria.copyWith(fangneatzeZaeune: value);
              });
            },
          ),
          CheckboxListTile(
            title: const Text('Sitztribüne (60 Punkte)'),
            value: _criteria.sitztribuene,
            onChanged: (value) {
              setState(() {
                _criteria = _criteria.copyWith(sitztribuene: value);
              });
            },
          ),
          CheckboxListTile(
            title: const Text('Spielfeldumrandung (30 Punkte)'),
            value: _criteria.spielfeldumrandung,
            onChanged: (value) {
              setState(() {
                _criteria = _criteria.copyWith(spielfeldumrandung: value);
              });
            },
          ),
          CheckboxListTile(
            title: const Text('Offizielle Maße für alle Beachplätze (20 Punkte)'),
            value: _criteria.alleBeachplaetzeOffiziellesMasse,
            onChanged: (value) {
              setState(() {
                _criteria = _criteria.copyWith(alleBeachplaetzeOffiziellesMasse: value);
              });
            },
          ),

          const SizedBox(height: 24),
          // Technical Equipment Section
          _buildSectionTitle('Technische Ausstattung'),
          CheckboxListTile(
            title: const Text('GBO Online Spielplan (100 Punkte)'),
            value: _criteria.gboOnlineSchedule,
            onChanged: (value) {
              setState(() {
                _criteria = _criteria.copyWith(gboOnlineSchedule: value);
              });
            },
          ),
          CheckboxListTile(
            title: const Text('GBO Scoring System (50 Punkte)'),
            value: _criteria.gboScoringSystem,
            onChanged: (value) {
              setState(() {
                _criteria = _criteria.copyWith(gboScoringSystem: value);
              });
            },
          ),
          CheckboxListTile(
            title: const Text('Elektronische Anzeigetafeln (40 Punkte)'),
            value: _criteria.elektronischeAnzeigetafeln,
            onChanged: (value) {
              setState(() {
                _criteria = _criteria.copyWith(elektronischeAnzeigetafeln: value);
              });
            },
          ),
        ],
      ),
    );
  }
  // Additional Services & Features
  Widget _buildCriteriaPage4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Zusätzliche Services & Features',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Zusatzleistungen und besondere Merkmale',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),

          // Location & Services Section
          _buildSectionTitle('Standort & Services'),
          CheckboxListTile(
            title: const Text('Turnier im Stadtzentrum (250 Punkte)'),
            value: _criteria.tournamentInTownCenter,
            onChanged: (value) {
              setState(() {
                _criteria = _criteria.copyWith(tournamentInTownCenter: value);
              });
            },
          ),
          CheckboxListTile(
            title: const Text('Sanitäterdienst (20 Punkte)'),
            value: _criteria.sanitaeterdienst,
            onChanged: (value) {
              setState(() {
                _criteria = _criteria.copyWith(sanitaeterdienst: value);
              });
            },
          ),
          CheckboxListTile(
            title: const Text('Wasser für Spieler (20 Punkte)'),
            value: _criteria.waterForPlayers,
            onChanged: (value) {
              setState(() {
                _criteria = _criteria.copyWith(waterForPlayers: value);
              });
            },
          ),

          const SizedBox(height: 24),
          // Media & Entertainment Section
          _buildSectionTitle('Medien & Unterhaltung'),
          ListTile(
            title: const Text('Livestream Option'),
            subtitle: const Text('Verschiedene Optionen mit unterschiedlichen Punktzahlen'),
            trailing: DropdownButton<String>(
              value: _criteria.livestreamOption,
              items: const [
                DropdownMenuItem(value: 'none', child: Text('Keine')),
                DropdownMenuItem(value: 'swtv_crew', child: Text('SWTV Crew (250 P.)')),
                DropdownMenuItem(value: 'swtv_remote', child: Text('SWTV Remote (250 P.)')),
                DropdownMenuItem(value: 'swtv_twitch', child: Text('SWTV Twitch (150 P.)')),
                DropdownMenuItem(value: 'own_stream', child: Text('Eigener Stream (50 P.)')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _criteria = _criteria.copyWith(livestreamOption: value);
                  });
                }
              },
            ),
          ),
          ListTile(
            title: const Text('EBT Status'),
            subtitle: const Text('Punktzahl basierend auf EBT-Ranking'),
            trailing: DropdownButton<int>(
              value: _criteria.ebtStatus,
              items: const [
                DropdownMenuItem(value: 0, child: Text('Kein EBT')),
                DropdownMenuItem(value: 1, child: Text('1-99 (20 P.)')),
                DropdownMenuItem(value: 100, child: Text('100-149 (40 P.)')),
                DropdownMenuItem(value: 150, child: Text('150-199 (60 P.)')),
                DropdownMenuItem(value: 200, child: Text('200-249 (80 P.)')),
                DropdownMenuItem(value: 250, child: Text('250-299 (100 P.)')),
                DropdownMenuItem(value: 300, child: Text('300+ (150 P.)')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _criteria = _criteria.copyWith(ebtStatus: value);
                  });
                }
              },
            ),
          ),
          CheckboxListTile(
            title: const Text('Arena Kommentator (20 Punkte)'),
            value: _criteria.arenaCommentator,
            onChanged: (value) {
              setState(() {
                _criteria = _criteria.copyWith(arenaCommentator: value);
              });
            },
          ),
          CheckboxListTile(
            title: const Text('Turnierauszeichnungen (20 Punkte)'),
            value: _criteria.tournierauszeichnungen,
            onChanged: (value) {
              setState(() {
                _criteria = _criteria.copyWith(tournierauszeichnungen: value);
              });
            },
          ),

          const SizedBox(height: 24),
          // Points Summary
          _buildSectionTitle('Punkteübersicht'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gesamtpunkte: ${_criteria.totalPoints}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_criteria.checkSupercupEligibility()) ...[
                    const SizedBox(height: 8),
                    const Text(
                      '✨ Supercup Bonus: +150 Punkte',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
                    'Kategorien & Divisionen',
                    Icons.sports_volleyball,
                    [
                      'Ausgewählte Kategorien:',
                      ..._selectedCategories.map((cat) => '• $cat'),
                      '',
                      'Ausgewählte Divisionen:',
                      ..._selectedDivisions.map((div) => '• $div'),
                    ],
                  ),
                  if (!_skipCriteria) ...[
                    const Divider(),
                    _buildSummarySection(
                      'Turnier-Kriterien',
                      Icons.rule,
                      [
                        'Kriterien wurden angepasst',
                      ],
                    ),
                  ],
                  const Divider(),
                  _buildSummarySection(
                    'Teams',
                    Icons.group,
                    [
                      'Registrierung: ${_isRegistrationOpen ? 'Offen' : 'Geschlossen'}',
                      if (_registrationDeadline != null)
                        'Anmeldefrist: ${_registrationDeadline!.day}.${_registrationDeadline!.month}.${_registrationDeadline!.year}',
                      '',
                      'Maximale Teams pro Division:',
                      ..._selectedDivisions.map((div) => 
                        '• $div: ${_divisionMaxTeams[div] ?? 32} Teams'
                      ),
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
            'Konfigurieren Sie die Team-Anmeldungen für jede Division',
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

          // Division Settings
          _buildSectionTitle('Divisions & Maximale Teams'),
          if (_selectedDivisions.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade800),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Wählen Sie zuerst Divisions in der Kategorien-Seite aus',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _selectedDivisions.length,
              itemBuilder: (context, index) {
                final division = _selectedDivisions[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          division,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Maximale Teams',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 100,
                              child: TextFormField(
                                initialValue: (_divisionMaxTeams[division] ?? 32).toString(),
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                  border: const OutlineInputBorder(),
                                  suffixText: 'Teams',
                                  suffixStyle: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(3),
                                ],
                                onChanged: (value) {
                                  final number = int.tryParse(value);
                                  if (number != null && number > 0) {
                                    setState(() {
                                      _divisionMaxTeams[division] = number;
                                    });
                                  }
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Erforderlich';
                                  }
                                  final number = int.tryParse(value);
                                  if (number == null || number <= 0) {
                                    return 'Ungültig';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
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
    print('Categories: $_selectedCategories');
    print('Divisions: $_selectedDivisions');
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
    
    if (_selectedCategories.isEmpty) {
      missingFields.add('Kategorien');
    }
    
    if (_selectedDivisions.isEmpty) {
      missingFields.add('Divisionen');
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
      print('Categories: $_selectedCategories');
      print('Divisions: $_selectedDivisions');
      print('Registration Open: $_isRegistrationOpen');
      print('Registration Deadline: $_registrationDeadline');
      print('===========================');
      
      final tournament = Tournament(
        id: '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        location: '${_cityController.text.trim()}, ${_bundeslandController.text.trim()}',
        startDate: _startDate!,
        endDate: _endDate!,
        categories: _selectedCategories.toList(),
        divisions: _selectedDivisions.toList(),
        divisionMaxTeams: _divisionMaxTeams,
        criteria: _criteria,
        isRegistrationOpen: _isRegistrationOpen,
        registrationDeadline: _registrationDeadline,
        points: 0,
        status: 'upcoming',
      );

      await TournamentService().addTournament(tournament);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turnier erfolgreich erstellt'),
            backgroundColor: Colors.green,
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