// PURPOSE: Immutable data model for a task row in Supabase
class TaskModel {
  final String id;
  final String userId;
  final String? attendanceId; // null if task added on day with no attendance
  final String date; // "2026-03-31"
  final String title;
  final String? description;
  final String status; // pending | in_progress | done
  final String createdAt;
  final String updatedAt;

  const TaskModel({
    required this.id,
    required this.userId,
    this.attendanceId,
    required this.date,
    required this.title,
    this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskModel.fromMap(Map<String, dynamic> map) => TaskModel(
    id: map['id'] as String,
    userId: map['user_id'] as String,
    attendanceId: map['attendance_id'] as String?,
    date: map['date'] as String,
    title: map['title'] as String,
    description: map['description'] as String?,
    status: map['status'] as String? ?? 'pending',
    createdAt: map['created_at'] as String,
    updatedAt: map['updated_at'] as String,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'attendance_id': attendanceId,
    'date': date,
    'title': title,
    'description': description,
    'status': status,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  // WHY copyWith: provider updates a single field without
  //   creating a full new instance from scratch
  TaskModel copyWith({
    String? title,
    String? description,
    String? status,
    String? updatedAt,
  }) => TaskModel(
    id: id,
    userId: userId,
    attendanceId: attendanceId,
    date: date,
    title: title ?? this.title,
    description: description ?? this.description,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
