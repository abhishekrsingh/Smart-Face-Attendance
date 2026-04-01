import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/app_logger.dart';
import '../../data/task_model.dart';
import '../../data/task_repository.dart';

// ── FLOW ──────────────────────────────────────────────────────
// 1. HistoryScreen loads attendance records
// 2. Calls loadForDates(allDatesInMonth) → single DB call
// 3. State = Map<"2026-03-31", [TaskModel, ...]>
// 4. TaskSection watches state[date] → rebuilds on change
// 5. Add/Edit/Delete → optimistic state update → DB call
//    WHY optimistic: UI feels instant — no spinner for writes

final taskProvider =
    NotifierProvider<TaskNotifier, Map<String, List<TaskModel>>>(
      TaskNotifier.new,
    );

class TaskNotifier extends Notifier<Map<String, List<TaskModel>>> {
  @override
  Map<String, List<TaskModel>> build() => {};

  // ── loadForDates() ─────────────────────────────────────────
  // WHY merge not replace: user may have toggled months quickly —
  //   merging keeps previously loaded months in memory
  Future<void> loadForDates(List<String> dates) async {
    try {
      final result = await taskRepository.getTasksForDates(dates);
      if (!ref.mounted) return;
      state = {...state, ...result};
    } catch (e) {
      AppLogger.error('Load tasks failed', e);
    }
  }

  // ── addTask() ──────────────────────────────────────────────
  Future<void> addTask({
    required String date,
    String? attendanceId,
    required String title,
    String? description,
    String status = 'pending',
  }) async {
    final task = await taskRepository.addTask(
      date: date,
      attendanceId: attendanceId,
      title: title,
      description: description,
      status: status,
    );
    if (!ref.mounted) return;
    // Optimistic append
    final list = List<TaskModel>.from(state[date] ?? [])..add(task);
    state = {...state, date: list};
  }

  // ── updateTask() ───────────────────────────────────────────
  Future<void> updateTask({
    required String id,
    required String date,
    required String title,
    String? description,
    required String status,
  }) async {
    final updated = await taskRepository.updateTask(
      id: id,
      title: title,
      description: description,
      status: status,
    );
    if (!ref.mounted) return;
    // Replace in-place
    final list = List<TaskModel>.from(state[date] ?? []);
    final idx = list.indexWhere((t) => t.id == id);
    if (idx >= 0) list[idx] = updated;
    state = {...state, date: list};
  }

  // ── deleteTask() ───────────────────────────────────────────
  Future<void> deleteTask({required String id, required String date}) async {
    await taskRepository.deleteTask(id);
    if (!ref.mounted) return;
    final list = List<TaskModel>.from(state[date] ?? [])
      ..removeWhere((t) => t.id == id);
    state = {...state, date: list};
  }

  // ── cycleStatus() ──────────────────────────────────────────
  // PURPOSE: Quick tap-to-cycle from task row without opening sheet
  // Cycle: pending → in_progress → done → pending
  Future<void> cycleStatus({
    required String id,
    required String date,
    required TaskModel task,
  }) async {
    final next = switch (task.status) {
      'pending' => 'in_progress',
      'in_progress' => 'done',
      _ => 'pending',
    };
    await updateTask(
      id: id,
      date: date,
      title: task.title,
      description: task.description,
      status: next,
    );
  }
}
