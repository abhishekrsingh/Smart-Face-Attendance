import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/leave_repository.dart';

class LeavePage extends StatefulWidget {
  const LeavePage({super.key});

  @override
  State<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends State<LeavePage> {
  List<Map<String, dynamic>> _leaves = [];
  bool _isLoading = true;
  String? _error;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadLeaves();
  }

  Future<void> _loadLeaves() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await leaveRepository.getMyLeaves();
      if (mounted) {
        setState(() {
          _leaves = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _leaves;
    return _leaves.where((l) => l['status'] == _filter).toList();
  }

  // ── _showLeaveSheet() ────────────────────────────────────────
  void _showLeaveSheet({Map<String, dynamic>? leave}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _LeaveFormSheet(existingLeave: leave, onSaved: _loadLeaves),
    );
  }

  // ── _confirmCancel() ─────────────────────────────────────────
  Future<void> _confirmCancel(Map<String, dynamic> leave) async {
    final leaveType = leave['leave_type'] as String;
    final startDate = leave['start_date'] as String;
    final endDate = leave['end_date'] as String;
    final start = DateTime.parse(startDate);
    final end = DateTime.parse(endDate);

    final confirm = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Text('🚫', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('Cancel Leave Request', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to cancel this leave?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _leaveTypeLabel(leaveType),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    startDate == endDate
                        ? DateFormat('dd MMM yyyy').format(start)
                        : '${DateFormat('dd MMM').format(start)} – '
                              '${DateFormat('dd MMM yyyy').format(end)}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'You can re-apply after cancellation.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(false),
            child: const Text('Keep Leave'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.cancel_rounded, size: 16),
            label: const Text('Yes, Cancel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await leaveRepository.cancelLeave(leaveId: leave['id'] as String);
      _loadLeaves();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚫 Leave request cancelled'),
            backgroundColor: Colors.grey,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── _confirmDelete() ─────────────────────────────────────────
  // PURPOSE: Confirm then hard-delete approved/rejected/cancelled
  // WHY Future<bool>: Dismissible uses return value to decide
  //   whether to remove card (true) or snap it back (false)
  Future<bool> _confirmDelete(Map<String, dynamic> leave) async {
    final leaveType = leave['leave_type'] as String;
    final startDate = leave['start_date'] as String;
    final endDate = leave['end_date'] as String;
    final status = leave['status'] as String;
    final start = DateTime.parse(startDate);
    final end = DateTime.parse(endDate);

    final confirm = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Text('🗑️', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('Delete Leave Record', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will permanently delete this leave record.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _leaveTypeLabel(leaveType),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      // ── Status pill ─────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: TextStyle(
                            fontSize: 11,
                            color: _statusColor(status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    startDate == endDate
                        ? DateFormat('dd MMM yyyy').format(start)
                        : '${DateFormat('dd MMM').format(start)} – '
                              '${DateFormat('dd MMM yyyy').format(end)}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(false),
            child: const Text('Keep'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_rounded, size: 16),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true),
          ),
        ],
      ),
    );

    if (confirm != true) return false;

    try {
      await leaveRepository.deleteLeave(leaveId: leave['id'] as String);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ Leave record deleted'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return true; // ← card removed from UI
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false; // ← card snaps back
    }
  }

  // ── Status helpers ───────────────────────────────────────────
  String _leaveTypeLabel(String type) => switch (type) {
    'sick' => '🤒 Sick Leave',
    'casual' => '🌴 Casual Leave',
    'emergency' => '🚨 Emergency Leave',
    _ => '📋 Other Leave',
  };

  String _statusLabel(String status) => switch (status) {
    'approved' => '🟢 Approved',
    'rejected' => '🔴 Rejected',
    'cancelled' => '⚫ Cancelled',
    _ => '🟡 Pending',
  };

  Color _statusColor(String status) => switch (status) {
    'approved' => Colors.green,
    'rejected' => Colors.red,
    'cancelled' => Colors.grey,
    _ => Colors.amber,
  };

  // ── _isDeletable() ───────────────────────────────────────────
  // WHY include approved: admin already actioned it —
  //   employee can safely clear it from history
  // WHY exclude pending: use cancel button instead —
  //   ensures admin sees withdrawal, not silent disappearance
  bool _isDeletable(String status) =>
      status == 'approved' || status == 'rejected' || status == 'cancelled';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Leaves'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Apply Leave',
            onPressed: () => _showLeaveSheet(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter chips ─────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  value: 'all',
                  selected: _filter,
                  onTap: (v) => setState(() => _filter = v),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: '🟡 Pending',
                  value: 'pending',
                  selected: _filter,
                  onTap: (v) => setState(() => _filter = v),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: '🟢 Approved',
                  value: 'approved',
                  selected: _filter,
                  onTap: (v) => setState(() => _filter = v),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: '🔴 Rejected',
                  value: 'rejected',
                  selected: _filter,
                  onTap: (v) => setState(() => _filter = v),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: '⚫ Cancelled',
                  value: 'cancelled',
                  selected: _filter,
                  onTap: (v) => setState(() => _filter = v),
                ),
              ],
            ),
          ),

          // ── Swipe hint banner ────────────────────────────────
          // WHY show only when deletable cards exist: avoids
          // confusing hint when only pending cards are visible
          if (_filtered.any((l) => _isDeletable(l['status'] as String)))
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.swipe_left_rounded, size: 14, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Swipe left to delete approved, rejected or cancelled leaves',
                      style: TextStyle(fontSize: 11, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadLeaves,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('📋', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text(
                          _filter == 'all'
                              ? 'No leave requests yet'
                              : 'No $_filter leaves',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        if (_filter == 'all') ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showLeaveSheet(),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Apply for Leave'),
                          ),
                        ],
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadLeaves,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final leave = _filtered[i];
                        final status = leave['status'] as String;
                        final isPending = status == 'pending';
                        final canDelete = _isDeletable(status);

                        // ── Swipe-to-delete for final status ──
                        // WHY Dismissible only on deletable:
                        // pending cards use cancel button — no swipe
                        if (canDelete) {
                          return Dismissible(
                            key: ValueKey(leave['id'] as String),
                            direction: DismissDirection.endToStart,
                            // WHY confirmDismiss: snaps card back
                            // if user taps "Keep" or DB fails
                            confirmDismiss: (_) => _confirmDelete(leave),
                            background: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.centerRight,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.delete_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Delete',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            child: _LeaveCard(
                              leave: leave,
                              onEdit: null,
                              onCancel: null,
                            ),
                          );
                        }

                        // ── Pending cards (no swipe) ──────────
                        return _LeaveCard(
                          leave: leave,
                          onEdit: isPending
                              ? () => _showLeaveSheet(leave: leave)
                              : null,
                          onCancel: isPending
                              ? () => _confirmCancel(leave)
                              : null,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLeaveSheet(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Apply Leave'),
      ),
    );
  }
}

// ── _FilterChip ───────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

// ── _LeaveCard ────────────────────────────────────────────────
class _LeaveCard extends StatelessWidget {
  final Map<String, dynamic> leave;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;

  const _LeaveCard({required this.leave, this.onEdit, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final status = leave['status'] as String;
    final leaveType = leave['leave_type'] as String;
    final startDate = leave['start_date'] as String;
    final endDate = leave['end_date'] as String;
    final reason = leave['reason'] as String?;
    final adminNote = leave['admin_note'] as String?;
    final createdAt = leave['created_at'] as String;

    final start = DateTime.parse(startDate);
    final end = DateTime.parse(endDate);
    final days = end.difference(start).inDays + 1;

    final (statusEmoji, statusLabel, statusColor) = switch (status) {
      'approved' => ('🟢', 'Approved', Colors.green),
      'rejected' => ('🔴', 'Rejected', Colors.red),
      'cancelled' => ('⚫', 'Cancelled', Colors.grey),
      _ => ('🟡', 'Pending', Colors.amber),
    };

    final typeLabel = switch (leaveType) {
      'sick' => '🤒 Sick Leave',
      'casual' => '🌴 Casual Leave',
      'emergency' => '🚨 Emergency Leave',
      _ => '📋 Other Leave',
    };

    final isDeletable =
        status == 'approved' || status == 'rejected' || status == 'cancelled';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  typeLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // ── Status badge ─────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$statusEmoji $statusLabel',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
              // ── Edit button (pending only) ────────────────────
              if (onEdit != null) ...[
                const SizedBox(width: 6),
                _ActionIconBtn(
                  icon: Icons.edit_rounded,
                  color: Colors.amber,
                  tooltip: 'Edit',
                  onPressed: onEdit!,
                ),
              ],
              // ── Cancel button (pending only) ──────────────────
              if (onCancel != null) ...[
                const SizedBox(width: 4),
                _ActionIconBtn(
                  icon: Icons.cancel_rounded,
                  color: Colors.red,
                  tooltip: 'Cancel Leave',
                  onPressed: onCancel!,
                ),
              ],
              // ── Swipe hint icon (deletable only) ─────────────
              // WHY show arrow: visual cue for swipe gesture
              if (isDeletable) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.swipe_left_rounded,
                  size: 16,
                  color: statusColor.withValues(alpha: 0.5),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // ── Date range ───────────────────────────────────────
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                startDate == endDate
                    ? DateFormat('dd MMM yyyy').format(start)
                    : '${DateFormat('dd MMM').format(start)} – '
                          '${DateFormat('dd MMM yyyy').format(end)}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$days day${days > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ],
          ),

          // ── Reason ──────────────────────────────────────────
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes_rounded, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    reason,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ],

          // ── Admin note ───────────────────────────────────────
          if (adminNote != null && adminNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.admin_panel_settings_rounded,
                    size: 14,
                    color: statusColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Admin: $adminNote',
                      style: TextStyle(fontSize: 12, color: statusColor),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Applied on ──────────────────────────────────────
          const SizedBox(height: 8),
          Text(
            'Applied ${DateFormat('dd MMM yyyy').format(DateTime.parse(createdAt).toLocal())}',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _ActionIconBtn ────────────────────────────────────────────
class _ActionIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const _ActionIconBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

// ── _LeaveFormSheet ───────────────────────────────────────────
class _LeaveFormSheet extends StatefulWidget {
  final Map<String, dynamic>? existingLeave;
  final VoidCallback onSaved;

  const _LeaveFormSheet({this.existingLeave, required this.onSaved});

  @override
  State<_LeaveFormSheet> createState() => _LeaveFormSheetState();
}

class _LeaveFormSheetState extends State<_LeaveFormSheet> {
  late final TextEditingController _reasonController;
  late String _leaveType;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSubmitting = false;

  bool get _isEditMode => widget.existingLeave != null;

  @override
  void initState() {
    super.initState();
    final leave = widget.existingLeave;
    _leaveType = leave?['leave_type'] as String? ?? 'sick';
    _reasonController = TextEditingController(
      text: leave?['reason'] as String? ?? '',
    );
    _startDate = leave != null
        ? DateTime.parse(leave['start_date'] as String)
        : null;
    _endDate = leave != null
        ? DateTime.parse(leave['end_date'] as String)
        : null;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? _startDate ?? DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end dates')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final reason = _reasonController.text.trim().isEmpty
          ? null
          : _reasonController.text.trim();

      if (_isEditMode) {
        await leaveRepository.updateLeave(
          leaveId: widget.existingLeave!['id'] as String,
          startDate: _startDate!,
          endDate: _endDate!,
          leaveType: _leaveType,
          reason: reason,
        );
      } else {
        await leaveRepository.applyLeave(
          startDate: _startDate!,
          endDate: _endDate!,
          leaveType: _leaveType,
          reason: reason,
        );
      }

      if (!mounted) return;

      // ── Success dialog shown before closing sheet ────────────
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _LeaveSuccessDialog(
          isEdit: _isEditMode,
          leaveType: _leaveType,
          startDate: _startDate!,
          endDate: _endDate!,
          reason: reason,
        ),
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Text('⚠️', style: TextStyle(fontSize: 22)),
                SizedBox(width: 8),
                Text('Cannot Submit', style: TextStyle(fontSize: 16)),
              ],
            ),
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Row(
              children: [
                Icon(
                  _isEditMode ? Icons.edit_rounded : Icons.send_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  _isEditMode ? 'Edit Leave Request' : 'Apply for Leave',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (_isEditMode) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.4),
                  ),
                ),
                child: const Text(
                  '✏️ Only pending requests can be edited',
                  style: TextStyle(fontSize: 11, color: Colors.amber),
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Leave Type',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TypeChip(
                  label: '🤒 Sick',
                  value: 'sick',
                  selected: _leaveType,
                  onTap: (v) => setState(() => _leaveType = v),
                ),
                _TypeChip(
                  label: '🌴 Casual',
                  value: 'casual',
                  selected: _leaveType,
                  onTap: (v) => setState(() => _leaveType = v),
                ),
                _TypeChip(
                  label: '🚨 Emergency',
                  value: 'emergency',
                  selected: _leaveType,
                  onTap: (v) => setState(() => _leaveType = v),
                ),
                _TypeChip(
                  label: '📋 Other',
                  value: 'other',
                  selected: _leaveType,
                  onTap: (v) => setState(() => _leaveType = v),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _DatePickerBox(
                    label: 'Start Date',
                    date: _startDate,
                    onPressed: () => _pickDate(isStart: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DatePickerBox(
                    label: 'End Date',
                    date: _endDate,
                    onPressed: () => _pickDate(isStart: false),
                  ),
                ),
              ],
            ),
            if (_startDate != null && _endDate != null) ...[
              const SizedBox(height: 8),
              Text(
                '${_endDate!.difference(_startDate!).inDays + 1} day(s) selected',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Reason (optional)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Brief reason for leave...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _isEditMode ? Icons.save_rounded : Icons.send_rounded,
                      ),
                label: Text(
                  _isSubmitting
                      ? (_isEditMode ? 'Saving...' : 'Submitting...')
                      : (_isEditMode ? 'Save Changes' : 'Submit Leave Request'),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSubmitting ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _LeaveSuccessDialog ───────────────────────────────────────
class _LeaveSuccessDialog extends StatelessWidget {
  final bool isEdit;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String? reason;

  const _LeaveSuccessDialog({
    required this.isEdit,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    this.reason,
  });

  @override
  Widget build(BuildContext context) {
    final days = endDate.difference(startDate).inDays + 1;

    final typeLabel = switch (leaveType) {
      'sick' => '🤒 Sick Leave',
      'casual' => '🌴 Casual Leave',
      'emergency' => '🚨 Emergency Leave',
      _ => '📋 Other Leave',
    };

    final dateLabel =
        DateFormat('yyyy-MM-dd').format(startDate) ==
            DateFormat('yyyy-MM-dd').format(endDate)
        ? DateFormat('dd MMM yyyy').format(startDate)
        : '${DateFormat('dd MMM').format(startDate)} – '
              '${DateFormat('dd MMM yyyy').format(endDate)}';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: EdgeInsets.zero,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Green header ────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: const BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 10),
                Text(
                  isEdit ? 'Leave Updated!' : 'Leave Request Submitted!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '🟡 Awaiting Admin Approval',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Details ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.event_note_rounded,
                  label: 'Leave Type',
                  value: typeLabel,
                ),
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Date(s)',
                  value: dateLabel,
                ),
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.timelapse_rounded,
                  label: 'Duration',
                  value: '$days day${days > 1 ? 's' : ''}',
                ),
                if (reason != null && reason!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.notes_rounded,
                    label: 'Reason',
                    value: reason!,
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: Colors.blue,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You will be notified once admin reviews your request.',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Got it button ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Got it!',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _DetailRow ────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── _TypeChip ─────────────────────────────────────────────────
class _TypeChip extends StatelessWidget {
  final String label, value, selected;
  final ValueChanged<String> onTap;

  const _TypeChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.3),
                ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

// ── _DatePickerBox ────────────────────────────────────────────
class _DatePickerBox extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onPressed;

  const _DatePickerBox({
    required this.label,
    required this.date,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: date != null
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: date != null
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  date != null
                      ? DateFormat('dd MMM yyyy').format(date!)
                      : 'Select',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: date != null
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
