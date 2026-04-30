import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/kampfgericht_member.dart';

/// Service for managing Kampfgericht (scoring table) members.
/// Kampfgericht members can serve as Zeitnehmer (Timekeeper) or Sekretär (Scorekeeper).
/// Note: All referees can also do Kampfgericht duties, but not vice versa.
class KampfgerichtService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'kampfgericht_members';

  // Get all members as a stream
  Stream<List<KampfgerichtMember>> getMembers() {
    return _firestore
        .collection(_collection)
        .limit(1000)
        .snapshots()
        .map((snapshot) {
          List<KampfgerichtMember> members = snapshot.docs
              .map((doc) => KampfgerichtMember.fromMap(
                  doc.data() as Map<String, dynamic>, doc.id))
              .toList();
          members.sort((a, b) => a.fullName.compareTo(b.fullName));
          return members;
        });
  }

  // Get all members as a list (non-stream)
  Future<List<KampfgerichtMember>> getAllMembers() async {
    QuerySnapshot snapshot = await _firestore.collection(_collection).get();
    List<KampfgerichtMember> members = snapshot.docs
        .map((doc) => KampfgerichtMember.fromMap(
            doc.data() as Map<String, dynamic>, doc.id))
        .toList();
    members.sort((a, b) => a.fullName.compareTo(b.fullName));
    return members;
  }

  // Add a new member (auto-geocodes address if provided)
  Future<void> addMember(KampfgerichtMember member) async {
    // Check if email already exists
    QuerySnapshot existingEmail = await _firestore
        .collection(_collection)
        .where('email', isEqualTo: member.email.toLowerCase())
        .get();

    if (existingEmail.docs.isNotEmpty) {
      throw Exception(
          'Ein Kampfgericht-Mitglied mit dieser E-Mail-Adresse existiert bereits');
    }

    KampfgerichtMember memberToAdd = member.copyWith(
      email: member.email.toLowerCase(),
    );

    await _firestore.collection(_collection).add(memberToAdd.toMap());
  }

  // Update a member (auto-geocodes address if changed)
  Future<void> updateMember(KampfgerichtMember updatedMember) async {
    // Check email uniqueness
    QuerySnapshot existingEmail = await _firestore
        .collection(_collection)
        .where('email', isEqualTo: updatedMember.email.toLowerCase())
        .get();

    for (var doc in existingEmail.docs) {
      if (doc.id != updatedMember.id) {
        throw Exception(
            'Ein anderes Kampfgericht-Mitglied mit dieser E-Mail-Adresse existiert bereits');
      }
    }

    KampfgerichtMember memberToUpdate = updatedMember.copyWith(
      email: updatedMember.email.toLowerCase(),
      updatedAt: DateTime.now(),
    );

    await _firestore
        .collection(_collection)
        .doc(updatedMember.id)
        .update(memberToUpdate.toMap());
  }

  // Delete a member
  Future<void> deleteMember(String memberId) async {
    await _firestore.collection(_collection).doc(memberId).delete();
  }

  // Get member by ID
  Future<KampfgerichtMember?> getMemberById(String id) async {
    DocumentSnapshot doc =
        await _firestore.collection(_collection).doc(id).get();
    if (doc.exists) {
      return KampfgerichtMember.fromMap(
          doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  // Search members
  Future<List<KampfgerichtMember>> searchMembers(String searchTerm) async {
    List<KampfgerichtMember> allMembers = await getAllMembers();
    final term = searchTerm.toLowerCase();

    return allMembers
        .where((m) =>
            m.firstName.toLowerCase().contains(term) ||
            m.lastName.toLowerCase().contains(term) ||
            m.email.toLowerCase().contains(term) ||
            (m.city?.toLowerCase().contains(term) ?? false))
        .toList();
  }

  // Get member count
  Future<int> get memberCount async {
    QuerySnapshot snapshot = await _firestore.collection(_collection).get();
    return snapshot.docs.length;
  }

  void dispose() {
    // Firebase streams dispose automatically
  }
}
