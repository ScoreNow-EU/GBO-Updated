import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/kanban_board.dart';
import '../models/kanban_task.dart';

class KanbanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _boardsCollection = 'kanban_boards';
  final String _tasksCollection = 'kanban_tasks';
  static const String _defaultBoardId = 'rhbl_main_board';

  // Get or create the single default board
  Future<KanbanBoard> getDefaultBoard() async {
    try {
      final doc = await _firestore.collection(_boardsCollection).doc(_defaultBoardId).get();
      if (doc.exists) {
        return KanbanBoard.fromFirestore(doc);
      } else {
        // Create default board if it doesn't exist
        final defaultBoard = KanbanBoard(
          id: _defaultBoardId,
          name: 'RHBL - Aufgaben',
          description: 'Hauptboard fÃ¼r die Verwaltung aller RHBL-Aufgaben',
          projectKey: 'RHBL',
          adminIds: [],
          memberIds: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          createdById: 'system',
          createdByName: 'System',
        );
        
        await _firestore.collection(_boardsCollection).doc(_defaultBoardId).set(defaultBoard.toFirestore());
        return defaultBoard;
      }
    } catch (e) {
      debugPrint('Error getting default board: $e');
      // Return a fallback board
      return KanbanBoard(
        id: _defaultBoardId,
        name: 'RHBL - Aufgaben',
        description: 'Hauptboard fÃ¼r die Verwaltung aller RHBL-Aufgaben',
        projectKey: 'RHBL',
        adminIds: [],
        memberIds: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdById: 'system',
        createdByName: 'System',
      );
    }
  }

  // Task Management - all tasks go to the default board
  Stream<List<KanbanTask>> getAllTasks() {
    return _firestore
        .collection(_tasksCollection)
        .where('boardId', isEqualTo: _defaultBoardId)
        .snapshots()
        .map((snapshot) {
          final tasks = snapshot.docs
              .map((doc) => KanbanTask.fromFirestore(doc))
              .toList();
          // Sort in memory to avoid compound index requirements
          tasks.sort((a, b) => a.position.compareTo(b.position));
          return tasks;
        });
  }

  Future<List<KanbanTask>> getAllTasksOnce() async {
    try {
      final querySnapshot = await _firestore
          .collection(_tasksCollection)
          .where('boardId', isEqualTo: _defaultBoardId)
          .get();

      final tasks = querySnapshot.docs
          .map((doc) => KanbanTask.fromFirestore(doc))
          .toList();
      
      // Sort in memory to avoid compound index requirements
      tasks.sort((a, b) => a.position.compareTo(b.position));
      return tasks;
    } catch (e) {
      debugPrint('Error getting tasks: $e');
      return [];
    }
  }

  Future<KanbanTask?> getTaskById(String taskId) async {
    try {
      final doc = await _firestore.collection(_tasksCollection).doc(taskId).get();
      if (doc.exists) {
        return KanbanTask.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint('Error getting task: $e');
    }
    return null;
  }

  Future<String?> createTask(KanbanTask task) async {
    try {
      // Ensure the task is assigned to the default board
      final taskWithBoard = KanbanTask(
        id: task.id,
        title: task.title,
        description: task.description,
        type: task.type,
        status: task.status,
        priority: task.priority,
        assigneeId: task.assigneeId,
        assigneeName: task.assigneeName,
        assigneeEmail: task.assigneeEmail,
        reporterId: task.reporterId,
        reporterName: task.reporterName,
        reporterEmail: task.reporterEmail,
        labels: task.labels,
        epicId: task.epicId,
        parentTaskId: task.parentTaskId,
        subtaskIds: task.subtaskIds,
        createdAt: task.createdAt,
        updatedAt: task.updatedAt,
        dueDate: task.dueDate,
        estimatedHours: task.estimatedHours,
        loggedHours: task.loggedHours,
        sprint: task.sprint,
        attachments: task.attachments,
        comments: task.comments,
        boardId: _defaultBoardId, // Force to default board
        position: task.position,
      );
      final docRef = await _firestore.collection(_tasksCollection).add(taskWithBoard.toFirestore());
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating task: $e');
      return null;
    }
  }

  Future<bool> updateTask(KanbanTask task) async {
    try {
      await _firestore
          .collection(_tasksCollection)
          .doc(task.id)
          .update(task.toFirestore());
      return true;
    } catch (e) {
      debugPrint('Error updating task: $e');
      return false;
    }
  }

  Future<bool> deleteTask(String taskId) async {
    try {
      await _firestore.collection(_tasksCollection).doc(taskId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting task: $e');
      return false;
    }
  }

  Future<bool> moveTask(String taskId, TaskStatus newStatus, int newPosition) async {
    try {
      await _firestore.collection(_tasksCollection).doc(taskId).update({
        'status': newStatus.name,
        'position': newPosition,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error moving task: $e');
      return false;
    }
  }

  Future<bool> assignTask(String taskId, String? assigneeId, String? assigneeName, String? assigneeEmail) async {
    try {
      await _firestore.collection(_tasksCollection).doc(taskId).update({
        'assigneeId': assigneeId,
        'assigneeName': assigneeName,
        'assigneeEmail': assigneeEmail,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error assigning task: $e');
      return false;
    }
  }

  Future<bool> addComment(String taskId, TaskComment comment) async {
    try {
      final task = await getTaskById(taskId);
      if (task != null) {
        final updatedComments = [...task.comments, comment];
        await _firestore.collection(_tasksCollection).doc(taskId).update({
          'comments': updatedComments.map((c) => c.toMap()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error adding comment: $e');
      return false;
    }
  }

  Future<bool> updateTaskPriority(String taskId, TaskPriority priority) async {
    try {
      await _firestore.collection(_tasksCollection).doc(taskId).update({
        'priority': priority.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error updating task priority: $e');
      return false;
    }
  }

  Future<bool> updateTaskLabels(String taskId, List<String> labels) async {
    try {
      await _firestore.collection(_tasksCollection).doc(taskId).update({
        'labels': labels,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error updating task labels: $e');
      return false;
    }
  }

  Future<bool> updateTaskDueDate(String taskId, DateTime? dueDate) async {
    try {
      await _firestore.collection(_tasksCollection).doc(taskId).update({
        'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error updating task due date: $e');
      return false;
    }
  }

  Future<bool> updateTaskTimeTracking(String taskId, int? estimatedHours, int? loggedHours) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (estimatedHours != null) {
        updateData['estimatedHours'] = estimatedHours;
      }
      
      if (loggedHours != null) {
        updateData['loggedHours'] = loggedHours;
      }

      await _firestore.collection(_tasksCollection).doc(taskId).update(updateData);
      return true;
    } catch (e) {
      debugPrint('Error updating task time tracking: $e');
      return false;
    }
  }

  // Search and Filter - now works across all tasks
  Future<List<KanbanTask>> searchTasks(String query) async {
    try {
      final querySnapshot = await _firestore
          .collection(_tasksCollection)
          .where('boardId', isEqualTo: _defaultBoardId)
          .get();

      final tasks = querySnapshot.docs
          .map((doc) => KanbanTask.fromFirestore(doc))
          .toList();

      // Filter by search query
      final lowercaseQuery = query.toLowerCase();
      return tasks.where((task) =>
          task.title.toLowerCase().contains(lowercaseQuery) ||
          task.description.toLowerCase().contains(lowercaseQuery) ||
          task.taskKey.toLowerCase().contains(lowercaseQuery) ||
          task.assigneeName?.toLowerCase().contains(lowercaseQuery) == true ||
          task.labels.any((label) => label.toLowerCase().contains(lowercaseQuery))
      ).toList();
    } catch (e) {
      debugPrint('Error searching tasks: $e');
      return [];
    }
  }

  Future<List<KanbanTask>> getTasksByStatus(TaskStatus status) async {
    try {
      final querySnapshot = await _firestore
          .collection(_tasksCollection)
          .where('boardId', isEqualTo: _defaultBoardId)
          .where('status', isEqualTo: status.name)
          .get();

      final tasks = querySnapshot.docs
          .map((doc) => KanbanTask.fromFirestore(doc))
          .toList();
      
      // Sort in memory to avoid compound index requirements
      tasks.sort((a, b) => a.position.compareTo(b.position));
      return tasks;
    } catch (e) {
      debugPrint('Error getting tasks by status: $e');
      return [];
    }
  }

  Future<List<KanbanTask>> getTasksByAssignee(String assigneeId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_tasksCollection)
          .where('boardId', isEqualTo: _defaultBoardId)
          .where('assigneeId', isEqualTo: assigneeId)
          .get();

      final tasks = querySnapshot.docs
          .map((doc) => KanbanTask.fromFirestore(doc))
          .toList();
      
      // Sort in memory to avoid compound index requirements
      tasks.sort((a, b) => a.position.compareTo(b.position));
      return tasks;
    } catch (e) {
      debugPrint('Error getting tasks by assignee: $e');
      return [];
    }
  }

  // Statistics - now for all tasks
  Future<Map<String, int>> getStatistics() async {
    try {
      final tasks = await getAllTasksOnce();
      
      final stats = <String, int>{};
      
      // Count by status
      for (final status in TaskStatus.values) {
        stats['status_${status.name}'] = tasks.where((t) => t.status == status).length;
      }
      
      // Count by priority
      for (final priority in TaskPriority.values) {
        stats['priority_${priority.name}'] = tasks.where((t) => t.priority == priority).length;
      }
      
      // Count by type
      for (final type in TaskType.values) {
        stats['type_${type.name}'] = tasks.where((t) => t.type == type).length;
      }
      
      stats['total'] = tasks.length;
      stats['completed'] = tasks.where((t) => t.status == TaskStatus.done).length;
      stats['in_progress'] = tasks.where((t) => t.status == TaskStatus.inProgress).length;
      stats['overdue'] = tasks.where((t) => 
          t.dueDate != null && 
          t.dueDate!.isBefore(DateTime.now()) && 
          t.status != TaskStatus.done
      ).length;
      
      return stats;
    } catch (e) {
      debugPrint('Error getting statistics: $e');
      return {};
    }
  }
} 