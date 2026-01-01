import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_config.dart';
import 'create_demo_data.dart';

/// Quick script to run demo data creation
/// Run with: flutter run -d chrome -t lib/utils/run_demo_data.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🚀 Starting demo data creation...');
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: FirebaseConfig.currentPlatform,
  );
  print('✅ Firebase initialized');
  
  // Create demo data
  final creator = DemoDataCreator();
  await creator.createDemoData();
  
  print('✅ All done! Check your Firestore database.');
  print('   Teams and tournaments should now be visible in the app.');
  
  runApp(const MaterialApp(
    home: Scaffold(
      body: Center(
        child: Text(
          '✅ Demo data created!\nCheck the console for details.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24),
        ),
      ),
    ),
  ));
}
