import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskPriority {
  lowest,
  low,
  medium,
  high,
  highest,
}

enum TaskType {
  task,
  bug,
  story,
  epic,
  subtask,
}

enum TaskStatus {
  backlog,
  todo,
  inProgress,
  inReview,
  testing,
  done,
}

class KanbanTask {
  final String id;
  final String title;
  final String description;
  final TaskType type;
  final TaskStatus status;
  final TaskPriority priority;
  final String? assigneeId;
  final String? assigneeName;
  final String? assigneeEmail;
  final String reporterId;
  final String reporterName;
  final String reporterEmail;
  final List<String> labels;
  final String? epicId;
  final String? parentTaskId;
  final List<String> subtaskIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? dueDate;
  final int? estimatedHours;
  final int? loggedHours;
  final String? sprint;
  final List<String> attachments;
  final List<TaskComment> comments;
  final String boardId;
  final int position;

  KanbanTask({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    required this.priority,
    this.assigneeId,
    this.assigneeName,
    this.assigneeEmail,
    required this.reporterId,
    required this.reporterName,
    required this.reporterEmail,
    required this.labels,
    this.epicId,
    this.parentTaskId,
    required this.subtaskIds,
    required this.createdAt,
    required this.updatedAt,
    this.dueDate,
    this.estimatedHours,
    this.loggedHours,
    this.sprint,
    required this.attachments,
    required this.comments,
    required this.boardId,
    required this.position,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'type': type.name,
      'status': status.name,
      'priority': priority.name,
      'assigneeId': assigneeId,
      'assigneeName': assigneeName,
      'assigneeEmail': assigneeEmail,
      'reporterId': reporterId,
      'reporterName': reporterName,
      'reporterEmail': reporterEmail,
      'labels': labels,
      'epicId': epicId,
      'parentTaskId': parentTaskId,
      'subtaskIds': subtaskIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'estimatedHours': estimatedHours,
      'loggedHours': loggedHours,
      'sprint': sprint,
      'attachments': attachments,
      'comments': comments.map((c) => c.toMap()).toList(),
      'boardId': boardId,
      'position': position,
    };
  }

  factory KanbanTask.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return KanbanTask(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      type: TaskType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => TaskType.task,
      ),
      status: TaskStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => TaskStatus.todo,
      ),
      priority: TaskPriority.values.firstWhere(
        (p) => p.name == data['priority'],
        orElse: () => TaskPriority.medium,
      ),
      assigneeId: data['assigneeId'],
      assigneeName: data['assigneeName'],
      assigneeEmail: data['assigneeEmail'],
      reporterId: data['reporterId'] ?? '',
      reporterName: data['reporterName'] ?? '',
      reporterEmail: data['reporterEmail'] ?? '',
      labels: List<String>.from(data['labels'] ?? []),
      epicId: data['epicId'],
      parentTaskId: data['parentTaskId'],
      subtaskIds: List<String>.from(data['subtaskIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      estimatedHours: data['estimatedHours'],
      loggedHours: data['loggedHours'],
      sprint: data['sprint'],
      attachments: List<String>.from(data['attachments'] ?? []),
      comments: (data['comments'] as List<dynamic>?)
          ?.map((c) => TaskComment.fromMap(c as Map<String, dynamic>))
          .toList() ?? [],
      boardId: data['boardId'] ?? '',
      position: data['position'] ?? 0,
    );
  }

  KanbanTask copyWith({
    String? title,
    String? description,
    TaskType? type,
    TaskStatus? status,
    TaskPriority? priority,
    String? assigneeId,
    String? assigneeName,
    String? assigneeEmail,
    List<String>? labels,
    String? epicId,
    String? parentTaskId,
    List<String>? subtaskIds,
    DateTime? updatedAt,
    DateTime? dueDate,
    int? estimatedHours,
    int? loggedHours,
    String? sprint,
    List<String>? attachments,
    List<TaskComment>? comments,
    int? position,
  }) {
    return KanbanTask(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      assigneeId: assigneeId ?? this.assigneeId,
      assigneeName: assigneeName ?? this.assigneeName,
      assigneeEmail: assigneeEmail ?? this.assigneeEmail,
      reporterId: reporterId,
      reporterName: reporterName,
      reporterEmail: reporterEmail,
      labels: labels ?? this.labels,
      epicId: epicId ?? this.epicId,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      subtaskIds: subtaskIds ?? this.subtaskIds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      dueDate: dueDate ?? this.dueDate,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      loggedHours: loggedHours ?? this.loggedHours,
      sprint: sprint ?? this.sprint,
      attachments: attachments ?? this.attachments,
      comments: comments ?? this.comments,
      boardId: boardId,
      position: position ?? this.position,
    );
  }

  String get taskKey => 'RHBL-${id.substring(0, 8).toUpperCase()}';

  String get priorityDisplayName {
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

  String get typeDisplayName {
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

  String get statusDisplayName {
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

class TaskComment {
  final String id;
  final String authorId;
  final String authorName;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;

  TaskComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'authorId': authorId,
      'authorName': authorName,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory TaskComment.fromMap(Map<String, dynamic> map) {
    return TaskComment(
      id: map['id'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      content: map['content'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
} 