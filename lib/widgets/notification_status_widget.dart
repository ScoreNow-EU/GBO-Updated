import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/referee_invitation_monitoring_service.dart';

class NotificationStatusWidget extends StatefulWidget {
  const NotificationStatusWidget({super.key});

  @override
  State<NotificationStatusWidget> createState() => _NotificationStatusWidgetState();
}

class _NotificationStatusWidgetState extends State<NotificationStatusWidget> {
  String? _lastCheck;
  List<String> _pendingInvitations = [];
  String? _currentRefereeId;
  
  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastCheck = prefs.getString('lastInvitationCheck');
      _currentRefereeId = prefs.getString('currentRefereeId');
      
      final pendingJson = prefs.getString('pendingInvitations');
      if (pendingJson != null) {
        _pendingInvitations = List<String>.from(
          pendingJson.split(',').where((s) => s.isNotEmpty)
        );
      }
      
      setState(() {});
    } catch (e) {
      print('Error loading notification status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Benachrichtigung',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadStatus,
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            
            // Current referee ID
            _buildStatusRow(
              'Aktueller Schiedsrichter', 
              _currentRefereeId ?? 'Nicht gesetzt',
              _currentRefereeId != null ? Colors.green : Colors.red,
            ),
            
            // Last check time
            _buildStatusRow(
              'Letzte Überprüfung',
              _lastCheck != null 
                  ? _formatDateTime(_lastCheck!)
                  : 'Noch nicht überprüft',
              _lastCheck != null ? Colors.green : Colors.orange,
            ),
            
            // Pending invitations
            _buildStatusRow(
              'Ausstehende Einladungen',
              '${_pendingInvitations.length} gefunden',
              _pendingInvitations.isNotEmpty ? Colors.orange : Colors.green,
            ),
            
            if (_pendingInvitations.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Ausstehende Turniere:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              ..._pendingInvitations.map((id) => Padding(
                padding: const EdgeInsets.only(left: 16, top: 2),
                child: Text(
                  '• $id',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              )).toList(),
            ],
            
            const SizedBox(height: 16),
            
            // Manual test button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _testNotification,
                icon: const Icon(Icons.notifications_active),
                label: const Text('Test-Benachrichtigung senden'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inMinutes < 1) {
        return 'Gerade eben';
      } else if (difference.inHours < 1) {
        return 'Vor ${difference.inMinutes} Minuten';
      } else if (difference.inDays < 1) {
        return 'Vor ${difference.inHours} Stunden';
      } else {
        return 'Vor ${difference.inDays} Tagen';
      }
    } catch (e) {
      return 'Unbekannt';
    }
  }

  Future<void> _testNotification() async {
    try {
      // This would trigger a manual check
      if (_currentRefereeId != null) {
        // The background service will handle the actual notification
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test-Benachrichtigung wird gesendet...'),
            duration: Duration(seconds: 2),
          ),
        );
        
        // Refresh status after a short delay
        await Future.delayed(const Duration(seconds: 1));
        await _loadStatus();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kein Schiedsrichter angemeldet'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Test: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 