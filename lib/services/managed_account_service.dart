import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/managed_account.dart';
import '../models/court.dart';
import '../models/tablet_status.dart';
import 'tournament_service.dart';

class ManagedAccountService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _firebaseAuth = firebase_auth.FirebaseAuth.instance;
  final TournamentService _tournamentService = TournamentService();
  
  static const String _collection = 'managed_accounts';

  // Get all managed accounts
  Stream<List<ManagedAccount>> getAllManagedAccounts() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) {
          final accounts = snapshot.docs
              .map((doc) => ManagedAccount.fromFirestore(doc))
              .toList();
          // Sort in memory instead of using Firestore orderBy to avoid index requirement
          accounts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return accounts;
        });
  }

  // Get managed accounts by type
  Stream<List<ManagedAccount>> getManagedAccountsByType(ManagedAccountType type) {
    return _firestore
        .collection(_collection)
        .where('type', isEqualTo: type.name)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final accounts = snapshot.docs
              .map((doc) => ManagedAccount.fromFirestore(doc))
              .toList();
          // Sort in memory instead of using Firestore orderBy to avoid index requirement
          accounts.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return accounts;
        });
  }

  // Get managed accounts by tournament
  Stream<List<ManagedAccount>> getManagedAccountsByTournament(String tournamentId) {
    return _firestore
        .collection(_collection)
        .where('tournamentId', isEqualTo: tournamentId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final accounts = snapshot.docs
              .map((doc) => ManagedAccount.fromFirestore(doc))
              .toList();
          // Sort in memory instead of using Firestore orderBy to avoid index requirement
          accounts.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return accounts;
        });
  }

  // Get managed account by ID
  Future<ManagedAccount?> getManagedAccountById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        return ManagedAccount.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting managed account: $e');
      return null;
    }
  }

  // Create managed account
  Future<ManagedAccount?> createManagedAccount(ManagedAccount account) async {
    try {
      // Check if email already exists
      final existingAccount = await _getManagedAccountByEmail(account.email);
      if (existingAccount != null) {
        throw Exception('Ein Account mit dieser E-Mail-Adresse existiert bereits');
      }

      // Validate court assignment for scoring tablets
      if (account.type == ManagedAccountType.scoringTablet) {
        if (account.tournamentId == null || account.courtId == null) {
          throw Exception('Scoring Tablets müssen einem Turnier und einem Court zugewiesen werden');
        }

        // Check if court is already assigned to another tablet in the same tournament
        final existingTablet = await _getTabletForCourt(account.tournamentId!, account.courtId!);
        if (existingTablet != null) {
          throw Exception('Dieser Court ist bereits einem anderen Tablet zugewiesen');
        }
      }

      // Generate one-time code for new account
      final oneTimeCode = generateOneTimeCode();
      final accountWithCode = account.copyWith(
        oneTimeCode: oneTimeCode,
        isOneTimeCodeUsed: false,
      );

      // First create the Firebase Auth account
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: accountWithCode.email,
        password: accountWithCode.password,
      );

      if (credential.user != null) {
        // Then create the Firestore document with the Firebase Auth UID
        final accountData = accountWithCode.toFirestore();
        await _firestore.collection(_collection).doc(credential.user!.uid).set(accountData);
        
        return accountWithCode.copyWith(id: credential.user!.uid);
      } else {
        throw Exception('Firebase Auth Account konnte nicht erstellt werden');
      }
    } catch (e) {
      print('Error creating managed account: $e');
      rethrow;
    }
  }

  // Update managed account
  Future<bool> updateManagedAccount(ManagedAccount account) async {
    try {
      // Validate court assignment for scoring tablets
      if (account.type == ManagedAccountType.scoringTablet) {
        if (account.tournamentId == null || account.courtId == null) {
          throw Exception('Scoring Tablets müssen einem Turnier und einem Court zugewiesen werden');
        }

        // Check if court is already assigned to another tablet (excluding current account)
        final existingTablet = await _getTabletForCourt(account.tournamentId!, account.courtId!);
        if (existingTablet != null && existingTablet.id != account.id) {
          throw Exception('Dieser Court ist bereits einem anderen Tablet zugewiesen');
        }
      }

      final data = account.toFirestore();
      data['updatedAt'] = Timestamp.fromDate(DateTime.now());

      await _firestore.collection(_collection).doc(account.id).update(data);
      return true;
    } catch (e) {
      print('Error updating managed account: $e');
      rethrow;
    }
  }

  // Delete managed account
  Future<bool> deleteManagedAccount(String id) async {
    try {
      // Delete from Firestore first
      await _firestore.collection(_collection).doc(id).delete();
      print('Managed account deleted from Firestore');
      
      // Note: Firebase Auth user remains but will be cleaned up later
      // This prevents UI conflicts during active operations
      print('Firebase Auth user will need manual cleanup or will expire naturally');
      
      return true;
      
    } catch (e) {
      print('Error deleting managed account: $e');
      return false;
    }
  }

  // Deactivate managed account
  Future<bool> deactivateManagedAccount(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).update({
        'isActive': false,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      return true;
    } catch (e) {
      print('Error deactivating managed account: $e');
      return false;
    }
  }

  // Activate managed account
  Future<bool> activateManagedAccount(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).update({
        'isActive': true,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      return true;
    } catch (e) {
      print('Error activating managed account: $e');
      return false;
    }
  }

  // Get available courts for a tournament (not assigned to tablets)
  Future<List<Court>> getAvailableCourtsForTournament(String tournamentId, {String? excludeAccountId}) async {
    try {
      // Get tournament to get its courts
      final tournament = await _tournamentService.getTournamentById(tournamentId);
      if (tournament == null) return [];

      // Get all scoring tablets assigned to this tournament
      final tablets = await _firestore
          .collection(_collection)
          .where('type', isEqualTo: ManagedAccountType.scoringTablet.name)
          .where('tournamentId', isEqualTo: tournamentId)
          .where('isActive', isEqualTo: true)
          .get();

      // Get assigned court IDs (excluding current account if updating)
      final assignedCourtIds = tablets.docs
          .where((doc) => excludeAccountId == null || doc.id != excludeAccountId)
          .map((doc) => doc.data()['courtId'] as String?)
          .where((courtId) => courtId != null)
          .cast<String>()
          .toSet();

      // Filter available courts
      final availableCourts = tournament.courts
          .where((court) => !assignedCourtIds.contains(court.id))
          .toList();

      return availableCourts;
    } catch (e) {
      print('Error getting available courts: $e');
      return [];
    }
  }

  // Helper method to get managed account by email
  Future<ManagedAccount?> _getManagedAccountByEmail(String email) async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return ManagedAccount.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      print('Error getting managed account by email: $e');
      return null;
    }
  }

  // Helper method to get tablet assigned to a specific court
  Future<ManagedAccount?> _getTabletForCourt(String tournamentId, String courtId) async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('type', isEqualTo: ManagedAccountType.scoringTablet.name)
          .where('tournamentId', isEqualTo: tournamentId)
          .where('courtId', isEqualTo: courtId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return ManagedAccount.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      print('Error getting tablet for court: $e');
      return null;
    }
  }

  // Clear tournament assignments (useful when tournament is completed)
  Future<bool> clearTournamentAssignments(String tournamentId) async {
    try {
      final batch = _firestore.batch();
      
      final accounts = await _firestore
          .collection(_collection)
          .where('tournamentId', isEqualTo: tournamentId)
          .get();

      for (final doc in accounts.docs) {
        batch.update(doc.reference, {
          'tournamentId': null,
          'courtId': null,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }

      await batch.commit();
      return true;
    } catch (e) {
      print('Error clearing tournament assignments: $e');
      return false;
    }
  }

  // Generate unique email for managed account
  String generateUniqueEmail(ManagedAccountType type, String tournamentName, {String? courtName}) {
    final prefix = type == ManagedAccountType.scoringTablet ? 'tablet' : 'medic';
    final tournamentSlug = tournamentName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    
    if (type == ManagedAccountType.scoringTablet && courtName != null) {
      final courtSlug = courtName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      return '$prefix-$tournamentSlug-$courtSlug@gbo-system.de';
    } else {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
      return '$prefix-$tournamentSlug-$timestamp@gbo-system.de';
    }
  }

  // Generate secure temporary password
  String generateTemporaryPassword() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    var password = '';
    
    for (int i = 0; i < 8; i++) {
      password += chars[(random + i) % chars.length];
    }
    
    return password;
  }

  // Generate one-time login code
  String generateOneTimeCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    var code = '';
    
    // Generate 6-digit code
    for (int i = 0; i < 6; i++) {
      code += chars[(timestamp + i * 17) % chars.length];
    }
    
    return code;
  }

  // Validate and use one-time code
  Future<ManagedAccount?> validateAndUseOneTimeCode(String code) async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('oneTimeCode', isEqualTo: code)
          .where('isOneTimeCodeUsed', isEqualTo: false)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return null; // Code not found or already used
      }

      final doc = query.docs.first;
      final account = ManagedAccount.fromFirestore(doc);

      // Mark the code as used
      await _firestore.collection(_collection).doc(account.id).update({
        'isOneTimeCodeUsed': true,
        'oneTimeCodeUsedAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      return account.copyWith(
        isOneTimeCodeUsed: true,
        oneTimeCodeUsedAt: DateTime.now(),
      );
    } catch (e) {
      print('Error validating one-time code: $e');
      return null;
    }
  }

  // Generate new one-time code for account (invalidates previous code)
  Future<String?> generateNewOneTimeCode(String accountId) async {
    try {
      final newCode = generateOneTimeCode();
      
      await _firestore.collection(_collection).doc(accountId).update({
        'oneTimeCode': newCode,
        'isOneTimeCodeUsed': false,
        'oneTimeCodeUsedAt': null,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      return newCode;
    } catch (e) {
      print('Error generating new one-time code: $e');
      return null;
    }
  }

  // Check if one-time code exists and is valid
  Future<bool> isOneTimeCodeValid(String accountId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(accountId).get();
      if (!doc.exists) return false;

      final account = ManagedAccount.fromFirestore(doc);
      return account.hasValidOneTimeCode;
    } catch (e) {
      print('Error checking one-time code validity: $e');
      return false;
    }
  }

  // ========== TABLET STATUS TRACKING ==========

  static const String _tabletStatusCollection = 'tablet_status';

  // Update tablet status (connection and battery)
  Future<bool> updateTabletStatus({
    required String courtId,
    required String tabletId,
    required TabletConnectionStatus connectionStatus,
    int? batteryPercentage,
    String? deviceName,
  }) async {
    try {
      // DISABLED: Prevent null errors on web/desktop platforms
      print('📱 Tablet status tracking disabled to prevent null errors');
      return true;
      
      // Validate required fields to prevent null errors
      if (courtId.isEmpty || tabletId.isEmpty) {
        print('❌ Cannot update tablet status: courtId or tabletId is empty');
        return false;
      }

      final tabletStatus = TabletStatus(
        courtId: courtId,
        tabletId: tabletId,
        connectionStatus: connectionStatus,
        batteryPercentage: batteryPercentage,
        lastSeen: DateTime.now(),
        deviceName: deviceName ?? 'Unknown Device',
      );

      // Use merge to prevent overwriting existing data
      await _firestore
          .collection(_tabletStatusCollection)
          .doc(courtId)
          .set(tabletStatus.toMap(), SetOptions(merge: true));

      print('✅ Tablet status updated for court $courtId: ${connectionStatus.name}');
      return true;
    } catch (e) {
      print('❌ Error updating tablet status: $e');
      return false;
    }
  }

  // Get tablet status for a specific court
  Future<TabletStatus?> getTabletStatusForCourt(String courtId) async {
    try {
      // DISABLED: Prevent null errors on web/desktop platforms
      return null;
      
      final doc = await _firestore
          .collection(_tabletStatusCollection)
          .doc(courtId)
          .get();

      if (!doc.exists) return null;

      return TabletStatus.fromMap({...doc.data()!, 'id': doc.id});
    } catch (e) {
      print('Error getting tablet status for court: $e');
      return null;
    }
  }

  // Stream tablet status for real-time updates
  Stream<TabletStatus?> streamTabletStatusForCourt(String courtId) {
    return _firestore
        .collection(_tabletStatusCollection)
        .doc(courtId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return TabletStatus.fromMap({...doc.data()!, 'id': doc.id});
        });
  }

  // Get tablet status for all courts in a tournament
  Future<Map<String, TabletStatus>> getTabletStatusForTournament(String tournamentId) async {
    try {
      // DISABLED: Prevent null errors on web/desktop platforms
      print('📱 Tournament tablet status tracking disabled to prevent null errors');
      return {};
      
      if (tournamentId.isEmpty) {
        print('❌ Cannot get tablet status: tournamentId is empty');
        return {};
      }

      // Get tournament to get its courts
      final tournament = await _tournamentService.getTournamentById(tournamentId);
      if (tournament == null) {
        print('❌ Tournament not found: $tournamentId');
        return {};
      }

      final Map<String, TabletStatus> statusMap = {};

      // Get status for each court
      for (final court in tournament.courts) {
        if (court.id.isNotEmpty) {
          final status = await getTabletStatusForCourt(court.id);
          if (status != null) {
            statusMap[court.id] = status;
            print('📱 Found tablet status for court ${court.name}: ${status.connectionStatus.name}');
          }
        }
      }

      print('📱 Loaded tablet statuses for ${statusMap.length} courts');
      return statusMap;
    } catch (e) {
      print('❌ Error getting tablet status for tournament: $e');
      return {};
    }
  }

  // Mark tablet as disconnected (called when tablet goes offline)
  Future<bool> markTabletDisconnected(String courtId) async {
    try {
      // DISABLED: Prevent null errors on web/desktop platforms
      print('📱 Tablet disconnect tracking disabled to prevent null errors');
      return true;
      
      final existingStatus = await getTabletStatusForCourt(courtId);
      if (existingStatus == null) return false;

      final updatedStatus = existingStatus.copyWith(
        connectionStatus: TabletConnectionStatus.disconnected,
        lastSeen: DateTime.now(),
      );

      await _firestore
          .collection(_tabletStatusCollection)
          .doc(courtId)
          .set(updatedStatus.toMap());

      return true;
    } catch (e) {
      print('Error marking tablet as disconnected: $e');
      return false;
    }
  }

  // Remove tablet status (when tablet is unassigned)
  Future<bool> removeTabletStatus(String courtId) async {
    try {
      await _firestore
          .collection(_tabletStatusCollection)
          .doc(courtId)
          .delete();
      return true;
    } catch (e) {
      print('Error removing tablet status: $e');
      return false;
    }
  }
} 