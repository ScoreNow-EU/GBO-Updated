import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../utils/version_helper.dart';

/// Centralized error reporter.
///
/// Always logs to the dev console via [debugPrint]. In release builds, also
/// writes a best-effort document to the `errorReports` Firestore collection
/// so unhandled exceptions can be triaged after the fact.
class ErrorReporterService {
  ErrorReporterService._();

  static const int _maxFieldChars = 4000;

  /// Report an error. Safe to call from `FlutterError.onError`,
  /// `PlatformDispatcher.onError`, or any catch block.
  static Future<void> report(
    Object error,
    StackTrace? stack, {
    String? context,
    String? route,
  }) async {
    final errStr = _truncate(error.toString());
    final stackStr = _truncate(stack?.toString() ?? '');

    debugPrint('❌ ${context ?? 'unhandled'}: $errStr');
    if (stack != null) {
      debugPrint(stackStr);
    }

    if (kDebugMode) return;
    if (Firebase.apps.isEmpty) return;

    try {
      String? userId;
      try {
        userId = FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {
        userId = null;
      }

      String version = '';
      try {
        version = await VersionHelper.getAppVersion();
      } catch (_) {
        version = '';
      }

      await FirebaseFirestore.instance.collection('errorReports').add({
        'timestamp': FieldValue.serverTimestamp(),
        'error': errStr,
        'stack': stackStr,
        'context': context ?? '',
        'route': route ?? '',
        'platform': defaultTargetPlatform.name,
        'isWeb': kIsWeb,
        'userId': userId ?? '',
        'appVersion': version,
      });
    } catch (e) {
      // Swallow — never let the reporter cause another crash.
      debugPrint('⚠️ errorReports write failed: $e');
    }
  }

  static String _truncate(String s) =>
      s.length <= _maxFieldChars ? s : '${s.substring(0, _maxFieldChars)}…';
}
