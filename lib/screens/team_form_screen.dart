import 'package:flutter/material.dart';
import '../models/city.dart';
import '../models/team.dart';
import '../models/team_manager.dart';
import '../services/city_service.dart';
import '../services/team_service.dart';
import '../services/team_manager_service.dart';

class TeamFormScreen extends StatefulWidget {
  final Team? team;
  
  const TeamFormScreen({super.key, this.team});

  @override
  State<TeamFormScreen> createState() => _TeamFormScreenState();
}

class _TeamFormScreenState extends State<TeamFormScreen> {
  final TeamService _teamService = TeamService();
  final TeamManagerService _teamManagerService = TeamManagerService();
  final CityService _cityService = CityService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _clubNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _teamManagerController = TextEditingController();

  static const List<String> _countries = [
    'Deutschland', 'Ã–sterreich', 'Niederlande',
    'DÃ¤nemark', 'Norwegen', 'Serbien', 'Frankreich',
  ];
  static const Set<String> _germanStates = {
    'Baden-WÃ¼rttemberg', 'Bayern', 'Berlin', 'Brandenburg', 'Bremen',
    'Hamburg', 'Hessen', 'Mecklenburg-Vorpommern', 'Niedersachsen',
    'Nordrhein-Westfalen', 'Rheinland-Pfalz', 'Saarland', 'Sachsen',
    'Sachsen-Anhalt', 'Schleswig-Holstein', 'ThÃ¼ringen',
  };

  String _selectedCountry = 'Deutschland';
  final _bundeslandController = TextEditingController();
  List<City> _stateCities = [];
  bool _citiesLoading = false;
  City? _selectedCity;
  List<TeamManager> _teamManagers = [];
  TeamManager? _selectedTeamManager;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTeamManagers();
    _initializeForm();
    _loadCitiesForCountry(_selectedCountry);
  }

  void _initializeForm() {
    if (widget.team != null) {
      final team = widget.team!;
      _nameController.text = team.name;
      _clubNameController.text = team.clubName ?? '';
      _cityController.text = team.city;
      _bundeslandController.text = team.bundesland;
      _selectedCountry = _deriveCountry(team.bundesland);
      _teamManagerController.text = team.teamManager ?? '';
    }
  }

  String _deriveCountry(String bundesland) {
    if (_germanStates.contains(bundesland)) return 'Deutschland';
    if (_countries.contains(bundesland)) return bundesland;
    return 'Deutschland';
  }

  Future<void> _loadCitiesForCountry(String country) async {
    if (country.isEmpty) return;
    setState(() => _citiesLoading = true);
    try {
      final cities = await _cityService.getCitiesByCountry(country);
      if (mounted) setState(() => _stateCities = cities);
    } catch (e) {
      debugPrint('Error loading cities for $country: $e');
    } finally {
      if (mounted) setState(() => _citiesLoading = false);
    }
  }

  Future<void> _loadTeamManagers() async {
    try {
      final teamManagers = await _teamManagerService.getAllTeamManagers();
      setState(() {
        _teamManagers = teamManagers;
        // If editing a team with a team manager, find and select it
        if (widget.team?.teamManager != null) {
          _selectedTeamManager = teamManagers.firstWhere(
            (manager) => manager.name == widget.team!.teamManager,
            orElse: () => TeamManager(
              id: '',
              name: widget.team!.teamManager!,
              email: '',
              teamIds: [],
              isActive: true,
              createdAt: DateTime.now(),
            ),
          );
        }
      });
    } catch (e) {
      debugPrint('Error loading team managers: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.team != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Team bearbeiten' : 'Neues Team'),
        backgroundColor: const Color(0xFFffd665),
        foregroundColor: Colors.black87,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.group, color: Colors.black87),
                          const SizedBox(width: 8),
                          const Text(
                            'Team Information',
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
                          labelText: 'Team Name *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.group),
                          hintText: 'z.B. Red Ants',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Bitte geben Sie einen Team Namen ein';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _clubNameController,
                        decoration: const InputDecoration(
                          labelText: 'Vereinsname',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.shield_outlined),
                          hintText: 'z.B. TuS Eicklingen',
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTeamManagerSelector(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
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
                      // 1. Land auswÃ¤hlen (lÃ¤dt nur StÃ¤dte dieses Landes)
                      DropdownButtonFormField<String>(
                        value: _selectedCountry,
                        decoration: const InputDecoration(
                          labelText: 'Land *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.public),
                        ),
                        items: _countries.map((country) {
                          return DropdownMenuItem(
                            value: country,
                            child: Text(country),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedCountry = value;
                            _selectedCity = null;
                            _cityController.clear();
                            _bundeslandController.clear();
                          });
                          _loadCitiesForCountry(value);
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Bitte wÃ¤hlen Sie ein Land';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // 2. Stadt aus dem gewÃ¤hlten Land
                      Autocomplete<City>(
                        displayStringForOption: (City city) => city.name,
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<City>.empty();
                          }
                          final query = textEditingValue.text.toLowerCase();
                          return _stateCities
                              .where((c) => c.name.toLowerCase().contains(query))
                              .take(10);
                        },
                        onSelected: (City city) {
                          setState(() {
                            _selectedCity = city;
                            _cityController.text = city.name;
                            _bundeslandController.text = city.state;
                          });
                        },
                        fieldViewBuilder: (context, textController, focusNode, onSubmitted) {
                          if (_cityController.text.isNotEmpty &&
                              textController.text != _cityController.text) {
                            textController.text = _cityController.text;
                          }
                          return TextFormField(
                            controller: textController,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: 'Stadt *',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.location_city),
                              hintText: _citiesLoading
                                  ? 'StÃ¤dte werden geladen...'
                                  : 'Stadt eingeben...',
                              helperText: _citiesLoading ? 'StÃ¤dte werden geladen...' : null,
                              suffixIcon: _citiesLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: Padding(
                                        padding: EdgeInsets.all(12),
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    )
                                  : null,
                            ),
                            onChanged: (value) {
                              _cityController.text = value;
                              if (!_stateCities.any((c) => c.name == value)) {
                                setState(() {
                                  _selectedCity = null;
                                  _bundeslandController.clear();
                                });
                              }
                            },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Bitte geben Sie eine Stadt ein';
                              }
                              return null;
                            },
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(8),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 200,
                                  maxWidth: 350,
                                ),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder: (context, index) {
                                    final city = options.elementAt(index);
                                    return InkWell(
                                      onTap: () => onSelected(city),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Colors.grey.shade200,
                                              width: 0.5,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          city.name,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      // 3. Bundesland / Region â€“ automatisch aus gewÃ¤hlter Stadt
                      TextFormField(
                        controller: _bundeslandController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Bundesland / Region',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.map),
                          fillColor: Colors.grey.shade100,
                          filled: true,
                          helperText: _selectedCity == null
                              ? 'Wird automatisch aus der Stadt Ã¼bernommen'
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveTeam,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          isEditing ? 'Team speichern' : 'Team erstellen',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamManagerSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Autocomplete<TeamManager>(
          displayStringForOption: (TeamManager option) => option.name,
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<TeamManager>.empty();
            }
            return _teamManagers.where((TeamManager manager) {
              final searchLower = textEditingValue.text.toLowerCase();
              return manager.name.toLowerCase().contains(searchLower) ||
                     manager.email.toLowerCase().contains(searchLower);
            }).take(10); // Limit to 10 results for performance
          },
          onSelected: (TeamManager selection) {
            setState(() {
              _selectedTeamManager = selection;
              _teamManagerController.text = selection.name;
            });
          },
          fieldViewBuilder: (
            BuildContext context,
            TextEditingController textEditingController,
            FocusNode focusNode,
            VoidCallback onFieldSubmitted,
          ) {
            // Sync the controller with our main team manager controller
            if (_teamManagerController.text.isNotEmpty && 
                textEditingController.text != _teamManagerController.text) {
              textEditingController.text = _teamManagerController.text;
            }
            
            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: 'Team Manager (optional)',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person),
                hintText: 'Name oder E-Mail eingeben...',
                suffixIcon: textEditingController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          textEditingController.clear();
                          setState(() {
                            _selectedTeamManager = null;
                            _teamManagerController.clear();
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                _teamManagerController.text = value;
                // If the text doesn't match any manager exactly, clear the selection
                if (!_teamManagers.any((manager) => manager.name == value)) {
                  setState(() {
                    _selectedTeamManager = null;
                  });
                }
              },
            );
          },
          optionsViewBuilder: (
            BuildContext context,
            AutocompleteOnSelected<TeamManager> onSelected,
            Iterable<TeamManager> options,
          ) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 250, maxWidth: 300),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final TeamManager option = options.elementAt(index);
                      return InkWell(
                        onTap: () => onSelected(option),
                        child: Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey.shade200,
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (option.email.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  option.email,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              if (option.phone != null && option.phone!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  option.phone!,
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                              // Show number of teams managed
                              if (option.teamIds.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFffd665).withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${option.teamIds.length} Team${option.teamIds.length != 1 ? 's' : ''}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
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
        ),
        const SizedBox(height: 8),
        // Show selected manager info
        if (_selectedTeamManager != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFffd665).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFffd665).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AusgewÃ¤hlt: ${_selectedTeamManager!.name}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      if (_selectedTeamManager!.email.isNotEmpty)
                        Text(
                          _selectedTeamManager!.email,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () {
                    setState(() {
                      _selectedTeamManager = null;
                      _teamManagerController.clear();
                    });
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        // Show helpful message when no managers exist
        if (_teamManagers.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.orange.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Colors.orange,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Keine Team Manager gefunden. Erstellen Sie zuerst Team Manager in der Team Manager Verwaltung.',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _saveTeam() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final team = Team(
        id: widget.team?.id ?? '',
        name: _nameController.text.trim(),
        clubName: _clubNameController.text.trim().isEmpty ? null : _clubNameController.text.trim(),
        teamManager: _selectedTeamManager?.name,
        city: _cityController.text.trim(),
        bundesland: _bundeslandController.text.isNotEmpty
            ? _bundeslandController.text
            : _selectedCountry,
        createdAt: widget.team?.createdAt ?? DateTime.now(),
      );

      bool success;
      String? teamId;
      
      if (widget.team == null) {
        // Creating new team
        debugPrint('Creating team: ${team.name} with manager: ${team.teamManager}');
        await _teamService.addTeam(team);
        success = true;
        debugPrint('Team creation success: $success');
        
        // Get the created team ID by finding the team with matching name and manager
        if (success) {
          debugPrint('Looking for created team...');
          final teams = await _teamService.getTeams().first;
          debugPrint('Found ${teams.length} total teams');
          
          final createdTeam = teams.firstWhere(
            (t) => t.name == team.name && t.teamManager == team.teamManager,
            orElse: () => Team(id: '', name: '', city: '', bundesland: '', createdAt: DateTime.now()),
          );
          teamId = createdTeam.id;
          debugPrint('Found team ID: $teamId');
        }
        
        // If team was created and assigned to a team manager, add team to manager
        if (success && _selectedTeamManager != null && teamId != null && teamId.isNotEmpty) {
          debugPrint('Assigning team to manager: ${_selectedTeamManager!.name} (ID: ${_selectedTeamManager!.id})');
          final assignSuccess = await _teamManagerService.assignTeamToManager(_selectedTeamManager!.id, teamId);
          debugPrint('Team assignment to manager success: $assignSuccess');
        }
      } else {
        // Updating existing team
        success = await _teamService.updateTeam(widget.team!.id, team);
        teamId = widget.team!.id;
        
        // Handle team manager assignment changes
        if (success) {
          final oldManagerName = widget.team!.teamManager;
          final newManagerName = _selectedTeamManager?.name;
          
          if (oldManagerName != newManagerName) {
            // Remove from old manager if there was one
            if (oldManagerName != null) {
              final oldManager = await _teamManagerService.getTeamManagerByEmail(''); // We'll need to find by name
              // For now, we'll handle this in a simpler way by just adding to new manager
            }
            
            // Add to new manager if selected
            if (_selectedTeamManager != null) {
              await _teamManagerService.assignTeamToManager(_selectedTeamManager!.id, widget.team!.id);
            }
          }
        }
      }

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.team == null 
                ? 'Team erfolgreich erstellt!' 
                : 'Team erfolgreich aktualisiert!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fehler beim Speichern des Teams'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    _nameController.dispose();
    _clubNameController.dispose();
    _cityController.dispose();
    _bundeslandController.dispose();
    _teamManagerController.dispose();
    super.dispose();
  }
} 