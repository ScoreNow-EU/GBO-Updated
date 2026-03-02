import 'package:flutter/material.dart';
import '../models/game.dart';
import '../models/referee.dart';
import '../models/court.dart';
import '../models/team.dart';
import '../services/game_service.dart';
import '../services/referee_service.dart';
import '../services/court_service.dart';
import '../services/team_service.dart';
import '../utils/app_colors.dart';

class GameEditScreen extends StatefulWidget {
  final Game game;

  const GameEditScreen({
    super.key,
    required this.game,
  });

  @override
  State<GameEditScreen> createState() => _GameEditScreenState();
}

class _GameEditScreenState extends State<GameEditScreen> {
  final GameService _gameService = GameService();
  final RefereeService _refereeService = RefereeService();
  final CourtService _courtService = CourtService();
  final TeamService _teamService = TeamService();

  late Game _editedGame;
  List<Referee> _allReferees = [];
  List<Court> _allCourts = [];
  List<Team> _allTeams = [];
  
  bool _isLoading = true;
  bool _isSaving = false;
  
  // Form controllers
  final _gameNotesController = TextEditingController();
  TimeOfDay? _selectedTime;
  DateTime? _selectedDate;
  
  // Selected values
  String? _selectedRefereeId;
  String? _selectedCourtId;
  String? _selectedTeamAId;
  String? _selectedTeamBId;
  GameStatus _selectedStatus = GameStatus.scheduled;

  @override
  void initState() {
    super.initState();
    _editedGame = widget.game;
    _initializeForm();
    _loadData();
  }

  void _initializeForm() {
    _gameNotesController.text = ''; // Game model doesn't have notes field
    _selectedTime = _editedGame.scheduledTime != null 
        ? TimeOfDay.fromDateTime(_editedGame.scheduledTime!)
        : null;
    _selectedDate = _editedGame.scheduledTime;
    _selectedRefereeId = _editedGame.refereeGespannId; // Use refereeGespannId instead
    _selectedCourtId = _editedGame.courtId;
    _selectedTeamAId = _editedGame.teamAId;
    _selectedTeamBId = _editedGame.teamBId;
    _selectedStatus = _editedGame.status;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final futures = await Future.wait([
        _refereeService.getReferees().first,
        _courtService.getCourts().first,
        _teamService.getTeams().first,
      ]);
      
      setState(() {
        _allReferees = futures[0] as List<Referee>;
        _allCourts = futures[1] as List<Court>;
        _allTeams = futures[2] as List<Team>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
  }

  @override
  void dispose() {
    _gameNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Edit Game: ${widget.game.teamAName} vs ${widget.game.teamBName}'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: _saveGame,
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column - Basic Info
                  Expanded(
                    flex: 1,
                    child: _buildBasicInfoColumn(),
                  ),
                  
                  const SizedBox(width: 24),
                  
                  // Right Column - Assignments & Settings
                  Expanded(
                    flex: 1,
                    child: _buildAssignmentsColumn(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBasicInfoColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          'Game Information',
          Icons.info,
          [
            _buildGameInfoRow('Game ID', widget.game.id),
            _buildGameInfoRow('Tournament', widget.game.tournamentId),
            _buildGameInfoRow('Game Type', widget.game.gameType.toString().split('.').last),
            if (widget.game.poolId != null)
              _buildGameInfoRow('Pool', widget.game.poolId!),
            _buildGameInfoRow('Created', _formatDateTime(widget.game.createdAt)),
            if (widget.game.updatedAt != null)
              _buildGameInfoRow('Last Updated', _formatDateTime(widget.game.updatedAt!)),
          ],
        ),
        
        const SizedBox(height: 24),
        
        _buildSectionCard(
          'Teams',
          Icons.groups,
          [
            _buildTeamSelector('Team A', _selectedTeamAId, (value) {
              setState(() {
                _selectedTeamAId = value;
              });
            }),
            const SizedBox(height: 16),
            _buildTeamSelector('Team B', _selectedTeamBId, (value) {
              setState(() {
                _selectedTeamBId = value;
              });
            }),
          ],
        ),
        
        const SizedBox(height: 24),
        
        _buildSectionCard(
          'Game Notes',
          Icons.note,
          [
            TextFormField(
              controller: _gameNotesController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Add notes about this game...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAssignmentsColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          'Schedule & Court',
          Icons.schedule,
          [
            _buildDateTimeSelector(),
            const SizedBox(height: 16),
            _buildCourtSelector(),
          ],
        ),
        
        const SizedBox(height: 24),
        
        _buildSectionCard(
          'Referee Assignment',
          Icons.sports,
          [
            _buildRefereeSelector(),
            const SizedBox(height: 16),
            _buildRefereeInfo(),
          ],
        ),
        
        const SizedBox(height: 24),
        
        _buildSectionCard(
          'Game Status',
          Icons.flag,
          [
            _buildStatusSelector(),
            const SizedBox(height: 16),
            _buildStatusInfo(),
          ],
        ),
        
        const SizedBox(height: 24),
        
        _buildSectionCard(
          'Actions',
          Icons.settings,
          [
            _buildActionButtons(),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primaryColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildGameInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamSelector(String label, String? selectedTeamId, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: selectedTeamId,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          hint: Text('Select $label'),
          items: _allTeams.map((team) {
            return DropdownMenuItem(
              value: team.id,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    team.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    team.city,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildDateTimeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Scheduled Date & Time',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        _selectedDate != null
                            ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                            : 'Select Date',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: _selectTime,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        _selectedTime != null
                            ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                            : 'Select Time',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCourtSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Court Assignment',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedCourtId,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          hint: const Text('Select Court'),
          items: _allCourts.map((court) {
            return DropdownMenuItem(
              value: court.id,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    court.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (court.description.isNotEmpty)
                    Text(
                      court.description,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedCourtId = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildRefereeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Assigned Referee',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedRefereeId,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          hint: const Text('Select Referee'),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('No Referee Assigned'),
            ),
            ..._allReferees.map((referee) {
              return DropdownMenuItem(
                value: referee.id,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      referee.fullName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      referee.licenseType,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              );
            }),
          ],
          onChanged: (value) {
            setState(() {
              _selectedRefereeId = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildRefereeInfo() {
    if (_selectedRefereeId == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          border: Border.all(color: Colors.orange.shade200),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade600, size: 20),
            const SizedBox(width: 8),
            const Text('No referee assigned to this game'),
          ],
        ),
      );
    }

    final referee = _allReferees.firstWhere((r) => r.id == _selectedRefereeId);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                referee.fullName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('License: ${referee.licenseType}'),
          if (referee.email.isNotEmpty) Text('Email: ${referee.email}'),
        ],
      ),
    );
  }

  Widget _buildStatusSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Game Status',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<GameStatus>(
          value: _selectedStatus,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: GameStatus.values.map((status) {
            return DropdownMenuItem(
              value: status,
              child: Row(
                children: [
                  Icon(_getStatusIcon(status), size: 20, color: _getStatusColor(status)),
                  const SizedBox(width: 8),
                  Text(_getStatusText(status)),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedStatus = value;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildStatusInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getStatusColor(_selectedStatus).withOpacity(0.1),
        border: Border.all(color: _getStatusColor(_selectedStatus).withOpacity(0.3)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(_getStatusIcon(_selectedStatus), color: _getStatusColor(_selectedStatus), size: 20),
          const SizedBox(width: 8),
          Text(_getStatusDescription(_selectedStatus)),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _duplicateGame,
            icon: const Icon(Icons.copy),
            label: const Text('Duplicate Game'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _openScoring,
            icon: const Icon(Icons.sports_score),
            label: const Text('Open Scoring'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _deleteGame,
            icon: const Icon(Icons.delete),
            label: const Text('Delete Game'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  // Helper methods
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  IconData _getStatusIcon(GameStatus status) {
    switch (status) {
      case GameStatus.scheduled:
        return Icons.schedule;
      case GameStatus.inProgress:
        return Icons.play_circle;
      case GameStatus.completed:
        return Icons.check_circle;
      case GameStatus.cancelled:
        return Icons.cancel;
    }
  }

  Color _getStatusColor(GameStatus status) {
    switch (status) {
      case GameStatus.scheduled:
        return Colors.blue.shade600;
      case GameStatus.inProgress:
        return Colors.green.shade600;
      case GameStatus.completed:
        return Colors.grey.shade600;
      case GameStatus.cancelled:
        return Colors.red.shade600;
    }
  }

  String _getStatusText(GameStatus status) {
    switch (status) {
      case GameStatus.scheduled:
        return 'Scheduled';
      case GameStatus.inProgress:
        return 'In Progress';
      case GameStatus.completed:
        return 'Completed';
      case GameStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _getStatusDescription(GameStatus status) {
    switch (status) {
      case GameStatus.scheduled:
        return 'Game is scheduled and ready to play';
      case GameStatus.inProgress:
        return 'Game is currently being played';
      case GameStatus.completed:
        return 'Game has finished';
      case GameStatus.cancelled:
        return 'Game has been cancelled';
    }
  }

  // Action methods
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveGame() async {
    setState(() => _isSaving = true);
    
    try {
      // Create updated game
      DateTime? scheduledTime;
      if (_selectedDate != null && _selectedTime != null) {
        scheduledTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );
      }

      final updatedGame = Game(
        id: widget.game.id,
        tournamentId: widget.game.tournamentId,
        teamAId: _selectedTeamAId ?? widget.game.teamAId,
        teamBId: _selectedTeamBId ?? widget.game.teamBId,
        teamAName: _selectedTeamAId != null 
            ? _allTeams.firstWhere((t) => t.id == _selectedTeamAId).name
            : widget.game.teamAName,
        teamBName: _selectedTeamBId != null 
            ? _allTeams.firstWhere((t) => t.id == _selectedTeamBId).name
            : widget.game.teamBName,
        gameType: widget.game.gameType,
        poolId: widget.game.poolId,
        scheduledTime: scheduledTime,
        courtId: _selectedCourtId,
        refereeGespannId: _selectedRefereeId,
        delegateId: widget.game.delegateId,
        status: _selectedStatus,
        result: widget.game.result,
        createdAt: widget.game.createdAt,
        updatedAt: DateTime.now(),
      );

      await _gameService.updateGame(updatedGame);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game updated successfully')),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving game: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _duplicateGame() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicate Game'),
        content: const Text('Create a copy of this game with the same settings?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement game duplication
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Game duplication will be implemented')),
              );
            },
            child: const Text('Duplicate'),
          ),
        ],
      ),
    );
  }

  void _openScoring() {
    // TODO: Navigate to scoring screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scoring screen will be opened')),
    );
  }

  void _deleteGame() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Game'),
        content: const Text('Are you sure you want to delete this game? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement game deletion
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Game deletion will be implemented')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
