import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/delegate.dart';

class DelegateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'delegates';

  // Get all delegates
  Stream<List<Delegate>> getDelegates() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) {
          List<Delegate> delegates = snapshot.docs
              .map((doc) => Delegate.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();
          
          // Sort locally by name
          delegates.sort((a, b) => a.fullName.compareTo(b.fullName));
          return delegates;
        });
  }

  // Get all delegates as a list (non-stream)
  Future<List<Delegate>> getAllDelegates() async {
    QuerySnapshot snapshot = await _firestore.collection(_collection).get();
    List<Delegate> delegates = snapshot.docs
        .map((doc) => Delegate.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
    
    // Sort by name
    delegates.sort((a, b) => a.fullName.compareTo(b.fullName));
    return delegates;
  }

  // Add a new delegate
  Future<void> addDelegate(Delegate delegate) async {
    // Check if email already exists
    QuerySnapshot existingEmail = await _firestore
        .collection(_collection)
        .where('email', isEqualTo: delegate.email.toLowerCase())
        .get();
        
    if (existingEmail.docs.isNotEmpty) {
      throw Exception('Ein Delegierter mit dieser E-Mail-Adresse existiert bereits');
    }

    // Create delegate with lowercase email for consistency
    final delegateToAdd = delegate.copyWith(
      email: delegate.email.toLowerCase(),
    );

    await _firestore.collection(_collection).add(delegateToAdd.toMap());
  }

  // Update delegate
  Future<void> updateDelegate(Delegate updatedDelegate) async {
    // Check if email already exists for other delegates
    QuerySnapshot existingEmail = await _firestore
        .collection(_collection)
        .where('email', isEqualTo: updatedDelegate.email.toLowerCase())
        .get();
        
    for (var doc in existingEmail.docs) {
      if (doc.id != updatedDelegate.id) {
        throw Exception('Ein anderer Delegierter mit dieser E-Mail-Adresse existiert bereits');
      }
    }

    // Update with lowercase email and updated timestamp
    final delegateToUpdate = updatedDelegate.copyWith(
      email: updatedDelegate.email.toLowerCase(),
      updatedAt: DateTime.now(),
    );

    await _firestore
        .collection(_collection)
        .doc(updatedDelegate.id)
        .update(delegateToUpdate.toMap());
  }

  // Delete delegate
  Future<void> deleteDelegate(String delegateId) async {
    await _firestore.collection(_collection).doc(delegateId).delete();
  }

  // Get delegate by ID
  Future<Delegate?> getDelegateById(String id) async {
    DocumentSnapshot doc = await _firestore.collection(_collection).doc(id).get();
    if (doc.exists) {
      return Delegate.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  // Get delegates by license type
  Future<List<Delegate>> getDelegatesByLicenseType(String licenseType) async {
    QuerySnapshot snapshot = await _firestore
        .collection(_collection)
        .where('licenseType', isEqualTo: licenseType)
        .get();
        
    List<Delegate> delegates = snapshot.docs
        .map((doc) => Delegate.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
        
    // Sort by name
    delegates.sort((a, b) => a.fullName.compareTo(b.fullName));
    return delegates;
  }

  // Search delegates
  Future<List<Delegate>> searchDelegates(String searchTerm) async {
    // Get all delegates and filter locally (Firestore doesn't support complex text search)
    List<Delegate> allDelegates = await getAllDelegates();
    final term = searchTerm.toLowerCase();
    
    return allDelegates.where((d) => 
      d.firstName.toLowerCase().contains(term) ||
      d.lastName.toLowerCase().contains(term) ||
      d.email.toLowerCase().contains(term) ||
      d.licenseType.toLowerCase().contains(term)
    ).toList();
  }

  // Get delegate count
  Future<int> get delegateCount async {
    QuerySnapshot snapshot = await _firestore.collection(_collection).get();
    return snapshot.docs.length;
  }

  // Get license type distribution
  Future<Map<String, int>> getLicenseTypeDistribution() async {
    List<Delegate> allDelegates = await getAllDelegates();
    final distribution = <String, int>{};
    
    for (final licenseType in Delegate.licenseTypes) {
      distribution[licenseType] = allDelegates.where((d) => d.licenseType == licenseType).length;
    }
    return distribution;
  }

  // Initialize with sample data
  Future<void> initializeSampleData() async {
    // Check if data already exists
    QuerySnapshot existing = await _firestore.collection(_collection).limit(1).get();
    if (existing.docs.isNotEmpty) return;

    // Add sample delegates
    List<Delegate> sampleDelegates = [
      Delegate(
        id: '',
        firstName: 'Hans',
        lastName: 'Müller',
        email: 'hans.mueller@example.com',
        licenseType: 'EHF Delegate',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Delegate(
        id: '',
        firstName: 'Petra',
        lastName: 'Schneider',
        email: 'petra.schneider@example.com',
        licenseType: 'DHB National Delegate',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Delegate(
        id: '',
        firstName: 'Michael',
        lastName: 'Fischer',
        email: 'michael.fischer@example.com',
        licenseType: 'EHF Delegate',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    for (Delegate delegate in sampleDelegates) {
      await addDelegate(delegate);
    }
  }

  // Dispose method (kept for compatibility but not needed for Firebase)
  void dispose() {
    // Firebase streams dispose automatically
  }
} 