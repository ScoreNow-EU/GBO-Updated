import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

class VersionHelper {
  static String? _cachedVersion;
  
  // Hardcoded version - update this with each release
  static const String APP_VERSION = '1.0.7';
  static const String FULL_APP_VERSION = '1.0.7+1';
  
  /// Get the app version from hardcoded constant
  /// Previously tried to load from pubspec.yaml, but that's not accessible as an asset
  static Future<String> getAppVersion() async {
    if (_cachedVersion != null) {
      return _cachedVersion!;
    }
    
    try {
      debugPrint('[VersionHelper] Using hardcoded app version: $APP_VERSION');
      _cachedVersion = APP_VERSION;
      return APP_VERSION;
    } catch (e) {
      debugPrint('[VersionHelper] Error getting version: $e');
    }
    
    // Fallback version
    _cachedVersion = '0.1.0';
    return _cachedVersion!;
  }
  
  /// Get the full version including build number
  static Future<String> getFullAppVersion() async {
    try {
      debugPrint('[VersionHelper] Using hardcoded full app version: $FULL_APP_VERSION');
      return FULL_APP_VERSION;
    } catch (e) {
      debugPrint('[VersionHelper] Error getting full version: $e');
    }
    
    return '0.1.0+1';
  }
  
  /// Clear cached version (useful for testing)
  static void clearCache() {
    _cachedVersion = null;
  }
}