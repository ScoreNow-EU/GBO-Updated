import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const _emailKey = 'saved_email';
  static const _passwordKey = 'saved_password';
  static const _biometricEnabledKey = 'biometric_enabled';

  static final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if biometric authentication is available
  static Future<bool> isBiometricAvailable() async {
    try {
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      print('Error checking biometric availability: $e');
      return false;
    }
  }

  /// Get available biometric types
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      print('Error getting available biometrics: $e');
      return [];
    }
  }

  /// Authenticate with biometrics
  static Future<bool> authenticateWithBiometrics() async {
    try {
      final bool isAvailable = await isBiometricAvailable();
      if (!isAvailable) return false;

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Bitte authentifizieren Sie sich, um auf gespeicherte Anmeldedaten zuzugreifen',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      return didAuthenticate;
    } catch (e) {
      print('Error during biometric authentication: $e');
      return false;
    }
  }

  /// Save login credentials
  static Future<void> saveCredentials(String email, String password) async {
    try {
      await _storage.write(key: _emailKey, value: email);
      await _storage.write(key: _passwordKey, value: password);
    } catch (e) {
      print('Error saving credentials: $e');
      throw Exception('Fehler beim Speichern der Anmeldedaten');
    }
  }

  /// Get saved credentials with biometric authentication
  static Future<Map<String, String>?> getSavedCredentials() async {
    try {
      final bool biometricEnabled = await isBiometricEnabled();
      
      if (biometricEnabled) {
        final bool authenticated = await authenticateWithBiometrics();
        if (!authenticated) return null;
      }

      final String? email = await _storage.read(key: _emailKey);
      final String? password = await _storage.read(key: _passwordKey);

      if (email != null && password != null) {
        return {'email': email, 'password': password};
      }

      return null;
    } catch (e) {
      print('Error getting saved credentials: $e');
      return null;
    }
  }

  /// Check if credentials are saved
  static Future<bool> hasCredentials() async {
    try {
      final String? email = await _storage.read(key: _emailKey);
      final String? password = await _storage.read(key: _passwordKey);
      return email != null && password != null;
    } catch (e) {
      print('Error checking saved credentials: $e');
      return false;
    }
  }

  /// Delete saved credentials
  static Future<void> deleteCredentials() async {
    try {
      await _storage.delete(key: _emailKey);
      await _storage.delete(key: _passwordKey);
    } catch (e) {
      print('Error deleting credentials: $e');
      throw Exception('Fehler beim Löschen der Anmeldedaten');
    }
  }

  /// Enable/disable biometric authentication
  static Future<void> setBiometricEnabled(bool enabled) async {
    try {
      await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
    } catch (e) {
      print('Error setting biometric enabled: $e');
    }
  }

  /// Check if biometric authentication is enabled
  static Future<bool> isBiometricEnabled() async {
    try {
      final String? enabled = await _storage.read(key: _biometricEnabledKey);
      return enabled == 'true';
    } catch (e) {
      print('Error checking biometric enabled: $e');
      return false;
    }
  }

  /// Clear all stored data
  static Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      print('Error clearing all data: $e');
    }
  }
} 