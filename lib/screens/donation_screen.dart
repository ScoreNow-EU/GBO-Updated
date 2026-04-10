import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:toastification/toastification.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../utils/app_colors.dart';
import '../services/auth_service.dart';
import '../services/apple_pay_service.dart';
import '../models/user.dart' as app_user;
import 'admin_donation_management_screen.dart';

class BankingAmountFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // If the new value is empty, return as is
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Remove any non-digit characters
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    
    // Convert to cents (divide by 100 to show as euros)
    String amountAsString = (int.parse(digitsOnly) / 100).toStringAsFixed(2);
    
    return TextEditingValue(
      text: amountAsString,
      selection: TextSelection.collapsed(offset: amountAsString.length),
    );
  }
}

class DonationScreen extends StatefulWidget {
  const DonationScreen({super.key});

  @override
  State<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen> with TickerProviderStateMixin {
  final TextEditingController _amountController = TextEditingController(text: '5.00');
  final List<int> _suggestedAmounts = [5, 10, 25, 50, 100];
  int? _selectedAmount = 5;
  bool _isLoading = false;
  bool _isApplePayAvailable = false;
  late AnimationController _heartController;
  late Animation<double> _heartAnimation;
  final AuthService _authService = AuthService();
  app_user.User? _currentAppUser;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    
    _heartAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _heartController,
      curve: Curves.easeInOut,
    ));
    
    _loadCurrentUser();
    _checkApplePayAvailability();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _authService.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentAppUser = user;
        });
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
    }
  }

  Future<void> _checkApplePayAvailability() async {
    try {
      final isSupported = await ApplePayService.isApplePaySupported();
      
      if (mounted) {
        setState(() {
          _isApplePayAvailable = isSupported;
        });
      }
    } catch (e) {
      debugPrint('Error checking Apple Pay availability: $e');
      if (mounted) {
        setState(() {
          _isApplePayAvailable = false;
        });
      }
    }
  }

  Future<void> _processApplePayPayment() async {
    final amountText = _amountController.text;
    if (amountText.isEmpty) {
      _showErrorToast('Bitte geben Sie einen Betrag ein');
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showErrorToast('Bitte geben Sie einen gültigen Betrag ein');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await ApplePayService.processApplePayPayment(
        amount: amount,
        currency: 'EUR',
        description: 'RHBL Spende - ${amount.toStringAsFixed(2)}â‚¬',
      );
      
      if (success) {
        _showSuccessToast('Vielen Dank für deine Spende! ðŸŽ‰');
        _clearForm();
      }
    } catch (e) {
      final errorMessage = e.toString().replaceAll('Exception: ', '');
      debugPrint('Apple Pay error details: $errorMessage');
      _showErrorToast(errorMessage.isNotEmpty ? errorMessage : 'Ein unerwarteter Fehler ist aufgetreten');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _heartController.dispose();
    super.dispose();
  }

  void _selectAmount(int amount) {
    setState(() {
      _selectedAmount = amount;
      _amountController.text = amount.toString();
    });
  }

  void _onCustomAmountChanged(String value) {
    setState(() {
      final parsedAmount = int.tryParse(value);
      if (parsedAmount != null && _suggestedAmounts.contains(parsedAmount)) {
        _selectedAmount = parsedAmount;
      } else {
        _selectedAmount = null;
      }
    });
  }

  void _clearForm() {
    setState(() {
      _amountController.text = '5.00';
      _selectedAmount = 5;
    });
  }

  void _showSuccessToast(String message) {
    toastification.show(
      context: context,
      title: Text(message),
      type: ToastificationType.success,
      style: ToastificationStyle.fillColored,
      autoCloseDuration: const Duration(seconds: 4),
      primaryColor: Colors.green,
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
    );
  }

  void _showErrorToast(String message) {
    toastification.show(
      context: context,
      title: Text(message),
      type: ToastificationType.error,
      style: ToastificationStyle.fillColored,
      autoCloseDuration: const Duration(seconds: 4),
      primaryColor: Colors.red,
      backgroundColor: Colors.red,
      foregroundColor: Colors.white,
    );
  }

  void _openAdminDonationManagement() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AdminDonationManagementScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _currentAppUser?.roles.contains(app_user.UserRole.admin) == true;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    
                    // Admin menu button (top right)
                    if (isAdmin)
                      Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          child: FloatingActionButton.extended(
                            onPressed: _openAdminDonationManagement,
                            backgroundColor: Colors.white.withOpacity(0.9),
                            foregroundColor: AppColors.primaryColor,
                            icon: const Icon(Icons.admin_panel_settings, size: 20),
                            label: const Text(
                              'Admin',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            elevation: 4,
                          ),
                        ),
                      ),
                
                // Header with animated heart
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _heartAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _heartAnimation.value,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.favorite,
                              color: Colors.red,
                              size: 48,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Title
                const Text(
                  'Unterstütze die\nRHBL App',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 2),
                        blurRadius: 4,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Subtitle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Text(
                    'Hilf uns, die App werbefrei und kostenfrei zu halten!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Main donation card
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 600),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Why we need support
                        _buildInfoSection(),
                        
                        const SizedBox(height: 32),
                        
                        // Amount selection
                        _buildAmountSelection(),
                        
                        const SizedBox(height: 32),
                        
                        // Payment buttons
                        _buildPaymentButtons(),
                        
                        const SizedBox(height: 24),
                        
                        // Security info
                        _buildSecurityInfo(),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Additional info cards
                _buildCostBreakdown(),
                
                const SizedBox(height: 24),
                
                _buildVolunteerInfo(),
                
                const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.info_outline,
                color: AppColors.primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Warum deine Unterstützung wichtig ist',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        const Text(
          'Die RHBL App wird vollständig ehrenamtlich betrieben und ist ein kostenloses, werbefreies Projekt. '
          'Um die App am Leben zu erhalten und kontinuierlich zu verbessern, entstehen uns laufende Kosten für '
          'Server, Datenbanken, App Store Gebühren und Entwicklungstools.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black87,
            height: 1.5,
          ),
        ),
        
        const SizedBox(height: 16),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade600,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ohne ausreichende Unterstützung müssen wir eventuell Werbung einblenden, um die Kosten zu decken.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmountSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Spendenbetrag wählen',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Suggested amounts
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _suggestedAmounts.map((amount) => _buildAmountChip(amount)).toList(),
        ),
        
        const SizedBox(height: 16),
        
        // Custom amount input
        TextField(
          controller: _amountController,
          onChanged: _onCustomAmountChanged,
          keyboardType: TextInputType.number,
          inputFormatters: [
            BankingAmountFormatter(),
          ],
          decoration: InputDecoration(
            labelText: 'Oder eigenen Betrag eingeben',
            hintText: '0.00',
            prefixText: 'â‚¬ ',
            prefixStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAmountChip(int amount) {
    final isSelected = _selectedAmount == amount;
    
    return InkWell(
      onTap: () => _selectAmount(amount),
      borderRadius: BorderRadius.circular(25),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? AppColors.primaryColor : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.primaryColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Text(
          '$amount â‚¬',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentButtons() {
    final amount = _amountController.text;
    final isAmountValid = amount.isNotEmpty && (double.tryParse(amount) ?? 0) > 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Spende abschließen',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        
        const SizedBox(height: 16),

        if (_isApplePayAvailable) ...[
          // Apple Pay Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading || _amountController.text.isEmpty ? null : _processApplePayPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.payment, size: 24),
              label: Text(
                _isLoading ? 'Verarbeitung...' : 'Mit Apple Pay bezahlen',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildSecurityInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.security,
            color: Colors.green.shade600,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sichere Zahlung',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade800,
                  ),
                ),
                Text(
                  'Deine Zahlungsdaten werden verschlüsselt übertragen und nicht gespeichert.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostBreakdown() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 600),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    color: Colors.blue.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Unsere monatlichen Kosten',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            ...[
              {'item': 'Firebase Hosting & Database', 'cost': '45â‚¬'},
              {'item': 'App Store & Play Store Gebühren', 'cost': '35â‚¬'},
              {'item': 'Domain & SSL Zertifikat', 'cost': '25â‚¬'},
              {'item': 'Entwicklungstools & Services', 'cost': '135â‚¬'},
              {'item': 'Backup & Monitoring', 'cost': '20â‚¬'},
            ].map((cost) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    cost['item']!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    cost['cost']!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            )).toList(),
            
            const Divider(height: 32),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Gesamt pro Monat:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '260â‚¬',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVolunteerInfo() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 600),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade50, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.volunteer_activism,
                color: Colors.purple.shade600,
                size: 32,
              ),
            ),
            
            const SizedBox(height: 16),
            
            const Text(
              '100% Ehrenamtlich',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            
            const SizedBox(height: 8),
            
            const Text(
              'Dieses Projekt wird in unserer Freizeit entwickelt und betrieben. Alle Projektmitglieder Arbeiten nebenbei noch Vollzeit. '
              'Wir investieren unzählige Stunden, um den Beach-Handball in Deutschland zu fördern. Ohne deine Unterstützung wäre das nicht möglich.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildVolunteerStat('1500+', 'Stunden\nEntwicklung'),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.purple.shade200,
                ),
                _buildVolunteerStat('0â‚¬', 'Gehalt\noder Lohn'),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.purple.shade200,
                ),
                _buildVolunteerStat('â¤ï¸', 'Leidenschaft\nfür den Sport'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVolunteerStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.purple.shade700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: Colors.purple.shade600,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
