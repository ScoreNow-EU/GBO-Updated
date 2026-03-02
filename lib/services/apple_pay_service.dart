import 'dart:async';
import 'dart:io';
import 'package:pay/pay.dart';

class ApplePayService {
  static const String _merchantIdentifier = 'merchant.com.scorenow.rollstuhlhandball';
  
  static const String _applePayConfigJson = '''
{
  "provider": "apple_pay",
  "data": {
    "merchantIdentifier": "merchant.com.scorenow.rollstuhlhandball",
    "displayName": "Rollstuhlhandball Bundesliga",
    "merchantCapabilities": ["3DS", "debit", "credit"],
    "supportedNetworks": ["visa", "masterCard", "amex"],
    "countryCode": "DE",
    "currencyCode": "EUR",
    "requiredBillingContactFields": ["emailAddress", "name"],
    "requiredShippingContactFields": []
  }
}
''';
  
  static Future<bool> isApplePaySupported() async {
    try {
      if (!Platform.isIOS) {
        print('Not iOS platform');
        return false;
      }
      
      print('Assuming Apple Pay is available on iOS');
      return true;
    } catch (e) {
      print('Error checking Apple Pay support: $e');
      return false;
    }
  }

  static Future<bool> processApplePayPayment({
    required double amount,
    required String currency,
    String? description,
  }) async {
    try {
      print('Starting Apple Pay payment: $amount $currency');
      
      // Check if Apple Pay is supported
      final isSupported = await isApplePaySupported();
      print('Apple Pay is supported: $isSupported');
      
      if (!isSupported && Platform.isAndroid) {
        throw Exception('Apple Pay is not supported on Android');
      }

      // Parse payment configuration
      final paymentConfiguration = PaymentConfiguration.fromJsonString(_applePayConfigJson);

      // Create payment items
      final List<PaymentItem> paymentItems = [
        PaymentItem(
          label: description ?? 'RHBL Spende',
          amount: amount.toStringAsFixed(2),
          status: PaymentItemStatus.final_price,
        ),
      ];

      print('Payment items: $paymentItems');
      print('Showing Apple Pay payment sheet...');

      // Create Pay instance with configuration and show payment
      final payClient = Pay({PayProvider.apple_pay: paymentConfiguration});
      
      try {
        await payClient.showPaymentSelector(
          PayProvider.apple_pay,
          paymentItems,
        );
      } on Exception catch (e) {
        final errorStr = e.toString();
        print('Exception during payment sheet: $errorStr');
        
        // If it's a "Failed to present payment controller" error, likely simulator
        if (errorStr.contains('Failed to present payment controller')) {
          print('ERROR: Apple Pay cannot be presented.');
          print('This typically happens on:');
          print('  - iOS Simulator (Apple Pay only works on physical devices)');
          print('  - Devices without Apple Pay configured');
          print('  - Missing merchant certificates');
          throw Exception('Apple Pay payment failed: ${errorStr}. Please ensure you\'re testing on a physical iOS device with Apple Pay configured.');
        }
        rethrow;
      }

      print('Apple Pay payment successful');
      
      // If we get here, payment was successful
      return true;
      
    } catch (e) {
      final errorMessage = e.toString();
      print('Apple Pay error: $errorMessage');
      
      // Check if user cancelled
      if (errorMessage.contains('cancelled') || 
          errorMessage.contains('Cancelled') || 
          errorMessage.contains('user cancelled') ||
          errorMessage.contains('User cancelled')) {
        print('User cancelled payment');
        return false;
      }
      
      // Rethrow other errors
      rethrow;
    }
  }
}

