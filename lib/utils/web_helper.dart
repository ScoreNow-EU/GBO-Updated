import 'package:flutter/foundation.dart';

class WebHelper {
  /// Updates the version display on web platforms
  /// Note: This is a stub implementation. Web-specific code should be 
  /// implemented in a separate web-only file if needed.
  static void updateVersionDisplay(String version) {
    if (kIsWeb) {
      try {
        // For now, just log the version. 
        // The actual web implementation can be added later if needed.
        print('App version: $version');
      } catch (e) {
        print('Error updating web version display: $e');
      }
    }
  }
}