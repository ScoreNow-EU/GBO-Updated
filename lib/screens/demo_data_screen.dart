import 'package:flutter/material.dart';
import '../utils/create_demo_data.dart';

class DemoDataScreen extends StatefulWidget {
  const DemoDataScreen({super.key});

  @override
  State<DemoDataScreen> createState() => _DemoDataScreenState();
}

class _DemoDataScreenState extends State<DemoDataScreen> {
  bool _isCreating = false;
  String _status = '';

  Future<void> _createDemoData() async {
    setState(() {
      _isCreating = true;
      _status = 'Creating demo data...';
    });

    try {
      final creator = DemoDataCreator();
      await creator.createDemoData();
      
      setState(() {
        _isCreating = false;
        _status = '✅ Demo data created successfully!\n\nYou can now view:\n- Teams in Rangliste\n- Tournaments in Turniere';
      });
    } catch (e) {
      setState(() {
        _isCreating = false;
        _status = '❌ Error creating demo data: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Demo Data'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.data_array,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              const Text(
                'Create Demo Data',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'This will create demo teams and tournaments\nthat are visible on public pages.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isCreating ? null : _createDemoData,
                icon: _isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.add_circle),
                label: Text(_isCreating ? 'Creating...' : 'Create Demo Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 24),
              if (_status.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _status.startsWith('✅')
                        ? Colors.green.shade50
                        : _status.startsWith('❌')
                            ? Colors.red.shade50
                            : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _status.startsWith('✅')
                          ? Colors.green.shade200
                          : _status.startsWith('❌')
                              ? Colors.red.shade200
                              : Colors.blue.shade200,
                    ),
                  ),
                  child: Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: _status.startsWith('✅')
                          ? Colors.green.shade900
                          : _status.startsWith('❌')
                              ? Colors.red.shade900
                              : Colors.blue.shade900,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
