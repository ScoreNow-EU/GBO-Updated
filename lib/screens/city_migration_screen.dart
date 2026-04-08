import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import '../data/german_cities.dart'; // Keep for migration comparison only
import '../models/city.dart';
import '../models/state.dart';
import '../models/team.dart';
import '../services/city_service.dart';
import '../services/team_service.dart';
import '../utils/responsive_helper.dart';
import '../utils/firebase_cities_helper.dart';
import 'package:toastification/toastification.dart';

class CityMigrationScreen extends StatefulWidget {
  const CityMigrationScreen({super.key});

  @override
  State<CityMigrationScreen> createState() => _CityMigrationScreenState();
}

class _CityMigrationScreenState extends State<CityMigrationScreen> {
  final CityService _cityService = CityService();
  final TeamService _teamService = TeamService();
  
  // File data
  List<String> fileStates = [];
  List<GermanCity> fileCities = [];
  String selectedFileState = '';
  List<GermanCity> filteredFileCities = [];
  
  // Firebase data
  List<GermanState> firebaseStates = [];
  List<City> firebaseCities = [];
  String selectedFirebaseState = '';
  List<City> filteredFirebaseCities = [];
  
  // CSV data
  List<City> csvCities = [];
  bool hasCsvData = false;
  
  // Teams data
  List<Team> teams = [];
  Map<String, String> teamCityMatches = {};
  
  bool isLoading = true;
  bool isMigrating = false;
  bool isMatchingTeams = false;
  bool isSyncingStates = false;
  Map<String, int> statistics = {'cities': 0, 'states': 0};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    
    try {
      // Load file data
      _loadFileData();
      
      // Load Firebase data
      await _loadFirebaseData();
      
      // Get statistics
      await _loadStatistics();
      
    } catch (e) {
      _showErrorToast('Fehler beim Laden der Daten: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _loadFileData() {
    // Extract unique states from file data
    final states = GermanCities.cities
        .map((city) => city.state)
        .toSet()
        .toList();
    states.sort();
    
    setState(() {
      fileStates = states;
      fileCities = GermanCities.cities;
      filteredFileCities = fileCities;
    });
  }

  Future<void> _loadFirebaseData() async {
    try {
      final states = await _cityService.getAllStates();
      final cities = await _cityService.getAllCities();
      
      setState(() {
        firebaseStates = states;
        firebaseCities = cities;
        filteredFirebaseCities = cities;
      });
    } catch (e) {
      debugPrint('Error loading Firebase data: $e');
    }
  }

  Future<void> _loadStatistics() async {
    try {
      final stats = await _cityService.getStatistics();
      setState(() {
        statistics = stats;
      });
    } catch (e) {
      debugPrint('Error loading statistics: $e');
    }
  }

  void _filterFileCities(String state) {
    setState(() {
      selectedFileState = state;
      filteredFileCities = state.isEmpty 
          ? fileCities 
          : fileCities.where((city) => city.state == state).toList();
    });
  }

  void _filterFirebaseCities(String state) {
    setState(() {
      selectedFirebaseState = state;
      filteredFirebaseCities = state.isEmpty 
          ? firebaseCities 
          : firebaseCities.where((city) => city.state == state).toList();
    });
  }

  Future<void> _migrateToFirebase() async {
    setState(() => isMigrating = true);
    
    try {
      // First, migrate states
      _showInfoToast('Migriere BundeslÃ¤nder...');
      
      final statesToMigrate = fileStates.map((stateName) {
        const stateAbbreviations = {
          'Baden-WÃ¼rttemberg': 'BW',
          'Bayern': 'BAY',
          'Berlin': 'BER',
          'Brandenburg': 'BRA',
          'Bremen': 'BRE',
          'Hamburg': 'HAM',
          'Hessen': 'HES',
          'Mecklenburg-Vorpommern': 'MVP',
          'Niedersachsen': 'NDS',
          'Nordrhein-Westfalen': 'NRW',
          'Rheinland-Pfalz': 'RLP',
          'Saarland': 'SAA',
          'Sachsen': 'SAC',
          'Sachsen-Anhalt': 'SAH',
          'Schleswig-Holstein': 'SHL',
          'ThÃ¼ringen': 'THU',
          // International "states" (countries)
          'DÃ¤nemark': 'DK',
          'Norwegen': 'NO',
          'Niederlande': 'NL',
          'Serbien': 'SRB',
          'Frankreich': 'FRA',
        };
        
        final abbreviation = stateAbbreviations[stateName] ?? 
            stateName.substring(0, 3).toUpperCase();
        
        final country = _isInternational(stateName) ? stateName : 'Deutschland';
        
        return GermanState(
          id: '', // Will be set by Firestore
          name: stateName,
          abbreviation: abbreviation,
          country: country,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }).toList();
      
      final statesSuccess = await _cityService.batchAddStates(statesToMigrate);
      if (!statesSuccess) {
        throw Exception('Fehler beim Migrieren der BundeslÃ¤nder');
      }
      
      _showSuccessToast('${statesToMigrate.length} BundeslÃ¤nder migriert');
      
      // Then, migrate cities
      _showInfoToast('Migriere StÃ¤dte...');
      
      final citiesToMigrate = fileCities.map((fileCity) {
        final country = _isInternational(fileCity.state) ? fileCity.state : 'Deutschland';
        return City(
          id: '', // Will be set by Firestore
          name: fileCity.name,
          state: fileCity.state,
          country: country,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }).toList();
      
      final citiesSuccess = await _cityService.batchAddCities(citiesToMigrate);
      if (!citiesSuccess) {
        throw Exception('Fehler beim Migrieren der StÃ¤dte');
      }
      
      _showSuccessToast('${citiesToMigrate.length} StÃ¤dte migriert');
      
      // Reload Firebase data
      await _loadFirebaseData();
      await _loadStatistics();
      
      _showSuccessToast('Migration erfolgreich abgeschlossen!');
      
    } catch (e) {
      _showErrorToast('Migration fehlgeschlagen: $e');
    } finally {
      setState(() => isMigrating = false);
    }
  }

  Future<void> _clearFirebaseData() async {
    final confirmed = await _showConfirmationDialog(
      'Firebase Daten lÃ¶schen',
      'MÃ¶chten Sie wirklich alle StÃ¤dte und BundeslÃ¤nder aus Firebase lÃ¶schen? Diese Aktion kann nicht rÃ¼ckgÃ¤ngig gemacht werden.',
    );
    
    if (!confirmed) return;
    
    setState(() => isMigrating = true);
    
    try {
      _showInfoToast('LÃ¶sche Firebase Daten...');
      
      final citiesSuccess = await _cityService.clearAllCities();
      final statesSuccess = await _cityService.clearAllStates();
      
      if (citiesSuccess && statesSuccess) {
        _showSuccessToast('Firebase Daten erfolgreich gelÃ¶scht');
        await _loadFirebaseData();
        await _loadStatistics();
      } else {
        throw Exception('Fehler beim LÃ¶schen der Daten');
      }
    } catch (e) {
      _showErrorToast('Fehler beim LÃ¶schen: $e');
    } finally {
      setState(() => isMigrating = false);
    }
  }

  Future<void> _importCsvFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );
      
      if (result == null || result.files.isEmpty) return;
      
      final file = result.files.first;
      if (file.bytes == null) {
        _showErrorToast('Fehler beim Lesen der Datei');
        return;
      }
      
      setState(() => isMigrating = true);
      _showInfoToast('CSV wird verarbeitet...');
      
      final csvContent = utf8.decode(file.bytes!);
      final cities = await _cityService.parseCitiesFromCsv(csvContent);
      
      if (cities.isEmpty) {
        _showErrorToast('Keine gÃ¼ltigen StÃ¤dte in der CSV-Datei gefunden');
        return;
      }
      
      setState(() {
        csvCities = cities;
        hasCsvData = true;
      });
      
      _showSuccessToast('${cities.length} StÃ¤dte aus CSV geladen');
      
    } catch (e) {
      _showErrorToast('Fehler beim Importieren der CSV: $e');
    } finally {
      setState(() => isMigrating = false);
    }
  }

  Future<void> _importCsvToFirebase() async {
    if (csvCities.isEmpty) {
      _showErrorToast('Keine CSV-Daten zum Importieren');
      return;
    }
    
    setState(() => isMigrating = true);
    
    try {
      _showInfoToast('Importiere ${csvCities.length} StÃ¤dte nach Firebase...');
      
      final success = await _cityService.batchAddCities(csvCities);
      if (success) {
        _showSuccessToast('${csvCities.length} StÃ¤dte erfolgreich importiert');
        await _loadFirebaseData();
        await _loadStatistics();
      } else {
        throw Exception('Import fehlgeschlagen');
      }
    } catch (e) {
      _showErrorToast('Fehler beim Importieren: $e');
    } finally {
      setState(() => isMigrating = false);
    }
  }

  Future<void> _loadTeams() async {
    try {
      final allTeams = await _teamService.getAllTeams();
      setState(() {
        teams = allTeams;
      });
    } catch (e) {
      debugPrint('Error loading teams: $e');
    }
  }

  Future<void> _matchTeamsToCities() async {
    if (teams.isEmpty) {
      await _loadTeams();
    }
    
    if (teams.isEmpty) {
      _showErrorToast('Keine Teams gefunden');
      return;
    }
    
    setState(() => isMatchingTeams = true);
    
    try {
      _showInfoToast('Gleiche Teams mit StÃ¤dten ab...');
      
      final matches = await _cityService.matchTeamsToCities(teams);
      
      setState(() {
        teamCityMatches = matches;
      });
      
      _showSuccessToast('${matches.length} von ${teams.length} Teams erfolgreich zugeordnet');
      
    } catch (e) {
      _showErrorToast('Fehler beim Zuordnen: $e');
    } finally {
      setState(() => isMatchingTeams = false);
    }
  }

  Future<void> _applyTeamMatches() async {
    if (teamCityMatches.isEmpty) {
      _showErrorToast('Keine Team-Zuordnungen vorhanden');
      return;
    }
    
    setState(() => isMigrating = true);
    
    try {
      _showInfoToast('Aktualisiere Teams mit Stadt-IDs...');
      
      final success = await _cityService.updateTeamsWithCityIds(teamCityMatches);
      if (success) {
        _showSuccessToast('${teamCityMatches.length} Teams erfolgreich aktualisiert');
      } else {
        throw Exception('Update fehlgeschlagen');
      }
    } catch (e) {
      _showErrorToast('Fehler beim Aktualisieren: $e');
    } finally {
      setState(() => isMigrating = false);
    }
  }

  Future<void> _syncStatesFromCities() async {
    setState(() => isSyncingStates = true);
    
    try {
      _showInfoToast('Synchronisiere BundeslÃ¤nder aus StÃ¤dten...');
      
      final result = await FirebaseCitiesHelper.syncStatesFromCities();
      
      if (result['success'] == true) {
        final added = result['added'] as int;
        final existing = result['existing'] as int;
        final total = result['total'] as int;
        
        if (added > 0) {
          final newStates = result['newStates'] as List<String>;
          _showSuccessToast(
            '${result['message']}\n'
            'Neue BundeslÃ¤nder: ${newStates.join(', ')}\n'
            'Gesamt: $total BundeslÃ¤nder ($existing bereits vorhanden, $added hinzugefÃ¼gt)'
          );
        } else {
          _showInfoToast('${result['message']} ($total BundeslÃ¤nder insgesamt)');
        }
        
        // Reload data to show updated states
        await _loadFirebaseData();
        await _loadStatistics();
        
      } else {
        _showErrorToast(result['message'] as String);
      }
    } catch (e) {
      _showErrorToast('Fehler beim Synchronisieren: $e');
    } finally {
      setState(() => isSyncingStates = false);
    }
  }

  bool _isInternational(String stateName) {
    return ['DÃ¤nemark', 'Norwegen', 'Niederlande', 'Serbien', 'Frankreich'].contains(stateName);
  }

  Future<bool> _showConfirmationDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('LÃ¶schen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showErrorToast(String message) {
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.fillColored,
      title: const Text('Fehler'),
      description: Text(message),
      autoCloseDuration: const Duration(seconds: 5),
    );
  }

  void _showSuccessToast(String message) {
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.fillColored,
      title: const Text('Erfolg'),
      description: Text(message),
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  void _showInfoToast(String message) {
    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.fillColored,
      title: const Text('Info'),
      description: Text(message),
      autoCloseDuration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveHelper.isMobile(screenWidth);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(isMobile),
          const SizedBox(height: 24),
          
          // Statistics and Actions
          _buildStatisticsAndActions(isMobile),
          const SizedBox(height: 24),
          
          // Main Content
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6, // 60% of screen height
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildComparisonView(isMobile),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.sync_alt,
            color: Colors.blue.shade700,
            size: 32,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'StÃ¤dte Migration',
                style: TextStyle(
                  fontSize: isMobile ? 20 : 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                'Migration von Datei-basierten zu Firebase-basierten StÃ¤dten',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsAndActions(bool isMobile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistiken & Aktionen',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            
            // Statistics
            Wrap(
              spacing: 24,
              runSpacing: 16,
              children: [
                _buildStatCard('Datei BundeslÃ¤nder', fileStates.length, Colors.green),
                _buildStatCard('Datei StÃ¤dte', fileCities.length, Colors.green),
                _buildStatCard('CSV StÃ¤dte', csvCities.length, Colors.orange),
                _buildStatCard('Firebase BundeslÃ¤nder', statistics['states'] ?? 0, Colors.blue),
                _buildStatCard('Firebase StÃ¤dte', statistics['cities'] ?? 0, Colors.blue),
                _buildStatCard('Teams', teams.length, Colors.purple),
                _buildStatCard('Team-Zuordnungen', teamCityMatches.length, Colors.teal),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Actions
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                // File migration
                ElevatedButton.icon(
                  onPressed: isMigrating ? null : _migrateToFirebase,
                  icon: isMigrating 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload),
                  label: const Text('Datei zu Firebase'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                
                // CSV import
                ElevatedButton.icon(
                  onPressed: isMigrating ? null : _importCsvFile,
                  icon: const Icon(Icons.file_upload),
                  label: const Text('CSV importieren'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                
                // CSV to Firebase
                if (hasCsvData)
                  ElevatedButton.icon(
                    onPressed: isMigrating ? null : _importCsvToFirebase,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('CSV â†’ Firebase'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                
                // Team matching
                ElevatedButton.icon(
                  onPressed: isMatchingTeams ? null : _matchTeamsToCities,
                  icon: isMatchingTeams 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link),
                  label: const Text('Teams zuordnen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                
                // Apply team matches
                if (teamCityMatches.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: isMigrating ? null : _applyTeamMatches,
                    icon: const Icon(Icons.save),
                    label: const Text('Zuordnungen anwenden'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                
                // Sync states from cities
                ElevatedButton.icon(
                  onPressed: (isMigrating || isSyncingStates) ? null : _syncStatesFromCities,
                  icon: isSyncingStates 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: const Text('BundeslÃ¤nder sync'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                
                // Utility actions
                ElevatedButton.icon(
                  onPressed: isMigrating ? null : _clearFirebaseData,
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Firebase lÃ¶schen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isMigrating ? null : _loadData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Aktualisieren'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonView(bool isMobile) {
    if (isMobile) {
      // Mobile: Stack vertically
      return Column(
        children: [
          Expanded(child: _buildFileSection()),
          const SizedBox(height: 16),
          Expanded(child: _buildFirebaseSection()),
        ],
      );
    } else {
      // Desktop: Side by side
      return Row(
        children: [
          Expanded(child: _buildFileSection()),
          const SizedBox(width: 16),
          Expanded(child: _buildFirebaseSection()),
        ],
      );
    }
  }

  Widget _buildFileSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.folder, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Datei-basierte Daten',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // States section
            const Text(
              'BundeslÃ¤nder:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            
            Container(
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                itemCount: fileStates.length,
                itemBuilder: (context, index) {
                  final state = fileStates[index];
                  final isSelected = selectedFileState == state;
                  
                  return ListTile(
                    dense: true,
                    title: Text(state),
                    selected: isSelected,
                    onTap: () => _filterFileCities(isSelected ? '' : state),
                    trailing: isSelected ? const Icon(Icons.check) : null,
                  );
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Cities section
            Text(
              'StÃ¤dte${selectedFileState.isNotEmpty ? ' in $selectedFileState' : ''}:',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: filteredFileCities.length,
                  itemBuilder: (context, index) {
                    final city = filteredFileCities[index];
                    return ListTile(
                      dense: true,
                      title: Text(city.name),
                      subtitle: Text(city.state),
                      trailing: Text(city.stateAbbreviation),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFirebaseSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Firebase Daten',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // States section
            const Text(
              'BundeslÃ¤nder:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            
            Container(
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: firebaseStates.isEmpty
                  ? const Center(
                      child: Text(
                        'Keine BundeslÃ¤nder in Firebase',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: firebaseStates.length,
                      itemBuilder: (context, index) {
                        final state = firebaseStates[index];
                        final isSelected = selectedFirebaseState == state.name;
                        
                        return ListTile(
                          dense: true,
                          title: Text(state.name),
                          subtitle: Text(state.abbreviation),
                          selected: isSelected,
                          onTap: () => _filterFirebaseCities(isSelected ? '' : state.name),
                          trailing: isSelected ? const Icon(Icons.check) : null,
                        );
                      },
                    ),
            ),
            
            const SizedBox(height: 16),
            
            // Cities section
            Text(
              'StÃ¤dte${selectedFirebaseState.isNotEmpty ? ' in $selectedFirebaseState' : ''}:',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: filteredFirebaseCities.isEmpty
                    ? const Center(
                        child: Text(
                          'Keine StÃ¤dte in Firebase',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredFirebaseCities.length,
                        itemBuilder: (context, index) {
                          final city = filteredFirebaseCities[index];
                          return ListTile(
                            dense: true,
                            title: Text(city.name),
                            subtitle: Text('${city.state}, ${city.country}'),
                            trailing: Text(city.stateAbbreviation),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}