import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/player.dart';

class PlayerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'players';

  // Create a new player
  Future<String?> addPlayer(Player player) async {
    try {
      // Check if email already exists
      QuerySnapshot existingEmail = await _firestore
          .collection(_collection)
          .where('email', isEqualTo: player.email.toLowerCase())
          .get();

      if (existingEmail.docs.isNotEmpty) {
        throw Exception('Ein Spieler mit dieser E-Mail existiert bereits');
      }

      // Create player with lowercase email for consistency
      DocumentReference docRef = await _firestore.collection(_collection).add({
        'firstName': player.firstName,
        'lastName': player.lastName,
        'email': player.email.toLowerCase(),
        'phone': player.phone,
        'birthDate': player.birthDate != null ? Timestamp.fromDate(player.birthDate!) : null,
        'position': player.position,
        'jerseyNumber': player.jerseyNumber,
        'clubId': player.clubId,
        'gender': player.gender,
        'isActive': player.isActive,
        'createdAt': Timestamp.fromDate(player.createdAt),
      });
      return docRef.id;
    } catch (e) {
      print('Error adding player: $e');
      return null;
    }
  }

  // Update an existing player
  Future<bool> updatePlayer(Player updatedPlayer) async {
    try {
      // Check if email already exists for other players
      QuerySnapshot existingEmail = await _firestore
          .collection(_collection)
          .where('email', isEqualTo: updatedPlayer.email.toLowerCase())
          .get();

      for (var doc in existingEmail.docs) {
        if (doc.id != updatedPlayer.id) {
          throw Exception('Ein anderer Spieler mit dieser E-Mail existiert bereits');
        }
      }

      // Update with lowercase email and updated timestamp
      await _firestore.collection(_collection).doc(updatedPlayer.id).update({
        'firstName': updatedPlayer.firstName,
        'lastName': updatedPlayer.lastName,
        'email': updatedPlayer.email.toLowerCase(),
        'phone': updatedPlayer.phone,
        'birthDate': updatedPlayer.birthDate != null ? Timestamp.fromDate(updatedPlayer.birthDate!) : null,
        'position': updatedPlayer.position,
        'jerseyNumber': updatedPlayer.jerseyNumber,
        'clubId': updatedPlayer.clubId,
        'gender': updatedPlayer.gender,
        'isActive': updatedPlayer.isActive,
      });
      return true;
    } catch (e) {
      print('Error updating player: $e');
      return false;
    }
  }

  // Delete a player
  Future<bool> deletePlayer(String playerId) async {
    try {
      await _firestore.collection(_collection).doc(playerId).delete();
      return true;
    } catch (e) {
      print('Error deleting player: $e');
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
      print('Error getting player: $e');
      return null;
    }
  }

  // Get all players
  Stream<List<Player>> getAllPlayers() {
    return _firestore
        .collection(_collection)
        .orderBy('lastName')
        .orderBy('firstName')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Player.fromFirestore(doc)).toList());
  }

  // Search players
  Stream<List<Player>> searchPlayers(String searchTerm) {
    return getAllPlayers().map((players) {
      final term = searchTerm.toLowerCase();
      return players.where((p) =>
          p.firstName.toLowerCase().contains(term) ||
          p.lastName.toLowerCase().contains(term) ||
          p.email.toLowerCase().contains(term) ||
          (p.position?.toLowerCase().contains(term) ?? false) ||
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
      print('Error getting players by IDs: $e');
      return [];
    }
  }

  // Bulk add players
  Future<List<String>> addPlayersInBulk(List<Player> players) async {
    List<String> results = [];
    
    for (Player player in players) {
      try {
        // Check if email already exists
        QuerySnapshot existingEmail = await _firestore
            .collection(_collection)
            .where('email', isEqualTo: player.email.toLowerCase())
            .get();

        if (existingEmail.docs.isNotEmpty) {
          results.add('FEHLER: Spieler ${player.fullName} - E-Mail bereits vorhanden');
          continue;
        }

        // Create player
        DocumentReference docRef = await _firestore.collection(_collection).add({
          'firstName': player.firstName,
          'lastName': player.lastName,
          'email': player.email.toLowerCase(),
          'phone': player.phone,
          'birthDate': player.birthDate != null ? Timestamp.fromDate(player.birthDate!) : null,
          'position': player.position,
          'jerseyNumber': player.jerseyNumber,
          'clubId': player.clubId,
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
        position: 'Blocker',
        jerseyNumber: '1',
        gender: 'male',
        createdAt: DateTime.now(),
      ),
      Player(
        id: '',
        firstName: 'Anna',
        lastName: 'Schmidt',
        email: 'anna.schmidt@example.com',
        phone: '+49 987 654321',
        position: 'Defender',
        jerseyNumber: '2',
        gender: 'female',
        createdAt: DateTime.now(),
      ),
      Player(
        id: '',
        firstName: 'Thomas',
        lastName: 'Weber',
        email: 'thomas.weber@example.com',
        position: 'Setter',
        jerseyNumber: '3',
        gender: 'male',
        createdAt: DateTime.now(),
      ),
      Player(
        id: '',
        firstName: 'Lisa',
        lastName: 'Mueller',
        email: 'lisa.mueller@example.com',
        phone: '+49 555 123456',
        position: 'Libero',
        jerseyNumber: '4',
        gender: 'female',
        createdAt: DateTime.now(),
      ),
    ];

    for (Player player in samplePlayers) {
      await addPlayer(player);
    }
  }
}
