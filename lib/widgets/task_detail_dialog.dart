import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:toastification/toastification.dart';
import '../models/kanban_task.dart';
import '../models/user.dart' as app_user;
import '../services/auth_service.dart';
import '../services/kanban_service.dart';
import '../utils/app_toast.dart';
import '../utils/responsive_helper.dart';

class TaskDetailDialog extends StatefulWidget {
  final KanbanTask task;
  final app_user.User? currentUser;
  final Function(KanbanTask) onTaskUpdated;
  final Function(String) onTaskDeleted;

  const TaskDetailDialog({
    super.key,
    required this.task,
    required this.currentUser,
    required this.onTaskUpdated,
    required this.onTaskDeleted,
  });

  @override
  State<TaskDetailDialog> createState() => _TaskDetailDialogState();
}

class _TaskDetailDialogState extends State<TaskDetailDialog>
    with SingleTickerProviderStateMixin {
  final KanbanService _kanbanService = KanbanService();
  late TabController _tabController;
  late KanbanTask _currentTask;
  
  // Edit controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _estimatedHoursController = TextEditingController();
  final TextEditingController _loggedHoursController = TextEditingController();
  
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _currentTask = widget.task;
    _initializeControllers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _commentController.dispose();
    _estimatedHoursController.dispose();
    _loggedHoursController.dispose();
    super.dispose();
  }

  void _initializeControllers() {
    _titleController.text = _currentTask.title;
    _descriptionController.text = _currentTask.description;
    _estimatedHoursController.text = _currentTask.estimatedHours?.toString() ?? '';
    _loggedHoursController.text = _currentTask.loggedHours?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(MediaQuery.of(context).size.width);
    
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * (isDesktop ? 0.8 : 0.95),
        height: MediaQuery.of(context).size.height * 0.9,
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 1200 : double.infinity,
          maxHeight: 800,
        ),
        child: Column(
          children: [
            _buildHeader(isDesktop),
            Expanded(
              child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Container(
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
          // Task type icon and key
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getTypeColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _getTypeColor().withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getTypeIcon(),
                  size: 16,
                  color: _getTypeColor(),
                ),
                const SizedBox(width: 4),
                Text(
                  _currentTask.taskKey,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getTypeColor(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          
          // Title
          Expanded(
            child: _isEditing
                ? TextField(
                    controller: _titleController,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  )
                : Text(
                    _currentTask.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          
          // Action buttons
          if (_isEditing) ...[
            TextButton(
              onPressed: _cancelEditing,
              child: const Text('Abbrechen'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveChanges,
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Speichern'),
            ),
          ] else ...[
            IconButton(
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              icon: const Icon(Icons.edit),
              tooltip: 'Bearbeiten',
            ),
            IconButton(
              onPressed: _showDeleteConfirmation,
              icon: const Icon(Icons.delete),
              tooltip: 'Löschen',
            ),
          ],
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Main content
        Expanded(
          flex: 2,
          child: Column(
            children: [
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDetailsTab(),
                    _buildCommentsTab(),
                    _buildTimeTrackingTab(),
                    _buildHistoryTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Sidebar
        Container(
          width: 300,
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: Colors.grey.shade300)),
          ),
          child: _buildSidebar(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Mobile summary
        _buildMobileSummary(),
        
        // Tabs
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildDetailsTab(),
              _buildCommentsTab(),
              _buildTimeTrackingTab(),
              _buildHistoryTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Details'),
          Tab(text: 'Kommentare'),
          Tab(text: 'Zeit'),
          Tab(text: 'Verlauf'),
        ],
      ),
    );
  }

  Widget _buildMobileSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildStatusChip(),
              const SizedBox(width: 8),
              _buildPriorityChip(),
              const Spacer(),
              if (_currentTask.dueDate != null) _buildDueDateChip(),
            ],
          ),
          if (_currentTask.assigneeName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person, size: 16),
                const SizedBox(width: 4),
                Text('Zugewiesen: ${_currentTask.assigneeName}'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSidebarSection(
            'Status',
            _buildStatusDropdown(),
          ),
          const SizedBox(height: 16),
          
          _buildSidebarSection(
            'Priorität',
            _buildPriorityDropdown(),
          ),
          const SizedBox(height: 16),
          
          _buildSidebarSection(
            'Zugewiesen',
            _buildAssigneeField(),
          ),
          const SizedBox(height: 16),
          
          _buildSidebarSection(
            'Fälligkeitsdatum',
            _buildDueDatePicker(),
          ),
          const SizedBox(height: 16),
          
          _buildSidebarSection(
            'Labels',
            _buildLabelsField(),
          ),
          const SizedBox(height: 16),
          
          _buildSidebarSection(
            'Sprint',
            _buildSprintField(),
          ),
          const SizedBox(height: 16),
          
          _buildSidebarSection(
            'Aufgaben-Info',
            _buildTaskInfo(),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        content,
      ],
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Beschreibung',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          
          _isEditing
              ? TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Beschreibung der Aufgabe...',
                  ),
                  maxLines: 8,
                )
              : Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _currentTask.description.isEmpty 
                        ? 'Keine Beschreibung verfügbar'
                        : _currentTask.description,
                    style: TextStyle(
                      color: _currentTask.description.isEmpty 
                          ? Colors.grey.shade600
                          : null,
                      fontStyle: _currentTask.description.isEmpty 
                          ? FontStyle.italic
                          : null,
                    ),
                  ),
                ),
          
          const SizedBox(height: 24),
          
          // Labels
          if (_currentTask.labels.isNotEmpty) ...[
            const Text(
              'Labels',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _currentTask.labels.map((label) => Chip(
                label: Text(label),
              )).toList(),
            ),
            const SizedBox(height: 24),
          ],
          
          // Time tracking progress
          if (_currentTask.estimatedHours != null || _currentTask.loggedHours != null) ...[
            const Text(
              'Zeiterfassung',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            _buildTimeProgressBar(),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentsTab() {
    return Column(
      children: [
        // Add comment
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: const InputDecoration(
                    hintText: 'Kommentar hinzufügen...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addComment,
                child: const Text('Senden'),
              ),
            ],
          ),
        ),
        
        // Comments list
        Expanded(
          child: _currentTask.comments.isEmpty
              ? const Center(
                  child: Text(
                    'Noch keine Kommentare',
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _currentTask.comments.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final comment = _currentTask.comments[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              child: Text(
                                comment.authorName.substring(0, 1).toUpperCase(),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              comment.authorName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('dd.MM.yyyy HH:mm').format(comment.createdAt),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(comment.content),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTimeTrackingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Zeiterfassung',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: TextField(
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
                child: TextField(
                  controller: _loggedHoursController,
                  decoration: const InputDecoration(
                    labelText: 'Erfasste Stunden',
                    border: OutlineInputBorder(),
                    suffixText: 'h',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          ElevatedButton(
            onPressed: _updateTimeTracking,
            child: const Text('Zeit aktualisieren'),
          ),
          const SizedBox(height: 24),
          
          // Progress visualization
          if (_currentTask.estimatedHours != null || _currentTask.loggedHours != null)
            _buildTimeProgressBar(),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return const Center(
      child: Text(
        'Verlauf wird bald verfügbar sein',
        style: TextStyle(
          color: Colors.grey,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<TaskStatus>(
                                    initialValue: _currentTask.status,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
      ),
      items: TaskStatus.values.map((status) => DropdownMenuItem(
        value: status,
        child: Text(_getStatusDisplayName(status)),
      )).toList(),
      onChanged: (status) {
        if (status != null) {
          _updateTaskStatus(status);
        }
      },
    );
  }

  Widget _buildPriorityDropdown() {
    return DropdownButtonFormField<TaskPriority>(
                                    initialValue: _currentTask.priority,
      decoration: const InputDecoration(
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
      onChanged: (priority) {
        if (priority != null) {
          _updateTaskPriority(priority);
        }
      },
    );
  }

  Widget _buildAssigneeField() {
    return InkWell(
      onTap: _showAssigneePicker,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            if (_currentTask.assigneeName != null) ...[
              CircleAvatar(
                radius: 12,
                child: Text(
                  _currentTask.assigneeName!.substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_currentTask.assigneeName!),
              ),
            ] else ...[
              const Icon(Icons.person_add, size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Nicht zugewiesen',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDueDatePicker() {
    return InkWell(
      onTap: _pickDueDate,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _currentTask.dueDate != null
                    ? DateFormat('dd.MM.yyyy').format(_currentTask.dueDate!)
                    : 'Kein Fälligkeitsdatum',
                style: TextStyle(
                  color: _currentTask.dueDate != null ? null : Colors.grey,
                ),
              ),
            ),
            if (_currentTask.dueDate != null)
              IconButton(
                onPressed: () {
                  _kanbanService.updateTaskDueDate(_currentTask.id, null);
                  setState(() {
                    _currentTask = _currentTask.copyWith(dueDate: null);
                  });
                  widget.onTaskUpdated(_currentTask);
                },
                icon: const Icon(Icons.clear, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabelsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_currentTask.labels.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Keine Labels',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: _currentTask.labels.map((label) => Chip(
              label: Text(label, style: const TextStyle(fontSize: 12)),
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () => _removeLabel(label),
            )).toList(),
          ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _addLabel,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Label hinzufügen'),
        ),
      ],
    );
  }

  Widget _buildSprintField() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const Icon(Icons.flag, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _currentTask.sprint ?? 'Kein Sprint',
              style: TextStyle(
                color: _currentTask.sprint != null ? null : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskInfo() {
    return Column(
      children: [
        _buildInfoRow('Erstellt', DateFormat('dd.MM.yyyy').format(_currentTask.createdAt)),
        _buildInfoRow('Aktualisiert', DateFormat('dd.MM.yyyy').format(_currentTask.updatedAt)),
        _buildInfoRow('Reporter', _currentTask.reporterName),
        _buildInfoRow('Typ', _currentTask.typeDisplayName),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getStatusColor().withOpacity(0.3)),
      ),
      child: Text(
        _currentTask.statusDisplayName,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: _getStatusColor(),
        ),
      ),
    );
  }

  Widget _buildPriorityChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getPriorityColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getPriorityColor().withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPriorityIcon(_currentTask.priority),
          const SizedBox(width: 4),
          Text(
            _currentTask.priorityDisplayName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _getPriorityColor(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDueDateChip() {
    if (_currentTask.dueDate == null) return const SizedBox.shrink();
    
    final isOverdue = _currentTask.dueDate!.isBefore(DateTime.now()) && 
                      _currentTask.status != TaskStatus.done;
    final isDueToday = _currentTask.dueDate!.day == DateTime.now().day &&
                       _currentTask.dueDate!.month == DateTime.now().month &&
                       _currentTask.dueDate!.year == DateTime.now().year;
    
    Color color = Colors.grey;
    if (isOverdue) color = Colors.red;
    else if (isDueToday) color = Colors.orange;
    
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
          Icon(Icons.schedule, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            DateFormat('dd.MM').format(_currentTask.dueDate!),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeProgressBar() {
    final estimated = _currentTask.estimatedHours ?? 0;
    final logged = _currentTask.loggedHours ?? 0;
    final progress = estimated > 0 ? (logged / estimated).clamp(0.0, 1.0) : 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${logged}h erfasst'),
            Text('${estimated}h geschätzt'),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.shade300,
          valueColor: AlwaysStoppedAnimation<Color>(
            progress > 1.0 ? Colors.red : Colors.blue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(progress * 100).toInt()}% abgeschlossen',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityIcon(TaskPriority priority) {
    Color color = _getPriorityColor();
    IconData icon;

    switch (priority) {
      case TaskPriority.highest:
        icon = Icons.keyboard_double_arrow_up;
        break;
      case TaskPriority.high:
        icon = Icons.keyboard_arrow_up;
        break;
      case TaskPriority.medium:
        icon = Icons.drag_handle;
        break;
      case TaskPriority.low:
        icon = Icons.keyboard_arrow_down;
        break;
      case TaskPriority.lowest:
        icon = Icons.keyboard_double_arrow_down;
        break;
    }

    return Icon(icon, size: 12, color: color);
  }

  Color _getTypeColor() {
    switch (_currentTask.type) {
      case TaskType.bug:
        return Colors.red;
      case TaskType.story:
        return Colors.green;
      case TaskType.epic:
        return Colors.purple;
      case TaskType.subtask:
        return Colors.blue;
      case TaskType.task:
        return Colors.blue.shade700;
    }
  }

  IconData _getTypeIcon() {
    switch (_currentTask.type) {
      case TaskType.bug:
        return Icons.bug_report;
      case TaskType.story:
        return Icons.book;
      case TaskType.epic:
        return Icons.stars;
      case TaskType.subtask:
        return Icons.subdirectory_arrow_right;
      case TaskType.task:
        return Icons.task_alt;
    }
  }

  Color _getStatusColor() {
    switch (_currentTask.status) {
      case TaskStatus.backlog:
        return Colors.grey;
      case TaskStatus.todo:
        return Colors.blue;
      case TaskStatus.inProgress:
        return Colors.orange;
      case TaskStatus.inReview:
        return Colors.purple;
      case TaskStatus.testing:
        return Colors.teal;
      case TaskStatus.done:
        return Colors.green;
    }
  }

  Color _getPriorityColor() {
    switch (_currentTask.priority) {
      case TaskPriority.highest:
        return Colors.red;
      case TaskPriority.high:
        return Colors.red.shade300;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.low:
        return Colors.green.shade300;
      case TaskPriority.lowest:
        return Colors.green;
    }
  }

  void _showSuccessToast(String message) {
    AppToast.success(context, message);
  }

  void _showErrorToast(String message) {
    AppToast.error(context, message);
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final updatedTask = _currentTask.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
      );

      final success = await _kanbanService.updateTask(updatedTask);
      
      if (success) {
        setState(() {
          _currentTask = updatedTask;
          _isEditing = false;
        });
        widget.onTaskUpdated(_currentTask);
        _showSuccessToast('Aufgabe gespeichert');
      } else {
        _showErrorToast('Fehler beim Speichern');
      }
    } catch (e) {
      _showErrorToast('Fehler: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
    });
    _initializeControllers();
  }

  Future<void> _updateTaskStatus(TaskStatus status) async {
    try {
      final success = await _kanbanService.moveTask(_currentTask.id, status, 0);
      if (success) {
        setState(() {
          _currentTask = _currentTask.copyWith(status: status);
        });
        widget.onTaskUpdated(_currentTask);
        _showSuccessToast('Status aktualisiert');
      }
    } catch (e) {
      _showErrorToast('Fehler beim Aktualisieren des Status: $e');
    }
  }

  Future<void> _updateTaskPriority(TaskPriority priority) async {
    try {
      final success = await _kanbanService.updateTaskPriority(_currentTask.id, priority);
      if (success) {
        setState(() {
          _currentTask = _currentTask.copyWith(priority: priority);
        });
        widget.onTaskUpdated(_currentTask);
        _showSuccessToast('Priorität aktualisiert');
      }
    } catch (e) {
      _showErrorToast('Fehler beim Aktualisieren der Priorität: $e');
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _currentTask.dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      try {
        final success = await _kanbanService.updateTaskDueDate(_currentTask.id, picked);
        if (success) {
          setState(() {
            _currentTask = _currentTask.copyWith(dueDate: picked);
          });
          widget.onTaskUpdated(_currentTask);
          _showSuccessToast('Fälligkeitsdatum aktualisiert');
        }
      } catch (e) {
        _showErrorToast('Fehler beim Aktualisieren des Fälligkeitsdatums: $e');
      }
    }
  }

  Future<void> _addComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || widget.currentUser == null) return;

    try {
      final comment = TaskComment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        authorId: widget.currentUser!.id,
        authorName: widget.currentUser!.fullName,
        content: content,
        createdAt: DateTime.now(),
      );

      final success = await _kanbanService.addComment(_currentTask.id, comment);
      if (success) {
        setState(() {
          _currentTask = _currentTask.copyWith(
            comments: [..._currentTask.comments, comment],
          );
          _commentController.clear();
        });
        widget.onTaskUpdated(_currentTask);
        _showSuccessToast('Kommentar hinzugefügt');
      }
    } catch (e) {
      _showErrorToast('Fehler beim Hinzufügen des Kommentars: $e');
    }
  }

  Future<void> _updateTimeTracking() async {
    try {
      final estimated = int.tryParse(_estimatedHoursController.text);
      final logged = int.tryParse(_loggedHoursController.text);

      final success = await _kanbanService.updateTaskTimeTracking(
        _currentTask.id,
        estimated,
        logged,
      );

      if (success) {
        setState(() {
          _currentTask = _currentTask.copyWith(
            estimatedHours: estimated,
            loggedHours: logged,
          );
        });
        widget.onTaskUpdated(_currentTask);
        _showSuccessToast('Zeiterfassung aktualisiert');
      }
    } catch (e) {
      _showErrorToast('Fehler beim Aktualisieren der Zeiterfassung: $e');
    }
  }

  void _addLabel() {
    final controller = TextEditingController();
    showDialog<_AddLabelResult>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Label hinzufügen'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'z.B. Bug, Feature, UX',
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(_AddLabelResult.submit),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(_AddLabelResult.submit),
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    ).then((result) async {
      if (result != _AddLabelResult.submit) return;
      final raw = controller.text.trim();
      if (raw.isEmpty) return;
      final existing = _currentTask.labels;
      if (existing.any((l) => l.toLowerCase() == raw.toLowerCase())) {
        _showErrorToast('Label "$raw" existiert bereits');
        return;
      }
      final updated = [...existing, raw];
      final ok = await _kanbanService.updateTaskLabels(_currentTask.id, updated);
      if (!mounted) return;
      if (ok) {
        setState(() {
          _currentTask = _currentTask.copyWith(labels: updated);
        });
        widget.onTaskUpdated(_currentTask);
      } else {
        _showErrorToast('Label konnte nicht gespeichert werden');
      }
    });
  }

  Future<void> _showAssigneePicker() async {
    final auth = AuthService();
    List<app_user.User> users;
    try {
      users = await auth.getAllUsers();
    } catch (e) {
      if (!mounted) return;
      _showErrorToast('Nutzer konnten nicht geladen werden: $e');
      return;
    }
    final active = users.where((u) => u.isActive).toList()
      ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
    if (!mounted) return;
    final picked = await showDialog<_AssigneePick>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zuweisen'),
        content: SizedBox(
          width: 360,
          height: 420,
          child: Column(
            children: [
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_off, size: 16)),
                title: const Text('Zuweisung entfernen'),
                onTap: () => Navigator.of(ctx).pop(const _AssigneePick.unassign()),
              ),
              const Divider(height: 1),
              Expanded(
                child: active.isEmpty
                    ? const Center(child: Text('Keine aktiven Nutzer'))
                    : ListView.builder(
                        itemCount: active.length,
                        itemBuilder: (_, i) {
                          final u = active[i];
                          final initials = (u.firstName.isNotEmpty ? u.firstName[0] : '') +
                              (u.lastName.isNotEmpty ? u.lastName[0] : '');
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                initials.toUpperCase(),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            title: Text(u.fullName),
                            subtitle: Text(u.email),
                            onTap: () => Navigator.of(ctx).pop(_AssigneePick.user(u)),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
    if (picked == null) return;
    final ok = await _kanbanService.assignTask(
      _currentTask.id,
      picked.user?.id,
      picked.user?.fullName,
      picked.user?.email,
    );
    if (!mounted) return;
    if (ok) {
      setState(() {
        if (picked.user != null) {
          _currentTask = _currentTask.copyWith(
            assigneeId: picked.user!.id,
            assigneeName: picked.user!.fullName,
            assigneeEmail: picked.user!.email,
          );
        } else {
          // Rebuild without assignee — copyWith can't null-out fields.
          _currentTask = KanbanTask(
            id: _currentTask.id,
            title: _currentTask.title,
            description: _currentTask.description,
            type: _currentTask.type,
            status: _currentTask.status,
            priority: _currentTask.priority,
            assigneeId: null,
            assigneeName: null,
            assigneeEmail: null,
            reporterId: _currentTask.reporterId,
            reporterName: _currentTask.reporterName,
            reporterEmail: _currentTask.reporterEmail,
            labels: _currentTask.labels,
            epicId: _currentTask.epicId,
            parentTaskId: _currentTask.parentTaskId,
            subtaskIds: _currentTask.subtaskIds,
            createdAt: _currentTask.createdAt,
            updatedAt: DateTime.now(),
            dueDate: _currentTask.dueDate,
            estimatedHours: _currentTask.estimatedHours,
            loggedHours: _currentTask.loggedHours,
            sprint: _currentTask.sprint,
            attachments: _currentTask.attachments,
            comments: _currentTask.comments,
            boardId: _currentTask.boardId,
            position: _currentTask.position,
          );
        }
      });
      widget.onTaskUpdated(_currentTask);
    } else {
      _showErrorToast('Zuweisung konnte nicht gespeichert werden');
    }
  }

  void _removeLabel(String label) {
    final updatedLabels = _currentTask.labels.where((l) => l != label).toList();
    _kanbanService.updateTaskLabels(_currentTask.id, updatedLabels);
    setState(() {
      _currentTask = _currentTask.copyWith(labels: updatedLabels);
    });
    widget.onTaskUpdated(_currentTask);
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aufgabe löschen'),
        content: Text('Sind Sie sicher, dass Sie "${_currentTask.title}" löschen möchten?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: _deleteTask,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTask() async {
    try {
      final success = await _kanbanService.deleteTask(_currentTask.id);
      if (success) {
        widget.onTaskDeleted(_currentTask.id);
        Navigator.of(context).pop(); // Close confirmation dialog
        Navigator.of(context).pop(); // Close task detail dialog
        _showSuccessToast('Aufgabe gelöscht');
      }
    } catch (e) {
      _showErrorToast('Fehler beim Löschen: $e');
    }
  }

  String _getStatusDisplayName(TaskStatus status) {
    return status.toString().split('.').last;
  }

  String _getPriorityDisplayName(TaskPriority priority) {
    return priority.toString().split('.').last;
  }
} 

enum _AddLabelResult { submit }

class _AssigneePick {
  final app_user.User? user;
  const _AssigneePick.user(app_user.User u) : user = u;
  const _AssigneePick.unassign() : user = null;
}
