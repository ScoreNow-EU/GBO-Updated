import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Local-only Kanban board. Data is stored in planning/kanban_board.json
/// via a local Dart server (planning/kanban_server.dart).
/// Run:  dart run planning/kanban_server.dart

// ──────────────────────────────────────────────
//  Data model
// ──────────────────────────────────────────────

class KanbanTask {
  String id;
  String title;
  String description;
  String priority; // low, medium, high
  DateTime createdAt;

  KanbanTask({
    required this.id,
    required this.title,
    this.description = '',
    this.priority = 'medium',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'priority': priority,
        'createdAt': createdAt.toIso8601String(),
      };

  factory KanbanTask.fromJson(Map<String, dynamic> j) => KanbanTask(
        id: j['id'] as String,
        title: j['title'] as String,
        description: (j['description'] as String?) ?? '',
        priority: (j['priority'] as String?) ?? 'medium',
        createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
      );
}

class KanbanColumn {
  String id;
  String title;
  List<KanbanTask> tasks;

  KanbanColumn({required this.id, required this.title, List<KanbanTask>? tasks})
      : tasks = tasks ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'tasks': tasks.map((t) => t.toJson()).toList(),
      };

  factory KanbanColumn.fromJson(Map<String, dynamic> j) => KanbanColumn(
        id: j['id'] as String,
        title: j['title'] as String,
        tasks: (j['tasks'] as List<dynamic>?)
                ?.map((t) => KanbanTask.fromJson(t as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

// ──────────────────────────────────────────────
//  Screen
// ──────────────────────────────────────────────

class KanbanBoardScreen extends StatefulWidget {
  const KanbanBoardScreen({super.key});

  @override
  State<KanbanBoardScreen> createState() => _KanbanBoardScreenState();
}

class _KanbanBoardScreenState extends State<KanbanBoardScreen> {
  static const _serverUrl = 'http://localhost:8099/kanban';

  List<KanbanColumn> _columns = [];
  bool _isLoading = true;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    _loadBoard();
  }

  // ── Persistence ──────────────────────────────

  Future<void> _loadBoard() async {
    try {
      final response = await http.get(Uri.parse(_serverUrl));
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        _columns = list
            .map((c) => KanbanColumn.fromJson(c as Map<String, dynamic>))
            .toList();
        if (_columns.isEmpty) {
          _columns = _defaultColumns();
          await _saveBoard();
        }
        _serverError = null;
      } else {
        _columns = _defaultColumns();
        _serverError = 'Server returned ${response.statusCode}';
      }
    } catch (e) {
      _columns = _defaultColumns();
      _serverError = 'Server nicht erreichbar.\nStarte: dart run planning/kanban_server.dart';
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveBoard() async {
    final json = jsonEncode(_columns.map((c) => c.toJson()).toList());
    try {
      await http.put(
        Uri.parse(_serverUrl),
        headers: {'Content-Type': 'application/json'},
        body: json,
      );
      if (_serverError != null) {
        setState(() => _serverError = null);
      }
    } catch (e) {
      setState(() {
        _serverError = 'Speichern fehlgeschlagen – Server nicht erreichbar';
      });
    }
  }

  List<KanbanColumn> _defaultColumns() => [
        KanbanColumn(id: 'backlog', title: 'Backlog'),
        KanbanColumn(id: 'todo', title: 'To Do'),
        KanbanColumn(id: 'in_progress', title: 'In Arbeit'),
        KanbanColumn(id: 'done', title: 'Erledigt'),
      ];

  // ── Export / Import ──────────────────────────

  void _exportJson() {
    final json = const JsonEncoder.withIndent('  ')
        .convert(_columns.map((c) => c.toJson()).toList());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Board exportieren'),
        content: SizedBox(
          width: 500,
          child: SelectableText(
            json,
            style: const TextStyle(
                fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  void _importJson() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Board importieren'),
        content: SizedBox(
          width: 500,
          height: 300,
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            decoration: const InputDecoration(
              hintText: 'JSON hier einfügen...',
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              try {
                final list = jsonDecode(controller.text) as List<dynamic>;
                setState(() {
                  _columns = list
                      .map((c) =>
                          KanbanColumn.fromJson(c as Map<String, dynamic>))
                      .toList();
                });
                _saveBoard();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Board importiert'),
                      backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Ungültiges JSON: $e'),
                      backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Importieren'),
          ),
        ],
      ),
    );
  }

  // ── Task CRUD ────────────────────────────────

  void _addTask(KanbanColumn column) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String priority = 'medium';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Neue Aufgabe'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  decoration:
                      const InputDecoration(labelText: 'Titel', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Beschreibung', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Priorität: '),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Niedrig'),
                      selected: priority == 'low',
                      selectedColor: Colors.green.shade100,
                      onSelected: (_) =>
                          setDialogState(() => priority = 'low'),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('Mittel'),
                      selected: priority == 'medium',
                      selectedColor: Colors.orange.shade100,
                      onSelected: (_) =>
                          setDialogState(() => priority = 'medium'),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('Hoch'),
                      selected: priority == 'high',
                      selectedColor: Colors.red.shade100,
                      onSelected: (_) =>
                          setDialogState(() => priority = 'high'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Abbrechen')),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                setState(() {
                  column.tasks.add(KanbanTask(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: titleCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    priority: priority,
                  ));
                });
                _saveBoard();
                Navigator.pop(ctx);
              },
              child: const Text('Erstellen'),
            ),
          ],
        ),
      ),
    );
  }

  void _editTask(KanbanColumn column, KanbanTask task) {
    final titleCtrl = TextEditingController(text: task.title);
    final descCtrl = TextEditingController(text: task.description);
    String priority = task.priority;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Aufgabe bearbeiten'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Titel', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Beschreibung', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Priorität: '),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Niedrig'),
                      selected: priority == 'low',
                      selectedColor: Colors.green.shade100,
                      onSelected: (_) =>
                          setDialogState(() => priority = 'low'),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('Mittel'),
                      selected: priority == 'medium',
                      selectedColor: Colors.orange.shade100,
                      onSelected: (_) =>
                          setDialogState(() => priority = 'medium'),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('Hoch'),
                      selected: priority == 'high',
                      selectedColor: Colors.red.shade100,
                      onSelected: (_) =>
                          setDialogState(() => priority = 'high'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  column.tasks.remove(task);
                });
                _saveBoard();
                Navigator.pop(ctx);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Löschen'),
            ),
            const Spacer(),
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Abbrechen')),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  task.title = titleCtrl.text.trim();
                  task.description = descCtrl.text.trim();
                  task.priority = priority;
                });
                _saveBoard();
                Navigator.pop(ctx);
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  void _moveTask(KanbanTask task, KanbanColumn from, KanbanColumn to) {
    setState(() {
      from.tasks.remove(task);
      to.tasks.add(task);
    });
    _saveBoard();
  }

  // ── Add / rename / delete column ─────────────

  void _addColumn() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Neue Spalte'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: 'Spaltenname', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              setState(() {
                _columns.add(KanbanColumn(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: ctrl.text.trim(),
                ));
              });
              _saveBoard();
              Navigator.pop(ctx);
            },
            child: const Text('Erstellen'),
          ),
        ],
      ),
    );
  }

  void _renameColumn(KanbanColumn column) {
    final ctrl = TextEditingController(text: column.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Spalte umbenennen'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () {
              setState(() => column.title = ctrl.text.trim());
              _saveBoard();
              Navigator.pop(ctx);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  void _deleteColumn(KanbanColumn column) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Spalte löschen?'),
        content: Text(
            '\"${column.title}\" und ${column.tasks.length} Aufgabe(n) werden gelöscht.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() => _columns.remove(column));
              _saveBoard();
              Navigator.pop(ctx);
            },
            child:
                const Text('Löschen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _resetBoard() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Board zurücksetzen?'),
        content: const Text(
            'Alle Spalten und Aufgaben werden gelöscht und das Board wird auf den Standardzustand zurückgesetzt.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() => _columns = _defaultColumns());
              _saveBoard();
              Navigator.pop(ctx);
            },
            child: const Text('Zurücksetzen',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Server error banner
        if (_serverError != null)
          MaterialBanner(
            backgroundColor: Colors.orange.shade50,
            leading: const Icon(Icons.warning_amber, color: Colors.orange),
            content: Text(_serverError!,
                style: const TextStyle(fontSize: 13)),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _loadBoard();
                },
                child: const Text('Retry'),
              ),
              TextButton(
                onPressed: () => setState(() => _serverError = null),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        // Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              const Icon(Icons.view_kanban, color: Colors.deepPurple),
              const SizedBox(width: 8),
              const Text(
                'Kanban Board',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              _toolbarButton(Icons.add, 'Spalte', _addColumn),
              const SizedBox(width: 8),
              _toolbarButton(Icons.file_upload_outlined, 'Export', _exportJson),
              const SizedBox(width: 8),
              _toolbarButton(
                  Icons.file_download_outlined, 'Import', _importJson),
              const SizedBox(width: 8),
              _toolbarButton(
                  Icons.restart_alt, 'Reset', _resetBoard),
            ],
          ),
        ),
        // Board
        Expanded(
          child: _columns.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.view_kanban_outlined,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text('Keine Spalten vorhanden'),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _addColumn,
                        icon: const Icon(Icons.add),
                        label: const Text('Spalte hinzufügen'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(16),
                  itemCount: _columns.length,
                  itemBuilder: (ctx, i) => _buildColumn(_columns[i]),
                ),
        ),
      ],
    );
  }

  Widget _toolbarButton(IconData icon, String label, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: TextButton.styleFrom(
        foregroundColor: Colors.grey.shade700,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }

  // ── Column widget ────────────────────────────

  Widget _buildColumn(KanbanColumn column) {
    final colIdx = _columns.indexOf(column);

    return DragTarget<_DragData>(
      onWillAcceptWithDetails: (details) => details.data.fromColumn != column,
      onAcceptWithDetails: (details) {
        _moveTask(details.data.task, details.data.fromColumn, column);
      },
      builder: (ctx, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Container(
          width: 300,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: isHovering
                ? Colors.deepPurple.shade50
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
            border: isHovering
                ? Border.all(color: Colors.deepPurple.shade200, width: 2)
                : null,
          ),
          child: Column(
            children: [
              // Column header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        column.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${column.tasks.length}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert,
                          size: 18, color: Colors.grey.shade600),
                      onSelected: (value) {
                        switch (value) {
                          case 'rename':
                            _renameColumn(column);
                            break;
                          case 'add':
                            _addTask(column);
                            break;
                          case 'move_left':
                            if (colIdx > 0) {
                              setState(() {
                                _columns.removeAt(colIdx);
                                _columns.insert(colIdx - 1, column);
                              });
                              _saveBoard();
                            }
                            break;
                          case 'move_right':
                            if (colIdx < _columns.length - 1) {
                              setState(() {
                                _columns.removeAt(colIdx);
                                _columns.insert(colIdx + 1, column);
                              });
                              _saveBoard();
                            }
                            break;
                          case 'delete':
                            _deleteColumn(column);
                            break;
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: 'add', child: Text('Aufgabe hinzufügen')),
                        const PopupMenuItem(
                            value: 'rename', child: Text('Umbenennen')),
                        if (colIdx > 0)
                          const PopupMenuItem(
                              value: 'move_left',
                              child: Text('Nach links')),
                        if (colIdx < _columns.length - 1)
                          const PopupMenuItem(
                              value: 'move_right',
                              child: Text('Nach rechts')),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                            value: 'delete',
                            child: Text('Löschen',
                                style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  ],
                ),
              ),
              // Tasks list
              Expanded(
                child: column.tasks.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Keine Aufgaben',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 13),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: column.tasks.length,
                        itemBuilder: (ctx, i) =>
                            _buildTaskCard(column, column.tasks[i]),
                      ),
              ),
              // Add task button
              Padding(
                padding: const EdgeInsets.all(8),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _addTask(column),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Aufgabe', style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Task card ────────────────────────────────

  Widget _buildTaskCard(KanbanColumn column, KanbanTask task) {
    final priorityColor = switch (task.priority) {
      'high' => Colors.red,
      'low' => Colors.green,
      _ => Colors.orange,
    };

    // Build move-to menu items
    final otherColumns =
        _columns.where((c) => c != column).toList();

    return Draggable<_DragData>(
      data: _DragData(task: task, fromColumn: column),
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 270,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: priorityColor.withOpacity(0.5)),
          ),
          child: Text(task.title,
              style:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _taskCardContent(column, task, priorityColor, otherColumns),
      ),
      child: _taskCardContent(column, task, priorityColor, otherColumns),
    );
  }

  Widget _taskCardContent(KanbanColumn column, KanbanTask task,
      Color priorityColor, List<KanbanColumn> otherColumns) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: priorityColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _editTask(column, task),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: priorityColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                  ),
                  if (otherColumns.isNotEmpty)
                    PopupMenuButton<KanbanColumn>(
                      icon: Icon(Icons.arrow_forward,
                          size: 16, color: Colors.grey.shade500),
                      tooltip: 'Verschieben',
                      onSelected: (target) =>
                          _moveTask(task, column, target),
                      itemBuilder: (_) => otherColumns
                          .map((c) => PopupMenuItem(
                              value: c, child: Text(c.title)))
                          .toList(),
                    ),
                ],
              ),
              if (task.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  task.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DragData {
  final KanbanTask task;
  final KanbanColumn fromColumn;
  _DragData({required this.task, required this.fromColumn});
}
