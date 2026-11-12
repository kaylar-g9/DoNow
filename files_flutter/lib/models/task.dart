enum TaskPriority { low, medium, high }

class Task {
  final String id;
  final String title;
  final String description;
  final TaskPriority priority;
  final bool isCompleted;
  final DateTime createdAt;

  const Task({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.isCompleted,
    required this.createdAt,
  });

  Task copyWith({
    String? title,
    String? description,
    TaskPriority? priority,
    bool? isCompleted,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'priority': priority.name,
        'isCompleted': isCompleted,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      priority: TaskPriority.values.firstWhere(
        (value) => value.name == json['priority'],
        orElse: () => TaskPriority.medium,
      ),
      isCompleted: json['isCompleted'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
