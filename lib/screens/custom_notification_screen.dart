import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../services/custom_notification_service.dart';
import '../models/user.dart' as app_user;
import '../services/auth_service.dart';
import '../services/team_manager_service.dart';
import '../models/team.dart';

class CustomNotificationScreen extends StatefulWidget {
  const CustomNotificationScreen({super.key});

  @override
  State<CustomNotificationScreen> createState() => _CustomNotificationScreenState();
}

class _CustomNotificationScreenState extends State<CustomNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final CustomNotificationService _notificationService = CustomNotificationService();
  final AuthService _authService = AuthService();
  final TeamManagerService _teamManagerService = TeamManagerService();
  
  String? _selectedUserEmail;
  bool _isLoading = false;
  bool _isSending = false;
  bool _isTimeSensitive = false;
  bool _isRequestingPermission = false;
  List<app_user.User> _users = [];
  Map<String, List<String>> _userTeamNames = {};
  
  @override
  void initState() {
    super.initState();
    _loadUsers();
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final users = await _authService.getAllUsers();
      Map<String, List<String>> userTeamNames = {};
      
      // Get team names for team managers
      for (final user in users) {
        if (user.roles.contains(app_user.UserRole.teamManager) && user.teamManagerId != null) {
          try {
            final teamManager = await _teamManagerService.getTeamManagerByUserId(user.id);
            if (teamManager != null) {
              final teams = await _teamManagerService.getTeamsManagedByUser(user.id);
              userTeamNames[user.email] = teams.map((team) => team.name).toList();
            }
          } catch (e) {
            print('Error loading teams for team manager ${user.email}: $e');
            userTeamNames[user.email] = [];
          }
        }
      }
      
      setState(() {
        _users = users;
        _userTeamNames = userTeamNames;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          title: const Text('Fehler'),
          description: Text('Benutzer konnten nicht geladen werden: $e'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    }
  }
  
  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUserEmail == null) {
      toastification.show(
        context: context,
        type: ToastificationType.warning,
        style: ToastificationStyle.fillColored,
        title: const Text('Warnung'),
        description: const Text('Bitte wählen Sie einen Benutzer aus.'),
        autoCloseDuration: const Duration(seconds: 3),
      );
      return;
    }
    
    setState(() {
      _isSending = true;
    });
    
    try {
      // Check time-sensitive permissions if needed
      if (_isTimeSensitive) {
        setState(() {
          _isRequestingPermission = true;
        });
        
        if (mounted) {
          toastification.show(
            context: context,
            type: ToastificationType.info,
            style: ToastificationStyle.fillColored,
            title: const Text('Berechtigung erforderlich'),
            description: const Text('Prüfe Berechtigung für zeitkritische Benachrichtigungen...'),
            autoCloseDuration: const Duration(seconds: 2),
          );
        }
        
        print('📱 Requesting time-sensitive notification permission...');
        final hasPermission = await _notificationService.requestTimeSensitivePermission();
        
        setState(() {
          _isRequestingPermission = false;
        });
        
        if (!hasPermission) {
          if (mounted) {
            toastification.show(
              context: context,
              type: ToastificationType.error,
              style: ToastificationStyle.fillColored,
              title: const Text('Berechtigung verweigert'),
              description: const Text('Zeitkritische Benachrichtigungen sind nicht verfügbar. Bitte prüfen Sie die Einstellungen.'),
              autoCloseDuration: const Duration(seconds: 5),
            );
          }
          setState(() {
            _isSending = false;
          });
          return;
        }
        
        if (mounted) {
          toastification.show(
            context: context,
            type: ToastificationType.success,
            style: ToastificationStyle.fillColored,
            title: const Text('Berechtigung erteilt'),
            description: const Text('Zeitkritische Benachrichtigungen sind jetzt verfügbar.'),
            autoCloseDuration: const Duration(seconds: 2),
          );
        }
      }
      
      // Send the notification
      final success = await _notificationService.sendCustomNotification(
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        userEmail: _selectedUserEmail!,
        isTimeSensitive: _isTimeSensitive,
      );
      
      if (success) {
        if (mounted) {
          toastification.show(
            context: context,
            type: ToastificationType.success,
            style: ToastificationStyle.fillColored,
            title: const Text('Benachrichtigung gesendet'),
            description: Text('Benachrichtigung wurde erfolgreich an $_selectedUserEmail gesendet.'),
            autoCloseDuration: const Duration(seconds: 3),
          );
        }
        
        // Clear the form
        _titleController.clear();
        _messageController.clear();
        setState(() {
          _selectedUserEmail = null;
          _isTimeSensitive = false;
        });
      } else {
        if (mounted) {
          toastification.show(
            context: context,
            type: ToastificationType.error,
            style: ToastificationStyle.fillColored,
            title: const Text('Fehler'),
            description: const Text('Benachrichtigung konnte nicht gesendet werden.'),
            autoCloseDuration: const Duration(seconds: 3),
          );
        }
      }
    } catch (e) {
      print('❌ Error sending notification: $e');
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          title: const Text('Fehler'),
          description: Text('Unerwarteter Fehler: $e'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _isRequestingPermission = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.notifications_active,
                          color: Colors.orange.shade700,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Benachrichtigungen senden',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              'Senden Sie benutzerdefinierte Push-Benachrichtigungen an einzelne Benutzer',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Form Card
                                      Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Neue Benachrichtigung erstellen',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Preset Templates Section
                            const Text(
                              'Vorlagen',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                                                 _buildPresetChip(
                                   'Mannschaft fehlt',
                                   Icons.group_off,
                                   Colors.red,
                                   () => _showMissingTeamDialog(),
                                 ),
                                 _buildPresetChip(
                                   'Anstehendes Spiel',
                                   Icons.schedule,
                                   Colors.blue,
                                   () => _showUpcomingGameDialog(),
                                 ),
                                 _buildPresetChip(
                                   'Spielergebnis',
                                   Icons.sports_score,
                                   Colors.green,
                                   () => _showMatchResultDialog(),
                                 ),
                                 _buildPresetChip(
                                   'Platz geändert',
                                   Icons.location_on,
                                   Colors.orange,
                                   () => _showCourtChangeDialog(),
                                 ),
                                 _buildPresetChip(
                                   'Verzögerung',
                                   Icons.access_time,
                                   Colors.purple,
                                   () => _showDelayDialog(),
                                 ),
                                 _buildPresetChip(
                                   'Turnier-Update',
                                   Icons.update,
                                   Colors.teal,
                                   () => _showTournamentUpdateDialog(),
                                 ),
                              ],
                            ),
                            
                            const SizedBox(height: 24),
                            
                            const Divider(),
                            
                            const SizedBox(height: 16),
                            
                            const Text(
                              'Oder benutzerdefinierte Nachricht erstellen',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Title Field
                            TextFormField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                labelText: 'Titel',
                                hintText: 'Geben Sie den Benachrichtigungstitel ein',
                                prefixIcon: Icon(Icons.title),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Bitte geben Sie einen Titel ein';
                                }
                                if (value.trim().length > 50) {
                                  return 'Titel darf maximal 50 Zeichen haben';
                                }
                                return null;
                              },
                              maxLength: 50,
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Message Field
                            TextFormField(
                              controller: _messageController,
                              decoration: const InputDecoration(
                                labelText: 'Nachricht',
                                hintText: 'Geben Sie die Nachricht ein',
                                prefixIcon: Icon(Icons.message),
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 4,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Bitte geben Sie eine Nachricht ein';
                                }
                                if (value.trim().length > 200) {
                                  return 'Nachricht darf maximal 200 Zeichen haben';
                                }
                                return null;
                              },
                              maxLength: 200,
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // User Selection
                            DropdownButtonFormField<String>(
                              value: _selectedUserEmail,
                              decoration: const InputDecoration(
                                labelText: 'Empfänger',
                                hintText: 'Wählen',
                                border: OutlineInputBorder(),
                                isDense: false,
                                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                              ),
                              menuMaxHeight: 400,
                              isExpanded: true,
                              items: _users.map((user) {
                                return DropdownMenuItem<String>(
                                  value: user.email,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: _getRoleColor(user.roles.first).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          child: Text(
                                            _getRoleDisplayName(user.roles.first),
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: _getRoleColor(user.roles.first),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${user.firstName} ${user.lastName} (${user.email})',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedUserEmail = value;
                                });
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'Bitte wählen Sie einen Empfänger aus';
                                }
                                return null;
                              },
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Critical Notification Checkbox
                            Row(
                              children: [
                                Checkbox(
                                  value: _isTimeSensitive,
                                  onChanged: (value) {
                                    setState(() {
                                      _isTimeSensitive = value ?? false;
                                    });
                                  },
                                  activeColor: Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Zeitkritische Benachrichtigung',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Durchbricht "Nicht stören" und wird als zeitkritisch markiert',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 32),
                            
                            // Send Button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: (_isSending || _isRequestingPermission) ? null : _sendNotification,
                                icon: (_isSending || _isRequestingPermission)
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Icon(Icons.send),
                                label: Text(
                                  _isRequestingPermission 
                                    ? 'Berechtigung wird angefragt...' 
                                    : _isSending 
                                      ? 'Wird gesendet...' 
                                      : 'Benachrichtigung senden'
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade600,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Info Card
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue.shade700,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Hinweise',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '• Benachrichtigungen werden als iOS Push-Benachrichtigungen gesendet\n'
                            '• Nur Benutzer, die in der App angemeldet sind, erhalten Benachrichtigungen\n'
                            '• Der Titel darf maximal 50 Zeichen haben\n'
                            '• Die Nachricht darf maximal 200 Zeichen haben\n'
                            '• Zeitkritische Benachrichtigungen können "Nicht stören" durchbrechen\n'
                            '• Beim ersten Versuch wird nach Berechtigung für zeitkritische Benachrichtigungen gefragt\n'
                            '• Berechtigungen können in iOS-Einstellungen → Benachrichtigungen → App geändert werden\n'
                            '• Benachrichtigungen werden sofort versendet',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade800,
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
  
  Color _getRoleColor(app_user.UserRole role) {
    switch (role) {
      case app_user.UserRole.admin:
        return Colors.red.shade100;
      case app_user.UserRole.referee:
        return Colors.orange.shade100;
      case app_user.UserRole.teamManager:
        return Colors.blue.shade100;
      case app_user.UserRole.delegate:
        return Colors.green.shade100;
      default:
        return Colors.grey.shade100;
    }
  }
  
  Color _getRoleTextColor(app_user.UserRole role) {
    switch (role) {
      case app_user.UserRole.admin:
        return Colors.red.shade700;
      case app_user.UserRole.referee:
        return Colors.orange.shade700;
      case app_user.UserRole.teamManager:
        return Colors.blue.shade700;
      case app_user.UserRole.delegate:
        return Colors.green.shade700;
      default:
        return Colors.grey.shade700;
    }
  }
  
  String _getRoleDisplayName(app_user.UserRole role) {
    switch (role) {
      case app_user.UserRole.admin:
        return 'ADMIN';
      case app_user.UserRole.referee:
        return 'REFEREE';
      case app_user.UserRole.teamManager:
        return 'TEAM MANAGER';
      case app_user.UserRole.delegate:
        return 'DELEGATE';
      default:
        return 'USER';
    }
  }
  
  Widget _buildPresetChip(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showMissingTeamDialog() {
    showDialog(
      context: context,
      builder: (context) => _MissingTeamDialog(
        onFillForm: (title, message) {
          _titleController.text = title;
          _messageController.text = message;
        },
      ),
    );
  }
  
  void _showUpcomingGameDialog() {
    showDialog(
      context: context,
      builder: (context) => _UpcomingGameDialog(
        onFillForm: (title, message) {
          _titleController.text = title;
          _messageController.text = message;
        },
      ),
    );
  }
  
  void _showMatchResultDialog() {
    showDialog(
      context: context,
      builder: (context) => _MatchResultDialog(
        onFillForm: (title, message) {
          _titleController.text = title;
          _messageController.text = message;
        },
      ),
    );
  }
  
  void _showCourtChangeDialog() {
    showDialog(
      context: context,
      builder: (context) => _CourtChangeDialog(
        onFillForm: (title, message) {
          _titleController.text = title;
          _messageController.text = message;
        },
      ),
    );
  }
  
  void _showDelayDialog() {
    showDialog(
      context: context,
      builder: (context) => _DelayDialog(
        onFillForm: (title, message) {
          _titleController.text = title;
          _messageController.text = message;
        },
      ),
    );
  }
  
  void _showTournamentUpdateDialog() {
    showDialog(
      context: context,
      builder: (context) => _TournamentUpdateDialog(
        onFillForm: (title, message) {
          _titleController.text = title;
          _messageController.text = message;
        },
      ),
    );
  }
}

// Dialog for missing team notification
class _MissingTeamDialog extends StatefulWidget {
  final Function(String title, String message) onFillForm;

  const _MissingTeamDialog({required this.onFillForm});

  @override
  State<_MissingTeamDialog> createState() => _MissingTeamDialogState();
}

class _MissingTeamDialogState extends State<_MissingTeamDialog> {
  final _formKey = GlobalKey<FormState>();
  final _courtController = TextEditingController();
  final _detailsController = TextEditingController();

  @override
  void dispose() {
    _courtController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mannschaft fehlt'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _courtController,
              decoration: const InputDecoration(
                labelText: 'Platz',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty == true ? 'Bitte geben Sie einen Platz an' : null,
            ),
            const SizedBox(height: 16),
                         TextFormField(
               controller: _detailsController,
               decoration: const InputDecoration(
                 labelText: 'Details (optional)',
                 border: OutlineInputBorder(),
               ),
               maxLines: 3,
             ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: () {
                         if (_formKey.currentState!.validate()) {
               final title = 'Mannschaft fehlt auf Platz ${_courtController.text}';
               final message = _detailsController.text.isEmpty 
                   ? 'Eine Mannschaft fehlt auf Platz ${_courtController.text}.\n\nBitte überprüfen Sie die Anwesenheit und informieren Sie das Team über die Spielzeit.'
                   : 'Eine Mannschaft fehlt auf Platz ${_courtController.text}.\n\nDetails: ${_detailsController.text}\n\nBitte überprüfen Sie die Anwesenheit und informieren Sie das Team über die Spielzeit.';
               widget.onFillForm(title, message);
               Navigator.of(context).pop();
             }
          },
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}

// Dialog for upcoming game notification
class _UpcomingGameDialog extends StatefulWidget {
  final Function(String title, String message) onFillForm;

  const _UpcomingGameDialog({required this.onFillForm});

  @override
  State<_UpcomingGameDialog> createState() => _UpcomingGameDialogState();
}

class _UpcomingGameDialogState extends State<_UpcomingGameDialog> {
  final _formKey = GlobalKey<FormState>();
  final _team1Controller = TextEditingController();
  final _team2Controller = TextEditingController();
  final _courtController = TextEditingController();
  final _timeController = TextEditingController();

  @override
  void dispose() {
    _team1Controller.dispose();
    _team2Controller.dispose();
    _courtController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Anstehendes Spiel'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _team1Controller,
              decoration: const InputDecoration(
                labelText: 'Team 1',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty == true ? 'Bitte geben Sie Team 1 an' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _team2Controller,
              decoration: const InputDecoration(
                labelText: 'Team 2',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty == true ? 'Bitte geben Sie Team 2 an' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _courtController,
              decoration: const InputDecoration(
                labelText: 'Platz',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty == true ? 'Bitte geben Sie einen Platz an' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _timeController,
              decoration: const InputDecoration(
                labelText: 'Uhrzeit',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty == true ? 'Bitte geben Sie eine Uhrzeit an' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: () {
                         if (_formKey.currentState!.validate()) {
               final title = 'Anstehendes Spiel: ${_timeController.text}';
               final message = 'Ihr nächstes Spiel steht bevor:\n\n${_team1Controller.text} vs ${_team2Controller.text}\nPlatz: ${_courtController.text}\nUhrzeit: ${_timeController.text}\n\nBitte seien Sie rechtzeitig vor Ort!';
               widget.onFillForm(title, message);
               Navigator.of(context).pop();
             }
          },
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}

// Dialog for match result notification
class _MatchResultDialog extends StatefulWidget {
  final Function(String title, String message) onFillForm;

  const _MatchResultDialog({required this.onFillForm});

  @override
  State<_MatchResultDialog> createState() => _MatchResultDialogState();
}

class _MatchResultDialogState extends State<_MatchResultDialog> {
  final _formKey = GlobalKey<FormState>();
  final _team1Controller = TextEditingController();
  final _team2Controller = TextEditingController();
  final _set1Team1Controller = TextEditingController();
  final _set1Team2Controller = TextEditingController();
  final _set2Team1Controller = TextEditingController();
  final _set2Team2Controller = TextEditingController();
  final _set3Team1Controller = TextEditingController();
  final _set3Team2Controller = TextEditingController();

  @override
  void dispose() {
    _team1Controller.dispose();
    _team2Controller.dispose();
    _set1Team1Controller.dispose();
    _set1Team2Controller.dispose();
    _set2Team1Controller.dispose();
    _set2Team2Controller.dispose();
    _set3Team1Controller.dispose();
    _set3Team2Controller.dispose();
    super.dispose();
  }

  String _calculateTotalScore() {
    try {
      int team1Sets = 0;
      int team2Sets = 0;
      
      // Count sets won
      if (_set1Team1Controller.text.isNotEmpty && _set1Team2Controller.text.isNotEmpty) {
        if (int.parse(_set1Team1Controller.text) > int.parse(_set1Team2Controller.text)) {
          team1Sets++;
        } else {
          team2Sets++;
        }
      }
      
      if (_set2Team1Controller.text.isNotEmpty && _set2Team2Controller.text.isNotEmpty) {
        if (int.parse(_set2Team1Controller.text) > int.parse(_set2Team2Controller.text)) {
          team1Sets++;
        } else {
          team2Sets++;
        }
      }
      
      if (_set3Team1Controller.text.isNotEmpty && _set3Team2Controller.text.isNotEmpty) {
        if (int.parse(_set3Team1Controller.text) > int.parse(_set3Team2Controller.text)) {
          team1Sets++;
        } else {
          team2Sets++;
        }
      }
      
      return '$team1Sets:$team2Sets';
    } catch (e) {
      return '0:0';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Spielergebnis'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _team1Controller,
                      decoration: const InputDecoration(
                        labelText: 'Team 1',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value?.isEmpty == true ? 'Erforderlich' : null,
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
                      validator: (value) => value?.isEmpty == true ? 'Erforderlich' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Satz 1', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _set1Team1Controller,
                      decoration: const InputDecoration(
                        labelText: 'Team 1',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value?.isEmpty == true ? 'Erforderlich' : null,
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _set1Team2Controller,
                      decoration: const InputDecoration(
                        labelText: 'Team 2',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value?.isEmpty == true ? 'Erforderlich' : null,
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Satz 2', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _set2Team1Controller,
                      decoration: const InputDecoration(
                        labelText: 'Team 1',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value?.isEmpty == true ? 'Erforderlich' : null,
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _set2Team2Controller,
                      decoration: const InputDecoration(
                        labelText: 'Team 2',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value?.isEmpty == true ? 'Erforderlich' : null,
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Satz 3 (optional)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _set3Team1Controller,
                      decoration: const InputDecoration(
                        labelText: 'Team 1',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _set3Team2Controller,
                      decoration: const InputDecoration(
                        labelText: 'Team 2',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text('Aktueller Gesamtstand:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_calculateTotalScore(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: () {
                         if (_formKey.currentState!.validate()) {
               final team1 = _team1Controller.text;
               final team2 = _team2Controller.text;
               final set1 = '${_set1Team1Controller.text}:${_set1Team2Controller.text}';
               final set2 = '${_set2Team1Controller.text}:${_set2Team2Controller.text}';
               final totalScore = _calculateTotalScore();
               
               String sets = '($set1, $set2';
               
               // Add set 3 if provided
               if (_set3Team1Controller.text.isNotEmpty && _set3Team2Controller.text.isNotEmpty) {
                 final set3 = '${_set3Team1Controller.text}:${_set3Team2Controller.text}';
                 sets += ', $set3)';
               } else {
                 sets += ')';
               }
               
               // Determine winner
               final scoreParts = totalScore.split(':');
               final team1Sets = int.parse(scoreParts[0]);
               final team2Sets = int.parse(scoreParts[1]);
               final winner = team1Sets > team2Sets ? team1 : team2;
               
               final title = '$winner Gewinnt $totalScore!';
               final message = 'Das Spiel ist beendet:\n$team1 vs $team2 $totalScore $sets';
               widget.onFillForm(title, message);
               Navigator.of(context).pop();
             }
          },
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}

// Dialog for court change notification
class _CourtChangeDialog extends StatefulWidget {
  final Function(String title, String message) onFillForm;

  const _CourtChangeDialog({required this.onFillForm});

  @override
  State<_CourtChangeDialog> createState() => _CourtChangeDialogState();
}

class _CourtChangeDialogState extends State<_CourtChangeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _oldCourtController = TextEditingController();
  final _newCourtController = TextEditingController();
  final _timeController = TextEditingController();
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _oldCourtController.dispose();
    _newCourtController.dispose();
    _timeController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Platz geändert'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _oldCourtController,
              decoration: const InputDecoration(
                labelText: 'Alter Platz',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty == true ? 'Bitte geben Sie den alten Platz an' : null,
            ),
            const SizedBox(height: 16),
                         TextFormField(
               controller: _newCourtController,
               decoration: const InputDecoration(
                 labelText: 'Neuer Platz',
                 border: OutlineInputBorder(),
               ),
               validator: (value) => value?.isEmpty == true ? 'Bitte geben Sie den neuen Platz an' : null,
             ),
             const SizedBox(height: 16),
             TextFormField(
               controller: _timeController,
               decoration: const InputDecoration(
                 labelText: 'Uhrzeit',
                 border: OutlineInputBorder(),
               ),
               validator: (value) => value?.isEmpty == true ? 'Bitte geben Sie die Uhrzeit an' : null,
             ),
             const SizedBox(height: 16),
             TextFormField(
               controller: _reasonController,
               decoration: const InputDecoration(
                 labelText: 'Grund (optional)',
                 border: OutlineInputBorder(),
               ),
               maxLines: 2,
             ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: () {
                         if (_formKey.currentState!.validate()) {
               final title = 'Platz geändert: ${_oldCourtController.text} → ${_newCourtController.text}';
               final message = _reasonController.text.isEmpty 
                   ? 'Wichtige Information: Ihr Spielplatz wurde geändert.\n\nVon: ${_oldCourtController.text}\nZu: ${_newCourtController.text}\nUhrzeit: ${_timeController.text}\n\nBitte begeben Sie sich zum neuen Platz.'
                   : 'Wichtige Information: Ihr Spielplatz wurde geändert.\n\nVon: ${_oldCourtController.text}\nZu: ${_newCourtController.text}\nUhrzeit: ${_timeController.text}\n\nGrund: ${_reasonController.text}\n\nBitte begeben Sie sich zum neuen Platz.';
               widget.onFillForm(title, message);
               Navigator.of(context).pop();
             }
          },
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}

// Dialog for delay notification
class _DelayDialog extends StatefulWidget {
  final Function(String title, String message) onFillForm;

  const _DelayDialog({required this.onFillForm});

  @override
  State<_DelayDialog> createState() => _DelayDialogState();
}

class _DelayDialogState extends State<_DelayDialog> {
  final _formKey = GlobalKey<FormState>();
  final _delayController = TextEditingController();
  final _timeController = TextEditingController();
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _delayController.dispose();
    _timeController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Verzögerung'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
                         TextFormField(
               controller: _delayController,
               decoration: const InputDecoration(
                 labelText: 'Verzögerung (z.B. 15 Minuten)',
                 border: OutlineInputBorder(),
               ),
               validator: (value) => value?.isEmpty == true ? 'Bitte geben Sie die Verzögerung an' : null,
             ),
             const SizedBox(height: 16),
             TextFormField(
               controller: _timeController,
               decoration: const InputDecoration(
                 labelText: 'Neue Uhrzeit',
                 border: OutlineInputBorder(),
               ),
               validator: (value) => value?.isEmpty == true ? 'Bitte geben Sie die neue Uhrzeit an' : null,
             ),
             const SizedBox(height: 16),
             TextFormField(
               controller: _reasonController,
               decoration: const InputDecoration(
                 labelText: 'Grund (optional)',
                 border: OutlineInputBorder(),
               ),
               maxLines: 3,
             ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: () {
                         if (_formKey.currentState!.validate()) {
               final title = 'Verzögerung: ${_delayController.text}';
               final message = _reasonController.text.isEmpty 
                   ? 'Ihr Spiel verzögert sich um ${_delayController.text}.\n\nNeue Spielzeit: ${_timeController.text}\n\nVielen Dank für Ihr Verständnis!'
                   : 'Ihr Spiel verzögert sich um ${_delayController.text}.\n\nGrund: ${_reasonController.text}\nNeue Spielzeit: ${_timeController.text}\n\nVielen Dank für Ihr Verständnis!';
               widget.onFillForm(title, message);
               Navigator.of(context).pop();
             }
          },
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}

// Dialog for tournament update notification
class _TournamentUpdateDialog extends StatefulWidget {
  final Function(String title, String message) onFillForm;

  const _TournamentUpdateDialog({required this.onFillForm});

  @override
  State<_TournamentUpdateDialog> createState() => _TournamentUpdateDialogState();
}

class _TournamentUpdateDialogState extends State<_TournamentUpdateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _updateTypeController = TextEditingController();
  final _detailsController = TextEditingController();

  @override
  void dispose() {
    _updateTypeController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Turnier-Update'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _updateTypeController,
              decoration: const InputDecoration(
                labelText: 'Update-Typ (z.B. Spielplan, Regeln)',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty == true ? 'Bitte geben Sie den Update-Typ an' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _detailsController,
              decoration: const InputDecoration(
                labelText: 'Details',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              validator: (value) => value?.isEmpty == true ? 'Bitte geben Sie Details an' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final title = 'Turnier-Update: ${_updateTypeController.text}';
              final message = 'Wichtiges Update zum Turnier:\n\n${_updateTypeController.text}\n\nDetails:\n${_detailsController.text}\n\nBitte beachten Sie diese Änderungen für den weiteren Turnierverlauf.';
              widget.onFillForm(title, message);
              Navigator.of(context).pop();
            }
          },
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
} 