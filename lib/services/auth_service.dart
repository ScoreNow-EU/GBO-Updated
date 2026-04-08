import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart' as app_user;
import '../models/referee.dart';
import '../models/team_manager.dart';
import '../services/referee_service.dart';
import '../services/team_manager_service.dart';
import '../services/notification_monitoring_service.dart';
import '../models/managed_account.dart';
import '../services/managed_account_service.dart';

class AuthService {
  final firebase_auth.FirebaseAuth _firebaseAuth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RefereeService _refereeService = RefereeService();
  final TeamManagerService _teamManagerService = TeamManagerService();
  
  static const String _usersCollection = 'users';

  // Get current firebase user
  firebase_auth.User? get currentFirebaseUser => _firebaseAuth.currentUser;

  // Get current app user stream
  Stream<app_user.User?> get currentUser {
    return _firebaseAuth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) {
        // Stop notification monitoring when user logs out
        await NotificationMonitoringService.stopMonitoring();
        return null;
      }
      final user = await getUserById(firebaseUser.uid);
      if (user != null) {
        // Start notification monitoring for logged in user
        await NotificationMonitoringService.initialize();
        await NotificationMonitoringService.startMonitoring(user.email);
      }
      return user;
    });
  }

  // Get current user as a Future
  Future<app_user.User?> getCurrentUser() async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) return null;
    return await getUserById(firebaseUser.uid);
  }

  // Update user profile information
  Future<void> updateUserProfile({
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Update email in Firebase Auth if it changed
      if (user.email != email) {
        await user.verifyBeforeUpdateEmail(email);
      }

      // Update profile in Firestore
      await _firestore.collection(_usersCollection).doc(user.uid).update({
        'firstName': firstName,
        'lastName': lastName,
        'email': email.toLowerCase(),
      });
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      rethrow;
    }
  }

  // Update user password
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Re-authenticate user before password change
      final credential = firebase_auth.EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);
    } catch (e) {
      debugPrint('Error updating password: $e');
      rethrow;
    }
  }

  // Update user preferences
  Future<void> updateUserPreferences({
    String? defaultTournamentFilter,
    String? defaultSeason,
  }) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) throw Exception('No user logged in');

      final updateData = <String, dynamic>{};
      if (defaultTournamentFilter != null) {
        updateData['defaultTournamentFilter'] = defaultTournamentFilter;
      }
      if (defaultSeason != null) {
        updateData['defaultSeason'] = defaultSeason;
      }

      await _firestore.collection(_usersCollection).doc(user.uid).update(updateData);
    } catch (e) {
      debugPrint('Error updating user preferences: $e');
      rethrow;
    }
  }

  // Sign in with email and password
  Future<app_user.User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Get or create user profile
        app_user.User? user = await getUserById(credential.user!.uid);
        
        if (user == null) {
          // Check if this email belongs to a referee
          final referee = await _checkIfRefereeEmail(email);
          // Check if this email belongs to a team manager
          final teamManager = await _checkIfTeamManagerEmail(email);
          
          if (referee != null) {
            // Create user profile with referee role
            user = await _createUserFromReferee(credential.user!, referee);
          } else if (teamManager != null) {
            // Create user profile with team manager role
            user = await _createUserFromTeamManager(credential.user!, teamManager);
          } else {
            // Create default admin user for unassigned emails
            user = await _createDefaultUser(credential.user!);
          }
        }

        // Update last login
        if (user != null) {
          await _updateLastLogin(user.id);
          
          // Initialize and start notification monitoring
          await NotificationMonitoringService.initialize();
          await NotificationMonitoringService.startMonitoring(user.email);
        }

        return user;
      }
    } catch (e) {
      debugPrint('Error signing in: $e');
      rethrow;
    }
    return null;
  }

  // Register new user
  Future<app_user.User?> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Check if this email belongs to a referee
        final referee = await _checkIfRefereeEmail(email);
        // Check if this email belongs to a team manager
        final teamManager = await _checkIfTeamManagerEmail(email);
        
        app_user.UserRole role = app_user.UserRole.user; // Default role for unassigned users
        String? refereeId;
        String? teamManagerId;

        if (referee != null) {
          role = app_user.UserRole.referee;
          refereeId = referee.id;
        } else if (teamManager != null) {
          role = app_user.UserRole.teamManager;
          teamManagerId = teamManager.id;
          // Link the user to the team manager record
          await _teamManagerService.linkUserToTeamManager(email, credential.user!.uid);
        }

        // Create user profile
        final user = app_user.User(
          id: credential.user!.uid,
          email: email,
          firstName: firstName,
          lastName: lastName,
          roles: [role],
          createdAt: DateTime.now(),
          refereeId: refereeId,
          teamManagerId: teamManagerId,
        );

        await _firestore.collection(_usersCollection).doc(user.id).set(user.toFirestore());
        // Sync display name to Firebase Auth so it's consistently available
        await credential.user!.updateProfile(displayName: '$firstName $lastName');
        return user;
      }
    } catch (e) {
      debugPrint('Error registering user: $e');
      rethrow;
    }
    return null;
  }

  // Sign out
  Future<void> signOut() async {
    await NotificationMonitoringService.stopMonitoring();
    await _firebaseAuth.signOut();
  }

  // Get user by ID
  Future<app_user.User?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(userId).get();
      if (doc.exists) {
        return app_user.User.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint('Error getting user: $e');
    }
    return null;
  }

  // Check if email belongs to a referee
  Future<Referee?> _checkIfRefereeEmail(String email) async {
    try {
      final referees = await _refereeService.getAllReferees();
      return referees.firstWhere(
        (referee) => referee.email.toLowerCase() == email.toLowerCase(),
        orElse: () => throw StateError('No referee found'),
      );
    } catch (e) {
      return null; // No referee found with this email
    }
  }

  // Check if email belongs to a team manager
  Future<TeamManager?> _checkIfTeamManagerEmail(String email) async {
    try {
      return await _teamManagerService.getTeamManagerByEmail(email);
    } catch (e) {
      return null; // No team manager found with this email
    }
  }

  // Create user from referee
  Future<app_user.User> _createUserFromReferee(firebase_auth.User firebaseUser, Referee referee) async {
    final user = app_user.User(
      id: firebaseUser.uid,
      email: firebaseUser.email!,
      firstName: referee.firstName,
      lastName: referee.lastName,
      roles: [app_user.UserRole.referee],
      createdAt: DateTime.now(),
      refereeId: referee.id,
    );

    await _firestore.collection(_usersCollection).doc(user.id).set(user.toFirestore());
    return user;
  }

  // Create user from team manager
  Future<app_user.User> _createUserFromTeamManager(firebase_auth.User firebaseUser, TeamManager teamManager) async {
    // Link the user to the team manager record
    await _teamManagerService.linkUserToTeamManager(firebaseUser.email!, firebaseUser.uid);
    
    final user = app_user.User(
      id: firebaseUser.uid,
      email: firebaseUser.email!,
      firstName: teamManager.name.split(' ').first,
      lastName: teamManager.name.split(' ').skip(1).join(' '),
      roles: [app_user.UserRole.teamManager],
      createdAt: DateTime.now(),
      teamManagerId: teamManager.id,
    );

    await _firestore.collection(_usersCollection).doc(user.id).set(user.toFirestore());
    return user;
  }

  // Create default user (admin for unassigned emails)
  Future<app_user.User> _createDefaultUser(firebase_auth.User firebaseUser) async {
    final firstName = firebaseUser.displayName?.split(' ').first ?? '';
    final lastName = firebaseUser.displayName?.split(' ').skip(1).join(' ') ?? '';

    final user = app_user.User(
      id: firebaseUser.uid,
      email: firebaseUser.email!,
      firstName: firstName,
      lastName: lastName,
      roles: [app_user.UserRole.admin],
      createdAt: DateTime.now(),
    );

    await _firestore.collection(_usersCollection).doc(user.id).set(user.toFirestore());
    return user;
  }

  // Update last login time
  Future<void> _updateLastLogin(String userId) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'lastLoginAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      debugPrint('Error updating last login: $e');
    }
  }

  // Update user role (admin function)
  Future<bool> updateUserRole(String userId, app_user.UserRole newRole, {
    String? refereeId,
    String? teamManagerId,
    String? delegateId,
  }) async {
    try {
      final updateData = {
        'role': newRole.name,
        'refereeId': refereeId,
        'teamManagerId': teamManagerId,
        'delegateId': delegateId,
      };

      await _firestore.collection(_usersCollection).doc(userId).update(updateData);
      return true;
    } catch (e) {
      debugPrint('Error updating user role: $e');
      return false;
    }
  }

  // Create sample referee users for testing
  Future<void> createSampleRefereeUsers() async {
    // This would be called after creating sample referees
    try {
      final referees = await _refereeService.getAllReferees();
      
      for (final referee in referees.take(2)) { // Create users for first 2 referees
        // Check if user already exists
        final existingUser = await getUserByEmail(referee.email);
        if (existingUser == null) {
          final user = app_user.User(
            id: 'referee_${referee.id}', // Using custom ID for demo
            email: referee.email,
            firstName: referee.firstName,
            lastName: referee.lastName,
            roles: [app_user.UserRole.referee],
            createdAt: DateTime.now(),
            refereeId: referee.id,
          );

          await _firestore.collection(_usersCollection).doc(user.id).set(user.toFirestore());
        }
      }
    } catch (e) {
      debugPrint('Error creating sample referee users: $e');
    }
  }

  // Get user by email
  Future<app_user.User?> getUserByEmail(String email) async {
    try {
      final query = await _firestore
          .collection(_usersCollection)
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        return app_user.User.fromFirestore(query.docs.first);
      }
    } catch (e) {
      debugPrint('Error getting user by email: $e');
    }
    return null;
  }

  // Get all users
  Future<List<app_user.User>> getAllUsers() async {
    try {
      final query = await _firestore
          .collection(_usersCollection)
          .orderBy('firstName')
          .get();
      
      return query.docs
          .map((doc) => app_user.User.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting all users: $e');
      return [];
    }
  }

  // Update user active status
  Future<void> updateUserStatus(String userId, bool isActive) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .update({'isActive': isActive});
    } catch (e) {
      debugPrint('Error updating user status: $e');
      throw Exception('Failed to update user status');
    }
  }

  // Add role to user (supports multiple roles)
  Future<bool> addRoleToUser(String userId, app_user.UserRole role, {
    String? refereeId,
    String? teamManagerId,
    String? delegateId,
  }) async {
    try {
      final user = await getUserById(userId);
      if (user == null) {
        debugPrint('User not found: $userId');
        return false;
      }

      // Check if user already has this role
      bool hasRole = user.roles.contains(role);
      bool needsUpdate = false;
      
      final updateData = <String, dynamic>{};
      
      // Add role if not already present
      if (!hasRole) {
        final updatedRoles = [...user.roles, role];
        updateData['roles'] = updatedRoles.map((r) => r.name).toList();
        needsUpdate = true;
        debugPrint('Adding role ${role.name} to user');
      }

      // Set specific role IDs if provided (even if user already has the role)
      if (refereeId != null && user.refereeId != refereeId) {
        updateData['refereeId'] = refereeId;
        needsUpdate = true;
        debugPrint('Updating refereeId to: $refereeId');
      }
      if (teamManagerId != null && user.teamManagerId != teamManagerId) {
        updateData['teamManagerId'] = teamManagerId;
        needsUpdate = true;
        debugPrint('Updating teamManagerId to: $teamManagerId');
      }
      if (delegateId != null && user.delegateId != delegateId) {
        updateData['delegateId'] = delegateId;
        needsUpdate = true;
        debugPrint('Updating delegateId to: $delegateId');
      }

      if (!needsUpdate) {
        debugPrint('No updates needed for user ${user.fullName}');
        return false;
      }

      await _firestore.collection(_usersCollection).doc(userId).update(updateData);
      debugPrint('âœ… Successfully updated user record');
      return true;
    } catch (e) {
      debugPrint('Error adding role to user: $e');
      return false;
    }
  }

  // Remove role from user (supports multiple roles)
  Future<bool> removeRoleFromUser(String userId, app_user.UserRole role) async {
    try {
      final user = await getUserById(userId);
      if (user == null) {
        debugPrint('User not found: $userId');
        return false;
      }

      // Check if user has this role
      if (!user.roles.contains(role)) {
        debugPrint('User does not have role: ${role.name}');
        return false;
      }

      // Remove the role from the list
      final updatedRoles = user.roles.where((r) => r != role).toList();
      
      // Ensure user has at least one role
      if (updatedRoles.isEmpty) {
        debugPrint('Cannot remove last role from user');
        return false;
      }

      final updateData = <String, dynamic>{
        'roles': updatedRoles.map((r) => r.name).toList(),
      };

      // Clear specific role IDs when removing roles
      if (role == app_user.UserRole.referee) {
        updateData['refereeId'] = null;
      } else if (role == app_user.UserRole.teamManager) {
        updateData['teamManagerId'] = null;
      } else if (role == app_user.UserRole.delegate) {
        updateData['delegateId'] = null;
      }

      await _firestore.collection(_usersCollection).doc(userId).update(updateData);
      return true;
    } catch (e) {
      debugPrint('Error removing role from user: $e');
      return false;
    }
  }

  // Sign in with one-time code for managed accounts
  Future<app_user.User?> signInWithOneTimeCode(String code) async {
    try {
      // Validate the one-time code
      final codeData = await validateOneTimeCode(code);
      
      if (codeData == null) {
        throw Exception('UngÃ¼ltiger oder bereits verwendeter Code');
      }

      final email = codeData['preEnteredEmail'] as String;
      final teamName = codeData['teamName'] as String;
      final rolesList = codeData['roles'] as List<dynamic>? ?? ['user'];

      // Convert role strings to UserRole enums
      final roles = rolesList
          .map((r) => app_user.UserRole.values.firstWhere(
              (e) => e.name == r,
              orElse: () => app_user.UserRole.user))
          .toList();

      // Check if user already exists
      var existingUser = await getUserByEmail(email);
      
      if (existingUser != null) {
        // User exists - add roles if not already present
        for (var role in roles) {
          if (!existingUser.roles.contains(role)) {
            existingUser.roles.add(role);
          }
        }
        // Update user with new roles
        await _firestore.collection(_usersCollection).doc(existingUser.id).update({
          'roles': existingUser.roles.map((r) => r.name).toList(),
        });
      } else {
        // Create new user with one-time code
        // Generate a temporary password
        final tempPassword = _generateTemporaryPassword();
        
        // Create Firebase Auth account
        final credential = await _firebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: tempPassword,
        );

        if (credential.user != null) {
          // Create user profile with assigned roles
          final newUser = app_user.User(
            id: credential.user!.uid,
            email: email,
            firstName: '',
            lastName: '',
            roles: roles.isEmpty ? [app_user.UserRole.user] : roles,
            isActive: true,
            createdAt: DateTime.now(),
            lastLoginAt: DateTime.now(),
          );

          await _firestore.collection(_usersCollection).doc(newUser.id).set(newUser.toFirestore());
          existingUser = newUser;
        }
      }

      // Mark code as used
      await _firestore.collection('oneTimeCodes').doc(code).update({
        'isUsed': true,
        'usedByUserId': existingUser?.id ?? '',
        'usedAt': DateTime.now(),
      });

      if (existingUser != null) {
        // Update last login
        await _updateLastLogin(existingUser.id);
        
        // Initialize and start notification monitoring
        await NotificationMonitoringService.initialize();
        await NotificationMonitoringService.startMonitoring(existingUser.email);
      }

      return existingUser;
    } catch (e) {
      debugPrint('Error signing in with one-time code: $e');
      rethrow;
    }
  }

  // Generate temporary password for one-time code users
  String _generateTemporaryPassword() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%';
    final random = DateTime.now().microsecond;
    String password = '';
    for (int i = 0; i < 12; i++) {
      password += chars[(random + i) % chars.length];
    }
    return password;
  }

  // Delete user account
  Future<void> deleteAccount() async {
    try {
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      // Delete user document from Firestore
      await _firestore.collection(_usersCollection).doc(currentUser.uid).delete();

      // Delete Firebase Auth user
      await currentUser.delete();

      debugPrint('User account deleted successfully');
    } catch (e) {
      debugPrint('Error deleting account: $e');
      rethrow;
    }
  }

  // Generate one-time sign-in code
  Future<String> generateOneTimeCode({
    required String teamName,
    required String preEnteredEmail,
    required int validityDays,
    required List<app_user.UserRole> roles,
  }) async {
    try {
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      // Generate a random 8-character code
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      final random = DateTime.now().microsecond;
      String code = '';
      for (int i = 0; i < 8; i++) {
        code += chars[(random + i) % chars.length];
      }

      // Create one-time code document
      final oneTimeCode = {
        'code': code,
        'teamName': teamName,
        'preEnteredEmail': preEnteredEmail,
        'expiryDate': DateTime.now().add(Duration(days: validityDays)),
        'isUsed': false,
        'createdByAdminId': currentUser.uid,
        'createdAt': DateTime.now(),
        'usedByUserId': null,
        'usedAt': null,
        'roles': roles.map((r) => r.name).toList(),
      };

      await _firestore.collection('oneTimeCodes').doc(code).set(oneTimeCode);
      return code;
    } catch (e) {
      debugPrint('Error generating one-time code: $e');
      rethrow;
    }
  }

  // Validate and retrieve one-time code
  Future<Map<String, dynamic>?> validateOneTimeCode(String code) async {
    try {
      final doc = await _firestore.collection('oneTimeCodes').doc(code).get();
      
      if (!doc.exists) {
        throw Exception('Code not found');
      }

      final data = doc.data()!;
      final expiryDate = (data['expiryDate'] as Timestamp).toDate();
      final isUsed = data['isUsed'] as bool;

      // Check if code is still valid
      if (isUsed) {
        throw Exception('Code has already been used');
      }

      if (DateTime.now().isAfter(expiryDate)) {
        throw Exception('Code has expired');
      }

      return {
        'code': code,
        'teamName': data['teamName'],
        'preEnteredEmail': data['preEnteredEmail'],
        'roles': data['roles'] ?? ['user'],
      };
    } catch (e) {
      debugPrint('Error validating one-time code: $e');
      rethrow;
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Error sending password reset email: $e');
      rethrow;
    }
  }

  // Delete user account by admin
  Future<void> deleteUserAccount(String userId) async {
    try {
      // Get user data before deletion for cleanup
      final userDoc = await _firestore.collection(_usersCollection).doc(userId).get();
      
      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      // Delete associated documents based on user roles
      final userData = userDoc.data() as Map<String, dynamic>;
      final roles = userData['roles'] as List<dynamic>? ?? [];

      // Delete referee data if user is a referee
      if (roles.contains('referee')) {
        await _refereeService.deleteRefereeByUserId(userId);
      }

      // Delete team manager data if user is a team manager
      if (roles.contains('team_manager')) {
        await _teamManagerService.deleteTeamManagerByUserId(userId);
      }

      // Delete managed accounts if user has any
      await _firestore
          .collection('managed_accounts')
          .where('userId', isEqualTo: userId)
          .get()
          .then((snapshot) {
            for (var doc in snapshot.docs) {
              doc.reference.delete();
            }
          });

      // Delete user document from Firestore
      await _firestore.collection(_usersCollection).doc(userId).delete();

      // Delete Firebase Auth user
      try {
        final firebaseUser = _firebaseAuth.currentUser;
        if (firebaseUser != null && firebaseUser.uid == userId) {
          // Current user deleting their own account â€” use client SDK
          await firebaseUser.delete();
        } else {
          // Admin deleting another user â€” use Cloud Function with Admin SDK
          debugPrint('Admin user deletion requires Firebase Console - cloud function not deployed');
        }
      } catch (e) {
        debugPrint('Warning: Could not delete Firebase Auth account: $e');
        // Continue with Firestore deletion even if Auth deletion fails
      }

      debugPrint('User account $userId deleted successfully');
    } catch (e) {
      debugPrint('Error deleting user account: $e');
      rethrow;
    }
  }

} 