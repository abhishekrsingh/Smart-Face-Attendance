import 'package:face_track/features/admin/data/admin_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class AdminLeavePage extends ConsumerStatefulWidget {
  const AdminLeavePage({super.key});

  @override
  ConsumerState<AdminLeavePage> createState() => _AdminLeavePageState();
}

class _AdminLeavePageState extends ConsumerState<AdminLeavePage> {
  List<Map<String, dynamic>> _leaves = [];
  bool _isLoading = true;
  String? _error;
  // WHY default to pending: admin's primary job here is
  // to action pending leaves — show them first
  String _filter = 'pending';

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
      final data = await adminRepository.getLeaveRequests();
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

  int get _pendingCount =>
      _leaves.where((l) => l['status'] == 'pending').length;

  // ── _showActionSheet() ───────────────────────────────────────
  // PURPOSE: Admin approve or reject with optional note
  // action = 'approved' or 'rejected'
  Future<void> _showActionSheet(
    Map<String, dynamic> leave,
    String action,
  ) async {
    final noteController = TextEditingController();
    bool isSaving = false;
    final employeeName = leave['full_name'] ?? 'Employee';
    final leaveType = leave['leave_type'] as String;
    final isApproving = action == 'approved';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────
                Row(
                  children: [
                    Icon(
                      isApproving
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: isApproving ? Colors.green : Colors.red,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${isApproving ? 'Approve' : 'Reject'} Leave',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$employeeName · '
                            '${_leaveTypeLabel(leaveType)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),

                const Divider(),
                const SizedBox(height: 12),

                // ── Admin Note ───────────────────────────────
                const Text(
                  'Admin Note (optional)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: isApproving
                        ? 'e.g. Approved. Enjoy your leave!'
                        : 'e.g. Rejected due to project deadline.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Confirm Button ───────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            isApproving
                                ? Icons.check_rounded
                                : Icons.close_rounded,
                          ),
                    label: Text(
                      isSaving
                          ? (isApproving ? 'Approving...' : 'Rejecting...')
                          : (isApproving ? 'Approve Leave' : 'Reject Leave'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isApproving ? Colors.green : Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isSaving
                        ? null
                        : () async {
                            setSheetState(() => isSaving = true);
                            try {
                              await adminRepository.updateLeaveStatus(
                                leaveId: leave['id'] as String,
                                status: action,
                                adminNote: noteController.text.trim().isEmpty
                                    ? null
                                    : noteController.text.trim(),
                              );
                              if (ctx.mounted) Navigator.of(ctx).pop();
                              await _loadLeaves();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${isApproving ? '✅ Approved' : '❌ Rejected'}: '
                                      '$employeeName\'s '
                                      '${_leaveTypeLabel(leaveType)} leave',
                                    ),
                                    backgroundColor: isApproving
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                );
                              }
                            } catch (e) {
                              setSheetState(() => isSaving = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    noteController.dispose();
  }

  String _leaveTypeLabel(String type) => switch (type) {
    'sick' => '🤒 Sick',
    'casual' => '🌴 Casual',
    'emergency' => '🚨 Emergency',
    _ => '📋 Other',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Leave Requests'),
            if (_pendingCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_pendingCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadLeaves,
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
                              ? 'No leave requests'
                              : 'No $_filter leave requests',
                          style: const TextStyle(color: Colors.grey),
                        ),
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
                        final isPending = leave['status'] == 'pending';
                        return _AdminLeaveCard(
                          leave: leave,
                          onApprove: isPending
                              ? () => _showActionSheet(leave, 'approved')
                              : null,
                          onReject: isPending
                              ? () => _showActionSheet(leave, 'rejected')
                              : null,
                        );
                      },
                    ),
                  ),
          ),
        ],
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

// ── _AdminLeaveCard ───────────────────────────────────────────
class _AdminLeaveCard extends StatelessWidget {
  final Map<String, dynamic> leave;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _AdminLeaveCard({required this.leave, this.onApprove, this.onReject});

  @override
  Widget build(BuildContext context) {
    final status = leave['status'] as String;
    final leaveType = leave['leave_type'] as String;
    final startDate = leave['start_date'] as String;
    final endDate = leave['end_date'] as String;
    final reason = leave['reason'] as String?;
    final adminNote = leave['admin_note'] as String?;
    final employeeName = leave['full_name'] as String? ?? 'Unknown';
    final employeeEmail = leave['email'] as String? ?? '';
    final createdAt = leave['created_at'] as String;
    final isPending = onApprove != null;

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
          // ── Header: Employee + Status ────────────────────
          Row(
            children: [
              // ── Avatar ──────────────────────────────────
              CircleAvatar(
                radius: 18,
                backgroundColor: statusColor.withValues(alpha: 0.15),
                child: Text(
                  employeeName.isNotEmpty ? employeeName[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employeeName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      employeeEmail,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              // ── Status badge ─────────────────────────────
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
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // ── Leave Type + Dates ───────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      typeLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 13,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          startDate == endDate
                              ? DateFormat('dd MMM yyyy').format(start)
                              : '${DateFormat('dd MMM').format(start)}'
                                    ' – ${DateFormat('dd MMM yyyy').format(end)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$days day${days > 1 ? 's' : ''}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Reason ──────────────────────────────────────
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes_rounded, size: 13, color: Colors.grey),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    reason,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ],

          // ── Admin note (already actioned) ────────────────
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
                    size: 13,
                    color: statusColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Your note: $adminNote',
                      style: TextStyle(fontSize: 12, color: statusColor),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Applied on ──────────────────────────────────
          const SizedBox(height: 8),
          Text(
            'Applied ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(createdAt).toLocal())}',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),

          // ── Approve / Reject buttons (pending only) ───────
          // FIX: Both wrapped in SizedBox(height: 44) +
          // minimumSize → always exactly same height & width
          if (isPending) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                // ── Reject ──────────────────────────────────
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Colors.red,
                      ),
                      label: const Text(
                        'Reject',
                        style: TextStyle(color: Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: onReject,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // ── Approve ─────────────────────────────────
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: onApprove,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
