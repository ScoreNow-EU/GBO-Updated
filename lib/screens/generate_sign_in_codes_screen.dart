import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../utils/validators.dart';
import '../services/auth_service.dart';
import '../services/team_service.dart';
import '../models/team.dart';
import '../models/user.dart' as app_user;
import 'package:toastification/toastification.dart';

class GenerateSignInCodesScreen extends StatefulWidget {
  const GenerateSignInCodesScreen({super.key});

  @override
  State<GenerateSignInCodesScreen> createState() => _GenerateSignInCodesScreenState();
}

class _GenerateSignInCodesScreenState extends State<GenerateSignInCodesScreen> {
  final AuthService _authService = AuthService();
  final TeamService _teamService = TeamService();
  final _emailController = TextEditingController();
  
  bool _isLoading = false;
  int _validityDays = 7;
  List<Map<String, dynamic>> _generatedCodes = [];
  List<Team> _teams = [];
  Team? _selectedTeam;
  app_user.UserRole _selectedRole = app_user.UserRole.teamManager;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    try {
      final teams = await _teamService.getAllTeams().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Team loading timed out after 10 seconds');
        },
      );
      if (mounted) {
        setState(() {
          _teams = teams;
          if (teams.isNotEmpty) {
            _selectedTeam = teams.first;
          }
        });
        debugPrint('Teams loaded: ${teams.length} teams');
      }
    } catch (e) {
      debugPrint('Error loading teams: $e');
      if (mounted) {
        _showErrorToast('Fehler beim Laden der Teams: ${e.toString()}');
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  List<Team> _getFilteredTeams(String query) {
    if (query.isEmpty) {
      return _teams;
    }
    return _teams
        .where((team) => team.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  Future<void> _generateCode() async {
    if (_selectedTeam == null) {
      _showErrorToast('Bitte wählen Sie ein Team aus');
      return;
    }

    if (_emailController.text.isEmpty) {
      _showErrorToast('Bitte geben Sie eine Email-Adresse ein');
      return;
    }

    // Basic email validation
    if (!Validators.isValidEmail(_emailController.text)) {
      _showErrorToast('Bitte geben Sie eine gültige Email-Adresse ein');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final code = await _authService.generateOneTimeCode(
        teamName: _selectedTeam!.name,
        preEnteredEmail: _emailController.text,
        validityDays: _validityDays,
        roles: [_selectedRole],
      );

      setState(() {
        _generatedCodes.insert(0, {
          'code': code,
          'teamName': _selectedTeam!.name,
          'email': _emailController.text,
          'role': _selectedRole.name,
          'createdAt': DateTime.now(),
          'expiresAt': DateTime.now().add(Duration(days: _validityDays)),
        });
      });

      _emailController.clear();
      _showSuccessToast('Code erfolgreich erstellt!');
    } catch (e) {
      _showErrorToast('Fehler: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _copyCodeToClipboard(String code) {
    Clipboard.setData(ClipboardData(text: code));
    _showSuccessToast('Code in Zwischenablage kopiert!');
  }

  String _getRoleDisplayName(app_user.UserRole role) {
    switch (role) {
      case app_user.UserRole.admin:
        return 'Admin';
      case app_user.UserRole.user:
        return 'Benutzer';
      case app_user.UserRole.referee:
        return 'Schiedsrichter';
      case app_user.UserRole.teamManager:
        return 'Team Manager';
      case app_user.UserRole.delegate:
        return 'Coach';
      case app_user.UserRole.scoringTablet:
        return 'Scoring Tablet';
      case app_user.UserRole.sanitater:
        return 'Sanitäter';
      case app_user.UserRole.seriesOrganizer:
        return 'Series Organizer';
      case app_user.UserRole.spieler:
        return 'Spieler';
      case app_user.UserRole.tournamentOrganizer:
        return 'Turnier Organisator';
      case app_user.UserRole.teamRHD:
        return 'Team RHD';
    }
  }

  void _showSuccessToast(String message) {
    toastification.show(
      context: context,
      title: Text(message),
      autoCloseDuration: const Duration(seconds: 3),
      type: ToastificationType.success,
    );
  }

  void _showErrorToast(String message) {
    toastification.show(
      context: context,
      title: Text(message),
      autoCloseDuration: const Duration(seconds: 3),
      type: ToastificationType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anmeldecodes generieren'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Generation Form
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Neuen Code erstellen',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Team Selection with Search (Autocomplete)
                    Autocomplete<Team>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        return _getFilteredTeams(textEditingValue.text);
                      },
                      onSelected: (Team selection) {
                        setState(() {
                          _selectedTeam = selection;
                        });
                      },
                      fieldViewBuilder: (
                        BuildContext context,
                        TextEditingController textEditingController,
                        FocusNode focusNode,
                        VoidCallback onFieldSubmitted,
                      ) {
                        return TextField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: 'Team auswählen',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.groups),
                            suffixIcon: _selectedTeam != null
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setState(() {
                                        _selectedTeam = null;
                                        textEditingController.clear();
                                        focusNode.requestFocus();
                                      });
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (value) {
                            onFieldSubmitted();
                          },
                        );
                      },
                      optionsViewBuilder: (
                        BuildContext context,
                        AutocompleteOnSelected<Team> onSelected,
                        Iterable<Team> options,
                      ) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4.0,
                            child: Container(
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final Team option = options.elementAt(index);
                                  return ListTile(
                                    leading: const Icon(Icons.group),
                                    title: Text(option.name),
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
                    ),
                    if (_selectedTeam != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Ausgewähltes Team: ${_selectedTeam!.name}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Role Selection Dropdown
                    DropdownButtonFormField<app_user.UserRole>(
                      value: _selectedRole,
                      isExpanded: true,
                      items: [
                        app_user.UserRole.teamManager,
                        app_user.UserRole.delegate,
                        app_user.UserRole.spieler,
                      ].map((role) {
                        return DropdownMenuItem(
                          value: role,
                          child: Text(_getRoleDisplayName(role)),
                        );
                      }).toList(),
                      onChanged: (role) {
                        if (role != null) {
                          setState(() => _selectedRole = role);
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Rolle auswählen',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.assignment_ind),
                      ),
                    ),

                    // Email Field
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email-Adresse',
                        hintText: 'team@example.com',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),

                    // Validity Days Selector
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gültig für (Tage): $_validityDays',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Slider(
                          value: _validityDays.toDouble(),
                          min: 1,
                          max: 90,
                          divisions: 89,
                          onChanged: (value) {
                            setState(() => _validityDays = value.toInt());
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Generate Button
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _generateCode,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                'Code generieren',
                                style: TextStyle(
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

            const SizedBox(height: 32),

            // Generated Codes List
            if (_generatedCodes.isNotEmpty) ...[
              Text(
                'Generierte Codes (${_generatedCodes.length})',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _generatedCodes.length,
                itemBuilder: (context, index) {
                  final codeData = _generatedCodes[index];
                  final expiresAt = codeData['expiresAt'] as DateTime;
                  final isExpired = DateTime.now().isAfter(expiresAt);

                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 16),
                    color: isExpired ? Colors.grey[100] : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Team and Email Info
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      codeData['teamName'] as String,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      codeData['email'] as String,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Rolle: ${_getRoleDisplayName(app_user.UserRole.values.firstWhere((r) => r.name == (codeData['role'] as String)))}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.blue[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isExpired)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red[100],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Abgelaufen',
                                    style: TextStyle(
                                      color: Colors.red[700],
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Code Display with Copy Button
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    codeData['code'] as String,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: () {
                                    _copyCodeToClipboard(codeData['code']);
                                  },
                                  tooltip: 'In Zwischenablage kopieren',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Expiry Info
                          Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Gültig bis: ${expiresAt.day}.${expiresAt.month}.${expiresAt.year}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
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
            ] else
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.vpn_key,
                        size: 48,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Noch keine Codes generiert',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
