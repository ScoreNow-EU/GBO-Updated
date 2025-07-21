import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;

class FirebaseConfig {
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyDZRIwJGLtdo4n2PDlMfjv4A3cRrCKw62k",
    authDomain: "gbo-updated.firebaseapp.com",
    projectId: "gbo-updated",
    storageBucket: "gbo-updated.firebasestorage.app",
    messagingSenderId: "295754050567",
    appId: "1:295754050567:web:630345ba20b01c8de20ea2",
    measurementId: "G-T9SM0MFPV9",
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: "AIzaSyDZRIwJGLtdo4n2PDlMfjv4A3cRrCKw62k",
    authDomain: "gbo-updated.firebaseapp.com",
    projectId: "gbo-updated",
    storageBucket: "gbo-updated.firebasestorage.app",
    messagingSenderId: "295754050567",
    appId: "1:295754050567:ios:db5a9f8b9d3c2a1e0e20ea2",
    iosBundleId: "com.scorenow.germanbeachopen",
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyDZRIwJGLtdo4n2PDlMfjv4A3cRrCKw62k",
    authDomain: "gbo-updated.firebaseapp.com",
    projectId: "gbo-updated",
    storageBucket: "gbo-updated.firebasestorage.app",
    messagingSenderId: "295754050567",
    appId: "1:295754050567:android:a7b8c9d0e1f2g3h4e20ea2",
  );

  /// Returns true if Firebase should be initialized for the current platform
  static bool get shouldInitializeFirebase {
    return kIsWeb; // Only initialize Firebase on web platform
  }

  /// Returns the Firebase options for the current platform
  /// Only call this if shouldInitializeFirebase returns true
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.android:
        return android;
      case TargetPlatform.macOS:
        return ios; // Use iOS config for macOS
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
      default:
        return web; // Fallback to web config
    }
  }
} 