import 'package:flutter/foundation.dart';

class DebugFilter {
  static void initialize() {
    if (kIsWeb) {
      // Override debugPrint to filter out unwanted messages
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) {
          // Filter out specific debug messages we don't want to see
          if (message.contains('Cannot send Null') ||
              message.contains('DebugService: Error serving requests') ||
              message.contains('Unsupported operation: Cannot send Null')) {
            // Silently ignore these messages
            return;
          }
        }
        
        // Print other messages normally
        debugPrintThrottled(message, wrapWidth: wrapWidth);
      };
      
      print('🔇 Debug filter initialized for web platform');
    }
  }
}
