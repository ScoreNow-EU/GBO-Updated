import 'package:cloud_firestore/cloud_firestore.dart';

class Donation {
  final String id;
  final String userId;
  final String userEmail;
  final double amount;
  final String currency;
  final DateTime donationDate;
  final String? description;
  final String? paymentMethod;
  final String? transactionId;
  final String addedByAdminId;
  final String addedByAdminEmail;
  final DateTime createdAt;

  Donation({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.amount,
    required this.currency,
    required this.donationDate,
    this.description,
    this.paymentMethod,
    this.transactionId,
    required this.addedByAdminId,
    required this.addedByAdminEmail,
    required this.createdAt,
  });

  factory Donation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Donation(
      id: doc.id,
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      currency: data['currency'] ?? 'EUR',
      donationDate: (data['donationDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: data['description'],
      paymentMethod: data['paymentMethod'],
      transactionId: data['transactionId'],
      addedByAdminId: data['addedByAdminId'] ?? '',
      addedByAdminEmail: data['addedByAdminEmail'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userEmail': userEmail,
      'amount': amount,
      'currency': currency,
      'donationDate': Timestamp.fromDate(donationDate),
      'description': description,
      'paymentMethod': paymentMethod,
      'transactionId': transactionId,
      'addedByAdminId': addedByAdminId,
      'addedByAdminEmail': addedByAdminEmail,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Donation.create({
    required String userId,
    required String userEmail,
    required double amount,
    required String currency,
    required DateTime donationDate,
    String? description,
    String? paymentMethod,
    String? transactionId,
    required String addedByAdminId,
    required String addedByAdminEmail,
  }) {
    return Donation(
      id: '', // Will be set by Firestore
      userId: userId,
      userEmail: userEmail,
      amount: amount,
      currency: currency,
      donationDate: donationDate,
      description: description,
      paymentMethod: paymentMethod,
      transactionId: transactionId,
      addedByAdminId: addedByAdminId,
      addedByAdminEmail: addedByAdminEmail,
      createdAt: DateTime.now(),
    );
  }
}
