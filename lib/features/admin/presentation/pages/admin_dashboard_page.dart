// ============================================================
// admin_dashboard_page.dart
// SUMMARY BAR: Only 3 statuses — present, wfh, absent
// No pending, no not_marked — clean 3-chip summary only
// ============================================================

import 'package:face_track/features/admin/data/admin_repository.dart';
import 'package:face_track/features/attendance/data/attendance_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  String _selectedFilter = 'all'; // all | present | wfh | absent

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
      final data = await adminRepository.getEmployeesWithTodayStatus();
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

  // WHY filter: admin can tap a chip to view only that group
  List<Map<String, dynamic>> get _filteredEmployees {
    if (_selectedFilter == 'all') return _employees;
    return _employees.where((e) => e['status'] == _selectedFilter).toList();
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
                // ── 3-chip Summary Bar ───────────────────────
                _SummaryBar(
                  employees: _employees,
                  selectedFilter: _selectedFilter,
                  onFilterChanged: (f) => setState(() => _selectedFilter = f),
                ),

                // ── Employee List ────────────────────────────
                Expanded(
                  child: _filteredEmployees.isEmpty
                      ? const Center(child: Text('No employees found'))
                      : RefreshIndicator(
                          onRefresh: _loadEmployees,
                          child: ListView.builder(
                            itemCount: _filteredEmployees.length,
                            itemBuilder: (_, i) =>
                                EmployeeTile(employee: _filteredEmployees[i]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

// ── _SummaryBar ───────────────────────────────────────────────
// PURPOSE: Shows 3 status counts at top of admin page.
// DESIGN: Tappable chips → filters list below.
// WHY only 3: present/wfh/absent are the only confirmed
// statuses. Employees with no record are simply not shown
// in any chip count.
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

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          // ── Total Employees line ─────────────────────────────
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
          const SizedBox(height: 10),

          // ── 3 Status Chips ───────────────────────────────────
          // WHY tappable: tap chip → filter list to that status
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
// WHY separate widget: reused 3 times in summary bar.
// isSelected: tapping a chip highlights it + filters the list.
// Tap same chip again → deselect → show all employees.
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
          // WHY fill when selected: clear visual feedback
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
