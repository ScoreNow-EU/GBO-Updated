import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recent_account.dart';
import '../models/user.dart' as app_user;

class RecentAccountsService {
  static const String _recentAccountsKey = 'rhbl_recent_accounts_global';
  static const int _maxRecentAccounts = 5; // Maximum number of recent accounts to keep
  static const String _encryptionKeyBase = 'rhbl_recent_accounts_key';
  /// Save data using SharedPreferences (works on all platforms)
  Future<void> _saveData(String data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recentAccountsKey, data);
  }

  /// Load data using SharedPreferences (works on all platforms)
  Future<String?> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_recentAccountsKey);
  }

  /// Remove data using SharedPreferences (works on all platforms)
  Future<void> _removeData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentAccountsKey);
  }

  /// Simple encryption for passwords (not production-grade, but better than plain text)
  String _encryptPassword(String password, String email) {
    final key = _encryptionKeyBase + email;
    final keyBytes = utf8.encode(key);
    final passwordBytes = utf8.encode(password);
    
    final encrypted = <int>[];
    for (int i = 0; i < passwordBytes.length; i++) {
      encrypted.add(passwordBytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    
    return base64.encode(encrypted);
  }

  /// Simple decryption for passwords
  String _decryptPassword(String encryptedPassword, String email) {
    try {
      final key = _encryptionKeyBase + email;
      final keyBytes = utf8.encode(key);
      final encryptedBytes = base64.decode(encryptedPassword);
      
      final decrypted = <int>[];
      for (int i = 0; i < encryptedBytes.length; i++) {
        decrypted.add(encryptedBytes[i] ^ keyBytes[i % keyBytes.length]);
      }
      
      return utf8.decode(decrypted);
    } catch (e) {
      debugPrint('Error decrypting password: $e');
      return '';
    }
  }

  /// No sync needed for SharedPreferences (no-op)
  Future<void> _ensureDataSync() async {
    // SharedPreferences handles persistence automatically
  }

  /// Get all recent accounts sorted by most recent login
  Future<List<RecentAccount>> getRecentAccounts() async {
    try {
      // Ensure data is synced between storage types
      await _ensureDataSync();
      
      final accountsJson = await _loadData();
      
      if (accountsJson == null) {
        return [];
      }
      
      final List<dynamic> accountsList = json.decode(accountsJson);
      final accounts = accountsList
          .map((accountJson) => RecentAccount.fromJson(accountJson))
          .toList();
      
      // Sort by most recent login first
      accounts.sort((a, b) => b.lastLoginAt.compareTo(a.lastLoginAt));
      
      return accounts;
    } catch (e) {
      debugPrint('Error loading recent accounts: $e');
      return [];
    }
  }

  /// Add or update a recent account
  Future<void> addRecentAccount(app_user.User user, {String? password}) async {
    try {
      final currentAccounts = await getRecentAccounts();
      
      // Encrypt password if provided
      String? encryptedPassword;
      if (password != null && password.isNotEmpty) {
        encryptedPassword = _encryptPassword(password, user.email);
      }
      
      // Create new recent account
      final newAccount = RecentAccount(
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        id: user.id,
        roles: user.roles.map((role) => role.name).toList(),
        lastLoginAt: DateTime.now(),
        avatarUrl: null, // Could be expanded to include avatar URLs
        encryptedPassword: encryptedPassword,
      );
      
      // Remove existing account with same email if it exists
      currentAccounts.removeWhere((account) => account.email == user.email);
      
      // Add new account to the beginning
      currentAccounts.insert(0, newAccount);
      
      // Keep only the maximum number of accounts
      if (currentAccounts.length > _maxRecentAccounts) {
        currentAccounts.removeRange(_maxRecentAccounts, currentAccounts.length);
      }
      
      // Save back to storage
      final accountsJson = json.encode(currentAccounts.map((account) => account.toJson()).toList());
      await _saveData(accountsJson);
      
      debugPrint('âœ… Added recent account: ${user.email}');
    } catch (e) {
      debugPrint('âŒ Error adding recent account: $e');
    }
  }

  /// Remove a specific recent account by email
  Future<void> removeRecentAccount(String email) async {
    try {
      final currentAccounts = await getRecentAccounts();
      
      // Remove account with specified email
      currentAccounts.removeWhere((account) => account.email == email);
      
      // Save back to storage
      final accountsJson = json.encode(currentAccounts.map((account) => account.toJson()).toList());
      await _saveData(accountsJson);
      
      debugPrint('âœ… Removed recent account: $email');
    } catch (e) {
      debugPrint('âŒ Error removing recent account: $e');
    }
  }

  /// Clear all recent accounts
  Future<void> clearAllRecentAccounts() async {
    try {
      await _removeData();
      debugPrint('âœ… Cleared all recent accounts');
    } catch (e) {
      debugPrint('âŒ Error clearing recent accounts: $e');
    }
  }

  /// Check if an account with the given email exists in recent accounts
  Future<bool> hasRecentAccount(String email) async {
    final accounts = await getRecentAccounts();
    return accounts.any((account) => account.email == email);
  }

  /// Get a specific recent account by email
  Future<RecentAccount?> getRecentAccount(String email) async {
    final accounts = await getRecentAccounts();
    try {
      return accounts.firstWhere((account) => account.email == email);
    } catch (e) {
      return null;
    }
  }

  /// Get decrypted password for a specific account
  Future<String?> getStoredPassword(String email) async {
    final account = await getRecentAccount(email);
    if (account?.encryptedPassword != null) {
      return _decryptPassword(account!.encryptedPassword!, email);
    }
    return null;
  }
}
