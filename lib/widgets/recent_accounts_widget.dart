import 'package:flutter/material.dart';
import '../models/recent_account.dart';
import '../services/recent_accounts_service.dart';
import '../utils/app_colors.dart';
import '../utils/responsive_helper.dart';

class RecentAccountsWidget extends StatefulWidget {
  final Function(String email) onAccountSelected;
  final VoidCallback? onAccountDeleted; // Callback when an account is deleted

  const RecentAccountsWidget({
    super.key,
    required this.onAccountSelected,
    this.onAccountDeleted,
  });

  @override
  State<RecentAccountsWidget> createState() => _RecentAccountsWidgetState();
}

class _RecentAccountsWidgetState extends State<RecentAccountsWidget> {
  final RecentAccountsService _recentAccountsService = RecentAccountsService();
  List<RecentAccount> _recentAccounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentAccounts();
  }

  Future<void> _loadRecentAccounts() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final accounts = await _recentAccountsService.getRecentAccounts();
      setState(() {
        _recentAccounts = accounts;
      });
    } catch (e) {
      debugPrint('Error loading recent accounts: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAccount(String email) async {
    try {
      await _recentAccountsService.removeRecentAccount(email);
      await _loadRecentAccounts(); // Reload the list
      widget.onAccountDeleted?.call();
    } catch (e) {
      debugPrint('Error deleting account: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveHelper.isMobile(screenWidth);
    
    if (_isLoading) {
      return _buildLoadingIndicator();
    }
    
    if (_recentAccounts.isEmpty) {
      return _buildEmptyState();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        Expanded(
          child: _recentAccounts.length <= 3 
            ? SingleChildScrollView(
                child: Column(
                  children: _recentAccounts.asMap().entries.map((entry) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: entry.key < _recentAccounts.length - 1 ? 12 : 0,
                      ),
                      child: _buildAccountCard(entry.value),
                    );
                  }).toList(),
                ),
              )
            : ListView.builder(
                itemCount: _recentAccounts.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index < _recentAccounts.length - 1 ? 12 : 0,
                    ),
                    child: _buildAccountCard(_recentAccounts[index]),
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 24),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 40,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  'Keine kÃ¼rzlich verwendeten Konten',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Melden Sie sich mit einem Konto an, um es hier zu sehen',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Text(
      'KÃ¼rzlich verwendet',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildAccountCard(RecentAccount account) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => widget.onAccountSelected(account.email),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryColor,
                      AppColors.primaryColor.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    _getInitials(account.fullName),
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Account info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.email,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        account.displayRole,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryColor.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Delete button
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onSelected: (value) {
                  if (value == 'delete') {
                    _showDeleteConfirmation(account);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          color: Colors.red.shade600,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Vergessen',
                          style: TextStyle(
                            color: Colors.red.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0].toUpperCase()}${parts.last[0].toUpperCase()}';
    } else if (parts.isNotEmpty) {
      return parts.first[0].toUpperCase();
    }
    return '?';
  }

  void _showDeleteConfirmation(RecentAccount account) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Konto vergessen',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'MÃ¶chten Sie das Konto "${account.fullName}" aus der Liste der kÃ¼rzlich verwendeten Konten entfernen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteAccount(account.email);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Vergessen'),
          ),
        ],
      ),
    );
  }
}
