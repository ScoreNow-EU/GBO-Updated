import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:toastification/toastification.dart';
import '../models/kanban_task.dart';
import '../models/user.dart' as app_user;
import '../services/kanban_service.dart';

class CreateTaskDialog extends StatefulWidget {
  final app_user.User currentUser;
  final TaskStatus? initialStatus;
  final Function(KanbanTask) onTaskCreated;

  const CreateTaskDialog({
    super.key,
    required this.currentUser,
    this.initialStatus,
    required this.onTaskCreated,
  });

  @override
  State<CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<CreateTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _kanbanService = KanbanService();
  
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _estimatedHoursController;
  late final TextEditingController _sprintController;
  
  late TaskType _selectedType;
  late TaskStatus _selectedStatus;
  late TaskPriority _selectedPriority;
  DateTime? _dueDate;
  final List<String> _labels = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _estimatedHoursController = TextEditingController();
    _sprintController = TextEditingController();
    
    _selectedType = TaskType.task;
    _selectedStatus = widget.initialStatus ?? TaskStatus.todo;
    _selectedPriority = TaskPriority.medium;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _estimatedHoursController.dispose();
    _sprintController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.add_task,
                    color: Colors.blue.shade700,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Neue Aufgabe erstellen',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Titel *',
                          hintText: 'Geben Sie einen aussagekräftigen Titel ein',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Titel ist erforderlich';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Beschreibung',
                          hintText: 'Detaillierte Beschreibung der Aufgabe',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),

                      // Type and Priority Row
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<TaskType>(
                              value: _selectedType,
                              decoration: const InputDecoration(
                                labelText: 'Typ',
                                border: OutlineInputBorder(),
                              ),
                              items: TaskType.values.map((type) => DropdownMenuItem(
                                value: type,
                                child: Row(
                                  children: [
                                    Icon(
                                      _getTypeIcon(type),
                                      size: 16,
                                      color: _getTypeColor(type),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(_getTypeDisplayName(type)),
                                  ],
                                ),
                              )).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedType = value;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<TaskPriority>(
                              value: _selectedPriority,
                              decoration: const InputDecoration(
                                labelText: 'Priorität',
                                border: OutlineInputBorder(),
                              ),
                              items: TaskPriority.values.map((priority) => DropdownMenuItem(
                                value: priority,
                                child: Row(
                                  children: [
                                    _buildPriorityIcon(priority),
                                    const SizedBox(width: 8),
                                    Text(_getPriorityDisplayName(priority)),
                                  ],
                                ),
                              )).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedPriority = value;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Status and Due Date Row
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<TaskStatus>(
                              value: _selectedStatus,
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                border: OutlineInputBorder(),
                              ),
                              items: TaskStatus.values.map((status) => DropdownMenuItem(
                                value: status,
                                child: Text(_getStatusDisplayName(status)),
                              )).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedStatus = value;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: _pickDueDate,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      _dueDate != null
                                          ? 'Fällig: ${DateFormat('dd.MM.yyyy').format(_dueDate!)}'
                                          : 'Fälligkeitsdatum',
                                      style: TextStyle(
                                        color: _dueDate != null 
                                            ? Colors.black 
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_dueDate != null)
                                      IconButton(
                                        onPressed: () {
                                          setState(() {
                                            _dueDate = null;
                                          });
                                        },
                                        icon: const Icon(Icons.clear, size: 16),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Estimated Hours and Sprint
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _estimatedHoursController,
                              decoration: const InputDecoration(
                                labelText: 'Geschätzte Stunden',
                                border: OutlineInputBorder(),
                                suffixText: 'h',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _sprintController,
                              decoration: const InputDecoration(
                                labelText: 'Sprint',
                                hintText: 'z.B. Sprint 1',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Labels
                      _buildLabelsSection(),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Abbrechen'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _createTask,
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Aufgabe erstellen'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabelsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Labels',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _showAddLabelDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Hinzufügen'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_labels.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Keine Labels hinzugefügt',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _labels.map((label) => Chip(
              label: Text(label),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () {
                setState(() {
                  _labels.remove(label);
                });
              },
            )).toList(),
          ),
      ],
    );
  }

  Widget _buildPriorityIcon(TaskPriority priority) {
    Color color;
    IconData icon;

    switch (priority) {
      case TaskPriority.highest:
        color = Colors.red;
        icon = Icons.keyboard_double_arrow_up;
        break;
      case TaskPriority.high:
        color = Colors.red.shade300;
        icon = Icons.keyboard_arrow_up;
        break;
      case TaskPriority.medium:
        color = Colors.orange;
        icon = Icons.drag_handle;
        break;
      case TaskPriority.low:
        color = Colors.green.shade300;
        icon = Icons.keyboard_arrow_down;
        break;
      case TaskPriority.lowest:
        color = Colors.green;
        icon = Icons.keyboard_double_arrow_down;
        break;
    }

    return Icon(icon, size: 16, color: color);
  }

  Color _getTypeColor(TaskType type) {
    switch (type) {
      case TaskType.bug:
        return Colors.red;
      case TaskType.story:
        return Colors.green;
      case TaskType.epic:
        return Colors.purple;
      case TaskType.subtask:
        return Colors.blue;
      case TaskType.task:
      default:
        return Colors.blue.shade700;
    }
  }

  IconData _getTypeIcon(TaskType type) {
    switch (type) {
      case TaskType.bug:
        return Icons.bug_report;
      case TaskType.story:
        return Icons.book;
      case TaskType.epic:
        return Icons.stars;
      case TaskType.subtask:
        return Icons.subdirectory_arrow_right;
      case TaskType.task:
      default:
        return Icons.task_alt;
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  void _showAddLabelDialog() {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Label hinzufügen'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Label-Name eingeben',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              final label = controller.text.trim();
              if (label.isNotEmpty && !_labels.contains(label)) {
                setState(() {
                  _labels.add(label);
                });
              }
              Navigator.of(context).pop();
            },
            child: const Text('Hinzufügen'),
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
      title: Text(message),
      alignment: Alignment.topRight,
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  void _showErrorToast(String message) {
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.fillColored,
      title: Text(message),
      alignment: Alignment.topRight,
      autoCloseDuration: const Duration(seconds: 5),
    );
  }

  Future<void> _createTask() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

          try {
        // Get the highest position for the selected status
        final existingTasks = await _kanbanService.getTasksByStatus(_selectedStatus);
        final newPosition = existingTasks.length;

      final task = KanbanTask(
        id: '', // Will be set by Firestore
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        status: _selectedStatus,
        priority: _selectedPriority,
        reporterId: widget.currentUser.id,
        reporterName: widget.currentUser.fullName,
        reporterEmail: widget.currentUser.email,
        labels: _labels,
        subtaskIds: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        dueDate: _dueDate,
        estimatedHours: _estimatedHoursController.text.isNotEmpty 
            ? int.tryParse(_estimatedHoursController.text) 
            : null,
        sprint: _sprintController.text.isNotEmpty ? _sprintController.text.trim() : null,
        attachments: [],
        comments: [],
                  boardId: 'gbo_main_board', // Will be set to default board by service
        position: newPosition,
      );

      final taskId = await _kanbanService.createTask(task);
      
      if (taskId != null) {
        final createdTask = task.copyWith();
        // Create a new task with the generated ID
        final taskWithId = KanbanTask(
          id: taskId,
          title: task.title,
          description: task.description,
          type: task.type,
          status: task.status,
          priority: task.priority,
          reporterId: task.reporterId,
          reporterName: task.reporterName,
          reporterEmail: task.reporterEmail,
          labels: task.labels,
          subtaskIds: task.subtaskIds,
          createdAt: task.createdAt,
          updatedAt: task.updatedAt,
          dueDate: task.dueDate,
          estimatedHours: task.estimatedHours,
          sprint: task.sprint,
          attachments: task.attachments,
          comments: task.comments,
          boardId: task.boardId,
          position: task.position,
        );
        
        widget.onTaskCreated(taskWithId);
        _showSuccessToast('Aufgabe erfolgreich erstellt');
        Navigator.of(context).pop();
      } else {
        _showErrorToast('Fehler beim Erstellen der Aufgabe');
      }
    } catch (e) {
      _showErrorToast('Fehler: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getTypeDisplayName(TaskType type) {
    switch (type) {
      case TaskType.task:
        return 'Aufgabe';
      case TaskType.bug:
        return 'Fehler';
      case TaskType.story:
        return 'Story';
      case TaskType.epic:
        return 'Epic';
      case TaskType.subtask:
        return 'Unteraufgabe';
    }
  }

  String _getPriorityDisplayName(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.lowest:
        return 'Niedrigste';
      case TaskPriority.low:
        return 'Niedrig';
      case TaskPriority.medium:
        return 'Mittel';
      case TaskPriority.high:
        return 'Hoch';
      case TaskPriority.highest:
        return 'Höchste';
    }
  }

  String _getStatusDisplayName(TaskStatus status) {
    switch (status) {
      case TaskStatus.backlog:
        return 'Backlog';
      case TaskStatus.todo:
        return 'Zu erledigen';
      case TaskStatus.inProgress:
        return 'In Bearbeitung';
      case TaskStatus.inReview:
        return 'In Überprüfung';
      case TaskStatus.testing:
        return 'Test';
      case TaskStatus.done:
        return 'Fertig';
    }
  }
} 