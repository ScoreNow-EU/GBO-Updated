import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:async';
import '../models/device.dart';


class FaceIdService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Timeout duration for operations
  static const Duration _operationTimeout = Duration(seconds: 30);
  
  /// Get unique device ID
  String _getDeviceId() {
    // Generate a unique device ID based on platform and device info
    if (kIsWeb) {
      return 'web_${DateTime.now().millisecondsSinceEpoch}';
    } else if (Platform.isIOS) {
      return 'ios_device'; // In a real app, you might want to use device_info_plus for actual device ID
    } else if (Platform.isAndroid) {
      return 'android_device';
    } else {
      return 'unknown_device';
    }
  }
  
  /// Get current user ID
  String? _getCurrentUserId() {
    return FirebaseAuth.instance.currentUser?.uid;
  }
  
  /// Check if user is currently logged in
  bool isUserLoggedIn() {
    return _getCurrentUserId() != null;
  }
  
  /// Check if device supports biometric authentication
  Future<bool> isDeviceSupported() async {
    try {
      final result = await _localAuth.isDeviceSupported().timeout(_operationTimeout);
      debugPrint('[FaceID] isDeviceSupported: $result');
      return result;
    } catch (e) {
      debugPrint('[FaceID] Error checking isDeviceSupported: $e');
      return false;
    }
  }
  
  /// Check if biometric authentication is available
  Future<bool> isBiometricAvailable() async {
    try {
      final result = await _localAuth.canCheckBiometrics.timeout(_operationTimeout);
      debugPrint('[FaceID] isBiometricAvailable: $result');
      return result;
    } catch (e) {
      debugPrint('[FaceID] Error checking isBiometricAvailable: $e');
      return false;
    }
  }
  
  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      final result = await _localAuth.getAvailableBiometrics().timeout(_operationTimeout);
      debugPrint('[FaceID] getAvailableBiometrics: $result');
      return result;
    } catch (e) {
      debugPrint('[FaceID] Error getting availableBiometrics: $e');
      return [];
    }
  }
  
  /// Get current device from user document
  Future<Device?> _getCurrentDevice() async {
    final userId = _getCurrentUserId();
    if (userId == null) return null;
    
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get().timeout(_operationTimeout);
      if (!userDoc.exists) return null;
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final devicesData = userData['devices'] as Map<String, dynamic>?;
      
      if (devicesData == null) return null;
      
      final deviceId = _getDeviceId();
      final deviceData = devicesData[deviceId] as Map<String, dynamic>?;
      
      if (deviceData == null) return null;
      
      return Device.fromFirestore(deviceData);
    } catch (e) {
      return null;
    }
  }
  
  /// Update device in user document
  Future<void> _updateCurrentDevice(Device device) async {
    final userId = _getCurrentUserId();
    if (userId == null) return;
    
    try {
      final deviceId = _getDeviceId();
      
      await _firestore.collection('users').doc(userId).update({
        'devices.$deviceId': device.toFirestore(),
      }).timeout(_operationTimeout);
    } catch (e) {
      rethrow;
    }
  }
  
  /// Check if Face ID has been enabled by user for this device
  Future<bool> isFaceIdEnabled() async {
    try {
      final userId = _getCurrentUserId();
      if (userId == null) return false;
      
      final device = await _getCurrentDevice();
      return device?.faceIdEnabled ?? false;
    } catch (e) {
      return false;
    }
  }
  
  /// Check if Face ID has been enabled for a specific email (for login flow)
  Future<bool> isFaceIdEnabledForEmail(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get()
          .timeout(_operationTimeout);
      
      if (querySnapshot.docs.isEmpty) return false;
      
      final userData = querySnapshot.docs.first.data();
      final devicesData = userData['devices'] as Map<String, dynamic>?;
      
      if (devicesData == null) return false;
      
      final deviceId = _getDeviceId();
      final deviceData = devicesData[deviceId] as Map<String, dynamic>?;
      
      if (deviceData == null) return false;
      
      final device = Device.fromFirestore(deviceData);
      return device.faceIdEnabled ?? false;
    } catch (e) {
      return false;
    }
  }
  
  /// Check if user has been asked about Face ID before on this device
  Future<bool> hasBeenAskedAboutFaceId() async {
    try {
      final device = await _getCurrentDevice();
      return device?.faceIdEnabled != null; // null means not asked, true/false means asked
    } catch (e) {
      return false;
    }
  }
  
  /// Set Face ID preference for current device
  Future<void> setFaceIdEnabled(bool enabled) async {
    try {
      final deviceId = _getDeviceId();
      final device = Device(
        deviceId: deviceId,
        faceIdEnabled: enabled,
        deviceName: _getDeviceName(),
        lastUsed: DateTime.now(),
      );
      
      await _updateCurrentDevice(device);
    } catch (e) {
      rethrow;
    }
  }
  
  /// Mark that user has been asked about Face ID (set to false)
  Future<void> markAskedAboutFaceId() async {
    try {
      final deviceId = _getDeviceId();
      final device = Device(
        deviceId: deviceId,
        faceIdEnabled: false,
        deviceName: _getDeviceName(),
        lastUsed: DateTime.now(),
      );
      
      await _updateCurrentDevice(device);
    } catch (e) {
      rethrow;
    }
  }
  
  /// Get device name for display
  String _getDeviceName() {
    if (kIsWeb) {
      return 'Web Browser';
    } else if (Platform.isIOS) {
      return 'iPhone';
    } else if (Platform.isAndroid) {
      return 'Android Device';
    } else {
      return 'Unknown Device';
    }
  }
  
  /// Get biometric type name for display
  String getBiometricTypeName(List<BiometricType> types) {
    if (types.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (types.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (types.contains(BiometricType.iris)) {
      return 'Iris';
    } else if (types.contains(BiometricType.strong) || types.contains(BiometricType.weak)) {
      return 'Biometric';
    }
    return 'Biometric';
  }
  
  /// Authenticate with biometrics for login process (doesn't require user to be logged in yet)
  Future<bool> authenticateForLogin() async {
    try {
      debugPrint('[FaceID] Starting authenticateForLogin');
      
      final deviceSupported = await isDeviceSupported();
      debugPrint('[FaceID] Device supported: $deviceSupported');
      if (!deviceSupported) {
        debugPrint('[FaceID] Device not supported, returning false');
        return false;
      }
      
      final biometricAvailable = await isBiometricAvailable();
      debugPrint('[FaceID] Biometric available: $biometricAvailable');
      if (!biometricAvailable) {
        debugPrint('[FaceID] Biometric not available, returning false');
        return false;
      }
      
      final availableBiometrics = await getAvailableBiometrics();
      debugPrint('[FaceID] Available biometrics: $availableBiometrics');
      if (availableBiometrics.isEmpty) {
        debugPrint('[FaceID] No biometrics actually available (empty list), returning false');
        return false;
      }
      
      final biometricName = getBiometricTypeName(availableBiometrics);
      debugPrint('[FaceID] Biometric name: $biometricName');
      
      try {
        debugPrint('[FaceID] Calling _localAuth.authenticate for login');
        final bool didAuthenticate = await _localAuth.authenticate(
          localizedReason: 'Anmeldung mit $biometricName',
          options: const AuthenticationOptions(biometricOnly: true),
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            debugPrint('[FaceID] Authentication timeout after 30 seconds');
            return false;
          },
        );
        
        debugPrint('[FaceID] Authentication result: $didAuthenticate');
        return didAuthenticate;
      } catch (authError) {
        debugPrint('[FaceID] Authentication error: $authError');
        rethrow;
      }
      
    } on PlatformException catch (e) {
      debugPrint('[FaceID] PlatformException in authenticateForLogin: ${e.code} - ${e.message}');
      return false;
    } on TimeoutException catch (e) {
      debugPrint('[FaceID] TimeoutException in authenticateForLogin: $e');
      return false;
    } catch (e) {
      debugPrint('[FaceID] Unknown exception in authenticateForLogin: $e');
      return false;
    }
  }
  
  /// Authenticate with biometrics
  Future<bool> authenticate() async {
    try {
      debugPrint('[FaceID] Starting authenticate for admin');
      
      final userId = _getCurrentUserId();
      debugPrint('[FaceID] Current user ID: $userId');
      if (userId == null) {
        debugPrint('[FaceID] No user logged in, returning false');
        return false;
      }
      
      final deviceSupported = await isDeviceSupported();
      debugPrint('[FaceID] Device supported: $deviceSupported');
      if (!deviceSupported) {
        debugPrint('[FaceID] Device not supported, returning false');
        return false;
      }
      
      final biometricAvailable = await isBiometricAvailable();
      debugPrint('[FaceID] Biometric available: $biometricAvailable');
      if (!biometricAvailable) {
        debugPrint('[FaceID] Biometric not available, returning false');
        return false;
      }
      
      final availableBiometrics = await getAvailableBiometrics();
      debugPrint('[FaceID] Available biometrics: $availableBiometrics');
      if (availableBiometrics.isEmpty) {
        debugPrint('[FaceID] No biometrics actually available (empty list), returning false');
        return false;
      }
      
      final completer = Completer<bool>();
      
      debugPrint('[FaceID] Calling _localAuth.authenticate for admin');
      _localAuth.authenticate(
        localizedReason: 'Authentifizierung für Admin-Bereiche',
        options: const AuthenticationOptions(biometricOnly: true),
      ).then((result) {
        debugPrint('[FaceID] Authentication succeeded: $result');
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      }).catchError((error) {
        debugPrint('[FaceID] Authentication error caught: $error');
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      });
      
      final didAuthenticate = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('[FaceID] Authentication timeout after 30 seconds');
          return false;
        },
      );
      
      debugPrint('[FaceID] Final authentication result: $didAuthenticate');
      
      if (didAuthenticate) {
        try {
          debugPrint('[FaceID] Updating device lastUsed timestamp');
          final device = await _getCurrentDevice();
          if (device != null) {
            await _updateCurrentDevice(device.copyWith(lastUsed: DateTime.now()));
            debugPrint('[FaceID] Device timestamp updated successfully');
          }
        } catch (e) {
          debugPrint('[FaceID] Error updating device timestamp (non-fatal): $e');
          // Don't fail authentication if we can't update the timestamp
        }
      }
      
      return didAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('[FaceID] PlatformException in authenticate: ${e.code} - ${e.message}');
      return false;
    } on TimeoutException catch (e) {
      debugPrint('[FaceID] TimeoutException in authenticate: $e');
      return false;
    } catch (e) {
      debugPrint('[FaceID] Unknown exception in authenticate: $e');
      return false;
    }
  }
  
  /// Check if Face ID should be prompted (device supported, not asked before)
  Future<bool> shouldPromptForFaceId() async {
    try {
      debugPrint('[FaceID] Checking shouldPromptForFaceId');
      
      final deviceSupported = await isDeviceSupported();
      debugPrint('[FaceID] Device supported: $deviceSupported');
      if (!deviceSupported) {
        debugPrint('[FaceID] Device not supported, shouldNotPrompt');
        return false;
      }
      
      final biometricAvailable = await isBiometricAvailable();
      debugPrint('[FaceID] Biometric available: $biometricAvailable');
      if (!biometricAvailable) {
        debugPrint('[FaceID] Biometric not available, shouldNotPrompt');
        return false;
      }
      
      final hasBeenAsked = await hasBeenAskedAboutFaceId();
      debugPrint('[FaceID] Has been asked before: $hasBeenAsked');
      if (hasBeenAsked) {
        debugPrint('[FaceID] Already asked, shouldNotPrompt');
        return false;
      }
      
      final availableBiometrics = await getAvailableBiometrics();
      debugPrint('[FaceID] Available biometrics: $availableBiometrics');
      
      final shouldPrompt = availableBiometrics.isNotEmpty;
      debugPrint('[FaceID] Should prompt for Face ID: $shouldPrompt');
      return shouldPrompt;
    } catch (e) {
      debugPrint('[FaceID] Error in shouldPromptForFaceId: $e');
      return false;
    }
  }
  
  /// Reset Face ID preferences (useful for testing)
  Future<void> resetFaceIdPreferences() async {
    final userId = _getCurrentUserId();
    if (userId == null) return;
    
    try {
      final deviceId = _getDeviceId();
      
      await _firestore.collection('users').doc(userId).update({
        'devices.$deviceId': FieldValue.delete(),
      }).timeout(_operationTimeout);
    } catch (e) {
      rethrow;
    }
  }
} 