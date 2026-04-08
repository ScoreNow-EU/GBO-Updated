import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class VersionHelper {
  static String? _cachedVersion;
  static String? _cachedFullVersion;

  /// Get the app version from pubspec.yaml via package_info_plus
  static Future<String> getAppVersion() async {
    if (_cachedVersion != null) {
      return _cachedVersion!;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _cachedVersion = packageInfo.version;
      return _cachedVersion!;
    } catch (e) {
      debugPrint('[VersionHelper] Error getting version: $e');
    }

    _cachedVersion = '0.1.0';
    return _cachedVersion!;
  }

  /// Get the full version including build number
  static Future<String> getFullAppVersion() async {
    if (_cachedFullVersion != null) {
      return _cachedFullVersion!;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _cachedFullVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      return _cachedFullVersion!;
    } catch (e) {
      debugPrint('[VersionHelper] Error getting full version: $e');
    }

    return '0.1.0+1';
  }

  /// Clear cached version (useful for testing)
  static void clearCache() {
    _cachedVersion = null;
    _cachedFullVersion = null;
  }
}