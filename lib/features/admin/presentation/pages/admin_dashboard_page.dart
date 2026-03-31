import 'package:face_track/features/admin/data/admin_repository.dart';
import 'package:face_track/features/admin/presentation/pages/admin_reports_page.dart';
import 'package:face_track/features/admin/presentation/pages/admin_leave_page.dart';
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

  // ── _showEditDialog() ─────────────────────────────────────
  Future<void> _showEditDialog(Map<String, dynamic> employee) async {
    final attendanceId = employee['attendance_id'] as String?;
    final employeeName = employee['full_name'] as String? ?? 'Employee';

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
                  // ── Header ─────────────────────────────
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

                  // ── Current Status ─────────────────────
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

                  // ── Change Status Dropdown ─────────────
                  const Text(
                    'Change Status',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                    ),
                    child: DropdownButton<String>(
                      value: selectedStatus,
                      isExpanded: true,
                      // WHY SizedBox(): InputDecorator already
                      //   draws the border — hide default
                      //   underline to avoid double border
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(
                          value: 'present',
                          child: Row(
                            children: [
                              Text('🏢 ', style: TextStyle(fontSize: 16)),
                              // WHY Flexible not Expanded:
                              //   DropdownMenuItem wraps its
                              //   child in its own internal Row
                              //   — nested Expanded breaks
                              //   constraints and throws errors.
                              //   Flexible softly constrains
                              //   the text, ellipsis prevents
                              //   the 3.4px overflow
                              Flexible(
                                child: Text(
                                  'Present — Work From Office',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        DropdownMenuItem(
                          value: 'wfh',
                          child: Row(
                            children: [
                              Text('🏠 ', style: TextStyle(fontSize: 16)),
                              Flexible(
                                child: Text(
                                  'WFH — Work From Home',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        DropdownMenuItem(
                          value: 'absent',
                          child: Row(
                            children: [
                              Text('❌ ', style: TextStyle(fontSize: 16)),
                              Flexible(
                                child: Text(
                                  'Absent',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
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
                  ),

                  const SizedBox(height: 16),

                  // ── Clear Checkout ─────────────────────
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
                        'Removes checkout → employee can '
                        'check out again from their phone',
                        style: TextStyle(fontSize: 11),
                      ),
                      onChanged: (val) {
                        setSheetState(() => clearCheckout = val ?? false);
                      },
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Save Button ────────────────────────
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
                                await adminRepository.updateAttendance(
                                  attendanceId: attendanceId,
                                  status: selectedStatus,
                                  checkOutTime: clearCheckout
                                      ? null
                                      : employee['check_out_time'] as String?,
                                );
                                if (ctx.mounted) {
                                  Navigator.of(ctx).pop();
                                }
                                await _loadEmployees();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '✅ $employeeName\'s '
                                        'attendance updated to '
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
                                      content: Text('Failed: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────
  String _statusLabel(String? status) => switch (status) {
    'present' => '🏢 Present',
    'wfh' => '🏠 WFH',
    'absent' => '❌ Absent',
    _ => '— No Record',
  };

  Color _statusColor(String? status) => switch (status) {
    'present' => Colors.green,
    'wfh' => Colors.blue,
    'absent' => Colors.red,
    _ => Colors.grey,
  };

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

  // ── build() ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_available_rounded),
            tooltip: 'Leave Requests',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminLeavePage()),
            ).then((_) => _loadEmployees()),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Monthly Reports',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminReportsPage()),
            ),
          ),
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
                // ── Date Picker Bar ──────────────────
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

                // ── Summary Chips ────────────────────
                _SummaryBar(
                  employees: _employees,
                  selectedFilter: _selectedFilter,
                  onFilterChanged: (f) => setState(() => _selectedFilter = f),
                ),

                // ── Employee List ────────────────────
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
                                    ? 'No records for '
                                          '${DateFormat('dd MMM yyyy').format(_selectedDate)}'
                                    : 'No $_selectedFilter '
                                          'records for this date',
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
