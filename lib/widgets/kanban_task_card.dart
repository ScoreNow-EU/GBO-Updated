import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/kanban_task.dart';

class KanbanTaskCard extends StatelessWidget {
  final KanbanTask task;
  final VoidCallback onTap;
  final Function(TaskStatus) onStatusChanged;

  const KanbanTaskCard({
    super.key,
    required this.task,
    required this.onTap,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with task key and type
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getTypeColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: _getTypeColor().withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getTypeIcon(),
                        size: 12,
                        color: _getTypeColor(),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        task.taskKey,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getTypeColor(),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _buildPriorityIcon(),
              ],
            ),
            const SizedBox(height: 8),

            // Title
            Text(
              task.title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Description (if not empty)
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                task.description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Labels
            if (task.labels.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: task.labels.take(3).map((label) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )).toList(),
              ),
            ],

            const SizedBox(height: 8),

            // Footer with assignee, due date, and progress
            Row(
              children: [
                // Assignee avatar
                if (task.assigneeName != null) ...[
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Center(
                      child: Text(
                        task.assigneeName!.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Due date
                if (task.dueDate != null) ...[
                  Icon(
                    Icons.schedule,
                    size: 12,
                    color: _isDueToday() 
                        ? Colors.orange 
                        : _isOverdue() 
                            ? Colors.red 
                            : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    DateFormat('dd.MM').format(task.dueDate!),
                    style: TextStyle(
                      fontSize: 10,
                      color: _isDueToday() 
                          ? Colors.orange 
                          : _isOverdue() 
                              ? Colors.red 
                              : Colors.grey.shade600,
                      fontWeight: _isDueToday() || _isOverdue() 
                          ? FontWeight.bold 
                          : FontWeight.normal,
                    ),
                  ),
                ],

                const Spacer(),

                // Comments count
                if (task.comments.isNotEmpty) ...[
                  Icon(
                    Icons.comment_outlined,
                    size: 12,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    task.comments.length.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Subtasks progress
                if (task.subtaskIds.isNotEmpty) ...[
                  Icon(
                    Icons.checklist_outlined,
                    size: 12,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${task.subtaskIds.length}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],

                // Time tracking
                if (task.estimatedHours != null || task.loggedHours != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.timer_outlined,
                    size: 12,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${task.loggedHours ?? 0}h/${task.estimatedHours ?? 0}h',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor() {
    switch (task.type) {
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
    switch (task.type) {
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

  Widget _buildPriorityIcon() {
    Color color;
    IconData icon;

    switch (task.priority) {
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

    return Icon(
      icon,
      size: 16,
      color: color,
    );
  }

  bool _isOverdue() {
    if (task.dueDate == null) return false;
    final now = DateTime.now();
    final dueDate = task.dueDate!;
    return dueDate.isBefore(DateTime(now.year, now.month, now.day)) && 
           task.status != TaskStatus.done;
  }

  bool _isDueToday() {
    if (task.dueDate == null) return false;
    final now = DateTime.now();
    final dueDate = task.dueDate!;
    return dueDate.year == now.year && 
           dueDate.month == now.month && 
           dueDate.day == now.day &&
           task.status != TaskStatus.done;
  }
} 