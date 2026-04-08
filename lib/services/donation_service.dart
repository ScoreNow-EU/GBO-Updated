import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/donation.dart';
import '../models/user.dart' as app_user;
import 'auth_service.dart';

class DonationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Add a donation record
  Future<bool> addDonation(Donation donation) async {
    try {
      // Add donation to donations collection
      final docRef = await _firestore.collection('donations').add(donation.toFirestore());
      
      // Update user's total donations
      await _updateUserDonationTotal(donation.userId, donation.amount);
      
      debugPrint('Donation added successfully with ID: ${docRef.id}');
      return true;
    } catch (e) {
      debugPrint('Error adding donation: $e');
      return false;
    }
  }

  // Get donations for a specific user
  Stream<List<Donation>> getUserDonations(String userId) {
    return _firestore
        .collection('donations')
        .where('userId', isEqualTo: userId)
        .orderBy('donationDate', descending: true)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => Donation.fromFirestore(doc)).toList());
  }

  // Get all donations (admin only)
  Stream<List<Donation>> getAllDonations() {
    return _firestore
        .collection('donations')
        .orderBy('donationDate', descending: true)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => Donation.fromFirestore(doc)).toList());
  }

  // Find user by email
  Future<app_user.User?> findUserByEmail(String email) async {
    try {
      return await _authService.getUserByEmail(email);
    } catch (e) {
      debugPrint('Error finding user by email: $e');
      return null;
    }
  }

  // Update user's total donations
  Future<void> _updateUserDonationTotal(String userId, double additionalAmount) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      
      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        
        if (userDoc.exists) {
          final currentTotal = (userDoc.data()?['totalDonations'] ?? 0.0).toDouble();
          final newTotal = currentTotal + additionalAmount;
          
          transaction.update(userRef, {
            'totalDonations': newTotal,
            'lastDonationDate': Timestamp.fromDate(DateTime.now()),
          });
        }
      });
    } catch (e) {
      debugPrint('Error updating user donation total: $e');
    }
  }

  // Get donation statistics
  Future<Map<String, dynamic>> getDonationStats() async {
    try {
      final snapshot = await _firestore.collection('donations').get();
      
      double totalAmount = 0;
      int totalDonations = snapshot.docs.length;
      Set<String> uniqueDonors = {};
      
      for (final doc in snapshot.docs) {
        final donation = Donation.fromFirestore(doc);
        totalAmount += donation.amount;
        uniqueDonors.add(donation.userId);
      }
      
      return {
        'totalAmount': totalAmount,
        'totalDonations': totalDonations,
        'uniqueDonors': uniqueDonors.length,
        'averageDonation': totalDonations > 0 ? totalAmount / totalDonations : 0.0,
      };
    } catch (e) {
      debugPrint('Error getting donation stats: $e');
      return {
        'totalAmount': 0.0,
        'totalDonations': 0,
        'uniqueDonors': 0,
        'averageDonation': 0.0,
      };
    }
  }

  // Delete a donation (admin only)
  Future<bool> deleteDonation(String donationId, String userId, double amount) async {
    try {
      // Delete from donations collection
      await _firestore.collection('donations').doc(donationId).delete();
      
      // Update user's total donations (subtract the amount)
      await _updateUserDonationTotal(userId, -amount);
      
      debugPrint('Donation deleted successfully');
      return true;
    } catch (e) {
      debugPrint('Error deleting donation: $e');
      return false;
    }
  }
}
