import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'firebase_config.dart';

/// Wires Firebase to the local emulator suite when run with
/// `--dart-define=USE_EMULATOR=true`.
///
/// Default emulator host is `localhost`; override with
/// `--dart-define=EMULATOR_HOST=10.0.2.2` (Android emulator) etc.
///
/// Ports must match firebase.json:
///   - Auth      9099
///   - Firestore 8080
///   - Storage   9199
class FirebaseTestConfig {
  static const bool useEmulator =
      bool.fromEnvironment('USE_EMULATOR', defaultValue: false);
  static const String emulatorHost =
      String.fromEnvironment('EMULATOR_HOST', defaultValue: 'localhost');

  static bool _initialized = false;

  /// Call once after `Firebase.initializeApp(...)`.
  /// No-op when `USE_EMULATOR` is false.
  static Future<void> initEmulators() async {
    if (!useEmulator || _initialized) return;
    _initialized = true;

    debugPrint('🧪 Firebase emulator mode: host=$emulatorHost');

    await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
    await FirebaseStorage.instance.useStorageEmulator(emulatorHost, 9199);
  }

  /// Convenience: initialise the default Firebase app and wire emulators.
  static Future<void> ensureInitialized() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: FirebaseConfig.web);
    }
    await initEmulators();
  }
}
