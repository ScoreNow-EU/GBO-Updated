import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:toastification/toastification.dart';
import '../utils/responsive_helper.dart';
// Live activities service removed due to iOS configuration issues
// import '../services/live_activities_service.dart';

class LiveNotificationsScreen extends StatefulWidget {
  const LiveNotificationsScreen({super.key});

  @override
  State<LiveNotificationsScreen> createState() => _LiveNotificationsScreenState();
}

class _LiveNotificationsScreenState extends State<LiveNotificationsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _team1Controller = TextEditingController();
  final _team2Controller = TextEditingController();
  final _score1Controller = TextEditingController();
  final _score2Controller = TextEditingController();
  final _timeController = TextEditingController();
  final _locationController = TextEditingController();
  
  String _notificationType = 'game_update';
  bool _isLoading = false;
  List<Map<String, dynamic>> _activeNotifications = [];

  @override
  void initState() {
    super.initState();
    _loadActiveNotifications();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _team1Controller.dispose();
    _team2Controller.dispose();
    _score1Controller.dispose();
    _score2Controller.dispose();
    _timeController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveNotifications() async {
    // TODO: Load active notifications from local storage or backend
    setState(() {
      _activeNotifications = [
        {
          'id': '1',
          'type': 'game_update',
          'title': 'Spiel läuft',
          'team1': 'Team Hamburg',
          'team2': 'Team München',
          'score1': '15',
          'score2': '12',
          'time': '18:30',
          'location': 'Platz 1',
          'isActive': true,
          'createdAt': DateTime.now().subtract(const Duration(minutes: 15)),
        },
        {
          'id': '2',
          'type': 'tournament_announcement',
          'title': 'Spielplan Update',
          'message': 'Neue Spielzeiten wurden veröffentlicht',
          'isActive': true,
          'createdAt': DateTime.now().subtract(const Duration(hours: 2)),
        },
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveHelper.isMobile(screenWidth);
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.notifications_active,
                  size: isMobile ? 24 : 28,
                  color: const Color(0xFF4A5568),
                ),
                const SizedBox(width: 12),
                Text(
                  'Live Notifications',
                  style: TextStyle(
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF4A5568),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _showCreateNotificationDialog(),
                  icon: const Icon(Icons.add, size: 20),
                  label: Text(isMobile ? 'Neu' : 'Neue Benachrichtigung'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFffd665),
                    foregroundColor: Colors.black,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Stats Cards
            if (!isMobile) _buildStatsCards(),
            if (!isMobile) const SizedBox(height: 24),
            
            // Active Notifications List
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A5568),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.notifications_active,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Aktive Benachrichtigungen',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFffd665),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_activeNotifications.length}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Content
                    Expanded(
                      child: _activeNotifications.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.notifications_off,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Keine aktiven Benachrichtigungen',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _activeNotifications.length,
                              itemBuilder: (context, index) {
                                final notification = _activeNotifications[index];
                                return _buildNotificationCard(notification, isMobile);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Aktive Notifications',
            '${_activeNotifications.length}',
            Icons.notifications_active,
            const Color(0xFFffd665),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Heute gesendet',
            '12',
            Icons.send,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Reichweite',
            '847',
            Icons.people,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Erfolgsrate',
            '94%',
            Icons.check_circle,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A5568),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification, bool isMobile) {
    final isGameUpdate = notification['type'] == 'game_update';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isGameUpdate ? Colors.green.shade100 : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isGameUpdate ? 'Spiel Update' : 'Ankündigung',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isGameUpdate ? Colors.green.shade800 : Colors.blue.shade800,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTime(notification['createdAt']),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editNotification(notification);
                    } else if (value == 'update' && notification['type'] == 'game_update') {
                      _updateMatchScore(notification);
                    } else if (value == 'delete') {
                      _deleteNotification(notification['id']);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16),
                          SizedBox(width: 8),
                          Text('Bearbeiten'),
                        ],
                      ),
                    ),
                    if (notification['type'] == 'game_update')
                      const PopupMenuItem(
                        value: 'update',
                        child: Row(
                          children: [
                            Icon(Icons.refresh, size: 16, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Punkte aktualisieren', style: TextStyle(color: Colors.blue)),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Löschen', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Content
            if (isGameUpdate) ...[
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        children: [
                          Text(
                            notification['team1'],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notification['score1'],
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4A5568),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      ':',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        children: [
                          Text(
                            notification['team2'],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notification['score2'],
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4A5568),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    notification['time'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    notification['location'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                notification['title'],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4A5568),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                notification['message'],
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Gerade eben';
    } else if (difference.inMinutes < 60) {
      return 'vor ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'vor ${difference.inHours} h';
    } else {
      return 'vor ${difference.inDays} Tag(en)';
    }
  }

  void _showCreateNotificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Neue Live Notification'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Type Selection
                  DropdownButtonFormField<String>(
                    value: _notificationType,
                    decoration: const InputDecoration(
                      labelText: 'Notification Typ',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'game_update',
                        child: Text('Spiel Update'),
                      ),
                      DropdownMenuItem(
                        value: 'tournament_announcement',
                        child: Text('Turnier Ankündigung'),
                      ),
                      DropdownMenuItem(
                        value: 'general_info',
                        child: Text('Allgemeine Info'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _notificationType = value!;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Common fields
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Titel',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Titel ist erforderlich';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Game-specific fields
                  if (_notificationType == 'game_update') ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _team1Controller,
                            decoration: const InputDecoration(
                              labelText: 'Team 1',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value?.isEmpty ?? true) {
                                return 'Team 1 erforderlich';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _team2Controller,
                            decoration: const InputDecoration(
                              labelText: 'Team 2',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value?.isEmpty ?? true) {
                                return 'Team 2 erforderlich';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _score1Controller,
                            decoration: const InputDecoration(
                              labelText: 'Punkte Team 1',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value?.isEmpty ?? true) {
                                return 'Punkte erforderlich';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _score2Controller,
                            decoration: const InputDecoration(
                              labelText: 'Punkte Team 2',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value?.isEmpty ?? true) {
                                return 'Punkte erforderlich';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _timeController,
                            decoration: const InputDecoration(
                              labelText: 'Uhrzeit',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value?.isEmpty ?? true) {
                                return 'Uhrzeit erforderlich';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _locationController,
                            decoration: const InputDecoration(
                              labelText: 'Ort/Platz',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value?.isEmpty ?? true) {
                                return 'Ort erforderlich';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Message field for non-game notifications
                    TextFormField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        labelText: 'Nachricht',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Nachricht ist erforderlich';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearForm();
            },
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _createNotification,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFffd665),
              foregroundColor: Colors.black,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Erstellen'),
          ),
        ],
      ),
    );
  }

  Future<void> _createNotification() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Prepare notification data
      Map<String, dynamic> notificationData = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'type': _notificationType,
        'title': _titleController.text,
        'isActive': true,
        'createdAt': DateTime.now(),
      };
      
      if (_notificationType == 'game_update') {
        notificationData.addAll({
          'team1': _team1Controller.text,
          'team2': _team2Controller.text,
          'score1': _score1Controller.text,
          'score2': _score2Controller.text,
          'time': _timeController.text,
          'location': _locationController.text,
        });
      } else {
        notificationData['message'] = _messageController.text;
      }
      
      // Send to iOS Live Activities via UserDefaults
      await _sendToiOSLiveActivity(notificationData);
      
      // Add to local list
      setState(() {
        _activeNotifications.insert(0, notificationData);
      });
      
      // Clear form and close dialog
      _clearForm();
      Navigator.of(context).pop();
      
      _showSuccessToast('Live Notification erfolgreich erstellt');
      
    } catch (e) {
      _showErrorToast('Fehler beim Erstellen der Notification: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendToiOSLiveActivity(Map<String, dynamic> notificationData) async {
    try {
      if (notificationData['type'] == 'game_update') {
        // Live activities disabled due to iOS configuration issues
        // final activityId = await LiveActivitiesService.startMatchActivity(
        //   team1: notificationData['team1'],
        //   team2: notificationData['team2'],
        //   score1: notificationData['score1'],
        //   score2: notificationData['score2'],
        //   time: notificationData['time'],
        //   location: notificationData['location'],
        //   matchId: notificationData['id'],
        // );
        
        // if (activityId != null) {
        //   // Store the activity ID for future updates
        //   notificationData['activityId'] = activityId;
        //   
        //   // Also write to UserDefaults for widget access
        //   await LiveActivitiesService.writeToUserDefaults(
        //     key: 'currentMatch_${notificationData['id']}',
        //     value: notificationData,
        //   );
        // }
      } else {
        // Live activities disabled due to iOS configuration issues
        // await LiveActivitiesService.sendGeneralNotification(
        //   title: notificationData['title'],
        //   message: notificationData['message'] ?? '',
        // );
        
        // Write to UserDefaults for widget access
        // await LiveActivitiesService.writeToUserDefaults(
        //   key: 'generalNotification_${notificationData['id']}',
        //   value: notificationData,
        // );
      }
      
    } catch (e) {
      print('Error sending to iOS Live Activity: $e');
      // Don't throw error - continue with local notification
    }
  }

  void _clearForm() {
    _titleController.clear();
    _messageController.clear();
    _team1Controller.clear();
    _team2Controller.clear();
    _score1Controller.clear();
    _score2Controller.clear();
    _timeController.clear();
    _locationController.clear();
    _notificationType = 'game_update';
  }

  void _editNotification(Map<String, dynamic> notification) {
    // TODO: Implement edit functionality
    _showInfoToast('Edit-Funktion wird noch entwickelt');
  }

  void _updateMatchScore(Map<String, dynamic> notification) {
    // Pre-fill form with current values
    _team1Controller.text = notification['team1'] ?? '';
    _team2Controller.text = notification['team2'] ?? '';
    _score1Controller.text = notification['score1'] ?? '';
    _score2Controller.text = notification['score2'] ?? '';
    _timeController.text = notification['time'] ?? '';
    _locationController.text = notification['location'] ?? '';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Spielstand aktualisieren'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Team names (read-only)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _team1Controller,
                        decoration: const InputDecoration(
                          labelText: 'Team 1',
                          border: OutlineInputBorder(),
                        ),
                        readOnly: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _team2Controller,
                        decoration: const InputDecoration(
                          labelText: 'Team 2',
                          border: OutlineInputBorder(),
                        ),
                        readOnly: true,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Scores (editable)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _score1Controller,
                        decoration: const InputDecoration(
                          labelText: 'Punkte Team 1',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _score2Controller,
                        decoration: const InputDecoration(
                          labelText: 'Punkte Team 2',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Time (editable)
                TextFormField(
                  controller: _timeController,
                  decoration: const InputDecoration(
                    labelText: 'Spielzeit',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearForm();
            },
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _performMatchUpdate(notification);
              Navigator.of(context).pop();
              _clearForm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Aktualisieren'),
          ),
        ],
      ),
    );
  }

  Future<void> _performMatchUpdate(Map<String, dynamic> notification) async {
    try {
      // Update the notification data
      final updatedNotification = Map<String, dynamic>.from(notification);
      updatedNotification['score1'] = _score1Controller.text;
      updatedNotification['score2'] = _score2Controller.text;
      updatedNotification['time'] = _timeController.text;
      
      // Live activities disabled due to iOS configuration issues
      // if (notification['activityId'] != null) {
      //   await LiveActivitiesService.updateMatchActivity(
      //     activityId: notification['activityId'],
      //     team1: notification['team1'],
      //     team2: notification['team2'],
      //     score1: _score1Controller.text,
      //     score2: _score2Controller.text,
      //     time: _timeController.text,
      //     location: notification['location'],
      //   );
      // }
      
      // Update UserDefaults
      // await LiveActivitiesService.writeToUserDefaults(
      //   key: 'currentMatch_${notification['id']}',
      //   value: updatedNotification,
      // );
      
      // Update local list
      setState(() {
        final index = _activeNotifications.indexWhere((n) => n['id'] == notification['id']);
        if (index != -1) {
          _activeNotifications[index] = updatedNotification;
        }
      });
      
      _showSuccessToast('Spielstand erfolgreich aktualisiert');
      
    } catch (e) {
      _showErrorToast('Fehler beim Aktualisieren: $e');
    }
  }

  void _deleteNotification(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification löschen'),
        content: const Text('Sind Sie sicher, dass Sie diese Notification löschen möchten?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _activeNotifications.removeWhere((n) => n['id'] == id);
              });
              Navigator.of(context).pop();
              _showSuccessToast('Notification erfolgreich gelöscht');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }

  void _showSuccessToast(String message) {
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.fillColored,
      title: const Text('Erfolg'),
      description: Text(message),
      alignment: Alignment.topRight,
      autoCloseDuration: const Duration(seconds: 3),
      showProgressBar: false,
    );
  }

  void _showErrorToast(String message) {
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.fillColored,
      title: const Text('Fehler'),
      description: Text(message),
      alignment: Alignment.topRight,
      autoCloseDuration: const Duration(seconds: 4),
      showProgressBar: false,
    );
  }

  void _showInfoToast(String message) {
    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.fillColored,
      title: const Text('Info'),
      description: Text(message),
      alignment: Alignment.topRight,
      autoCloseDuration: const Duration(seconds: 3),
      showProgressBar: false,
    );
  }
} 