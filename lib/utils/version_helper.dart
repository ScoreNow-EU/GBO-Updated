import 'package:flutter/services.dart';
import 'dart:convert';

class VersionHelper {
  static String? _cachedVersion;
  
  /// Get the app version from pubspec.yaml
  static Future<String> getAppVersion() async {
    if (_cachedVersion != null) {
      return _cachedVersion!;
    }
    
    try {
      // Try to read from pubspec.yaml
      final pubspecString = await rootBundle.loadString('pubspec.yaml');
      final lines = pubspecString.split('\n');
      
      for (String line in lines) {
        if (line.trim().startsWith('version:')) {
          final versionLine = line.trim();
          // Extract version part (remove 'version:' and any build number after '+')
          final version = versionLine
              .replaceFirst('version:', '')
              .trim()
              .split('+')[0]; // Remove build number
          
          _cachedVersion = version;
          return version;
        }
      }
    } catch (e) {
      print('Error reading version from pubspec.yaml: $e');
    }
    
    // Fallback version
    _cachedVersion = '0.1.0';
    return _cachedVersion!;
  }
  
  /// Get the full version including build number
  static Future<String> getFullAppVersion() async {
    try {
      final pubspecString = await rootBundle.loadString('pubspec.yaml');
      final lines = pubspecString.split('\n');
      
      for (String line in lines) {
        if (line.trim().startsWith('version:')) {
          final versionLine = line.trim();
          final version = versionLine.replaceFirst('version:', '').trim();
          return version;
        }
      }
    } catch (e) {
      print('Error reading full version from pubspec.yaml: $e');
    }
    
    return '0.1.0+1';
  }
  
  /// Clear cached version (useful for testing)
  static void clearCache() {
    _cachedVersion = null;
  }
}