import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/task_model.dart';
import '../providers/task_provider.dart';

// ── TaskSection ───────────────────────────────────────────────
// PURPOSE: Collapsible task list dropped inside each _DayTile
// FLOW: Collapsed by default with badge count summary
//   → tap header → expands → shows tasks + Add button
//   → task status chip tap → cycles status (no sheet needed)
//   → edit icon → _TaskSheet
//   → delete icon → confirm dialog → delete
class TaskSection extends ConsumerStatefulWidget {
  final String date; // "2026-03-31"
  final String?
  attendanceId; // from attendance record — null on weekends/unrecorded days

  const TaskSection({super.key, required this.date, this.attendanceId});

  @override
  ConsumerState<TaskSection> createState() => _TaskSectionState();
}

class _TaskSectionState extends ConsumerState<TaskSection>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  // WHY select: only rebuilds when THIS date's tasks change —
  //   not when any other date in the map changes
  List<TaskModel> get _tasks =>
      ref.watch(taskProvider.select((m) => m[widget.date] ?? []));

  @override
  Widget build(BuildContext context) {
    final tasks = _tasks;
    final count = tasks.length;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Divider ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Divider(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: 0.3),
          ),
        ),

        // ── Toggle row ──────────────────────────────────────
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Icons.task_alt_rounded, size: 14, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  'Tasks',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),

                // ── Status summary badges ─────────────────
                if (count > 0) ...[
                  const SizedBox(width: 8),
                  _StatusSummaryBadges(tasks: tasks),
                ] else ...[
                  const SizedBox(width: 6),
                  Text(
                    'Tap to add',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
                ],

                const Spacer(),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Expanded task list ───────────────────────────
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _TaskList(
            tasks: tasks,
            date: widget.date,
            attendanceId: widget.attendanceId,
          ),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
          sizeCurve: Curves.easeInOut,
        ),
      ],
    );
  }
}

// ── _TaskList ─────────────────────────────────────────────────
// Extracted so AnimatedCrossFade secondChild doesn't rebuild
class _TaskList extends ConsumerWidget {
  final List<TaskModel> tasks;
  final String date;
  final String? attendanceId;

  const _TaskList({
    required this.tasks,
    required this.date,
    required this.attendanceId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),

        // ── Empty state ──────────────────────────────────
        if (tasks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  Icons.inbox_rounded,
                  size: 13,
                  color: Colors.grey.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 6),
                Text(
                  'No tasks yet for this day',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          )
        // ── Task rows ────────────────────────────────────
        else
          ...tasks.map(
            (task) => _TaskRow(
              task: task,
              date: date,
              onEdit: () => _showSheet(context, existing: task),
              onDelete: () => _confirmDelete(context, ref, task),
              onCycle: () => ref
                  .read(taskProvider.notifier)
                  .cycleStatus(id: task.id, date: date, task: task),
            ),
          ),

        const SizedBox(height: 8),

        // ── Add Task button ──────────────────────────────
        InkWell(
          onTap: () => _showSheet(context),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_rounded,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Add Task',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Future<void> _showSheet(BuildContext ctx, {TaskModel? existing}) async {
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TaskSheet(
        date: date,
        attendanceId: attendanceId,
        existing: existing,
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext ctx,
    WidgetRef ref,
    TaskModel task,
  ) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      useRootNavigator: true,
      builder: (dctx) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref.read(taskProvider.notifier).deleteTask(id: task.id, date: date);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Task deleted'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }
}

// ── _StatusSummaryBadges ──────────────────────────────────────
// Shows compact colored count pills e.g. ● 2  ● 1
class _StatusSummaryBadges extends StatelessWidget {
  final List<TaskModel> tasks;
  const _StatusSummaryBadges({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final done = tasks.where((t) => t.status == 'done').length;
    final inProgress = tasks.where((t) => t.status == 'in_progress').length;
    final pending = tasks.where((t) => t.status == 'pending').length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (done > 0) _pill(Colors.green, done, '✅'),
        if (inProgress > 0) _pill(Colors.blue, inProgress, '🔄'),
        if (pending > 0) _pill(Colors.orange, pending, '⏳'),
      ],
    );
  }

  Widget _pill(Color color, int n, String emoji) => Padding(
    padding: const EdgeInsets.only(right: 4),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$emoji $n',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    ),
  );
}

// ── _TaskRow ──────────────────────────────────────────────────
// PURPOSE: Single task item row with status, title, actions
class _TaskRow extends StatelessWidget {
  final TaskModel task;
  final String date;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCycle; // tap status chip → cycle

  const _TaskRow({
    required this.task,
    required this.date,
    required this.onEdit,
    required this.onDelete,
    required this.onCycle,
  });

  (String, Color) get _statusDisplay => switch (task.status) {
    'done' => ('✅ Done', Colors.green),
    'in_progress' => ('🔄 In Progress', Colors.blue),
    _ => ('⏳ Pending', Colors.orange),
  };

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = _statusDisplay;
    final isDone = task.status == 'done';
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status chip (tap to cycle) ─────────────────
          // WHY cycle on tap: fastest way to update status —
          //   no sheet needed, single tap changes state
          GestureDetector(
            onTap: onCycle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // ── Title + description ───────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    // WHY strikethrough: visual signal that
                    //   done tasks are complete — matches todo convention
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    color: isDone
                        ? cs.onSurface.withValues(alpha: 0.4)
                        : cs.onSurface,
                  ),
                ),
                if (task.description != null && task.description!.isNotEmpty)
                  Text(
                    task.description!,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.45),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // ── Edit icon ────────────────────────────────
          GestureDetector(
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.edit_rounded,
                size: 14,
                color: Colors.blue.withValues(alpha: 0.7),
              ),
            ),
          ),

          // ── Delete icon ──────────────────────────────
          GestureDetector(
            onTap: onDelete,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.delete_outline_rounded,
                size: 14,
                color: Colors.red.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _TaskSheet ────────────────────────────────────────────────
// PURPOSE: Add or edit a task
// existing == null → Add mode
// existing != null → Edit mode
class _TaskSheet extends ConsumerStatefulWidget {
  final String date;
  final String? attendanceId;
  final TaskModel? existing;

  const _TaskSheet({required this.date, this.attendanceId, this.existing});

  @override
  ConsumerState<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends ConsumerState<_TaskSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late String _status;
  bool _isSaving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
    _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
    _status = widget.existing?.status ?? 'pending';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Title is required')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      if (_isEdit) {
        await ref
            .read(taskProvider.notifier)
            .updateTask(
              id: widget.existing!.id,
              date: widget.date,
              title: _titleCtrl.text.trim(),
              description: _descCtrl.text.trim().isEmpty
                  ? null
                  : _descCtrl.text.trim(),
              status: _status,
            );
      } else {
        await ref
            .read(taskProvider.notifier)
            .addTask(
              date: widget.date,
              attendanceId: widget.attendanceId,
              title: _titleCtrl.text.trim(),
              description: _descCtrl.text.trim().isEmpty
                  ? null
                  : _descCtrl.text.trim(),
              status: _status,
            );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle ────────────────────────────────────
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Header ────────────────────────────────────
            Row(
              children: [
                Icon(
                  _isEdit ? Icons.edit_note_rounded : Icons.add_task_rounded,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _isEdit ? 'Edit Task' : 'Add Task',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Title ────────────────────────────────────
            const Text(
              'Title *',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              autofocus: !_isEdit,
              decoration: InputDecoration(
                hintText: 'e.g. Fix login bug',
                prefixIcon: const Icon(Icons.task_alt_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 16),

            // ── Description ──────────────────────────────
            const Text(
              'Description (optional)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add details...',
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 48),
                  child: Icon(Icons.notes_rounded),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 16),

            // ── Status chips ─────────────────────────────
            const Text(
              'Status',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _StatusChip(
                  label: '⏳ Pending',
                  color: Colors.orange,
                  selected: _status == 'pending',
                  onTap: () => setState(() => _status = 'pending'),
                ),
                const SizedBox(width: 8),
                _StatusChip(
                  label: '🔄 In Progress',
                  color: Colors.blue,
                  selected: _status == 'in_progress',
                  onTap: () => setState(() => _status = 'in_progress'),
                ),
                const SizedBox(width: 8),
                _StatusChip(
                  label: '✅ Done',
                  color: Colors.green,
                  selected: _status == 'done',
                  onTap: () => setState(() => _status = 'done'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Save ─────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(_isEdit ? Icons.save_rounded : Icons.add_rounded),
                label: Text(
                  _isSaving
                      ? 'Saving...'
                      : _isEdit
                      ? 'Save Changes'
                      : 'Add Task',
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSaving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _StatusChip ───────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.3),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? color : color.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}
