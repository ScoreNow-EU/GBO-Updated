import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Result of a backup restore operation.
class RestoreSummary {
  RestoreSummary({
    required this.dryRun,
    required this.collections,
    required this.totalDocs,
    this.errors = const [],
  });

  final bool dryRun;

  /// Per-collection document counts.
  final Map<String, int> collections;

  /// Sum across all collections.
  final int totalDocs;

  /// Any non-fatal errors encountered (e.g. a single bad doc).
  final List<String> errors;
}

/// Full Firestore JSON backup + restore for admin use.
///
/// Scope: data collections only. Identity / secret / runtime collections
/// are intentionally **excluded** to avoid leaking PII or breaking auth on
/// restore: `users`, `notifications`, `errorReports`, `coach_auth_requests`,
/// `gameStates`, `fcmTokens`.
class BackupService {
  BackupService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Collections included in the export. Order also defines restore order.
  static const List<String> backupCollections = [
    'tournaments',
    'teams',
    'players',
    'games',
    'gameEvents',
    'gameReports',
    'game_squads',
    'suspensions',
    'transfers',
    'referees',
    'delegates',
    'kampfgericht_members',
    'seasons',
    'fines',
    'ligapunkte',
    'settings',
    'documents',
    'presets',
  ];

  /// Snapshot version. Bump if the on-disk shape changes.
  static const int snapshotVersion = 1;

  /// Read every document from each backup collection and return a JSON-safe
  /// map. Firestore [Timestamp] values are converted to ISO-8601 strings
  /// with a leading `__timestamp__:` marker so [restore] can round-trip
  /// them.
  Future<Map<String, dynamic>> exportAll({
    void Function(String collection, int count)? onProgress,
  }) async {
    final result = <String, dynamic>{
      'version': snapshotVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'collections': <String, dynamic>{},
    };

    final collections = result['collections'] as Map<String, dynamic>;

    for (final name in backupCollections) {
      try {
        final snap = await _firestore.collection(name).get();
        final docs = <Map<String, dynamic>>[];
        for (final doc in snap.docs) {
          docs.add({
            'id': doc.id,
            'data': _encodeValue(doc.data()),
          });
        }
        collections[name] = docs;
        onProgress?.call(name, docs.length);
      } catch (e) {
        debugPrint('[BackupService] Export of "$name" failed: $e');
        collections[name] = <Map<String, dynamic>>[];
      }
    }

    return result;
  }

  /// Convert a parsed snapshot back into Firestore. Each collection is
  /// written in batches of 500 with `set(merge: false)`, replacing any
  /// existing document with the same id.
  ///
  /// When [dryRun] is true, no writes happen — only counts are returned.
  Future<RestoreSummary> restore(
    Map<String, dynamic> snapshot, {
    bool dryRun = true,
    void Function(String collection, int written, int total)? onProgress,
  }) async {
    final errors = <String>[];

    final raw = snapshot['collections'];
    if (raw is! Map) {
      throw const FormatException(
        'Ungültiges Backup: Feld "collections" fehlt oder ist kein Objekt.',
      );
    }
    final collections = Map<String, dynamic>.from(raw);
    final perCollection = <String, int>{};
    var total = 0;

    for (final name in backupCollections) {
      final docs = collections[name];
      if (docs is! List) {
        perCollection[name] = 0;
        continue;
      }
      perCollection[name] = docs.length;
      total += docs.length;

      if (dryRun) continue;

      final ref = _firestore.collection(name);
      var batch = _firestore.batch();
      var inBatch = 0;
      var written = 0;

      for (final entry in docs) {
        if (entry is! Map) {
          errors.add('$name: ungültiger Eintrag übersprungen');
          continue;
        }
        final id = entry['id'];
        final data = entry['data'];
        if (id is! String || data is! Map) {
          errors.add('$name: Eintrag ohne id/data übersprungen');
          continue;
        }
        final decoded = _decodeValue(Map<String, dynamic>.from(data));
        batch.set(ref.doc(id), decoded as Map<String, dynamic>);
        inBatch++;
        if (inBatch >= 500) {
          await batch.commit();
          written += inBatch;
          onProgress?.call(name, written, docs.length);
          batch = _firestore.batch();
          inBatch = 0;
        }
      }

      if (inBatch > 0) {
        await batch.commit();
        written += inBatch;
        onProgress?.call(name, written, docs.length);
      }
    }

    return RestoreSummary(
      dryRun: dryRun,
      collections: perCollection,
      totalDocs: total,
      errors: errors,
    );
  }

  /// Encode JSON for download.
  String exportToJsonString(Map<String, dynamic> snapshot) =>
      const JsonEncoder.withIndent('  ').convert(snapshot);

  /// Parse a previously-exported JSON string.
  Map<String, dynamic> parseSnapshot(String jsonText) {
    final decoded = json.decode(jsonText);
    if (decoded is! Map) {
      throw const FormatException('Backup-Datei ist kein JSON-Objekt.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  // --- internal codec ----------------------------------------------------

  static const String _tsTag = '__timestamp__';
  static const String _refTag = '__docref__';
  static const String _geoTag = '__geopoint__';

  Object? _encodeValue(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) {
      return {_tsTag: value.toDate().toUtc().toIso8601String()};
    }
    if (value is DocumentReference) {
      return {_refTag: value.path};
    }
    if (value is GeoPoint) {
      return {_geoTag: [value.latitude, value.longitude]};
    }
    if (value is Map) {
      return value
          .map((k, v) => MapEntry(k.toString(), _encodeValue(v)));
    }
    if (value is List) {
      return value.map(_encodeValue).toList();
    }
    return value;
  }

  Object? _decodeValue(Object? value) {
    if (value is Map) {
      if (value.length == 1) {
        if (value.containsKey(_tsTag)) {
          final iso = value[_tsTag];
          if (iso is String) {
            final dt = DateTime.tryParse(iso);
            if (dt != null) return Timestamp.fromDate(dt);
          }
        }
        if (value.containsKey(_refTag)) {
          final path = value[_refTag];
          if (path is String) return _firestore.doc(path);
        }
        if (value.containsKey(_geoTag)) {
          final coords = value[_geoTag];
          if (coords is List && coords.length == 2) {
            return GeoPoint(
              (coords[0] as num).toDouble(),
              (coords[1] as num).toDouble(),
            );
          }
        }
      }
      return value
          .map((k, v) => MapEntry(k.toString(), _decodeValue(v)));
    }
    if (value is List) {
      return value.map(_decodeValue).toList();
    }
    return value;
  }
}
