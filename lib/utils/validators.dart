/// Centralized form validators for `TextFormField.validator` and ad-hoc
/// validation. Returns `null` when the value is valid, otherwise a German
/// error message suitable for display.
///
/// Use:
/// ```dart
/// TextFormField(validator: Validators.email)
/// TextFormField(validator: (v) => Validators.required(v, label: 'Name'))
/// ```
import 'package:flutter/widgets.dart';

class Validators {
  Validators._();

  /// Permissive RFC-5322-ish email regex. Matches what most user-facing
  /// forms accept (e.g. `name+tag@sub.domain.tld`). Avoid stricter TLD
  /// length caps — `.museum`, `.travel`, etc. are valid.
  static final RegExp _emailRegExp =
      RegExp(r'^[\w.+-]+@([\w-]+\.)+[a-zA-Z]{2,}$');

  /// Email validator. Empty values are reported as required.
  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'E-Mail-Adresse erforderlich';
    if (!_emailRegExp.hasMatch(v)) return 'Ungültige E-Mail-Adresse';
    return null;
  }

  /// Optional-email variant: passes through when empty, validates format
  /// otherwise.
  static String? emailOptional(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (!_emailRegExp.hasMatch(v)) return 'Ungültige E-Mail-Adresse';
    return null;
  }

  /// Cheap regex check for use outside form contexts (e.g. CSV import
  /// loops). Does not produce a message.
  static bool isValidEmail(String value) =>
      _emailRegExp.hasMatch(value.trim());

  /// Required text field. `label` appears in the error message.
  static String? required(String? value, {String label = 'Feld'}) {
    if (value == null || value.trim().isEmpty) {
      return '$label erforderlich';
    }
    return null;
  }

  /// Minimum-length validator (counts characters, not bytes).
  static String? minLength(String? value, int min, {String label = 'Feld'}) {
    final v = value ?? '';
    if (v.length < min) return '$label muss mindestens $min Zeichen lang sein';
    return null;
  }

  /// Numeric integer validator. Allows leading/trailing whitespace.
  static String? integer(String? value, {String label = 'Wert'}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$label erforderlich';
    if (int.tryParse(v) == null) return '$label muss eine ganze Zahl sein';
    return null;
  }

  /// Combine several validators; first non-null result wins.
  static FormFieldValidator<String> combine(
    List<FormFieldValidator<String>> validators,
  ) {
    return (value) {
      for (final v in validators) {
        final result = v(value);
        if (result != null) return result;
      }
      return null;
    };
  }
}
