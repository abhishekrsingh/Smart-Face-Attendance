import 'package:supabase_flutter/supabase_flutter.dart';
import 'task_model.dart';
import '../../../core/utils/app_logger.dart';

// WHY singleton: same pattern as attendanceRepository —
//   single instance, no rebuild cost, easy to call anywhere
final taskRepository = TaskRepository._();

class TaskRepository {
  TaskRepository._();

  final _client = Supabase.instance.client;
  String get _userId => _client.auth.currentUser!.id;

  // ── getTasksForDates() ─────────────────────────────────────
  // PURPOSE: Batch fetch tasks for a list of dates
  // WHY batch: one DB call for all dates vs N per-date calls
  //   history screen shows 30 days → single query for all
  Future<Map<String, List<TaskModel>>> getTasksForDates(
    List<String> dates,
  ) async {
    if (dates.isEmpty) return {};

    final response = await _client
        .from('tasks')
        .select()
        .eq('user_id', _userId)
        .inFilter('date', dates)
        .order('created_at');

    AppLogger.debug(
      'Tasks loaded: ${response.length} for ${dates.length} dates',
    );

    // Group by date string
    final result = <String, List<TaskModel>>{};
    for (final row in response) {
      final task = TaskModel.fromMap(row as Map<String, dynamic>);
      result.putIfAbsent(task.date, () => []).add(task);
    }
    return result;
  }

  // ── addTask() ──────────────────────────────────────────────
  Future<TaskModel> addTask({
    required String date,
    String? attendanceId,
    required String title,
    String? description,
    String status = 'pending',
  }) async {
    final response = await _client
        .from('tasks')
        .insert({
          'user_id': _userId,
          'attendance_id': attendanceId,
          'date': date,
          'title': title.trim(),
          'description': description?.trim(),
          'status': status,
        })
        .select()
        .single();

    AppLogger.info('Task added: ${response['id']}');
    return TaskModel.fromMap(response);
  }

  // ── updateTask() ───────────────────────────────────────────
  Future<TaskModel> updateTask({
    required String id,
    required String title,
    String? description,
    required String status,
  }) async {
    final response = await _client
        .from('tasks')
        .update({
          'title': title.trim(),
          'description': description?.trim(),
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .eq('user_id', _userId) // WHY double guard: RLS + query
        .select()
        .single();

    AppLogger.info('Task updated: $id → $status');
    return TaskModel.fromMap(response);
  }

  // ── deleteTask() ───────────────────────────────────────────
  Future<void> deleteTask(String id) async {
    await _client.from('tasks').delete().eq('id', id).eq('user_id', _userId);

    AppLogger.info('Task deleted: $id');
  }
}
