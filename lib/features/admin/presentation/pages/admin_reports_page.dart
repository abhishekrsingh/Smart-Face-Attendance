// ============================================================
// admin_reports_page.dart
// ============================================================

import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/admin_repository.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  List<Map<String, dynamic>> _reportData = [];
  bool _isLoading = true;
  bool _isExporting = false;
  String? _error;

  String _sortColumn = 'full_name';
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await adminRepository.getMonthlyReport(_selectedMonth);
      if (mounted) {
        setState(() {
          _reportData = data;
          _isLoading = false;
        });
        _sortData();
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

  void _sortBy(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = column == 'full_name';
      }
      _sortData();
    });
  }

  void _sortData() {
    _reportData.sort((a, b) {
      dynamic aVal = a[_sortColumn];
      dynamic bVal = b[_sortColumn];
      if (aVal is String) aVal = aVal.toLowerCase();
      if (bVal is String) bVal = bVal.toLowerCase();
      final cmp = Comparable.compare(aVal as Comparable, bVal as Comparable);
      return _sortAscending ? cmp : -cmp;
    });
  }

  bool get _canGoNext {
    final now = DateTime.now();
    return _selectedMonth.year < now.year ||
        (_selectedMonth.year == now.year && _selectedMonth.month < now.month);
  }

  void _previousMonth() {
    setState(
      () => _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
      ),
    );
    _loadReport();
  }

  void _nextMonth() {
    if (!_canGoNext) return;
    setState(
      () => _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
      ),
    );
    _loadReport();
  }

  int get _totalPresent =>
      _reportData.fold(0, (s, e) => s + (e['present_days'] as int));
  int get _totalWfh =>
      _reportData.fold(0, (s, e) => s + (e['wfh_days'] as int));
  int get _totalAbsent =>
      _reportData.fold(0, (s, e) => s + (e['absent_days'] as int));
  double get _totalHours =>
      _reportData.fold(0.0, (s, e) => s + (e['total_hours'] as double));

  // ── Export CSV → save directly to Downloads folder ─────────
  // WHY no share_plus: user wants direct download, not share sheet
  // WHY /storage/emulated/0/Download: standard Android public Downloads
  //   folder visible in Files app without any extra step
  Future<void> _exportCsv() async {
    setState(() => _isExporting = true);
    try {
      final rows = <List<dynamic>>[
        [
          'Employee Name',
          'Email',
          'Department',
          'Present Days',
          'WFH Days',
          'Absent Days',
          'Late Days',
          'Total Hours',
        ],
        ..._reportData.map(
          (e) => [
            e['full_name'] ?? '',
            e['email'] ?? '',
            e['department'] ?? '',
            e['present_days'] ?? 0,
            e['wfh_days'] ?? 0,
            e['absent_days'] ?? 0,
            e['late_days'] ?? 0,
            e['total_hours'] ?? 0.0,
          ],
        ),
      ];

      final csvString = const ListToCsvConverter().convert(rows);
      final month = DateFormat('MMM_yyyy').format(_selectedMonth);
      final fileName = 'attendance_report_$month.csv';

      // ── Try Downloads first, fallback to app documents ──────
      File savedFile;
      final downloadsDir = Directory('/storage/emulated/0/Download');

      if (await downloadsDir.exists()) {
        savedFile = File('${downloadsDir.path}/$fileName');
      } else {
        // WHY fallback: some emulators don't expose /Download path
        final appDir = await getApplicationDocumentsDirectory();
        savedFile = File('${appDir.path}/$fileName');
      }

      await savedFile.writeAsString(csvString);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Saved to Downloads!',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        fileName,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showDrillDown(Map<String, dynamic> employee) {
    final records = (employee['records'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    records.sort(
      (a, b) => (b['date'] as String).compareTo(a['date'] as String),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, controller) => Column(
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.person_rounded, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employee['full_name'] ?? 'Employee',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${employee['department'] ?? ''} • '
                          '${DateFormat('MMMM yyyy').format(_selectedMonth)}',
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
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            // Mini summary
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MiniStat(
                    label: 'Present',
                    value: '${employee['present_days']}d',
                    color: Colors.green,
                  ),
                  _MiniStat(
                    label: 'WFH',
                    value: '${employee['wfh_days']}d',
                    color: Colors.blue,
                  ),
                  _MiniStat(
                    label: 'Absent',
                    value: '${employee['absent_days']}d',
                    color: Colors.red,
                  ),
                  _MiniStat(
                    label: 'Hours',
                    value: '${employee['total_hours']}h',
                    color: Colors.purple,
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            // Daily records
            Expanded(
              child: records.isEmpty
                  ? const Center(
                      child: Text(
                        'No records this month',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: records.length,
                      itemBuilder: (_, i) => _DrillDownTile(record: records[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Report'),
        centerTitle: true,
        actions: [
          _isExporting
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.download_rounded),
                  tooltip: 'Download CSV',
                  onPressed: _isLoading || _reportData.isEmpty
                      ? null
                      : _exportCsv,
                ),
        ],
      ),
      body: Column(
        children: [
          _MonthBar(
            month: _selectedMonth,
            canGoNext: _canGoNext,
            onPrevious: _previousMonth,
            onNext: _nextMonth,
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
                          onPressed: _loadReport,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _reportData.isEmpty
                ? const Center(
                    child: Text(
                      'No data for this month',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadReport,
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        _OverallSummary(
                          totalEmployees: _reportData.length,
                          present: _totalPresent,
                          wfh: _totalWfh,
                          absent: _totalAbsent,
                          hours: _totalHours,
                          month: _selectedMonth,
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: Text(
                            '${_reportData.length} Employees  •  Tap row for daily details',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        _TableHeader(
                          sortColumn: _sortColumn,
                          sortAscending: _sortAscending,
                          onSort: _sortBy,
                        ),
                        ..._reportData.map(
                          (emp) => _EmployeeRow(
                            employee: emp,
                            onTap: () => _showDrillDown(emp),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ElevatedButton.icon(
                            icon: _isExporting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.download_rounded),
                            label: Text(
                              _isExporting
                                  ? 'Saving...'
                                  : '📥  Download as CSV',
                            ),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _isExporting ? null : _exportCsv,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── _MonthBar ─────────────────────────────────────────────────
class _MonthBar extends StatelessWidget {
  final DateTime month;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _MonthBar({
    required this.month,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrentMonth =
        month.year == DateTime.now().year &&
        month.month == DateTime.now().month;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: onPrevious,
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isCurrentMonth ? 'Current Month' : 'Viewing',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.7),
                        ),
                      ),
                      Text(
                        DateFormat('MMMM yyyy').format(month),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right_rounded,
              color: canGoNext ? null : Colors.grey.withValues(alpha: 0.3),
            ),
            onPressed: canGoNext ? onNext : null,
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _OverallSummary ───────────────────────────────────────────
class _OverallSummary extends StatelessWidget {
  final int totalEmployees;
  final int present;
  final int wfh;
  final int absent;
  final double hours;
  final DateTime month;

  const _OverallSummary({
    required this.totalEmployees,
    required this.present,
    required this.wfh,
    required this.absent,
    required this.hours,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '📊 ${DateFormat('MMMM yyyy').format(month)} Overview',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '👥 $totalEmployees staff',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SummaryItem(
                emoji: '🏢',
                label: 'Present',
                value: '$present',
                color: Colors.green,
              ),
              _SummaryItem(
                emoji: '🏠',
                label: 'WFH',
                value: '$wfh',
                color: Colors.blue,
              ),
              _SummaryItem(
                emoji: '❌',
                label: 'Absent',
                value: '$absent',
                color: Colors.red,
              ),
              _SummaryItem(
                emoji: '🕐',
                label: 'Hours',
                value: '${hours.toStringAsFixed(0)}h',
                color: Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8)),
        ),
      ],
    );
  }
}

// ── _TableHeader ──────────────────────────────────────────────
class _TableHeader extends StatelessWidget {
  final String sortColumn;
  final bool sortAscending;
  final ValueChanged<String> onSort;

  const _TableHeader({
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
  });

  Widget _headerCell(
    BuildContext ctx,
    String label,
    String column, {
    bool rightAlign = false,
  }) {
    final isActive = sortColumn == column;
    return InkWell(
      onTap: () => onSort(column),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Row(
          mainAxisAlignment: rightAlign
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isActive
                    ? Theme.of(ctx).colorScheme.primary
                    : Theme.of(
                        ctx,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            if (isActive)
              Icon(
                sortAscending
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 10,
                color: Theme.of(ctx).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: _headerCell(context, 'NAME', 'full_name')),
          Expanded(
            child: _headerCell(context, '🏢', 'present_days', rightAlign: true),
          ),
          Expanded(
            child: _headerCell(context, '🏠', 'wfh_days', rightAlign: true),
          ),
          Expanded(
            child: _headerCell(context, '❌', 'absent_days', rightAlign: true),
          ),
          Expanded(
            child: _headerCell(context, '⚠️', 'late_days', rightAlign: true),
          ),
          Expanded(
            child: _headerCell(context, '🕐h', 'total_hours', rightAlign: true),
          ),
        ],
      ),
    );
  }
}

// ── _EmployeeRow ──────────────────────────────────────────────
class _EmployeeRow extends StatelessWidget {
  final Map<String, dynamic> employee;
  final VoidCallback onTap;

  const _EmployeeRow({required this.employee, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = employee['full_name'] as String? ?? '—';
    final department = employee['department'] as String? ?? '';
    final present = employee['present_days'] as int;
    final wfh = employee['wfh_days'] as int;
    final absent = employee['absent_days'] as int;
    final late = employee['late_days'] as int;
    final hours = employee['total_hours'] as double;

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (department.isNotEmpty)
                    Text(
                      department,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '$present',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '$wfh',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '$absent',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: absent > 3
                        ? Colors.red
                        : Colors.red.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '$late',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: late > 0
                        ? Colors.orange
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  hours.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _DrillDownTile ────────────────────────────────────────────
class _DrillDownTile extends StatelessWidget {
  final Map<String, dynamic> record;
  const _DrillDownTile({required this.record});

  String? _formatTime(String? iso) {
    if (iso == null) return null;
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final date = record['date'] as String;
    final status = record['status'] as String?;
    final isLate = record['is_late'] as bool? ?? false;
    final totalHours = (record['total_hours'] as num?)?.toDouble();
    final checkIn = _formatTime(record['check_in_time'] as String?);
    final checkOut = _formatTime(record['check_out_time'] as String?);

    final (emoji, label, color) = switch (status) {
      'present' => ('🏢', 'Present', Colors.green),
      'wfh' => ('🏠', 'WFH', Colors.blue),
      'absent' => ('❌', 'Absent', Colors.red),
      _ => ('—', 'Unknown', Colors.grey),
    };

    final dt = DateTime.parse(date);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Text(
                  DateFormat('dd').format(dt),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  DateFormat('EEE').format(dt),
                  style: TextStyle(
                    fontSize: 10,
                    color: color.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    if (isLate) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '⚠️ Late',
                          style: TextStyle(fontSize: 9, color: Colors.amber),
                        ),
                      ),
                    ],
                  ],
                ),
                if (checkIn != null)
                  Row(
                    children: [
                      Text(
                        '$checkIn${checkOut != null ? ' → $checkOut' : ' → —'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      if (totalHours != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${totalHours.toStringAsFixed(1)}h',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── _MiniStat ─────────────────────────────────────────────────
class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7)),
        ),
      ],
    );
  }
}
