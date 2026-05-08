import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/observation_template.dart';

class ObservationTemplateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'observation_templates';

  Stream<List<ObservationTemplate>> getTemplates({String? type}) {
    Query query = _firestore.collection(_collection);
    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }
    return query.snapshots().map((snap) => snap.docs
        .map((doc) => ObservationTemplate.fromMap(
            doc.data() as Map<String, dynamic>, doc.id))
        .toList());
  }

  Future<ObservationTemplate?> getTemplate(String id) async {
    final doc = await _firestore.collection(_collection).doc(id).get();
    if (!doc.exists) return null;
    return ObservationTemplate.fromMap(
        doc.data() as Map<String, dynamic>, doc.id);
  }

  Future<String> addTemplate(ObservationTemplate template) async {
    final now = DateTime.now();
    final ref = await _firestore.collection(_collection).add(
          template.copyWith(createdAt: now, updatedAt: now).toMap(),
        );
    return ref.id;
  }

  Future<void> updateTemplate(ObservationTemplate template) async {
    await _firestore
        .collection(_collection)
        .doc(template.id)
        .update(template.copyWith(updatedAt: DateTime.now()).toMap());
  }

  Future<void> deleteTemplate(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }
}
