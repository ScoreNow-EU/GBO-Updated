import 'package:flutter/material.dart';
import '../models/tournament.dart';
import '../services/game_service.dart';
import '../services/game_scheduler.dart';
import '../services/team_service.dart';

class AdvancedSchedulingDialog extends StatefulWidget {
  final Tournament tournament;
  final GameService gameService;
  final TeamService teamService;
  final TimeOfDay scheduleStartTime;
  final TimeOfDay scheduleEndTime;
  final int timeSlotDuration;
  final Function(SchedulingResult) onSchedulingComplete;

  const AdvancedSchedulingDialog({
    Key? key,
    required this.tournament,
    required this.gameService,
    required this.teamService,
    required this.scheduleStartTime,
    required this.scheduleEndTime,
    required this.timeSlotDuration,
    required this.onSchedulingComplete,
  }) : super(key: key);

  @override
  State<AdvancedSchedulingDialog> createState() => _AdvancedSchedulingDialogState();
}

class _AdvancedSchedulingDialogState extends State<AdvancedSchedulingDialog> {
  bool _isLoading = false;
  int _maxFieldsToUse = 10;
  bool _optimizeForMinimalFields = false;
  bool _preserveExistingSchedule = false;
  double _minRestTimeMinutes = 30.0;
  bool _prioritizePoolGames = true;
  String _distributionStrategy = 'balanced'; // balanced, sequential, minimize_fields
  
  // Conflict handling options
  bool _allowSameTimeConflicts = false;
  bool _allowBackToBackGames = false;
  int _minimumRestMinutes = 15;
  
  // Division priority settings
  Map<String, String> _divisionPriorities = {}; // division -> priority (today, asap, time)
  List<String> _availableDivisions = [];
  bool _divisionsLoaded = false;
  
  // Break/ceremony slots
  List<BreakSlot> _breakSlots = [];
  bool _allowGapsForConflicts = true;

  @override
  void initState() {
    super.initState();
    _maxFieldsToUse = widget.tournament.courts.length;
    _loadDivisions();
  }

  Future<void> _loadDivisions() async {
    try {
      final scheduler = GameScheduler();
      final divisions = await scheduler.getDivisionsWithGames(
        widget.tournament, 
        widget.gameService, 
        widget.teamService,
      );
      
      setState(() {
        _availableDivisions = divisions.toList()..sort();
        // Initialize division priorities
        for (String division in _availableDivisions) {
          _divisionPriorities[division] = 'asap'; // Default to ASAP
        }
        _divisionsLoaded = true;
      });
    } catch (e) {
      // Fallback to tournament categories if loading fails
      setState(() {
        _availableDivisions = widget.tournament.categories;
        for (String category in _availableDivisions) {
          _divisionPriorities[category] = 'asap';
        }
        _divisionsLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = GameScheduler().getSchedulingStats(widget.tournament, widget.gameService);
    
    return Dialog(
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_fix_high, color: Colors.blue.shade700, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Erweiterte Spielplanung',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        Text(
                          'Intelligente Verteilung von ${stats['totalGames']} Spielen auf ${stats['totalFields']} Felder',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Current Statistics
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aktueller Status',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStatChip('Geplant', '${stats['scheduledGames']}', Colors.green),
                      const SizedBox(width: 8),
                      _buildStatChip('Ungeplant', '${stats['unscheduledGames']}', Colors.orange),
                      const SizedBox(width: 8),
                      _buildStatChip('Felder genutzt', '${stats['fieldsUsed']}/${stats['totalFields']}', Colors.blue),
                    ],
                  ),
                ],
              ),
            ),

            // Configuration Options
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Feldoptionen'),
                    _buildFieldOptions(),
                    
                    const SizedBox(height: 20),
                    _buildSectionTitle('Planungsstrategie'),
                    _buildStrategyOptions(),
                    
                    const SizedBox(height: 20),
                    _buildSectionTitle('Konfliktbehandlung'),
                    _buildConflictOptions(),
                    
                    const SizedBox(height: 20),
                    _buildSectionTitle('Kategorien-Prioritäten'),
                    _buildDivisionPriorities(),
                    
                    const SizedBox(height: 20),
                    _buildSectionTitle('Pausen & Zeremonien'),
                    _buildBreakSlots(),
                    
                    const SizedBox(height: 20),
                    _buildSectionTitle('Erweiterte Einstellungen'),
                    _buildAdvancedOptions(),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Abbrechen'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _performScheduling,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isLoading 
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Spiele planen'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color.fromRGBO(
                (color.red * 0.7).round(),
                (color.green * 0.7).round(),
                (color.blue * 0.7).round(),
                1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFieldOptions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Maximale Anzahl Felder',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
            SizedBox(
              width: 100,
              child: Slider(
                value: _maxFieldsToUse.toDouble(),
                min: 1,
                max: widget.tournament.courts.length.toDouble(),
                divisions: widget.tournament.courts.length > 1 ? widget.tournament.courts.length - 1 : 1,
                label: _maxFieldsToUse.toString(),
                onChanged: (value) {
                  setState(() {
                    _maxFieldsToUse = value.round();
                  });
                },
              ),
            ),
            Text('$_maxFieldsToUse'),
          ],
        ),
        
        SwitchListTile(
          title: const Text('Minimale Feldanzahl verwenden'),
          subtitle: const Text('Versuche, möglichst wenige Felder zu nutzen'),
          value: _optimizeForMinimalFields,
          onChanged: (value) {
            setState(() {
              _optimizeForMinimalFields = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildStrategyOptions() {
    return Column(
      children: [
        RadioListTile<String>(
          title: const Text('Ausgewogen'),
          subtitle: const Text('Gleichmäßige Verteilung über alle Felder'),
          value: 'balanced',
          groupValue: _distributionStrategy,
          onChanged: (value) {
            setState(() {
              _distributionStrategy = value!;
            });
          },
        ),
        RadioListTile<String>(
          title: const Text('Sequenziell'),
          subtitle: const Text('Felder nacheinander füllen'),
          value: 'sequential',
          groupValue: _distributionStrategy,
          onChanged: (value) {
            setState(() {
              _distributionStrategy = value!;
            });
          },
        ),
        RadioListTile<String>(
          title: const Text('Minimal Felder'),
          subtitle: const Text('So wenige Felder wie möglich verwenden'),
          value: 'minimize_fields',
          groupValue: _distributionStrategy,
          onChanged: (value) {
            setState(() {
              _distributionStrategy = value!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildConflictOptions() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Gleichzeitige Spiele erlauben'),
          subtitle: const Text('Teams können zur gleichen Zeit auf verschiedenen Feldern spielen'),
          value: _allowSameTimeConflicts,
          onChanged: (value) {
            setState(() {
              _allowSameTimeConflicts = value;
            });
          },
        ),
        
        SwitchListTile(
          title: const Text('Direkt aufeinanderfolgende Spiele erlauben'),
          subtitle: const Text('Teams können ohne Pause zwischen Spielen antreten'),
          value: _allowBackToBackGames,
          onChanged: (value) {
            setState(() {
              _allowBackToBackGames = value;
            });
          },
        ),
        
        if (!_allowBackToBackGames)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Mindestpause zwischen Spielen (Min.)',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Slider(
                    value: _minimumRestMinutes.toDouble(),
                    min: 5,
                    max: 60,
                    divisions: 11,
                    label: '$_minimumRestMinutes Min.',
                    onChanged: (value) {
                      setState(() {
                        _minimumRestMinutes = value.round();
                      });
                    },
                  ),
                ),
                Text('$_minimumRestMinutes Min.'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDivisionPriorities() {
    if (!_divisionsLoaded) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_availableDivisions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'Keine Divisionen mit Spielen gefunden',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      children: _availableDivisions.map((category) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text('Nur heute'),
                      subtitle: const Text('Nur am ersten Tag planen'),
                      value: 'today',
                      groupValue: _divisionPriorities[category],
                      onChanged: (value) {
                        setState(() {
                          _divisionPriorities[category] = value!;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<String>(
                      title: const Text('ASAP'),
                      subtitle: const Text('So früh wie möglich planen'),
                      value: 'asap',
                      groupValue: _divisionPriorities[category],
                      onChanged: (value) {
                        setState(() {
                          _divisionPriorities[category] = value!;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<String>(
                      title: const Text('Zeit geben'),
                      subtitle: const Text('Über mehrere Tage verteilen'),
                      value: 'time',
                      groupValue: _divisionPriorities[category],
                      onChanged: (value) {
                        setState(() {
                          _divisionPriorities[category] = value!;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBreakSlots() {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Pausenzeiten verwalten',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _addBreakSlot,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Pause hinzufügen'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_breakSlots.isEmpty)
                  const Text(
                    'Keine Pausen definiert. Fügen Sie Zeiten für Zeremonien, Siegerehrungen oder Pausen hinzu.',
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  ..._breakSlots.asMap().entries.map((entry) {
                    final index = entry.key;
                    final breakSlot = entry.value;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      child: ListTile(
                        title: Text(breakSlot.title),
                        subtitle: Text(
                          '${_formatTime(breakSlot.startTime)} - ${_formatTime(breakSlot.endTime)}\n${breakSlot.description}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeBreakSlot(index),
                        ),
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedOptions() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Bestehende Planung erhalten'),
          subtitle: const Text('Bereits geplante Spiele nicht verschieben'),
          value: _preserveExistingSchedule,
          onChanged: (value) {
            setState(() {
              _preserveExistingSchedule = value;
            });
          },
        ),
        
        SwitchListTile(
          title: const Text('Gruppenspiele priorisieren'),
          subtitle: const Text('Gruppenspiele vor K.O.-Spielen planen'),
          value: _prioritizePoolGames,
          onChanged: (value) {
            setState(() {
              _prioritizePoolGames = value;
            });
          },
        ),
        
        SwitchListTile(
          title: const Text('Lücken bei Konflikten erlauben'),
          subtitle: const Text('Zeitslots freilassen wenn Konflikte nicht lösbar sind'),
          value: _allowGapsForConflicts,
          onChanged: (value) {
            setState(() {
              _allowGapsForConflicts = value;
            });
          },
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _addBreakSlot() {
    showDialog(
      context: context,
      builder: (context) => _BreakSlotDialog(
        onAdd: (breakSlot) {
          setState(() {
            _breakSlots.add(breakSlot);
          });
        },
      ),
    );
  }

  void _removeBreakSlot(int index) {
    setState(() {
      _breakSlots.removeAt(index);
    });
  }

  Future<void> _performScheduling() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final scheduler = GameScheduler();
      final result = await scheduler.scheduleWithOptimization(
        tournament: widget.tournament,
        gameService: widget.gameService,
        scheduleStartTime: widget.scheduleStartTime,
        scheduleEndTime: widget.scheduleEndTime,
        timeSlotDuration: widget.timeSlotDuration,
        maxFieldsToUse: _maxFieldsToUse,
        optimizeForMinimalFields: _optimizeForMinimalFields,
        allowSameTimeConflicts: _allowSameTimeConflicts,
        allowBackToBackGames: _allowBackToBackGames,
        minimumRestMinutes: _minimumRestMinutes,
        divisionPriorities: _divisionPriorities,
        teamService: widget.teamService,
        breakSlots: _breakSlots,
        allowGapsForConflicts: _allowGapsForConflicts,
      );

      Navigator.of(context).pop();
      widget.onSchedulingComplete(result);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler bei der Spielplanung: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

class _BreakSlotDialog extends StatefulWidget {
  final Function(BreakSlot) onAdd;

  const _BreakSlotDialog({required this.onAdd});

  @override
  State<_BreakSlotDialog> createState() => _BreakSlotDialogState();
}

class _BreakSlotDialogState extends State<_BreakSlotDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  TimeOfDay _startTime = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 13, minute: 0);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pause hinzufügen'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Titel',
                hintText: 'z.B. Siegerehrung, Mittagspause',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Beschreibung (optional)',
                hintText: 'Zusätzliche Details',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('Startzeit'),
                    subtitle: Text(_startTime.format(context)),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _startTime,
                      );
                      if (time != null) {
                        setState(() {
                          _startTime = time;
                        });
                      }
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text('Endzeit'),
                    subtitle: Text(_endTime.format(context)),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _endTime,
                      );
                      if (time != null) {
                        setState(() {
                          _endTime = time;
                        });
                      }
                    },
                  ),
                ),
              ],
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
          onPressed: _titleController.text.isNotEmpty ? _addBreakSlot : null,
          child: const Text('Hinzufügen'),
        ),
      ],
    );
  }

  void _addBreakSlot() {
    final now = DateTime.now();
    final startTime = DateTime(
      now.year, now.month, now.day,
      _startTime.hour, _startTime.minute,
    );
    final endTime = DateTime(
      now.year, now.month, now.day,
      _endTime.hour, _endTime.minute,
    );

    if (endTime.isBefore(startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Endzeit muss nach Startzeit liegen'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final breakSlot = BreakSlot(
      startTime: startTime,
      endTime: endTime,
      title: _titleController.text,
      description: _descriptionController.text,
    );

    widget.onAdd(breakSlot);
    Navigator.of(context).pop();
  }
} 