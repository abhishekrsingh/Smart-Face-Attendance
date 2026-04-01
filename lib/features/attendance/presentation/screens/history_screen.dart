import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../data/attendance_repository.dart';
import '../../../../features/tasks/presentation/providers/task_provider.dart'; // ← NEW
import '../../../../features/tasks/presentation/widgets/task_section.dart'; // ← NEW

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;
  String? _error;

  final ScrollController _scrollController = ScrollController();
  final Map<String, Map<String, dynamic>> _recordMap = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadHistory();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await attendanceRepository.getMonthlyAttendance(
        _focusedMonth,
      );
      if (mounted) {
        final map = <String, Map<String, dynamic>>{};
        for (final r in data) map[r['date'] as String] = r;
        setState(() {
          _records = data;
          _recordMap
            ..clear()
            ..addAll(map);
          _isLoading = false;
        });

        // ← NEW: load tasks for all days in this month
        // WHY after setState: _allDaysInMonth uses _focusedMonth
        //   which is already set; one batch call covers all days
        //   including weekends that may have tasks but no attendance
        final allDates = _allDaysInMonth.map((e) => e.dateStr).toList();
        if (allDates.isNotEmpty) {
          ref.read(taskProvider.notifier).loadForDates(allDates);
        }
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

  // ── Month navigation ──────────────────────────────────────
  bool get _canGoNext {
    final now = DateTime.now();
    return _focusedMonth.year < now.year ||
        (_focusedMonth.year == now.year && _focusedMonth.month < now.month);
  }

  void _previousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
      _selectedDay = null;
    });
    _loadHistory();
  }

  void _nextMonth() {
    if (!_canGoNext) return;
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
      _selectedDay = null;
    });
    _loadHistory();
  }

  // ── Helpers ───────────────────────────────────────────────
  String _dateStr(DateTime d) =>
      '${d.year}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic>? _recordFor(DateTime day) => _recordMap[_dateStr(day)];

  Color _dotColor(DateTime day) {
    final r = _recordFor(day);
    if (r == null) return Colors.transparent;
    return switch (r['status'] as String?) {
      'present' => Colors.green,
      'wfh' => Colors.blue,
      'absent' => Colors.red,
      _ => Colors.grey,
    };
  }

  // ── Calendar bottom sheet ─────────────────────────────────
  Future<void> _showCalendarSheet() async {
    DateTime sheetFocused = _focusedMonth;
    DateTime? sheetSelected = _selectedDay;

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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Pick a Date',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const Divider(),
                  TableCalendar(
                    firstDay: DateTime(2024, 1, 1),
                    lastDay: DateTime.now(),
                    focusedDay: sheetFocused,
                    selectedDayPredicate: (day) =>
                        sheetSelected != null && isSameDay(day, sheetSelected!),
                    availableGestures: AvailableGestures.horizontalSwipe,
                    pageAnimationEnabled: true,
                    pageAnimationCurve: Curves.easeInOut,
                    pageAnimationDuration: const Duration(milliseconds: 300),
                    calendarFormat: CalendarFormat.month,
                    availableCalendarFormats: const {
                      CalendarFormat.month: 'Month',
                    },
                    onPageChanged: (focused) {
                      final now = DateTime.now();
                      if (focused.isAfter(DateTime(now.year, now.month)))
                        return;
                      setSheetState(() => sheetFocused = focused);
                    },
                    onDaySelected: (selected, focused) {
                      if (selected.isAfter(DateTime.now())) return;
                      setSheetState(() {
                        sheetSelected = selected;
                        sheetFocused = focused;
                      });
                      Future.delayed(const Duration(milliseconds: 150), () {
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        final newMonth = DateTime(
                          selected.year,
                          selected.month,
                        );
                        final monthChanged =
                            newMonth.year != _focusedMonth.year ||
                            newMonth.month != _focusedMonth.month;
                        setState(() {
                          _selectedDay = selected;
                          _focusedMonth = newMonth;
                        });
                        if (monthChanged) {
                          _loadHistory().then((_) => _scrollToDay(selected));
                        } else {
                          _scrollToDay(selected);
                        }
                      });
                    },
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      todayTextStyle: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      selectedTextStyle: const TextStyle(color: Colors.white),
                      outsideDaysVisible: false,
                      markersMaxCount: 1,
                      markerDecoration: const BoxDecoration(),
                      markerMargin: EdgeInsets.zero,
                      cellMargin: const EdgeInsets.all(4),
                      weekendTextStyle: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      disabledTextStyle: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.2),
                      ),
                    ),
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (ctx, day, _) => _calendarDayCell(
                        ctx,
                        day,
                        isSelected: false,
                        isToday: false,
                      ),
                      todayBuilder: (ctx, day, _) => _calendarDayCell(
                        ctx,
                        day,
                        isSelected: false,
                        isToday: true,
                      ),
                      selectedBuilder: (ctx, day, _) => _calendarDayCell(
                        ctx,
                        day,
                        isSelected: true,
                        isToday: false,
                      ),
                      disabledBuilder: (ctx, day, _) => Center(
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(
                              ctx,
                            ).colorScheme.onSurface.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                    ),
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      leftChevronIcon: Icon(
                        Icons.chevron_left_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      rightChevronIcon: Icon(
                        Icons.chevron_right_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      weekendStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LegendDot(color: Colors.green, label: 'Present'),
                      const SizedBox(width: 16),
                      _LegendDot(color: Colors.blue, label: 'WFH'),
                      const SizedBox(width: 16),
                      _LegendDot(color: Colors.red, label: 'Absent'),
                      const SizedBox(width: 16),
                      _LegendDot(color: Colors.grey, label: 'No Record'),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Scroll to day ─────────────────────────────────────────
  void _scrollToDay(DateTime day) {
    final entries = _allDaysInMonth;
    final idx = entries.indexWhere(
      (e) =>
          e.date.day == day.day &&
          e.date.month == day.month &&
          e.date.year == day.year,
    );
    if (idx < 0) return;
    // WHY 84.0: approximate tile height when tasks collapsed.
    // Actual scroll position may drift when tasks are expanded
    // WHY 84.0: approximate tile height when tasks collapsed.
    // Actual scroll position may drift when tasks are expanded
    // → postFrameCallback ensures list is built before scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          idx * 84.0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // ── Calendar day cell with colored dot ──────────────────
  Widget _calendarDayCell(
    BuildContext ctx,
    DateTime day, {
    required bool isSelected,
    required bool isToday,
  }) {
    final dotColor = _dotColor(day);
    final hasDot = dotColor != Colors.transparent;
    final colorScheme = Theme.of(ctx).colorScheme;

    Color? bgColor;
    Color textColor = colorScheme.onSurface;

    if (isSelected) {
      bgColor = colorScheme.primary;
      textColor = Colors.white;
    } else if (isToday) {
      bgColor = colorScheme.primary.withValues(alpha: 0.15);
      textColor = colorScheme.primary;
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday || isSelected
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: hasDot
                  ? (isSelected ? Colors.white70 : dotColor)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  // ── All days for list ─────────────────────────────────────
  // ← CHANGED: _DayEntry now exposes dateStr for taskProvider
  List<_DayEntry> get _allDaysInMonth {
    final now = DateTime.now();
    final lastDay = DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
      0,
    ).day;
    final entries = <_DayEntry>[];
    for (int d = lastDay; d >= 1; d--) {
      final date = DateTime(_focusedMonth.year, _focusedMonth.month, d);
      if (date.isAfter(now)) continue;
      entries.add(_DayEntry(date: date, record: _recordFor(date)));
    }
    return entries;
  }

  int get _presentCount =>
      _records.where((r) => r['status'] == 'present').length;
  int get _wfhCount => _records.where((r) => r['status'] == 'wfh').length;
  int get _absentCount => _records.where((r) => r['status'] == 'absent').length;
  int get _lateCount => _records.where((r) => r['is_late'] == true).length;

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _focusedMonth.year == now.year && _focusedMonth.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Attendance'), centerTitle: true),
      body: GestureDetector(
        onHorizontalDragEnd: (d) {
          if (d.primaryVelocity == null) return;
          if (d.primaryVelocity! < -100) _nextMonth();
          if (d.primaryVelocity! > 100) _previousMonth();
        },
        child: Column(
          children: [
            // ── Month Bar ──────────────────────────────────
            _MonthBar(
              month: _focusedMonth,
              isCurrentMonth: _isCurrentMonth,
              canGoNext: _canGoNext,
              onPrevious: _previousMonth,
              onNext: _nextMonth,
              onCalendarTap: _showCalendarSheet,
            ),

            // ── Summary Bar ────────────────────────────────
            if (!_isLoading && _error == null)
              _MonthlySummary(
                present: _presentCount,
                wfh: _wfhCount,
                absent: _absentCount,
                late: _lateCount,
              ),

            // ── Day List ───────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _ErrorView(error: _error!, onRetry: _loadHistory)
                  : _allDaysInMonth.isEmpty
                  ? const Center(
                      child: Text(
                        'No records this month',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadHistory,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: _allDaysInMonth.length,
                        itemBuilder: (_, i) {
                          final e = _allDaysInMonth[i];
                          return _DayTile(
                            entry: e,
                            isSelected:
                                _selectedDay != null &&
                                isSameDay(e.date, _selectedDay!),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _MonthBar ──────────────────────────────────────────────────
class _MonthBar extends StatelessWidget {
  final DateTime month;
  final bool isCurrentMonth;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onCalendarTap;

  const _MonthBar({
    required this.month,
    required this.isCurrentMonth,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
    required this.onCalendarTap,
  });

  @override
  Widget build(BuildContext context) {
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
            child: GestureDetector(
              onTap: onCalendarTap,
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
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

// ── _LegendDot ─────────────────────────────────────────────────
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

// ── _MonthlySummary ────────────────────────────────────────────
class _MonthlySummary extends StatelessWidget {
  final int present;
  final int wfh;
  final int absent;
  final int late;

  const _MonthlySummary({
    required this.present,
    required this.wfh,
    required this.absent,
    required this.late,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryChip(
            label: 'Present',
            count: present,
            color: Colors.green,
            emoji: '🏢',
          ),
          _SummaryChip(
            label: 'WFH',
            count: wfh,
            color: Colors.blue,
            emoji: '🏠',
          ),
          _SummaryChip(
            label: 'Absent',
            count: absent,
            color: Colors.red,
            emoji: '❌',
          ),
          _SummaryChip(
            label: 'Late',
            count: late,
            color: Colors.orange,
            emoji: '⚠️',
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final String emoji;

  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 2),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
        ),
      ],
    );
  }
}

// ── _DayTile ───────────────────────────────────────────────────
// ← CHANGED: TaskSection injected at the bottom of each tile
class _DayTile extends StatelessWidget {
  final _DayEntry entry;
  final bool isSelected;

  const _DayTile({required this.entry, this.isSelected = false});

  (String, String, Color) get _statusInfo {
    final status = entry.record?['status'] as String?;
    return switch (status) {
      'present' => ('🏢', 'Present', Colors.green),
      'wfh' => ('🏠', 'WFH', Colors.blue),
      'absent' => ('❌', 'Absent', Colors.red),
      _ => ('—', 'Not Marked', Colors.grey),
    };
  }

  String? _formatTime(String? iso) {
    if (iso == null) return null;
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  bool get _isToday {
    final now = DateTime.now();
    return entry.date.year == now.year &&
        entry.date.month == now.month &&
        entry.date.day == now.day;
  }

  bool get _isWeekend =>
      entry.date.weekday == DateTime.saturday ||
      entry.date.weekday == DateTime.sunday;

  @override
  Widget build(BuildContext context) {
    final (emoji, label, color) = _statusInfo;
    final record = entry.record;
    final hasRecord = record != null;
    final isLate = record?['is_late'] as bool? ?? false;
    final totalHours = (record?['total_hours'] as num?)?.toDouble();
    final checkIn = _formatTime(record?['check_in_time'] as String?);
    final checkOut = _formatTime(record?['check_out_time'] as String?);

    // ← NEW: pull attendance ID for task FK
    final attendanceId = record?['id'] as String?;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? color.withValues(alpha: 0.12)
            : _isToday
            ? color.withValues(alpha: 0.07)
            : _isWeekend
            ? Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? color.withValues(alpha: 0.6)
              : _isToday
              ? color.withValues(alpha: 0.4)
              : Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: isSelected || _isToday ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          // ← CHANGED: Row → Column so
          // TaskSection sits below attendance info
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Original attendance row ──────────────
            Row(
              children: [
                // ── Date box ──────────────────────────
                Container(
                  width: 48,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _isWeekend && !hasRecord
                        ? Colors.grey.withValues(alpha: 0.08)
                        : color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('dd').format(entry.date),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: hasRecord ? color : Colors.grey,
                        ),
                      ),
                      Text(
                        DateFormat('EEE').format(entry.date),
                        style: TextStyle(
                          fontSize: 10,
                          color: hasRecord
                              ? color.withValues(alpha: 0.8)
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 14),

                // ── Status + time details ─────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                          if (_isToday) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Today',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          if (isLate) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.amber.withValues(alpha: 0.5),
                                ),
                              ),
                              child: const Text(
                                '⚠️ Late',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      if (hasRecord && checkIn != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.login_rounded,
                              size: 12,
                              color: Colors.green.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              checkIn,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                              ),
                            ),
                            if (checkOut != null) ...[
                              const SizedBox(width: 10),
                              Icon(
                                Icons.logout_rounded,
                                size: 12,
                                color: Colors.red.withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                checkOut,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                            if (totalHours != null) ...[
                              const SizedBox(width: 10),
                              Icon(
                                Icons.access_time_rounded,
                                size: 12,
                                color: Colors.grey.withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${totalHours.toStringAsFixed(1)}h',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],

                      if (hasRecord &&
                          checkIn != null &&
                          checkOut == null &&
                          record['status'] != 'absent') ...[
                        const SizedBox(height: 2),
                        Text(
                          'Still checked in',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.withValues(alpha: 0.7),
                          ),
                        ),
                      ],

                      if (_isWeekend && !hasRecord)
                        Text(
                          'Weekend',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // ── TaskSection ──────────────────────────────
            // ← NEW: dropped here — sits below attendance
            // info, full tile width, collapsed by default
            TaskSection(date: entry.dateStr, attendanceId: attendanceId),
          ],
        ),
      ),
    );
  }
}

// ── _ErrorView ─────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// ── _DayEntry ──────────────────────────────────────────────────
// ← CHANGED: added dateStr getter so TaskSection + loadForDates
//   can reference the formatted date without re-computing it
class _DayEntry {
  final DateTime date;
  final Map<String, dynamic>? record;

  const _DayEntry({required this.date, this.record});

  // "2026-03-31" — matches Supabase DATE column format
  String get dateStr =>
      '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
