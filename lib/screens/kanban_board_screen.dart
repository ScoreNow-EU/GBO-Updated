import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import 'package:intl/intl.dart';
import '../models/kanban_board.dart';
import '../models/kanban_task.dart';
import '../models/user.dart' as app_user;
import '../services/kanban_service.dart';
import '../services/auth_service.dart';
import '../utils/responsive_helper.dart';
import '../widgets/kanban_task_card.dart';
import '../widgets/task_detail_dialog.dart';
import '../widgets/create_task_dialog.dart';

class KanbanBoardScreen extends StatefulWidget {
  const KanbanBoardScreen({super.key});

  @override
  State<KanbanBoardScreen> createState() => _KanbanBoardScreenState();
}

class _KanbanBoardScreenState extends State<KanbanBoardScreen> {
  final KanbanService _kanbanService = KanbanService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  
  KanbanBoard? _currentBoard;
  app_user.User? _currentUser;
  List<KanbanTask> _allTasks = [];
  List<KanbanTask> _filteredTasks = [];
  Map<String, int> _statistics = {};
  
  // Filters
  String? _selectedAssigneeFilter;
  TaskType? _selectedTypeFilter;
  TaskPriority? _selectedPriorityFilter;
  String? _selectedSprintFilter;
  
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get current user
      final firebaseUser = _authService.currentFirebaseUser;
      if (firebaseUser != null) {
        _currentUser = await _authService.getUserById(firebaseUser.uid);
      }
      
      if (_currentUser == null) {
        setState(() {
          _error = 'Benutzer nicht authentifiziert';
          _isLoading = false;
        });
        return;
      }

      // Get the default board
      _currentBoard = await _kanbanService.getDefaultBoard();

      // Load tasks and statistics
      await _loadTasks();
      await _loadStatistics();
    } catch (e) {
      setState(() {
        _error = 'Fehler beim Laden der Daten: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTasks() async {
    try {
      _allTasks = await _kanbanService.getAllTasksOnce();
      _applyFilters();
    } catch (e) {
      print('Error loading tasks: $e');
    }
  }

  Future<void> _loadStatistics() async {
    try {
      _statistics = await _kanbanService.getStatistics();
      setState(() {});
    } catch (e) {
      print('Error loading statistics: $e');
    }
  }

  void _applyFilters() {
    _filteredTasks = _allTasks.where((task) {
      // Search filter
      if (_searchController.text.isNotEmpty) {
        final query = _searchController.text.toLowerCase();
        if (!task.title.toLowerCase().contains(query) &&
            !task.description.toLowerCase().contains(query) &&
            !task.taskKey.toLowerCase().contains(query) &&
            !(task.assigneeName?.toLowerCase().contains(query) ?? false)) {
          return false;
        }
      }
      
      // Assignee filter
      if (_selectedAssigneeFilter != null && task.assigneeId != _selectedAssigneeFilter) {
        return false;
      }
      
      // Type filter
      if (_selectedTypeFilter != null && task.type != _selectedTypeFilter) {
        return false;
      }
      
      // Priority filter
      if (_selectedPriorityFilter != null && task.priority != _selectedPriorityFilter) {
        return false;
      }
      
      // Sprint filter
      if (_selectedSprintFilter != null && task.sprint != _selectedSprintFilter) {
        return false;
      }
      
      return true;
    }).toList();
    
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeData,
                child: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      );
    }

    final isDesktop = ResponsiveHelper.isDesktop(MediaQuery.of(context).size.width);
    
    return Scaffold(
      appBar: _buildAppBar(isDesktop),
      body: Column(
        children: [
          // Toolbar with filters and search
          if (isDesktop) _buildDesktopToolbar() else _buildMobileToolbar(),
          
          // Statistics chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _buildStatisticsChips(),
              ),
            ),
          ),
          
          // Kanban board
          Expanded(
            child: _buildKanbanBoard(isDesktop),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateTaskDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDesktop) {
    return AppBar(
      title: Row(
        children: [
          Icon(
            Icons.dashboard,
            color: Colors.blue.shade700,
          ),
          const SizedBox(width: 8),
          Text(_currentBoard?.name ?? 'Kanban Board'),
        ],
      ),
      actions: [
        if (isDesktop) ...[
          IconButton(
            onPressed: _loadTasks,
            icon: const Icon(Icons.refresh),
            tooltip: 'Aktualisieren',
          ),
          IconButton(
            onPressed: _exportBoard,
            icon: const Icon(Icons.download),
            tooltip: 'Exportieren',
          ),
        ] else ...[
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'refresh':
                  _loadTasks();
                  break;
                case 'export':
                  _exportBoard();
                  break;
                case 'filters':
                  _showFiltersDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('Aktualisieren'),
                ),
              ),
              const PopupMenuItem(
                value: 'filters',
                child: ListTile(
                  leading: Icon(Icons.filter_list),
                  title: Text('Filter'),
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Exportieren'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDesktopToolbar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          // Search
          Expanded(
            flex: 2,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Aufgaben durchsuchen...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (_) => _applyFilters(),
            ),
          ),
          const SizedBox(width: 16),
          
          // Filters
          _buildFilterDropdown(
            'Zugewiesen',
            _selectedAssigneeFilter,
            _allTasks.map((t) => t.assigneeName).where((name) => name != null).cast<String>().toSet().toList(),
            (value) {
              setState(() {
                _selectedAssigneeFilter = value;
              });
              _applyFilters();
            },
          ),
          const SizedBox(width: 8),
          
          _buildFilterDropdown(
            'Typ',
            _getTypeDisplayName(_selectedTypeFilter),
            TaskType.values.map(_getTypeDisplayName).where((name) => name != null).cast<String>().toList(),
            (value) {
              setState(() {
                _selectedTypeFilter = value != null 
                    ? TaskType.values.firstWhere((t) => _getTypeDisplayName(t) == value)
                    : null;
              });
              _applyFilters();
            },
          ),
          const SizedBox(width: 8),
          
          _buildFilterDropdown(
            'Priorität',
            _getPriorityDisplayName(_selectedPriorityFilter),
            TaskPriority.values.map(_getPriorityDisplayName).where((name) => name != null).cast<String>().toList(),
            (value) {
              setState(() {
                _selectedPriorityFilter = value != null 
                    ? TaskPriority.values.firstWhere((p) => _getPriorityDisplayName(p) == value)
                    : null;
              });
              _applyFilters();
            },
          ),
          const SizedBox(width: 16),
          
          // Clear filters
          TextButton.icon(
            onPressed: () {
              setState(() {
                _selectedAssigneeFilter = null;
                _selectedTypeFilter = null;
                _selectedPriorityFilter = null;
                _selectedSprintFilter = null;
                _searchController.clear();
              });
              _applyFilters();
            },
            icon: const Icon(Icons.clear_all),
            label: const Text('Filter zurücksetzen'),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileToolbar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Aufgaben durchsuchen...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            onPressed: _showFiltersDialog,
            icon: const Icon(Icons.filter_list),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onChanged: (_) => _applyFilters(),
      ),
    );
  }

  Widget _buildFilterDropdown(String label, String? value, List<String> items, Function(String?) onChanged) {
    return SizedBox(
      width: 140,
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text('Alle', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ...items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(item),
          )),
        ],
        onChanged: onChanged,
      ),
    );
  }

  List<Widget> _buildStatisticsChips() {
    final chips = <Widget>[];
    
    chips.add(_buildStatChip('Gesamt', '${_statistics['total'] ?? 0}', Colors.blue));
    chips.add(_buildStatChip('In Bearbeitung', '${_statistics['in_progress'] ?? 0}', Colors.orange));
    chips.add(_buildStatChip('Fertig', '${_statistics['completed'] ?? 0}', Colors.green));
    chips.add(_buildStatChip('Überfällig', '${_statistics['overdue'] ?? 0}', Colors.red));
    
    return chips;
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKanbanBoard(bool isDesktop) {
    final columns = [
      {'status': TaskStatus.backlog, 'title': 'Backlog', 'color': Colors.grey},
      {'status': TaskStatus.todo, 'title': 'Zu erledigen', 'color': Colors.blue},
      {'status': TaskStatus.inProgress, 'title': 'In Bearbeitung', 'color': Colors.orange},
      {'status': TaskStatus.inReview, 'title': 'In Überprüfung', 'color': Colors.purple},
      {'status': TaskStatus.testing, 'title': 'Test', 'color': Colors.teal},
      {'status': TaskStatus.done, 'title': 'Fertig', 'color': Colors.green},
    ];

    if (isDesktop) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: columns.map((column) => 
            _buildKanbanColumn(
              column['status'] as TaskStatus,
              column['title'] as String,
              column['color'] as Color,
            )
          ).toList(),
        ),
      );
    } else {
      return PageView(
        children: columns.map((column) => 
          _buildKanbanColumn(
            column['status'] as TaskStatus,
            column['title'] as String,
            column['color'] as Color,
          )
        ).toList(),
      );
    }
  }

  Widget _buildKanbanColumn(TaskStatus status, String title, Color color) {
    final columnTasks = _filteredTasks.where((task) => task.status == status).toList();
    final isDesktop = ResponsiveHelper.isDesktop(MediaQuery.of(context).size.width);
    
    return Container(
      width: isDesktop ? 300 : double.infinity,
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:                     Text(
                      columnTasks.length.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _showCreateTaskDialog(initialStatus: status),
                  icon: const Icon(Icons.add, size: 16),
                  tooltip: 'Aufgabe hinzufügen',
                ),
              ],
            ),
          ),
          
          // Column content
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                border: Border(
                  left: BorderSide(color: color.withOpacity(0.3)),
                  right: BorderSide(color: color.withOpacity(0.3)),
                  bottom: BorderSide(color: color.withOpacity(0.3)),
                ),
              ),
              child: columnTasks.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Keine Aufgaben',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: columnTasks.length,
                      itemBuilder: (context, index) {
                        final task = columnTasks[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: KanbanTaskCard(
                            task: task,
                            onTap: () => _showTaskDetail(task),
                            onStatusChanged: (newStatus) => _moveTask(task, newStatus),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTaskDetail(KanbanTask task) {
    showDialog(
      context: context,
      builder: (context) => TaskDetailDialog(
        task: task,
        currentUser: _currentUser,
        onTaskUpdated: (updatedTask) {
          _loadTasks();
          _loadStatistics();
        },
        onTaskDeleted: (taskId) {
          _loadTasks();
          _loadStatistics();
        },
      ),
    );
  }

  void _showCreateTaskDialog({TaskStatus? initialStatus}) {
    if (_currentUser == null) return;
    
    showDialog(
      context: context,
      builder: (context) => CreateTaskDialog(
        currentUser: _currentUser!,
        initialStatus: initialStatus,
        onTaskCreated: (task) {
          _loadTasks();
          _loadStatistics();
        },
      ),
    );
  }





  void _showFiltersDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedAssigneeFilter,
              decoration: const InputDecoration(labelText: 'Zugewiesen'),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('Alle')),
                ..._allTasks.map((t) => t.assigneeName).where((name) => name != null).cast<String>().toSet().map(
                  (name) => DropdownMenuItem(value: name, child: Text(name)),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedAssigneeFilter = value;
                });
              },
            ),
            // Add more filter dropdowns as needed
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedAssigneeFilter = null;
                _selectedTypeFilter = null;
                _selectedPriorityFilter = null;
                _selectedSprintFilter = null;
              });
              _applyFilters();
              Navigator.of(context).pop();
            },
            child: const Text('Zurücksetzen'),
          ),
          ElevatedButton(
            onPressed: () {
              _applyFilters();
              Navigator.of(context).pop();
            },
            child: const Text('Anwenden'),
          ),
        ],
      ),
    );
  }

  Future<void> _moveTask(KanbanTask task, TaskStatus newStatus) async {
    try {
      final success = await _kanbanService.moveTask(task.id, newStatus, 0);
      if (success) {
        _loadTasks();
        _loadStatistics();
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          title: Text('Aufgabe nach "${_getStatusDisplayName(newStatus)}" verschoben'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        title: Text('Fehler beim Verschieben: $e'),
        alignment: Alignment.topRight,
        autoCloseDuration: const Duration(seconds: 3),
      );
    }
  }

  void _exportBoard() {
    // TODO: Implement board export functionality
    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.fillColored,
      title: const Text('Export-Funktion wird bald verfügbar sein'),
      alignment: Alignment.topRight,
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  String? _getTypeDisplayName(TaskType? type) {
    if (type == null) return null;
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

  String? _getPriorityDisplayName(TaskPriority? priority) {
    if (priority == null) return null;
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