import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';
import '../utils/version_helper.dart';
import '../models/user.dart' as app_user;
import '../utils/app_colors.dart';
import 'package:toastification/toastification.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final AuthService _authService = AuthService();
  final _personalFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  
  // Text controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Preferences
  String _defaultTournamentFilter = 'Alle';
  String _defaultSeason = '2025';
  bool _isLoading = true;
  app_user.User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        setState(() {
          _currentUser = user;
          _firstNameController.text = user.firstName ?? '';
          _lastNameController.text = user.lastName ?? '';
          _emailController.text = user.email ?? '';
          _defaultTournamentFilter = user.defaultTournamentFilter ?? 'Alle';
          _defaultSeason = user.defaultSeason ?? '2025';
        });
      }
    } catch (e) {
      _showErrorToast('Fehler beim Laden der Benutzerdaten');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePersonalInfo() async {
    if (!_personalFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authService.updateUserProfile(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        email: _emailController.text,
      );
      _showSuccessToast('Persönliche Daten aktualisiert');
    } catch (e) {
      _showErrorToast('Fehler beim Aktualisieren der persönlichen Daten');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authService.updatePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      _showSuccessToast('Passwort erfolgreich aktualisiert');
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } catch (e) {
      _showErrorToast('Fehler beim Aktualisieren des Passworts');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePreferences() async {
    setState(() => _isLoading = true);
    try {
      await _authService.updateUserPreferences(
        defaultTournamentFilter: _defaultTournamentFilter,
        defaultSeason: _defaultSeason,
      );
      _showSuccessToast('Einstellungen gespeichert');
    } catch (e) {
      _showErrorToast('Fehler beim Speichern der Einstellungen');
    } finally {
      setState(() => _isLoading = false);
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profil Einstellungen',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),

            // Personal Information Section
            _buildSectionCard(
              title: 'Persönliche Informationen',
              child: Form(
                key: _personalFormKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'Vorname',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value?.isEmpty == true ? 'Bitte geben Sie Ihren Vornamen ein' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nachname',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value?.isEmpty == true ? 'Bitte geben Sie Ihren Nachnamen ein' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'E-Mail',
                        border: OutlineInputBorder(),
                      ),
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _updatePersonalInfo,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(200, 45),
                      ),
                      child: const Text('Persönliche Daten speichern'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Password Section
            _buildSectionCard(
              title: 'Passwort ändern',
              child: Form(
                key: _passwordFormKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _currentPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Aktuelles Passwort',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (value) =>
                          value?.isEmpty == true ? 'Bitte geben Sie Ihr aktuelles Passwort ein' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _newPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Neues Passwort',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value?.isEmpty == true) {
                          return 'Bitte geben Sie ein neues Passwort ein';
                        }
                        if (value!.length < 8) {
                          return 'Das Passwort muss mindestens 8 Zeichen lang sein';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Neues Passwort bestätigen',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value?.isEmpty == true) {
                          return 'Bitte bestätigen Sie Ihr neues Passwort';
                        }
                        if (value != _newPasswordController.text) {
                          return 'Die Passwörter stimmen nicht überein';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _updatePassword,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(200, 45),
                      ),
                      child: const Text('Passwort ändern'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Preferences Section
            _buildSectionCard(
              title: 'Einstellungen',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Standard Turnier-Filter',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _defaultTournamentFilter,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Alle',
                        child: Text('Alle Turniere'),
                      ),
                      DropdownMenuItem(
                        value: 'RHBL Spieltag',
                        child: Text('RHBL Spieltag'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _defaultTournamentFilter = value!);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Standard Saison',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _defaultSeason,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: '2025',
                        child: Text('Saison 2025'),
                      ),
                      DropdownMenuItem(
                        value: '2026',
                        child: Text('Saison 2026'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _defaultSeason = value!);
                    },
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: ElevatedButton(
                      onPressed: _updatePreferences,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(200, 45),
                      ),
                      child: const Text('Einstellungen speichern'),
                    ),
                  ),
                ],
              ),
            ),

            // Legal Links Section
            const SizedBox(height: 24),
            _buildSectionCard(
              title: 'Rechtliches',
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.gavel),
                    title: const Text('Impressum'),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => launchUrl(Uri.parse('/impressum')),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip),
                    title: const Text('Datenschutzerklärung'),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => launchUrl(Uri.parse('/datenschutz')),
                  ),
                ],
              ),
            ),

            // Delete Account Section
            const SizedBox(height: 32),
            _buildSectionCard(
              title: 'Konto löschen',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Warnung: Das Löschen Ihres Kontos ist nicht rückgängig zu machen. Alle Ihre Daten werden dauerhaft gelöscht.',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: ElevatedButton(
                      onPressed: _showDeleteAccountConfirmation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        minimumSize: const Size(200, 45),
                      ),
                      child: const Text(
                        'Konto löschen',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // About this app
            _buildAboutCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutCard() {
    return _buildSectionCard(
      title: 'Über die App',
      child: FutureBuilder<String>(
        future: VersionHelper.getFullAppVersion(),
        builder: (context, snapshot) {
          final version = snapshot.data ?? '…';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rollstuhlhandball Bundesliga',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Version $version',
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 4),
              const Text(
                '© Rollstuhlhandball Bundesliga',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: 'Rollstuhlhandball Bundesliga',
                    applicationVersion: version,
                  ),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Open-Source-Lizenzen anzeigen'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteAccountConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konto löschen?'),
          content: const Text(
            'Sind Sie sicher, dass Sie Ihr Konto löschen möchten? Diese Aktion kann nicht rückgängig gemacht werden.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAccount();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    setState(() => _isLoading = true);
    try {
      await _authService.deleteAccount();
      _showSuccessToast('Konto erfolgreich gelöscht');
      
      // Navigate to login screen
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      _showErrorToast('Fehler beim Löschen des Kontos: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    );
  }
}