import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart' as app_user;
import '../models/referee.dart';
import '../models/team_manager.dart';
import '../services/referee_service.dart';
import '../services/team_manager_service.dart';

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
      if (firebaseUser == null) return null;
      return await getUserById(firebaseUser.uid);
    });
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
        }

        return user;
      }
    } catch (e) {
      print('Error signing in: $e');
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
        
        app_user.UserRole role = app_user.UserRole.admin; // Default role for unassigned users
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
          role: role,
          createdAt: DateTime.now(),
          refereeId: refereeId,
          teamManagerId: teamManagerId,
        );

        await _firestore.collection(_usersCollection).doc(user.id).set(user.toFirestore());
        return user;
      }
    } catch (e) {
      print('Error registering user: $e');
      rethrow;
    }
    return null;
  }

  // Sign out
  Future<void> signOut() async {
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
      print('Error getting user: $e');
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
      role: app_user.UserRole.referee,
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
      role: app_user.UserRole.teamManager,
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
      role: app_user.UserRole.admin,
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
      print('Error updating last login: $e');
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
      print('Error updating user role: $e');
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
            role: app_user.UserRole.referee,
            createdAt: DateTime.now(),
            refereeId: referee.id,
          );

          await _firestore.collection(_usersCollection).doc(user.id).set(user.toFirestore());
        }
      }
    } catch (e) {
      print('Error creating sample referee users: $e');
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
      print('Error getting user by email: $e');
    }
    return null;
  }


} 