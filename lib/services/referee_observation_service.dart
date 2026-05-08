import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/referee_observation.dart';

class RefereeObservationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'referee_observations';

  RefereeObservation _fromDoc(DocumentSnapshot doc) =>
      RefereeObservation.fromMap(doc.data() as Map<String, dynamic>, doc.id);

  Stream<List<RefereeObservation>> getAllObservations() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(_fromDoc).toList());
  }

  Stream<List<RefereeObservation>> getObservationsForReferee(String refereeId) {
    return _firestore
        .collection(_collection)
        .where('refereeIds', arrayContains: refereeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(_fromDoc).toList());
  }

  Stream<List<RefereeObservation>> getObservationsForGame(String gameId) {
    return _firestore
        .collection(_collection)
        .where('gameId', isEqualTo: gameId)
        .snapshots()
        .map((s) => s.docs.map(_fromDoc).toList());
  }

  Stream<List<RefereeObservation>> getObservationsBySubmitter(
      String submitterId) {
    return _firestore
        .collection(_collection)
        .where('submitterId', isEqualTo: submitterId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(_fromDoc).toList());
  }

  Future<String> createObservation(RefereeObservation observation) async {
    final now = DateTime.now();
    final ref = await _firestore.collection(_collection).add(
          observation.copyWith(createdAt: now, updatedAt: now).toMap(),
        );
    return ref.id;
  }

  Future<void> updateObservation(RefereeObservation observation) async {
    await _firestore
        .collection(_collection)
        .doc(observation.id)
        .update(observation.copyWith(updatedAt: DateTime.now()).toMap());
  }

  Future<void> deleteObservation(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }
}
