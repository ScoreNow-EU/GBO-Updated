import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

/// Centralised toast utility (T15 / T52).
///
/// All in-app notifications should go through this class so the look,
/// duration and error logging stay consistent. The previous codebase had
/// 16+ private `_showSuccessToast` / `_showErrorToast` helpers and many
/// ad-hoc `ScaffoldMessenger…showSnackBar(...)` calls — those should
/// delegate here over time.
///
/// Usage:
///   AppToast.success(context, 'Gespeichert');
///   AppToast.error(context, 'Konnte nicht speichern', error: e);
class AppToast {
  AppToast._();

  static void success(BuildContext context, String message) {
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.fillColored,
      title: Text(message),
      alignment: Alignment.topRight,
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  static void error(
    BuildContext context,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (error != null) {
      debugPrint('❌ $message: $error');
      if (stackTrace != null) debugPrint(stackTrace.toString());
    } else {
      debugPrint('❌ $message');
    }
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.fillColored,
      title: Text(message),
      alignment: Alignment.topRight,
      autoCloseDuration: const Duration(seconds: 5),
    );
  }

  static void info(BuildContext context, String message) {
    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.fillColored,
      title: Text(message),
      alignment: Alignment.topRight,
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  static void warning(BuildContext context, String message) {
    toastification.show(
      context: context,
      type: ToastificationType.warning,
      style: ToastificationStyle.fillColored,
      title: Text(message),
      alignment: Alignment.topRight,
      autoCloseDuration: const Duration(seconds: 4),
    );
  }
}

/// Convenience extension so future snackbar-replacements can stay terse.
///
/// Migration shorthand: replace
///   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('x')));
/// with
///   context.toast('x');
extension AppToastContext on BuildContext {
  void toast(String message) => AppToast.info(this, message);
  void toastSuccess(String message) => AppToast.success(this, message);
  void toastError(String message, {Object? error}) =>
      AppToast.error(this, message, error: error);
}
