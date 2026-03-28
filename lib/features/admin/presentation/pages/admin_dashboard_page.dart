import 'package:face_track/features/admin/data/admin_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/employee_tile.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  List<Map<String, dynamic>> _employees = [];
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'all';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await adminRepository.fetchEmployeesWithAttendance(
        _selectedDate,
      );
      if (mounted) {
        setState(() {
          _employees = data;
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      helpText: 'Select Date',
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedFilter = 'all';
      });
      await _loadEmployees();
    }
  }

  List<Map<String, dynamic>> get _filteredEmployees {
    if (_selectedFilter == 'all') return _employees;
    return _employees.where((e) => e['status'] == _selectedFilter).toList();
  }

  // ── _showEditDialog() ───────────────────────────────────────
  // PURPOSE: Admin corrects employee attendance manually
  //
  // Scenario 1 — Wrong Status (GPS inaccuracy / VPN):
  //   Employee GPS said WFH but was actually in office
  //   Admin taps ✏️ → changes WFH → Present → Save
  //   DB record corrected immediately ✅
  //
  // Scenario 2 — Forgot to Check Out:
  //   Employee left at 6 PM, forgot to tap Check Out
  //   Admin taps ✏️ → ticks "Clear checkout time"
  //   → check_out_time set to null in DB
  //   → employee can now check out from their phone ✅
  //
  // WHY attendance_id not employee id:
  //   employee['id'] = user UUID from profiles table
  //   employee['attendance_id'] = attendance record UUID
  //   updateAttendance() needs attendance record UUID
  //   Using user UUID → 0 rows matched → silent fail ❌
  Future<void> _showEditDialog(Map<String, dynamic> employee) async {
    // ── Scenario 1/2 guard: no record = nothing to edit ──────
    // WHY check attendance_id not status: employee may have
    // a record with null status (edge case from old data)
    final attendanceId = employee['attendance_id'] as String?;
    final employeeName = employee['full_name'] ?? 'Employee';

    if (attendanceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$employeeName has no attendance record for '
            '${DateFormat('dd MMM yyyy').format(_selectedDate)}.\n'
            'Cannot edit what does not exist.',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    String selectedStatus = employee['status'] as String? ?? 'present';
    bool clearCheckout = false;
    bool isSaving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
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
                  // ── Header ────────────────────────────────
                  Row(
                    children: [
                      const Icon(Icons.edit_rounded, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Attendance — $employeeName',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            // WHY show date: admin always knows
                            // which date they are correcting
                            Text(
                              DateFormat(
                                'EEE, dd MMM yyyy',
                              ).format(_selectedDate),
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
                  const SizedBox(height: 8),

                  // ── Current status ─────────────────────────
                  // WHY show current: admin sees what they
                  // are changing FROM — avoids accidental edits
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Current Status:  ',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _statusLabel(employee['status'] as String?),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(employee['status'] as String?),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Scenario 1: Status Dropdown ─────────────
                  // USE CASE: GPS was wrong / VPN changed location
                  // Admin changes WFH → Present or vice versa
                  const Text(
                    'Change Status',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'present',
                        child: Row(
                          children: [
                            Text('🏢 ', style: TextStyle(fontSize: 16)),
                            Text('Present — Work From Office'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'wfh',
                        child: Row(
                          children: [
                            Text('🏠 ', style: TextStyle(fontSize: 16)),
                            Text('WFH — Work From Home'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'absent',
                        child: Row(
                          children: [
                            Text('❌ ', style: TextStyle(fontSize: 16)),
                            Text('Absent'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() => selectedStatus = val);
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // ── Scenario 2: Clear Checkout ──────────────
                  // USE CASE: Employee forgot to check out
                  //   check_out_time exists → employee stuck
                  //   Admin ticks this → clears checkout
                  //   Employee can now check out from their phone
                  // WHY only show when checked out: no checkout
                  //   to clear if employee hasn't checked out yet
                  if (employee['check_out_time'] != null) ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Employee checked out at '
                            '${_formatTime(employee['check_out_time'] as String?)}. '
                            'Clear if they need to check out again.',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    CheckboxListTile(
                      value: clearCheckout,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Clear checkout time',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: const Text(
                        'Removes checkout → employee can check out again from their phone',
                        style: TextStyle(fontSize: 11),
                      ),
                      onChanged: (val) {
                        setSheetState(() => clearCheckout = val ?? false);
                      },
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Save ────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(isSaving ? 'Saving...' : 'Save Changes'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              setSheetState(() => isSaving = true);
                              try {
                                // WHY attendance_id not employee id:
                                // must update attendance row not profile row
                                await adminRepository.updateAttendance(
                                  attendanceId: attendanceId,
                                  status: selectedStatus,
                                  // Scenario 2: null clears checkout
                                  // so employee can re-checkout
                                  checkOutTime: clearCheckout
                                      ? null
                                      : employee['check_out_time'] as String?,
                                );

                                if (ctx.mounted) Navigator.of(ctx).pop();
                                await _loadEmployees();

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '✅ ${employeeName}\'s attendance updated to '
                                        '${_statusLabel(selectedStatus)}',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setSheetState(() => isSaving = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to update: $e'),
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
        );
      },
    );
  }

  // ── Helpers ─────────────────────────────────────────────────
  String _statusLabel(String? status) {
    switch (status) {
      case 'present':
        return '🏢 Present';
      case 'wfh':
        return '🏠 WFH';
      case 'absent':
        return '❌ Absent';
      default:
        return '— No Record';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'present':
        return Colors.green;
      case 'wfh':
        return Colors.blue;
      case 'absent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String? _formatTime(String? iso) {
    if (iso == null) return null;
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadEmployees,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async =>
                await Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadEmployees,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // ── Date Picker Bar ────────────────────────
                _DatePickerBar(
                  selectedDate: _selectedDate,
                  isToday: _isToday,
                  onPickDate: _pickDate,
                  onGoToToday: () {
                    setState(() {
                      _selectedDate = DateTime.now();
                      _selectedFilter = 'all';
                    });
                    _loadEmployees();
                  },
                ),

                // ── Summary Chips ──────────────────────────
                _SummaryBar(
                  employees: _employees,
                  selectedFilter: _selectedFilter,
                  onFilterChanged: (f) => setState(() => _selectedFilter = f),
                ),

                // ── Employee List ──────────────────────────
                Expanded(
                  child: _filteredEmployees.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.event_busy_rounded,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _selectedFilter == 'all'
                                    ? 'No records for ${DateFormat('dd MMM yyyy').format(_selectedDate)}'
                                    : 'No $_selectedFilter records for this date',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadEmployees,
                          child: ListView.builder(
                            itemCount: _filteredEmployees.length,
                            itemBuilder: (_, i) {
                              final emp = _filteredEmployees[i];
                              return EmployeeTile(
                                employee: emp,
                                // WHY only show edit when attendance
                                // record exists: can't edit what
                                // hasn't been marked yet
                                onEditTap: emp['attendance_id'] != null
                                    ? () => _showEditDialog(emp)
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

// ── _DatePickerBar ────────────────────────────────────────────
class _DatePickerBar extends StatelessWidget {
  final DateTime selectedDate;
  final bool isToday;
  final VoidCallback onPickDate;
  final VoidCallback onGoToToday;

  const _DatePickerBar({
    required this.selectedDate,
    required this.isToday,
    required this.onPickDate,
    required this.onGoToToday,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onPickDate,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isToday ? 'Today' : 'Viewing',
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.7),
                          ),
                        ),
                        Text(
                          DateFormat('EEE, dd MMM yyyy').format(selectedDate),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!isToday) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onGoToToday,
              icon: const Icon(Icons.today_rounded, size: 16),
              label: const Text('Today'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── _SummaryBar ───────────────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  final List<Map<String, dynamic>> employees;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  const _SummaryBar({
    required this.employees,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final total = employees.length;
    final present = employees.where((e) => e['status'] == 'present').length;
    final wfh = employees.where((e) => e['status'] == 'wfh').length;
    final absent = employees.where((e) => e['status'] == 'absent').length;
    final notMarked = employees.where((e) => e['attendance_id'] == null).length;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '👥 $total Employees',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              if (notMarked > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    '⏳ $notMarked not marked',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatChip(
                label: 'Present',
                count: present,
                color: Colors.green,
                isSelected: selectedFilter == 'present',
                onTap: () => onFilterChanged(
                  selectedFilter == 'present' ? 'all' : 'present',
                ),
              ),
              _StatChip(
                label: 'WFH',
                count: wfh,
                color: Colors.blue,
                isSelected: selectedFilter == 'wfh',
                onTap: () =>
                    onFilterChanged(selectedFilter == 'wfh' ? 'all' : 'wfh'),
              ),
              _StatChip(
                label: 'Absent',
                count: absent,
                color: Colors.red,
                isSelected: selectedFilter == 'absent',
                onTap: () => onFilterChanged(
                  selectedFilter == 'absent' ? 'all' : 'absent',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── _StatChip ─────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.35),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
