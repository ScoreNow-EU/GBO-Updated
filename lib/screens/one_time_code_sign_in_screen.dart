import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/app_colors.dart';
import 'package:toastification/toastification.dart';

class OneTimeCodeSignInScreen extends StatefulWidget {
  const OneTimeCodeSignInScreen({super.key});

  @override
  State<OneTimeCodeSignInScreen> createState() => _OneTimeCodeSignInScreenState();
}

class _OneTimeCodeSignInScreenState extends State<OneTimeCodeSignInScreen> {
  final AuthService _authService = AuthService();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  
  String? _preEnteredEmail;
  String? _teamName;
  bool _codeValidated = false;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _validateCode() async {
    if (_codeController.text.isEmpty) {
      _showErrorToast('Bitte geben Sie einen Code ein');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final codeData = await _authService.validateOneTimeCode(_codeController.text.toUpperCase());
      if (codeData != null) {
        setState(() {
          _preEnteredEmail = codeData['preEnteredEmail'] as String;
          _teamName = codeData['teamName'] as String;
          _codeValidated = true;
        });
        _showSuccessToast('Code bestätigt! Email: $_preEnteredEmail');
      }
    } catch (e) {
      _showErrorToast('Fehler: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signIn() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorToast('Passwörter stimmen nicht überein');
      return;
    }

    if (_passwordController.text.length < 6) {
      _showErrorToast('Passwort muss mindestens 6 Zeichen lang sein');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.signInWithOneTimeCode(_codeController.text.toUpperCase());

      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      _showErrorToast('Fehler beim Anmelden: ${e.toString().replaceAll('Exception: ', '')}');
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
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            
            // Header
            Text(
              'Anmeldung mit Code',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Geben Sie den Einmalcode ein, um sich anzumelden',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Code Input Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Schritt 1: Code eingeben',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: _codeController,
                      enabled: !_codeValidated || _isLoading,
                      decoration: InputDecoration(
                        labelText: 'Einmalcode',
                        hintText: 'z.B. ABC12345',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.vpn_key),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(letterSpacing: 2),
                    ),
                    const SizedBox(height: 16),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading || _codeValidated ? null : _validateCode,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_codeValidated ? '✓ Code bestätigt' : 'Code bestätigen'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_codeValidated) ...[
              const SizedBox(height: 24),
              
              // Email Display Section
              Card(
                elevation: 2,
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Team Information',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Team Name (Display Only)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Team',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _teamName ?? '',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Email (Display Only)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Email (nicht änderbar)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _preEnteredEmail ?? '',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Password Input Section
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Schritt 2: Passwort setzen',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Password field
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Passwort',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPassword ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() => _showPassword = !_showPassword);
                            },
                          ),
                        ),
                        obscureText: !_showPassword,
                      ),
                      const SizedBox(height: 16),
                      
                      // Confirm password field
                      TextField(
                        controller: _confirmPasswordController,
                        decoration: InputDecoration(
                          labelText: 'Passwort bestätigen',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showConfirmPassword ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() => _showConfirmPassword = !_showConfirmPassword);
                            },
                          ),
                        ),
                        obscureText: !_showConfirmPassword,
                      ),
                      const SizedBox(height: 8),
                      
                      Text(
                        'Mindestens 6 Zeichen',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Sign In Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGradient.colors.first,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Anmelden',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Back to regular login
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Zurück zur normalen Anmeldung'),
            ),
          ],
        ),
      ),
    );
  }
}
