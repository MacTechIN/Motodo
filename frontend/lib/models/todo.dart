class Todo {
  final String id;
  final String content;
  final int priority;
  final bool isSecret;
  final bool isCompleted;
  final String createdBy;
  final String teamId;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? attachmentUrl;

  Todo({
    required this.id,
    required this.content,
    required this.priority,
    required this.isSecret,
    required this.isCompleted,
    required this.createdBy,
    required this.teamId,
    required this.createdAt,
    this.completedAt,
    this.attachmentUrl,
  });

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'],
      content: json['content'],
      priority: json['priority'],
      isSecret: json['isSecret'] ?? false,
      isCompleted: json['isCompleted'] ?? false,
      createdBy: json['createdBy'],
      teamId: json['teamId'],
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
      attachmentUrl: json['attachmentUrl'],
    );
  }
}
