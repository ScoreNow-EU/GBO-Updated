import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/player.dart';

class PlayerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  static const String _collection = 'players';

  /// Upload a player profile photo and persist its download URL on the player doc.
  /// [bytes] is the raw image bytes (use FilePicker with `withData: true`).
  /// [extension] is the file extension without dot, e.g. 'jpg', 'png'.
  /// Returns the download URL.
  Future<String> uploadPlayerPhoto({
    required String playerId,
    required Uint8List bytes,
    String extension = 'jpg',
  }) async {
    final path = 'playerImages/$playerId/${DateTime.now().millisecondsSinceEpoch}.$extension';
    final ref = _storage.ref().child(path);
    final metadata = SettableMetadata(contentType: 'image/$extension');
    await ref.putData(bytes, metadata);
    final url = await ref.getDownloadURL();
    await _firestore.collection(_collection).doc(playerId).update({
      'photoUrl': url,
    });
    return url;
  }

  /// Remove the photoUrl on the player doc and best-effort delete the storage object.
  Future<void> removePlayerPhoto(String playerId, {String? currentUrl}) async {
    if (currentUrl != null && currentUrl.isNotEmpty) {
      try {
        await _storage.refFromURL(currentUrl).delete();
      } catch (e) {
        debugPrint('removePlayerPhoto: storage delete failed (non-fatal): $e');
      }
    }
    await _firestore.collection(_collection).doc(playerId).update({
      'photoUrl': FieldValue.delete(),
    });
  }

  /// Upload a secondary hero image (full-height accent shown beside the name).
  Future<String> uploadPlayerSecondaryPhoto({
    required String playerId,
    required Uint8List bytes,
    String extension = 'jpg',
  }) async {
    final path =
        'playerImages/$playerId/secondary_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final ref = _storage.ref().child(path);
    final metadata = SettableMetadata(contentType: 'image/$extension');
    await ref.putData(bytes, metadata);
    final url = await ref.getDownloadURL();
    await _firestore.collection(_collection).doc(playerId).update({
      'secondaryPhotoUrl': url,
    });
    return url;
  }

  /// Remove secondary hero image.
  Future<void> removePlayerSecondaryPhoto(String playerId,
      {String? currentUrl}) async {
    if (currentUrl != null && currentUrl.isNotEmpty) {
      try {
        await _storage.refFromURL(currentUrl).delete();
      } catch (e) {
        debugPrint(
            'removePlayerSecondaryPhoto: storage delete failed (non-fatal): $e');
      }
    }
    await _firestore.collection(_collection).doc(playerId).update({
      'secondaryPhotoUrl': FieldValue.delete(),
    });
  }

  /// Persist the opacity (0..1) of the secondary hero image.
  Future<void> updatePlayerSecondaryOpacity(
      String playerId, double opacity) async {
    final clamped = opacity.clamp(0.0, 1.0);
    await _firestore.collection(_collection).doc(playerId).update({
      'secondaryPhotoOpacity': clamped,
    });
  }

  // Create a new player
  Future<String?> addPlayer(Player player) async {
    try {
      // Only check email if it's provided
      if (player.email != null && player.email!.isNotEmpty) {
        QuerySnapshot existingEmail = await _firestore
            .collection(_collection)
            .where('email', isEqualTo: player.email!.toLowerCase())
            .get();

        if (existingEmail.docs.isNotEmpty) {
          throw Exception('Ein Spieler mit dieser E-Mail existiert bereits');
        }
      }

      // Create player with optional email
      DocumentReference docRef = await _firestore.collection(_collection).add({
        'firstName': player.firstName,
        'lastName': player.lastName,
        'email': player.email?.toLowerCase() ?? '',
        'phone': player.phone,
        'birthDate': player.birthDate != null ? Timestamp.fromDate(player.birthDate!) : null,
        'classification': player.classification,
        'jerseyNumber': player.jerseyNumber,
        'gender': player.gender,
        'isActive': player.isActive,
        'createdAt': Timestamp.fromDate(player.createdAt),
      });
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding player: $e');
      return null;
    }
  }

  // Update an existing player
  Future<bool> updatePlayer(Player updatedPlayer) async {
    try {
      // Only check email if it's provided
      if (updatedPlayer.email != null && updatedPlayer.email!.isNotEmpty) {
        QuerySnapshot existingEmail = await _firestore
            .collection(_collection)
            .where('email', isEqualTo: updatedPlayer.email!.toLowerCase())
            .get();

        for (var doc in existingEmail.docs) {
          if (doc.id != updatedPlayer.id) {
            throw Exception('Ein anderer Spieler mit dieser E-Mail existiert bereits');
          }
        }
      }

      // Update with optional email
      await _firestore.collection(_collection).doc(updatedPlayer.id).update({
        'firstName': updatedPlayer.firstName,
        'lastName': updatedPlayer.lastName,
        'email': updatedPlayer.email?.toLowerCase() ?? '',
        'phone': updatedPlayer.phone,
        'birthDate': updatedPlayer.birthDate != null ? Timestamp.fromDate(updatedPlayer.birthDate!) : null,
        'classification': updatedPlayer.classification,
        'jerseyNumber': updatedPlayer.jerseyNumber,
        'gender': updatedPlayer.gender,
        'isActive': updatedPlayer.isActive,
      });
      return true;
    } catch (e) {
      debugPrint('Error updating player: $e');
      return false;
    }
  }

  // Delete a player
  Future<bool> deletePlayer(String playerId) async {
    try {
      await _firestore.collection(_collection).doc(playerId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting player: $e');
      return false;
    }
  }

  // Get a player by ID
  Future<Player?> getPlayerById(String playerId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection(_collection).doc(playerId).get();
      if (doc.exists) {
        return Player.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting player: $e');
      return null;
    }
  }

  // Get all players
  Stream<List<Player>> getAllPlayers() {
    return _firestore
        .collection(_collection)
        .limit(2000)
        .snapshots()
        .map((snapshot) {
          try {
            final players = snapshot.docs.map((doc) => Player.fromFirestore(doc)).toList();
            // Sort in memory instead of using Firestore ordering
            players.sort((a, b) {
              final lastNameComparison = a.lastName.compareTo(b.lastName);
              if (lastNameComparison != 0) return lastNameComparison;
              return a.firstName.compareTo(b.firstName);
            });
            return players;
          } catch (e) {
            debugPrint('Error mapping players from snapshot: $e');
            throw e;
          }
        })
        .handleError((error) {
          debugPrint('Error in getAllPlayers stream: $error');
          throw error;
        });
  }

  // Search players
  Stream<List<Player>> searchPlayers(String searchTerm) {
    return getAllPlayers().map((players) {
      final term = searchTerm.toLowerCase();
      return players.where((p) =>
          p.firstName.toLowerCase().contains(term) ||
          p.lastName.toLowerCase().contains(term) ||
          (p.email?.toLowerCase().contains(term) ?? false) ||
          (p.classification?.toLowerCase().contains(term) ?? false) ||
          (p.jerseyNumber?.toLowerCase().contains(term) ?? false)
      ).toList();
    });
  }

  // Get players by IDs (for team rosters)
  Future<List<Player>> getPlayersByIds(List<String> playerIds) async {
    if (playerIds.isEmpty) return [];
    
    try {
      List<Player> players = [];
      
      // Firestore 'in' queries are limited to 10 items, so batch them
      for (int i = 0; i < playerIds.length; i += 10) {
        final batch = playerIds.skip(i).take(10).toList();
        final snapshot = await _firestore
            .collection(_collection)
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        
        players.addAll(
          snapshot.docs.map((doc) => Player.fromFirestore(doc)).toList()
        );
      }
      
      return players;
    } catch (e) {
      debugPrint('Error getting players by IDs: $e');
      return [];
    }
  }

  // Bulk add players
  Future<List<String>> addPlayersInBulk(List<Player> players) async {
    List<String> results = [];
    
    for (Player player in players) {
      try {
        // Only check email if it's provided
        if (player.email != null && player.email!.isNotEmpty) {
          QuerySnapshot existingEmail = await _firestore
              .collection(_collection)
              .where('email', isEqualTo: player.email!.toLowerCase())
              .get();

          if (existingEmail.docs.isNotEmpty) {
            results.add('FEHLER: Spieler ${player.fullName} - E-Mail bereits vorhanden');
            continue;
          }
        }

        // Create player
        DocumentReference docRef = await _firestore.collection(_collection).add({
          'firstName': player.firstName,
          'lastName': player.lastName,
          'email': player.email?.toLowerCase() ?? '',
          'phone': player.phone,
          'birthDate': player.birthDate != null ? Timestamp.fromDate(player.birthDate!) : null,
          'classification': player.classification,
          'jerseyNumber': player.jerseyNumber,
          'gender': player.gender,
          'isActive': player.isActive,
          'createdAt': Timestamp.fromDate(player.createdAt),
        });
        
        results.add('ERFOLG: Spieler ${player.fullName} erstellt');
      } catch (e) {
        results.add('FEHLER: Spieler ${player.fullName} - $e');
      }
    }
    
    return results;
  }

  // Create sample players for testing
  Future<void> createSamplePlayers() async {
    List<Player> samplePlayers = [
      Player(
        id: '',
        firstName: 'Max',
        lastName: 'Mustermann',
        email: 'max.mustermann@example.com',
        phone: '+49 123 456789',
        classification: 'Gruppe A',
        jerseyNumber: '1',
        gender: 'männlich',
        createdAt: DateTime.now(),
      ),
      Player(
        id: '',
        firstName: 'Anna',
        lastName: 'Schmidt',
        email: 'anna.schmidt@example.com',
        phone: '+49 987 654321',
        classification: 'Gruppe B',
        jerseyNumber: '2',
        gender: 'weiblich',
        createdAt: DateTime.now(),
      ),
      Player(
        id: '',
        firstName: 'Thomas',
        lastName: 'Weber',
        email: 'thomas.weber@example.com',
        classification: 'Gruppe C',
        jerseyNumber: '3',
        gender: 'männlich',
        createdAt: DateTime.now(),
      ),
      Player(
        id: '',
        firstName: 'Lisa',
        lastName: 'Mueller',
        email: 'lisa.mueller@example.com',
        phone: '+49 555 123456',
        classification: 'Gruppe A',
        jerseyNumber: '4',
        gender: 'weiblich',
        createdAt: DateTime.now(),
      ),
    ];

    for (Player player in samplePlayers) {
      await addPlayer(player);
    }
  }
}
